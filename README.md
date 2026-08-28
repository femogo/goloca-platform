# Goloca AI — DevOps Infrastructure Platform

**Laboratorio de infraestructura de 6 meses sobre hardware real. Sin ejercicios académicos.**

Construcción desde cero de la plataforma que sustentaría a **Goloca AI**, una startup ficticia
de agentes de IA para empresa. Cada componente se despliega, se rompe a propósito y se
documenta como si estuviera en producción: persistencia, observabilidad, control de acceso y
recuperación ante fallos.

Este repositorio no es un tutorial seguido paso a paso. Es la bitácora de una infraestructura
que existe, con sus decisiones justificadas, sus desviaciones del plan y sus incidentes reales.

---

## Estado actual

**Proyecto 1 de 6 · ~72% · última sesión: 28 agosto 2026**

| Mini-proyecto | Estado |
|---|---|
| 1.1 · Segmentación de red con FortiGate | 🔄 En progreso (~40%) |
| 1.2 · SSL-VPN + DDNS | ⏸️ Pendiente |
| 1.3 · Proxmox VE bare-metal | ✅ Completado |
| 1.4 · Template Ubuntu + cloud-init | ✅ Completado |
| 1.5 · Bastión + VS Code Remote SSH | ✅ Completado |
| 1.6 · Baseline Linux + Docker | ✅ Completado |

**Funcionando ahora mismo:** FortiGate como router y firewall perimetral, hipervisor Proxmox
con dos VMs endurecidas y un contenedor LXC, toda la infraestructura del laboratorio migrada
a `10.20.0.0/24` detrás del cortafuegos, y salida a Internet mediante política con NAT.

**Aún no hecho:** el switch interno del FortiGate sigue sin partir en zonas (la red del
laboratorio es plana), la política de salida es transitoria y permisiva, y no hay acceso
remoto por VPN.

El detalle sesión a sesión, con decisiones, desviaciones y deuda técnica, está en
[`PROGRESS-LOG.md`](PROGRESS-LOG.md). El plan completo de los 6 meses, en
[`ROADMAP.md`](ROADMAP.md).

---

## Arquitectura de red

Segmentación híbrida: los equipos físicos entran por puertos del FortiGate; las máquinas
virtuales llegan etiquetadas por un troncal 802.1Q hacia el hipervisor.

```
                    INTERNET
                        │
                 HGU Movistar ──┬── AP WiFi        RED DOMÉSTICA
                                │   (fuera del lab)  192.168.1.0/24
                                ▼ WAN1
        ╔═══════════════════════════════════════════════════╗
        ║          FortiGate 30E · fgt-prod-01              ║
        ║                                                   ║
        ║  Grupo MGMT (puertos físicos)   Troncal 802.1Q    ║
        ║       10.10.0.1/24              VLAN 20 SERVERS   ║
        ║                                 VLAN 30 DMZ       ║
        ╚═══┬══════════════════════════════════┬════════════╝
            │                                  │
      workstations                    ┌────────▼─────────┐
      NIC de gestión                  │  Proxmox VE 9.2  │
      del hipervisor                  │  vmbr0 VLAN-aware│
                                      │                  │
                                      │ bastión · app01  │
                                      │ nginx-dmz (P2)   │
                                      └──────────────────┘
```

**Por qué un troncal y no un puerto por zona.** El hipervisor tiene una sola NIC integrada.
Con segmentación puramente física, toda máquina virtual quedaría encerrada en la zona a la que
estuviese puenteada esa tarjeta, lo que hacía imposible el reverse proxy en DMZ previsto para
P2. El enlace Proxmox↔FortiGate es punto a punto —no interviene ningún switch— así que el
motivo original para descartar VLANs (el switch no es gestionable) no aplica en ese tramo.
Razonamiento completo en la sección 4.1 del roadmap.

**Por qué la NIC USB se dedica a gestión.** Separar plano de gestión y plano de datos hace que
un error en las VLANs o los bridges no deje al hipervisor incomunicado. Importa: el servidor
no tiene monitor ni teclado conectados.

---

## Recorrido por los 6 proyectos

| Proyecto | Mes | Contenido | Estado |
|---|---|---|---|
| **P1** | 1 | Networking, FortiGate, Proxmox, VMs Ubuntu endurecidas | 🔄 En progreso |
| **P2** | 2 | Docker Compose, NGINX en DMZ, PostgreSQL, Redis | ⏳ Siguiente |
| **P3** | 3 | K3s, Helm, Ingress, pgvector | ⏳ Futuro |
| **P4** | 4 | GitHub Actions, Trivy, Prometheus, Grafana, Loki | ⏳ Futuro |
| **P5** | 5 | AWS, Terraform, Ansible, VPN site-to-site | ⏳ Futuro |
| **P6** | 6 | Hardening CIS, Vault, disaster recovery, Ollama en GPU | ⏳ Futuro |

Cada proyecto reutiliza la infraestructura del anterior. Nada se tira y nada se despliega
en el vacío.

---

## Incidentes reales resueltos

La parte del portfolio que no se puede copiar de un tutorial.

