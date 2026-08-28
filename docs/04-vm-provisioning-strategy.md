# P1.4 — Estrategia de aprovisionamiento de VMs

> **Proyecto:** P1 · Infraestructura Base
> **Mini-proyecto:** 1.4 — Template Ubuntu + cloud-init
> **Estado:** Cerrado (sesión 3)
> **Documentos relacionados:** [`05-bastion-host-pattern.md`](05-bastion-host-pattern.md) · [`06-linux-baseline-spec.md`](06-linux-baseline-spec.md)

---

## 1. Problema que resuelve

Instalar Ubuntu a mano desde una ISO cuesta entre veinte minutos y media hora, y produce una máquina distinta cada vez: el particionado que decidiste ese día, los paquetes que recordaste marcar, la configuración de SSH que aplicaste de memoria. En una plataforma que va a levantar bastión, host de aplicación, base de datos, dos o tres nodos de Kubernetes y un servidor de observabilidad, eso es inaceptable por dos motivos: el tiempo y, sobre todo, **la divergencia**.

La divergencia es el problema real. Dos máquinas que deberían ser idénticas y no lo son producen fallos que solo ocurren en una de ellas, y esos son los más caros de diagnosticar.

El objetivo del mini-proyecto es que aprovisionar una máquina nueva cueste **menos de 90 segundos** y produzca siempre exactamente lo mismo.

---

## 2. Decisión: imagen cloud + cloud-init, no ISO

| Método | Tiempo | Reproducibilidad | Traduce a IaC |
|---|---|---|---|
| ISO + instalación manual | 20-30 min | Nula | No |
| ISO + autoinstall (subiquity) | 10-15 min | Alta | Parcialmente |
| **Imagen cloud + cloud-init** (elegido) | < 90 s | Total | Sí, directamente |

Se elige la imagen cloud oficial de Ubuntu con cloud-init por una razón que va más allá de la velocidad: **es el mismo mecanismo que usan AWS, Azure y GCP para arrancar instancias**. Aprender a aprovisionar así no es aprender una particularidad de Proxmox; es aprender el modelo que se va a reutilizar en P5 con Terraform sobre EC2.

El patrón mental que se establece aquí —una plantilla inmutable más datos de configuración inyectados en el arranque— es el que sostiene todo lo que viene después.

---

## 3. La plantilla

VM 9000, `ubuntu-24-tpl`, construida sobre la imagen cloud de Ubuntu 24.04 LTS.

### 3.1 Inyección del guest agent antes de convertir en plantilla

```bash
virt-customize -a ubuntu-24.04-server-cloudimg-amd64.img --install qemu-guest-agent
```

Se instala **offline sobre la imagen**, antes de crear la VM. Instalarlo después, máquina por máquina, reintroduce exactamente la divergencia que la plantilla pretende eliminar.

Esta decisión resultó ser más importante de lo previsto. El guest agent proporciona:

- La dirección IP visible en la interfaz de Proxmox.
- Backups consistentes en caliente (congelación del sistema de archivos).
- Apagado ordenado.
- **Un canal de control independiente de la red.**

Ese último punto salvó la migración de la sesión 7: cuando las dos VMs quedaron aisladas en la red antigua, el guest agent fue la única vía para reconfigurarlas sin apagarlas. Ver [`../runbooks/04-vm-network-reconfig-guest-agent.md`](../runbooks/04-vm-network-reconfig-guest-agent.md).

### 3.2 Configuración inyectada

Un snippet de cloud-init define el usuario, las claves SSH autorizadas, los paquetes base y el endurecimiento inicial de SSH. Cada VM recibe además su direccionamiento por `ipconfig0`.

---

## 4. Trade-off documentado: solo clave SSH, sin contraseña de consola

La plantilla configura **únicamente autenticación por clave**. Es la decisión correcta desde el punto de vista de seguridad, y tiene un coste que conviene conocer antes de pagarlo.

