# PROGRESS LOG — GOLOCA AI INFRASTRUCTURE PLATFORM

> **Bitácora incremental** del avance del roadmap. Se actualiza en cada sesión de trabajo.  
> **Fuente de verdad estratégica:** `ROADMAP.md`  
> **Fuente de verdad operacional:** este archivo.

---

## ESTADO GLOBAL ACTUAL

**Fecha última actualización:** 24 mayo 2026 (v1.3 — fin sesión 4)  
**Proyecto activo:** P1 — Infraestructura Base, Networking Real y Virtualización  
**Mini-proyecto activo:** P1.1 — Segmentación FortiGate (bloqueado por cable; siguiente cuando llegue)  
**Mini-proyectos bloqueados:** P1.1 y P1.2 (FortiGate, esperando cable de consola)

---

## RESUMEN EJECUTIVO DEL ESTADO

| Mini-Proyecto | Estado | Bloqueador |
|---|---|---|
| P1.1 — Segmentación FortiGate | ⏸️ BLOQUEADO | Cable de consola en pedido |
| P1.2 — SSL-VPN + DDNS | ⏸️ PENDIENTE | Depende de P1.1 |
| P1.3 — Proxmox VE bare-metal | ✅ COMPLETADO | Cerrado 100% (DT-11/14/16 saldadas) |
| P1.4 — Template Ubuntu + Cloud-Init | ✅ COMPLETADO | — |
| P1.5 — Bastión + VS Code Remote SSH | ✅ COMPLETADO | — |
| P1.6 — Linux baseline + Docker | ✅ COMPLETADO | Cerrado en sesión 4 |

**P1 al 67% (4 de 6 mini-proyectos).** Solo restan P1.1 y P1.2, ambos dependientes del cable de consola del FortiGate.

---

## CRONOLOGÍA DE SESIONES

### Sesión 1 — 21 mayo 2026 (tarde-noche)

**Duración:** ~5 horas continuas.  
**Trabajo realizado:**

1. **Definición de empresa ficticia.** Selección de Goloca AI como arquetipo (Plataforma de Agentes IA Empresariales). Cambio inicial desde "Solva AI" → "Goloca AI" por preferencia del aprendiz.

2. **Decisiones arquitectónicas cerradas:**
   - Switch DGS-1005P confirmado no gestionable → segmentación por puertos físicos del FortiGate.
   - Proxmox VE bare-metal sobre el PC servidor (no Hyper-V, no VMware).
   - LVM-thin sobre discos individuales (ZFS descartado por heterogeneidad).
   - HGU Movistar en doble NAT con DMZ Host hacia FortiGate.
   - Bastión provisional en zona SERVERS hasta adaptador USB-Ethernet.

3. **Inventario de hardware confirmado:**
   - PC servidor: i5 10ª gen, 32 GB RAM, RTX 4060.
   - 4 discos NVMe (3 de 238 GB + 1 de 465 GB Samsung) + 1 SSD SATA (PNY 240 GB).
   - FortiGate 30E (con configuración previa desconocida).
   - Switch D-Link DGS-1005P (no gestionable).

4. **Inicio P1.1 — Mini-Proyecto FortiGate.**
   - Reset físico intentado sin éxito (botón existe, no responde al procedimiento estándar).
   - Credenciales `admin` sin contraseña no funcionan (equipo configurado previamente).
   - **Decisión:** acceso vía cable de consola serie + cuenta `maintainer` de emergencia.

5. **Documento maestro creado:** `ROADMAP.md` (v1.2, 790 líneas).

6. **Repositorio GitHub creado:**
   - URL: https://github.com/femogo/goloca-platform
   - Estructura inicial de carpetas: `docs/`, `infrastructure/`, `runbooks/`, `scripts/`.
   - README profesional reescrito.
   - `.gitignore` configurado.
   - Primer commit + push exitoso.

### Sesión 2 — 22 mayo 2026

