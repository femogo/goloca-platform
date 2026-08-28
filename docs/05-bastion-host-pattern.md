# P1.5 — Patrón bastión y flujo de trabajo del desarrollador

> **Proyecto:** P1 · Infraestructura Base
> **Mini-proyecto:** 1.5 — Bastion host + VS Code Remote SSH
> **Estado:** Cerrado (sesión 3)
> **Documentos relacionados:** [`04-vm-provisioning-strategy.md`](04-vm-provisioning-strategy.md) · [`06-hardening-checklist.md`](06-hardening-checklist.md)

---

## 1. Problema de negocio

En Goloca AI ningún ingeniero abre una sesión SSH directa contra un servidor de aplicación. Dos razones, y la segunda pesa más de lo que parece:

**Superficie de ataque.** Cada host con SSH expuesto es una puerta que hay que vigilar, parchear y auditar. Con un bastión, hay una sola puerta.

**Trazabilidad.** El AI Act europeo y cualquier auditoría razonable exigen saber quién accedió a qué y cuándo. Con accesos directos distribuidos, esa información está repartida en los logs de cada máquina. Con un bastión, todo pasa por un punto que registra.

Es el mismo razonamiento que hay detrás de AWS Systems Manager Session Manager o de Azure Bastion. La implementación es más humilde; el patrón es idéntico y se explica igual en una entrevista.

---

## 2. Arquitectura

```
   Workstation (Windows)
        │  clave Ed25519
        │  SSH :2222
        ▼
   bastion-prod-01  ◄── único host con SSH alcanzable
        │                desde la red de gestión
        │  ProxyJump
        ▼
   app-prod-01      ◄── UFW: SSH solo desde el bastión
   db, k3s, ...         nunca desde la estación de trabajo
```

La regla de UFW de `app-prod-01` no permite una subred: permite **exactamente la dirección del bastión**. Eso convierte el patrón en algo aplicado, no en una convención que se respeta por costumbre. Aunque alguien intente conectar directamente desde su equipo, el cortafuegos del host lo rechaza.

---

## 3. Gestión de claves

- **Ed25519**, no RSA. Claves más cortas, verificación más rápida, sin los tamaños mínimos que hacen incómodo a RSA hoy.
- **Una clave por estación de trabajo**, no una compartida. Revocar el acceso de un equipo comprometido no debe obligar a rotar las claves de todos.
- Las claves públicas se inyectan en el aprovisionamiento vía cloud-init, no se copian a mano después.

> **Desviación D-08.** La clave se generó en Windows, no en el host Proxmox. Un intento previo de copiarla desde Proxmox rompió el formato del fichero. La clave operativa es la de Windows; la de Proxmox se descartó. Documentado porque explica por qué el par de claves no vive donde cabría esperar.

---

## 4. Endurecimiento de SSH

Se aplica en `/etc/ssh/sshd_config.d/00-goloca.conf` — un fichero *drop-in*, no una edición del `sshd_config` principal. Así una actualización del paquete no pisa la configuración ni genera un conflicto de fusión.

| Directiva | Valor | Motivo |
|---|---|---|
| `Port` | 2222 | Reduce el ruido de escaneos automáticos. No es seguridad, es higiene de logs |
| `PasswordAuthentication` | `no` | Solo clave. Elimina la fuerza bruta como vector |
| `PermitRootLogin` | `no` | Escalada explícita vía `sudo`, que además deja rastro |
| `AllowUsers` | `ubuntu` | Lista blanca, no lista negra |
| `MaxAuthTries` | 3 | Corta los intentos encadenados |
| `ClientAliveInterval` | 300 | Cierra sesiones colgadas |

Cambiar el puerto **no es una medida de seguridad** y conviene decirlo: un escaneo de puertos lo encuentra en segundos. Lo que hace es reducir drásticamente el ruido de los bots que solo prueban el 22, y eso sí tiene valor operativo — un log de autenticación con cien líneas al día es un log que alguien lee; con cien mil, no.

---

## 5. Incidente: la activación por socket de Ubuntu 24.04

**Síntoma:** `sshd_config` especificaba el puerto 2222, el servicio se reiniciaba sin error, y SSH seguía escuchando en el 22.