**Lo que pasó en la sesión 4:** ambas VMs perdieron SSH tras un reinicio. La consola de Proxmox estaba disponible, pero sin contraseña local **no había forma de usarla**. La recuperación exigió apagar las máquinas y editar sus discos con `guestfish`.

**Lo que se aprendió:** una consola sin contraseña es una puerta que existe pero no se puede abrir. Las opciones razonables son dos, y hay que elegir conscientemente:

1. Aceptarlo y garantizar que el guest agent está siempre presente como canal alternativo (lo que se hace aquí).
2. Definir una contraseña de consola para las máquinas de infraestructura, aunque el acceso normal siga siendo por clave.

Un detalle que confunde: `cipassword` en Proxmox **no se reaplica** en reinicios posteriores, así que inyectarlo durante una emergencia no funciona como se espera. La configuración de red mediante `ipconfig0`, en cambio, **sí se reaplica** al cambiarla y reiniciar — comprobado en la sesión 7.

---

## 5. Incidente: el disco heredado del clon

Las VMs clonadas nacían con un disco de ~3,5 GB pese a haber indicado un tamaño mayor en el asistente. La causa es que **el clon hereda el tamaño del disco base de la imagen cloud**, que viene deliberadamente pequeño.

Redimensionar en caliente son tres pasos, y saltarse cualquiera de ellos deja el trabajo a medias:

```bash
qm disk resize <vmid> scsi1 +16G     # el disco virtual
growpart /dev/sda 1                  # la tabla de particiones
resize2fs /dev/sda1                  # el sistema de archivos
```

Tres capas independientes. Ampliar el disco sin ampliar la partición no da un solo byte más de espacio utilizable.

Registrado como DT-18, con resolución prevista: automatizarlo en el módulo de Terraform de P5, donde el tamaño pasa a ser un parámetro declarativo.

---

## 6. Inventario aprovisionado

| VMID | Hostname | Recursos | Almacenamiento | Rol |
|---|---|---|---|---|
| 9000 | `ubuntu-24-tpl` | 2 vCPU / 2 GB | `local-lvm` | Plantilla |
| 110 | `bastion-prod-01` | 1 vCPU / 2 GB / 20 GB | `local-lvm-nvme1` | Bastión SSH |
| 120 | `app-prod-01` | 2 vCPU / 4 GB / 40 GB | `local-lvm-nvme1` | Host Docker |

El dimensionamiento del bastión es deliberadamente austero: no corre cargas, solo termina sesiones SSH. `app-prod-01` va más holgado porque en P2 alojará la API, PostgreSQL y Redis en contenedores.

> Ambas nacieron por error en `local-lvm`, el pool del disco del sistema, en lugar del pool dedicado. Corregido con `qm move-disk` en la sesión 4 tras un aviso de sobreaprovisionamiento del thin-pool. Ver [`03-storage-design.md`](03-storage-design.md).

---

## 7. Validación

Una VM no se considera aprovisionada hasta que:

- [ ] `cloud-init status` devuelve `done`.
- [ ] `hostnamectl` muestra el nombre correcto, no el heredado del snippet.
- [ ] `ip a` muestra la dirección esperada.
- [ ] SSH con clave funciona; con contraseña, no.
- [ ] `systemctl is-enabled ssh.service` devuelve `enabled` — no basta con que esté `active`.
- [ ] `df -h /` refleja el tamaño de disco real, no el heredado.
- [ ] El guest agent responde: `qm guest cmd <vmid> network-get-interfaces`.

El quinto punto está en la lista precisamente porque su ausencia causó el incidente de la sesión 4.

---

## 8. Deuda técnica

| ID | Deuda | Resolución prevista |
|---|---|---|
| DT-18 | Redimensionado de disco manual post-clon | Automatizar en Terraform (P5) |
| DT-20 | Divergencia entre VMs creadas por CLI y por interfaz web | ✅ Resuelta: baseline único parametrizado |
| — | Sin contraseña de consola en las VMs | Decisión consciente; mitigada por el guest agent |