| Incidente | Causa raíz | Resolución |
|---|---|---|
| Ambas VMs sin SSH tras reiniciar | `systemctl restart` no implica `enable`: el servicio corría en memoria sin enlace en `multi-user.target.wants/` | Edición del disco de la VM apagada con `guestfish` para crear el symlink. [Runbook](runbooks/06-vm-ssh-recovery-guestfish.md) |
| Clientes de la LAN sin salida a Internet, sin error visible | Subredes solapadas: `192.168.1.0/24` presente en la interfaz WAN y en la LAN a la vez, dejando ambiguo el camino de retorno | Renumerar la red interna a `10.20.0.1/24` |
| Aviso de sobreaprovisionamiento del thin-pool LVM | Las VMs nacieron en el pool del disco del sistema en lugar del pool dedicado | `qm move-disk` en caliente. [Runbook](runbooks/03-storage-move-disk.md) |
| FortiGate de segunda mano sin credenciales y con el botón de reset inoperativo | — | Consola serie y cuenta `maintainer`, cuya contraseña deriva del número de serie |
| Intentos de login espurios en la consola serie | Diafonía TX/RX del cable: el equipo recibía su propio eco como pulsaciones | Reasentar el conector y cambiar de puerto USB |
| Migrar el hipervisor de red sin monitor ni teclado | — | Direccionamiento dual en caliente: responde en la red vieja y la nueva a la vez hasta confirmar |
| Reconfigurar VMs aisladas en la red equivocada | — | `qemu-guest-agent` por canal virtio, sin depender de la red ni de contraseña de consola |

---

## Hardware

| Componente | Especificación |
|---|---|
| **Host Proxmox** | Intel i5 10ª gen · 32 GB DDR4 · RTX 4060 (8 GB) |
| **Almacenamiento** | 4× NVMe (3×238 GB + 1×465 GB) + SSD SATA 223 GB para backups |
| **Red del host** | NIC integrada (troncal 802.1Q) + adaptador USB 3.0-Gigabit (gestión) |
| **Firewall** | FortiGate 30E · FortiOS 6.2.5 |
| **Switch** | D-Link DGS-1005P (L2 no gestionable) — situado **delante** del FortiGate, en la red doméstica |
| **Workstations** | PC Windows (desarrollo) · Portátil (administración) |

> El HDD de 1 TB que figuraba en la planificación inicial no está presente (desviación D-04).
> Los backups van al SSD SATA.

---

## Stack técnico

**En uso hoy:** FortiGate 30E · Proxmox VE 9.2 · LVM-thin · Ubuntu Server 24.04 LTS ·
cloud-init · OpenSSH con ProxyJump · UFW · systemd/journald · Docker Engine · VLANs 802.1Q

**Por venir:** Docker Compose · NGINX · PostgreSQL 16 · Redis · K3s · Helm · MetalLB ·
GitHub Actions · Trivy · Prometheus · Grafana · Loki · AWS · Terraform · Ansible · Vault ·
Ollama

---

## Estructura del repositorio

```
goloca-platform/
├── README.md                     Este archivo
├── ROADMAP.md                    Plan técnico de los 6 meses y decisiones de arquitectura
├── PROGRESS-LOG.md               Bitácora operacional: sesiones, incidentes, deuda técnica
├── docs/                         Documentación técnica con trade-offs
│   ├── 03-proxmox-architecture-decision.md
│   ├── 03-storage-design.md
│   ├── 06-linux-baseline-spec.md
│   ├── 06-hardening-checklist.md
│   ├── 06-docker-installation.md
│   └── 06-defense-in-depth-rationale.md
├── infrastructure/
│   ├── fortigate/backups/        Configuraciones sanitizadas del firewall
│   ├── linux-baseline/           baseline-setup.sh (idempotente, parametrizado por rol)
│   ├── proxmox/
│   └── docker/
├── runbooks/                     Procedimientos autocontenidos para ejecutar bajo presión
│   ├── 03-storage-move-disk.md
│   ├── 06-vm-ssh-recovery-guestfish.md
│   ├── 06-systemd-enable-offline.md
│   ├── 06-ufw-remote-safe-apply.md
│   └── 06-docker-install-validate.md
└── scripts/
```

Los documentos llevan el prefijo del mini-proyecto que los originó. Los runbooks son
autocontenidos a propósito: deben poder ejecutarse sin abrir ningún otro fichero.

---

## Nota sobre datos sensibles

Este repositorio documenta infraestructura real en funcionamiento, por lo que la información
que permitiría localizarla o acceder a ella se sustituye deliberadamente por marcadores:

| Marcador | Sustituye a |
|---|---|
| `203.0.113.10` | La IP pública real (rango RFC 5737, reservado para documentación) |
| `<DDNS-HOSTNAME>` | El nombre DDNS real del laboratorio |
| `FGT30E<SERIAL-REDACTED>` | El número de serie del FortiGate |

El serial se redacta porque la cuenta de recuperación `maintainer` de FortiOS deriva su
contraseña de él.

Las configuraciones de red se publican **sanitizadas**: los hashes de credenciales
(`set password ENC ...`) y las claves privadas de certificados nunca se versionan. Ver
[`infrastructure/fortigate/backups/README.md`](infrastructure/fortigate/backups/README.md).

El direccionamiento privado (`10.x`, `192.168.x`) sí se documenta íntegro: es RFC 1918, no es
accesible desde Internet, y es precisamente el contenido técnico que este portfolio muestra.

---

## Objetivo

Poder sostener una conversación técnica sobre arquitectura de red, troubleshooting real,
observabilidad, automatización y decisiones de infraestructura — no recitar herramientas.

**Perfiles objetivo:** DevOps Junior · Cloud Engineer Junior · Platform Engineer Junior ·
SRE Junior, en remoto en Europa.

---

## Contacto

- **Autor:** Fernando Morales ([@femogo](https://github.com/femogo))
- **Inicio:** mayo 2026

---

**Última actualización:** 28 de agosto de 2026