**Duración:** ~3 horas.  
**Trabajo realizado:**

1. **Decisión:** mientras llega el cable de consola, avanzar con P1.3 (Proxmox) en paralelo.

2. **Identificación de cable:** el aprendiz tenía un cable DB9-RJ45 (no USB-RJ45). Inutilizable sin adaptador. Cable USB-RJ45 con chip FTDI pedido.

3. **Backup datos Windows Server:** sin datos relevantes, sistema borrado.

4. **Descarga ISO Proxmox VE 9.2.** Versión más reciente que la prevista (8.x).

5. **USB booteable creado con Rufus en modo DD.**

6. **BIOS MSI B460M Pro-VDH verificada:** VT-x, VT-d, UEFI, Secure Boot off → todo correcto sin tocar nada.

7. **Instalación Proxmox VE 9.2 completada:**
   - Disco: `/dev/nvme0n1` (238 GB).
   - Hostname original previsto: `pve-prod-01.goloca.lab`.
   - IP original prevista: `10.20.0.10/24`.
   - **Cambio durante la sesión:** sin FortiGate funcional, no hay red 10.20.0.x. IP cambiada temporalmente a `192.168.1.101/24` (red doméstica) editando `/etc/network/interfaces`.

8. **Acceso web Proxmox funcional desde PC Windows:** `https://192.168.1.101:8006`.

9. **Inventario real de discos detectado (corrección a planificación inicial):**
   - `/dev/nvme0n1` 238 GB → Proxmox SO
   - `/dev/nvme1n1` 238 GB → libre
   - `/dev/nvme2n1` 238 GB → libre (no se sabía que existía)
   - `/dev/nvme3n1` 465 GB Samsung → libre
   - `/dev/sda` 223 GB SATA SSD PNY → libre

   **HDD 1 TB previsto en el roadmap original NO está conectado** (al menos no detectado por Proxmox).

10. **Configuración de almacenamiento (ejecutada paso a paso vía CLI):** thin-pools LVM sobre cada NVMe + backup ext4 en el PNY. Troubleshooting de discos en uso (Ubuntu LVM viejo en el PNY) y firmas vfat residuales. Resultado: 4 storages operativos (`local-lvm-nvme1`, `local-lvm-nvme2`, `local-lvm-ssd-samsung`, `backup-pny`).

11. **Boot Manager residual de Windows Server detectado.** Pendiente limpiar EFI (DT-11).

12. **Inicio P1.4 — Template Ubuntu:** lanzada descarga de la imagen cloud Ubuntu 24.04.

13-15. **Pausas formativa y estratégica** (conceptos de virtualización/LVM, visión de producto Goloca AI) + creación de `PROGRESS-LOG.md`.

### Sesión 3 — 23 mayo 2026 (mañana)

**Duración:** ~3 horas.  
**Trabajo realizado:**

1. **P1.4 CERRADO — Template Ubuntu + Cloud-Init.** Template 9000 (`ubuntu-24-tpl`) con qemu-guest-agent inyectado offline. VM 110 (bastion) clonada vía CLI; VM 120 (app01) clonada vía UI. Clave SSH Ed25519 generada en Windows.

2. **P1.5 CERRADO — Bastión + VS Code Remote SSH.** Hardening SSH (`00-goloca.conf`: Port 2222, etc.). **Troubleshooting socket activation (DT-17):** `ssh.socket` de Ubuntu 24.04 ignora el `Port` de sshd_config. Resuelto con `disable + mask ssh.socket` + `restart ssh.service`. ProxyJump Windows → bastión → app01 verificado. VS Code Remote SSH OK.

3. **Troubleshooting de disco (DT-18):** clon de CloudImg hereda disco base (~3.5 GB). Resize en caliente (`qm disk resize` + `growpart` + `resize2fs`) → bastion 19 GB, app01 39 GB.