**Causa:** Ubuntu 24.04 arranca SSH mediante **activación por socket**. `ssh.socket` es quien decide en qué puerto se escucha, y **ignora la directiva `Port`** del fichero de configuración. El servicio se comporta como si el cambio no existiera.

**Resolución:**

```bash
systemctl disable --now ssh.socket
systemctl mask ssh.socket
systemctl enable --now ssh.service
```

**El detalle que convirtió esto en un incidente mayor:** la primera vez se ejecutó `mask` y `restart`, pero **no `enable`**. El servicio quedó corriendo en memoria, sin enlace en `multi-user.target.wants/`. Funcionó perfectamente hasta el siguiente reinicio, que llegó una sesión después y dejó **ambas VMs sin SSH a la vez**.

`restart` y `enable` operan sobre ejes independientes:

| | `active` (corre ahora) | `enabled` (arranca en el boot) |
|---|---|---|
| `restart` | lo cambia | no lo toca |
| `enable` | no lo toca | lo cambia |

La recuperación exigió editar los discos de las VMs apagadas con `guestfish` para crear el symlink a mano. Ver [`../runbooks/06-vm-ssh-recovery-guestfish.md`](../runbooks/06-vm-ssh-recovery-guestfish.md) y [`../runbooks/06-systemd-enable-offline.md`](../runbooks/06-systemd-enable-offline.md).

Registrado como DT-17. Desde entonces, **verificar `systemctl is-enabled` antes de cualquier reinicio** es un paso fijo de los procedimientos.

---

## 6. Flujo de trabajo del desarrollador

Configuración en `~/.ssh/config` de la estación de trabajo:

```
Host goloca-bastion
    HostName 10.20.0.40
    User ubuntu
    Port 2222
    IdentityFile ~/.ssh/id_ed25519_goloca

Host goloca-app01
    HostName 10.20.0.20
    User ubuntu
    Port 2222
    IdentityFile ~/.ssh/id_ed25519_goloca
    ProxyJump goloca-bastion

Host goloca-pve
    HostName 10.20.0.10
    User root
```

`ProxyJump` establece el túnel a través del bastión de forma transparente. La autenticación es **de extremo a extremo**: la clave privada nunca sale de la estación de trabajo, y el bastión no necesita tenerla. Es una diferencia importante respecto a copiar la clave al bastión, que convertiría ese host en un objetivo mucho más valioso.

VS Code Remote SSH lee esta misma configuración, así que abrir una carpeta remota de `app-prod-01` funciona sin ajustes adicionales: el editor hereda el salto.

> Un efecto secundario práctico: `ProxyJump` sirve también para alcanzar máquinas en redes a las que la estación de trabajo no tiene ruta directa, mientras el bastión sí. Se usó en la sesión 7 como vía para llegar a las VMs durante la migración.

---

## 7. Validación

- [ ] SSH al bastión con clave funciona; con contraseña, falla.
- [ ] SSH a `app-prod-01` funciona **solo** a través de `ProxyJump`.
- [ ] SSH directo a `app-prod-01` desde la estación de trabajo es rechazado por UFW.
- [ ] `root` no puede autenticarse en ninguna de las dos.
- [ ] VS Code Remote SSH conecta a `goloca-app01`.
- [ ] `systemctl is-enabled ssh.service` devuelve `enabled` en ambas.
- [ ] Tras un reinicio, SSH sigue disponible sin intervención.

Los dos últimos existen porque su ausencia costó una sesión entera de recuperación.

---

## 8. Deuda técnica

| ID | Deuda | Resolución prevista |
|---|---|---|
| DT-01 | Bastión en SERVERS en lugar de MGMT | Migración vía VLAN 10 sobre el troncal (P1.1 fase C) |
| DT-08 | Fail2ban instalado pero sin afinar | P6: ajustar al puerto 2222 + integración con el cortafuegos |
| DT-26 | Reglas UFW obsoletas de la red antigua | `ufw delete` tras confirmar estabilidad |
| — | Sin registro centralizado de sesiones del bastión | P4: envío del log de autenticación a Loki |

El último punto merece una nota: **el patrón bastión aporta trazabilidad solo si alguien recoge esos registros**. Hoy los logs de sesión viven en el propio bastión y se pierden si la máquina desaparece. Hasta P4 la trazabilidad es potencial, no efectiva.