4. **Corrección de hostname** heredado del snippet (`hostnamectl set-hostname`).

### Sesión 4 — 24 mayo 2026 (madrugada)

**Duración:** ~3 horas.  
**Resumen:** cierre de P1.3, incidente mayor de SSH (DT-17 mal cerrado), migración de almacenamiento, P1.6 completo, generación del primer script de baseline reproducible.

**Trabajo realizado:**

1. **P1.3 CERRADO al 100%.** Saldadas las tres deudas pendientes:
   - **DT-16 (fstab):** verificado que `/mnt/backup-pny` ya estaba en `/etc/fstab` por UUID con `nofail`. UUID confirmado contra `blkid`. (Resuelto entre sesiones; validado aquí).
   - **DT-14 (USB instalación):** `shutdown -h now`, desconexión física del USB Kingston (`/dev/sdb`), reinicio. `/dev/sdb` ya no aparece en `lsblk`.
   - **DT-11 (EFI residual):** `efibootmgr -b {0000,0001,0002,0004} -B` → eliminadas entradas de Windows Boot Manager, Ubuntu viejo, USB Kingston y UEFI OS duplicado. Quedan solo `proxmox` (Boot0003) + genéricas UEFI.
   - **Pendiente menor NO bloqueante:** el BIOS se detiene al arrancar esperando Enter (sin monitor, molesto en reboots desatendidos). Requiere acceso físico al BIOS para desactivar "wait on error/F1". Aparcado hasta tener el FortiGate (DT-22).

2. **INCIDENTE MAYOR — pérdida de SSH en ambas VMs tras reboot.**
   - **Síntoma:** al arrancar las VMs desde la UI (estaban apagadas), SSH rechazaba conexión en 22 y 2222, en bastion Y app01. VMs vivas (ping OK, boot limpio a `multi-user.target`), pero `ssh.service` no escuchaba.
   - **Causa raíz:** DT-17 estaba **mal cerrado** en sesión 3. Se hizo `mask ssh.socket` + `restart ssh.service`, pero NUNCA `enable ssh.service`. El servicio corría en memoria pero sin symlink en `multi-user.target.wants/`. Funcionó hasta el primer reboot, que ocurrió en esta sesión.
   - **Diagnóstico:** sin password de consola (cloud-init solo configuró clave SSH), GRUB no capturable por timing del Esc. Se descartó reset de password vía `cipassword` (cloud-init no reaplica en reboot).
   - **Resolución (técnica nueva → runbook):** edición del disco de la VM **apagada** con `guestfish` (libguestfs, ya instalado de P1.4). Montar `/dev/sda1`, confirmar ausencia del symlink, crear `ln-s /usr/lib/systemd/system/ssh.service → multi-user.target.wants/ssh.service`. Aplicado en **ambas** VMs (bastion por guestfish; app01 igual, porque también había reiniciado y caído en el mismo fallo).
   - **Verificación:** `systemctl is-enabled ssh.service` → `enabled` + `is-active` → `active` en ambas. SSH persiste tras reboot.
   - **Limpieza:** `qm set 110 --delete cipassword` (quitar password temporal inyectado durante el diagnóstico).
   - **Lección:** `restart` ≠ `enable`. Ejes independientes (estado actual vs arranque). DT-17 reclasificado como RESUELTO de verdad.

3. **MIGRACIÓN DE ALMACENAMIENTO — VMs de `local-lvm` a `local-lvm-nvme1`.**
   - **Detonante:** al crear snapshots `pre-baseline-clean`, LVM emitió warnings de sobreaprovisionamiento del thin-pool `pve/data` (`local-lvm`): suma de volúmenes (159 GB) > tamaño del pool, solo 16 GB libres en el VG, sin `thin_pool_autoextend_threshold` configurado. Riesgo real de corrupción de FS si el pool llega al 100%.
   - **Causa raíz:** desviación de sesión 2 no respetada. Ambas VMs (110, 120) nacieron en `local-lvm` (140 GB, disco del SO de Proxmox) en lugar de `local-lvm-nvme1` (230 GB dedicados, vacíos). El log de sesión 2 había decidido explícitamente NO usar `local-lvm` para VMs.
   - **Resolución (técnica nueva → runbook):** `qm move-disk {110,120} scsi1 local-lvm-nvme1 --delete 1`. Uso real movido ~12 GB (sobreaprovisionamiento era potencial, no actual). Verificado: `local-lvm` de vuelta a 3.18% (solo cloudinit drives de 4 MB), ambas VMs en `local-lvm-nvme1`. El symlink de ssh.service (enable) sobrevivió al move (está en el FS de la VM, se copió íntegro).
   - **Pendiente menor:** los cloudinit drives (`ide2`, 4 MB) siguen en `local-lvm`. Irrelevante, regenerables. No se mueven.
   - **Snapshots rehechos** sin warnings, ya en el pool correcto.

4. **P1.6 COMPLETO — Linux baseline + Docker.** Ejecutado pieza a pieza en bastion (didáctico), luego replicado en app01 (validando convergencia).

   | Pieza | bastion-prod-01 | app-prod-01 |
   |---|---|---|
   | 1. apt full-upgrade | ✅ (4 paquetes, 3 de seguridad) | ✅ (0, ya al día) |
   | 2. journald persistente | ✅ `99-goloca.conf` + `usermod -aG adm` | ✅ idéntico |
   | 3. unattended-upgrades | ✅ solo `-security`, `Automatic-Reboot false` | ✅ idéntico |
   | 4. UFW | ✅ SSH 2222 desde `192.168.1.0/24` (MGMT) | ✅ SSH 2222 desde `192.168.1.110` (solo bastión) |
   | 5. herramientas operación | ✅ htop/iotop/iftop/tcpdump/dnsutils/net-tools/jq/lsof/fail2ban | ✅ idéntico |
   | 6. Docker Engine | ─ (n/a, bastión no corre cargas) | ✅ Docker 29.5.2 + Compose v2 (repo oficial) |

   - **journald:** descubierto que persistía "por accidente" (`Storage=auto` + directorio `/var/log/journal` existente). Hecho explícito con drop-in. Tras `usermod -aG adm`, 10 boots de historial visibles (forense del incidente SSH).
   - **unattended-upgrades:** política por defecto incluía el repo general `noble` (actualizaciones funcionales). Comentado vía `sed`; validado con `--dry-run` que `Allowed origins` solo lista `-security`.
   - **UFW:** aplicado con red de seguridad (`nohup sleep 300 && ufw --force disable` en background) por ser cambio de firewall remoto. Verificado con conexión nueva (no solo la sesión abierta) antes de cancelar la red. **DT-21 nueva:** orígenes transitorios `192.168.1.x`, endurecer a `10.10.x`/`10.20.0.40` post-FortiGate.
   - **Docker:** instalado desde `download.docker.com` (NO `apt docker.io`). Clave GPG + repo + 5 paquetes. `enable --now` (verificado `active`+`enabled`, evitando la trampa del incidente). Validación más allá de `hello-world`: NGINX:alpine efímero con port mapping 8080→80, verificado con `docker ps` + `curl -I` (200 OK) + `docker logs` (petición desde `172.17.0.1`, gateway del bridge `docker0`). **DT-07** reafirmada: `usermod -aG docker ubuntu` == root efectivo, mitigado por patrón bastión, rootless a estudiar en P6.

5. **ENTREGABLE — `baseline-setup.sh`.** Script idempotente, parametrizado por rol, que captura las 6 piezas. Cierra DT-19 (baseline a mano) y DT-20 (divergencia bastion/app01) formalmente.
   - Uso: `sudo ./baseline-setup.sh <bastion|app> <origen_ssh_ufw>`.
   - `set -euo pipefail`, validación de args, idempotencia (`grep -q ||`, `[ -f ]`, reglas UFW que no duplican).
   - Ruta repo: `infrastructure/linux-baseline/baseline-setup.sh`.
   - Validado con `bash -n` + `shellcheck` (solo 2 falsos positivos `info` esperados: SC2016 por las comillas simples deliberadas del sed, SC1091 por el source de `/etc/os-release`).
   - **NO ejecutado sobre las VMs actuales** (ya tienen baseline a mano). Se probará sobre VMs limpias en P2 (db-prod-01) y P3 (nodos K3s).

6. **Snapshots de estado baseline creados** (ver tabla en sección de snapshots).

---

## DESVIACIONES DEL PLAN ORIGINAL

Cambios respecto a lo que dice `ROADMAP.md`:

| ID | Desviación | Causa | Impacto | Estado |
|---|---|---|---|---|
| D-01 | Proxmox VE 9.2 instalado (no 8.x previsto) | Versión más reciente disponible | Positivo | Aceptado |
| D-02 | IP Proxmox temporalmente en 192.168.1.101 (no 10.20.0.10) | FortiGate sin configurar (bloqueado por cable) | Temporal. Requiere migración | Aceptado provisional |
| D-03 | 4 NVMe + 1 SATA SSD (no 2 NVMe + 1 SSD + 1 HDD) | Inventario real difiere | Más NVMe disponible. HDD 1 TB no aparece | Aceptado |
| D-04 | HDD 1 TB no detectado por Proxmox | Posiblemente desconectado físicamente | Backups van a SSD PNY | Pendiente verificación física |
| D-05 | P1.3 ejecutado antes de P1.1 y P1.2 | Bloqueo de FortiGate por cable | Orden adaptado | Aceptado provisional |
| D-06 | FortiGate de segunda mano con config previa | No documentado al inicio | Reset físico no funcionó. Requiere `maintainer` vía consola serie | Diagnóstico cerrado, pendiente cable |
| D-07 | VM 110 y 120 nacen con disco 3.5 GB pese al wizard | Clon de CloudImg hereda disco base | Resize manual post-clon | Resuelto en sesión 3 |
| D-08 | Clave SSH Ed25519 generada en Windows, no en Proxmox | Copiar de Proxmox a Windows rompió formato | Clave operativa = la de Windows | Aceptado |
| D-09 | app01 configurado 100% por UI (no cicustom snippet) | Decisión de hacer la 2ª VM por UI | Divergencia bastion/app01 | Resuelto en sesión 4 (baseline convergido + script) |
| **D-10** | **VMs nacieron en `local-lvm` (no `local-lvm-nvme1`)** | **Desviación de sesión 2 no aplicada al clonar** | **Sobreaprovisionamiento thin-pool, riesgo corrupción** | **Resuelto sesión 4 (`qm move-disk`)** |
| **D-11** | **VS Code Server / disco app01 al 96% en sesión 3** | (ya cubierto en D-07) | — | Resuelto sesión 3 |

---

## DEUDAS TÉCNICAS

### Del roadmap original (DT-01 a DT-10)

| ID | Deuda | Resolución prevista | Estado |
|---|---|---|---|
| DT-01 | Bastión en zona SERVERS en lugar de MGMT | Migración con adaptador USB-Ethernet | Pendiente |
| DT-02 | Switch DGS-1005P no gestionable | TP-Link TL-SG108E cuando el lab exceda 4 zonas | Pendiente |
| DT-03 | Proxmox repos no-subscription | Suscripción de pago en prod real | Aceptada (lab) |
| DT-04 | Usuarios VPN locales (no LDAP/AD) | P6: IdP (Authentik/Keycloak/AWS IAM) | Pendiente P6 |
| DT-05 | Doble NAT (HGU + FortiGate) | Opcional: HGU monopuesto | Pendiente opcional |
| DT-06 | Certificado VPN autofirmado | P6: Let's Encrypt via acme.sh | Pendiente P6 |
| DT-07 | Usuario en grupo docker = root | P3: RBAC K8s. P6: rootless Docker | **Reafirmada sesión 4** |
| DT-08 | Sin Fail2ban configurado | P6: afinar puerto 2222 + integración FortiGate | Instalado, sin afinar |
| DT-09 | Sin gestión centralizada de secretos | P6: Vault + AWS Secrets Manager | Pendiente P6 |
| DT-10 | Sin backups automatizados de VMs | P4-P6: vzdump programado + S3 | Pendiente |

### Detectadas en ejecución (DT-11 a DT-22)

| ID | Deuda | Resolución | Estado |
|---|---|---|---|
| DT-11 | Entradas EFI residuales de Windows | `efibootmgr -B` | ✅ RESUELTA sesión 4 |
| DT-12 | IP Proxmox en 192.168.1.101 temporal | Migrar a 10.20.0.10 con FortiGate | Pendiente (post-cable) |
| DT-13 | HDD 1 TB no detectado | Verificar conexión física | Pendiente |
| DT-14 | USB de instalación conectado (`/dev/sdb`) | Desconectar físicamente | ✅ RESUELTA sesión 4 |
| DT-15 | DNS por defecto Proxmox 8.8.8.8 | Cambiar a 10.10.0.1 con FortiGate forwarder | Pendiente (post-cable) |
| DT-16 | `/mnt/backup-pny` no en fstab | Añadir con `nofail` | ✅ RESUELTA (verificada sesión 4) |
| DT-17 | `ssh.socket` fuerza puerto, ignora sshd_config | `mask ssh.socket` **+ `enable ssh.service`** | ✅ RESUELTA DE VERDAD sesión 4 (faltaba el enable) |
| DT-18 | Clon CloudImg hereda disco base ~3.5 GB | `qm disk resize`+growpart+resize2fs | ✅ RESUELTA sesión 3. P5: automatizar en Terraform |
| DT-19 | Hardening/baseline aplicado a mano post-clon | Script idempotente de baseline | ✅ RESUELTA sesión 4 (`baseline-setup.sh`) |
| DT-20 | Divergencia bastion (cicustom) vs app01 (UI) | Baseline único reproducible | ✅ RESUELTA sesión 4 (convergidas + script parametrizado) |
| **DT-21** | **Reglas UFW con origen transitorio `192.168.1.x`** | **Endurecer a `10.10.x` (bastion) / `10.20.0.40` (app01) post-FortiGate** | **Nueva sesión 4** |
| **DT-22** | **BIOS se detiene en boot esperando Enter (sin monitor)** | **Acceso físico al BIOS: desactivar "wait on error/F1". Hacer junto a config FortiGate** | **Nueva sesión 4** |

---

## SNAPSHOTS PROXMOX ACTUALES

| VM | Snapshot | Contenido |
|---|---|---|
| 110 (bastion) | `pre-baseline-clean` | Estado tras migración a nvme1, SSH reparado, pre-baseline |
| 110 (bastion) | `baseline-clean` | 5 piezas baseline (sin Docker). SSH 2222 enabled |
| 120 (app01) | `pre-baseline-clean` | Estado tras migración a nvme1, SSH reparado, pre-baseline |
| 120 (app01) | `baseline-with-docker` | Baseline completo + Docker 29.5 + Compose v2 |

---

## RUNBOOKS GENERADOS DURANTE LA EJECUCIÓN

| Runbook | En repo | Origen |
|---|---|---|
| Cambiar IP de Proxmox post-instalación | Pendiente | S2 |
| Crear thin-pool LVM en NVMe (pvcreate→vgcreate→lvcreate→lvconvert) | Pendiente | S2 |
| Limpiar disco con particiones previas (`wipefs -af`, `sgdisk -Z`) | Pendiente | S2 |
| Liberar disco "en uso" con LVM viejo (`umount`→`lvremove -f`→`pvremove`) | Pendiente | S2 |
| Resolver "host key changed" tras cambio de IP (`ssh-keygen -R`) | Pendiente | S2 |
| Recuperar de Boot Manager múltiple post-reinstalación + limpiar EFI (`efibootmgr -B`) | Pendiente | S2/S4 |
| Descartar aviso "sin suscripción" de Proxmox | Pendiente | S2 |
| Forzar puerto SSH en Ubuntu 24.04 (mask ssh.socket) | Pendiente | S3 |
| Expandir disco de VM clonada de CloudImg (resize→growpart→resize2fs en caliente) | Pendiente | S3 |
| Configurar ProxyJump en Windows (Workstation→bastión→app) | Pendiente | S3 |
| Conectar VS Code Remote SSH detrás de bastión vía ProxyJump | Pendiente | S3 |
| Corregir hostname heredado del snippet (`hostnamectl`) | Pendiente | S3 |
| **Recuperar SSH de una VM sin acceso editando el disco offline con `guestfish`** | **Pendiente** | **S4** |
| **Habilitar un servicio systemd en disco offline (symlink en `*.target.wants/`)** | **Pendiente** | **S4** |
| **Migrar disco de VM entre pools de almacenamiento (`qm move-disk --delete`)** | **Pendiente** | **S4** |
| **Aplicar UFW en host remoto con red de seguridad (`nohup sleep && ufw disable`)** | **Pendiente** | **S4** |
| **Instalar Docker Engine desde repo oficial (no docker.io) + validación NGINX** | **Pendiente** | **S4** |

---

## PRÓXIMOS PASOS INMEDIATOS

### Bloqueante crítico
- **Llegada del cable USB-RJ45 FTDI.** Imprescindible para desbloquear P1.1 y P1.2.

### Trabajo post-cable (P1.1 + P1.2 + migración de red)
1. Reset FortiGate vía consola serie + cuenta `maintainer`.
2. Configuración inicial FortiGate (P1.1): 4 zonas físicas, políticas least-privilege, NAT, DHCP, logging.
3. SSL-VPN + DDNS (P1.2).
4. Aprovechar el acceso físico al servidor para resolver DT-22 (BIOS boot sin Enter).
5. **Migración de red 192.168.1.x → 10.x:**
   - Proxmox: 192.168.1.101 → 10.20.0.10 (DT-12).
   - DNS Proxmox: 8.8.8.8 → 10.10.0.1 (DT-15).
   - VMs 110/120: reconfigurar `ipconfig0` a 10.20.0.x. Reconfigurar `~/.ssh/config` en Windows.
   - **Endurecer reglas UFW (DT-21):** bastion → `10.10.0.0/24`+`10.10.99.0/24`; app01 → `10.20.0.40`+`10.10.99.0/24`.

### Pendiente de subir a GitHub (acumulado de S3+S4)
- `PROGRESS-LOG.md` v1.3.
- `infrastructure/linux-baseline/baseline-setup.sh`.
- Trabajo P1.4/P1.5 (template, cloud-init, sshd_config.d).
- Runbooks nuevos (especialmente los 5 de S4).
- Docs de P1.3 (storage-design) y P1.6 (linux-baseline-spec, hardening-checklist, docker-installation).

### Cuando empiece P2
- Probar `baseline-setup.sh` sobre VM limpia (db-prod-01) → validar reproducibilidad real.

---

## DECISIONES OPERACIONALES TOMADAS

| Fecha | Decisión | Justificación |
|---|---|---|
| 22-may | Avanzar P1.3 sin completar P1.1/P1.2 | Cable consola bloquea, Proxmox no |
| 22-may | IP temporal Proxmox 192.168.1.101 | Trabajo paralelo sin FortiGate |
| 23-may | `mask ssh.socket` (no override del puerto) | Solución robusta; override limpio en P6 |
| 23-may | Discos: bastion 20 GB, app01 40 GB | app01 corre Docker+PG+Redis en P2 |
| 23-may | Clave SSH operativa = la de Windows | La de Proxmox quedó con formato roto |
| 24-may | **Recuperar SSH vía `guestfish` (no GRUB/cipassword)** | **Determinista, sin password ni timing. GRUB no capturable, cipassword no reaplica en reboot** |
| 24-may | **Migrar VMs a `local-lvm-nvme1` (opción A, no autoextend)** | **Corrige causa raíz (pool equivocado), no parchea síntoma. 16 GB de margen no bastan para autoextend** |
| 24-may | **UFW app01 estricto (solo bastión, no /24)** | **Fiel al patrón bastión: app01 solo accesible vía bastión. ProxyJump ya hace origen=bastión** |
| 24-may | **Baseline pieza a pieza (no script directo)** | **Didáctico: entender cada elemento antes de automatizar** |
| 24-may | **Script parametrizado por args (opción A, no 2 copias)** | **Un artefacto, evita reintroducir DT-20. Traduce limpio a Ansible en P5** |
| 24-may | **No ejecutar baseline-setup.sh sobre VMs actuales** | **Ya tienen baseline a mano. Probar en VM limpia (P2/P3) tiene más valor** |

---

## MÉTRICAS DEL PROGRESO

| Métrica | Valor |
|---|---|
| Mini-proyectos P1 completados | 4 de 6 (P1.3, P1.4, P1.5, P1.6) |
| Mini-proyectos P1 bloqueados | 2 (P1.1, P1.2 — cable) |
| Avance porcentual P1 | ~67% |
| Avance global roadmap | ~11% |
| Commits en GitHub | 1 (initial) — pendiente subir S3+S4 |
| Deudas técnicas registradas | 22 (DT-01 a DT-22) |
| Deudas técnicas resueltas | 7 (DT-11,14,16,17,18,19,20) |
| Desviaciones del plan | 11 (D-01 a D-11) |
| Storages LVM operativos | 4 (3 thin-pool + 1 backup ext4) |
| VMs operativas | 2 (bastion, app01) en `local-lvm-nvme1` + 1 template (9000) |
| Snapshots activos | 4 (2 por VM) |
| Incidentes mayores resueltos | 1 (pérdida SSH ambas VMs — DT-17) |
| Entregables de código | 1 (`baseline-setup.sh`, 142 líneas, idempotente) |

---

## CHANGELOG DEL ARCHIVO

| Fecha | Versión | Cambios |
|---|---|---|
| 2026-05-22 | 1.0 | Creación. Volcado de sesiones 1 y 2. |
| 2026-05-22 | 1.1 | Detalle de storages LVM paso a paso. DT-16. Métricas. |
| 2026-05-23 | 1.2 | Sesión 3. P1.4 y P1.5 cerrados. Hardening SSH, ProxyJump, VS Code. D-07/08/09, DT-17/18/19/20. |
| 2026-05-24 | 1.3 | Sesión 4. **P1.3 cerrado 100%** (DT-11/14/16). **Incidente mayor SSH** (DT-17 mal cerrado, rescate guestfish ambas VMs). **Migración almacenamiento** local-lvm→nvme1 (D-10). **P1.6 completo** (baseline 6 piezas + Docker). **`baseline-setup.sh`** (cierra DT-19/20). DT-21/22 nuevas. P1 al 67%, global ~11%. 7 deudas resueltas. |

---

## REGLA DE ACTUALIZACIÓN

Este archivo se actualiza:
- **Al inicio de cada sesión:** revisión rápida del estado actual.
- **Durante la sesión:** en cuanto se toma una decisión importante o se detecta una desviación.
- **Al final de cada sesión:** resumen consolidado.
- **Cada 2 semanas:** consolidación en el documento maestro `ROADMAP.md`.
