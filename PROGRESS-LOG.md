# PROGRESS LOG — GOLOCA AI INFRASTRUCTURE PLATFORM

> **Bitácora incremental** del avance del roadmap. Se actualiza en cada sesión de trabajo.  
> **Fuente de verdad estratégica:** `ROADMAP.md`  
> **Fuente de verdad operacional:** este archivo.

---

## ESTADO GLOBAL ACTUAL

**Fecha última actualización:** 28 agosto 2026 (v1.6 — fin sesión 7)  
**Proyecto activo:** P1 — Infraestructura Base, Networking Real y Virtualización  
**Mini-proyecto activo:** P1.1 — Segmentación FortiGate (EN PROGRESO ~40%: equipo recuperado y operativo, red migrada a 10.x; falta partir el switch interno en zonas y las políticas reales)  
**Mini-proyectos bloqueados:** ninguno  
**Foco sesión 7:** arranque real de P1.1. Recuperación del FortiGate de segunda mano, configuración base, y migración completa de la infraestructura de `192.168.1.x` a `10.20.0.0/24` detrás del firewall.

**Foco sesión 6:** reconexión tras 3 meses de inactividad. Auditoría completa del estado real de Proxmox (discos, VMs, LXC, GPU) y reconciliación contra lo documentado. Detectada deriva no registrada: un LXC ajeno al roadmap ("ia-gpu") ocupa el SSD Samsung y comparte la GPU a nivel de host. Recalculado el plan de almacenamiento para el resto del roadmap. Sin avance de infraestructura del propio roadmap (FortiGate sigue sin configurar).

---

## RESUMEN EJECUTIVO DEL ESTADO

| Mini-Proyecto | Estado | Bloqueador |
|---|---|---|
| P1.1 — Segmentación FortiGate | 🔄 EN PROGRESO (~40%) | Ninguno |
| P1.2 — SSL-VPN + DDNS | ⏸️ PENDIENTE | Depende de P1.1 |
| P1.3 — Proxmox VE bare-metal | ✅ COMPLETADO | Cerrado 100% (DT-11/14/16 saldadas) |
| P1.4 — Template Ubuntu + Cloud-Init | ✅ COMPLETADO | — |
| P1.5 — Bastión + VS Code Remote SSH | ✅ COMPLETADO | — |
| P1.6 — Linux baseline + Docker | ✅ COMPLETADO | Cerrado en sesión 4 |

**P1 al ~72%.** 4 mini-proyectos cerrados, P1.1 arrancado y a mitad, P1.2 pendiente. El FortiGate ya es el núcleo real de la red: toda la infraestructura del laboratorio vive detrás de él en `10.20.0.0/24`.

### Mapa de red operativo (fin sesión 7)

| Host | IP | Conexión | Estado |
|---|---|---|---|
| `fgt-prod-01` | `10.20.0.1` (lan) / `192.168.1.33` (wan, DHCP del HGU) | — | Operativo |
| `pve-prod-01` | `10.20.0.10` | internal3 | Operativo |
| `app-prod-01` | `10.20.0.20` | VM sobre vmbr0 | Operativo |
| `bastion-prod-01` | `10.20.0.40` | VM sobre vmbr0 | Operativo |
| `estudio` (PC dev) | `10.20.0.101` (DHCP) | internal2 | Operativo |
| portátil admin | `10.20.0.100` (DHCP) | internal1 | Operativo |
| `ia-gpu` (LXC 130) | DHCP `10.20.0.x` | vmbr0 | Se recupera solo (usa DHCP) |
| AP WiFi + TP-Link + Raspberry | `192.168.1.x` | Red doméstica (HGU) | Deliberadamente fuera |

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

### Sesión 5 — 24 mayo 2026

**Duración:** ~2,5 horas.  
**Naturaleza:** sesión de consolidación de portfolio. CERO avance de infraestructura física (FortiGate sigue bloqueado por cable). Todo el trabajo fue versionado, documentación y runbooks. Objetivo: poner a salvo en GitHub las ~6 horas de trabajo de S3+S4 y construir el contenido de portfolio que estaba ausente.

**Trabajo realizado:**

1. **Diagnóstico del estado real de Git (corrección de premisa falsa).** El plan de la sesión asumía "todo S3+S4 sin subir". El diagnóstico (`git status`, `git log`, `git ls-files`) reveló que **era falso**: el repo ya tenía 4 commits, incluido `Terminado 1.6` con `baseline-setup.sh` y `PROGRESS-LOG` v1.3 ya subidos. El dato "Commits en GitHub: 1 (initial)" del propio log estaba **desactualizado**. Lección operacional: verificar el estado real antes de actuar sobre lo que se asume. Se perdieron los primeros pasos de la sesión diagnosticando algo ya hecho — justamente por confiar en una bitácora desfasada.

2. **Hallazgo real:** lo que faltaba NO era subir código, sino que las carpetas `docs/` y `runbooks/` estaban **vacías** (solo `.gitkeep`). El agujero del portfolio no era versionado, era documentación inexistente. Replanteado el peso de la sesión: el grueso pasó a ser escritura de docs/runbooks, no `git push`.

3. **Bloque docs — 6 documentos de P1.3 + P1.6 escritos y subidos** (`docs/`, commit `fb0133a`):
   - `03-storage-design.md` — diseño de almacenamiento, LVM-thin vs ZFS, incidente de sobreaprovisionamiento del thin-pool (D-10).
   - `03-proxmox-architecture-decision.md` — Proxmox vs Hyper-V vs VMware, bare-metal vs nested.
   - `06-linux-baseline-spec.md` — 6 piezas del baseline, incidente SSH (DT-17), script parametrizado.
   - `06-hardening-checklist.md` — checklist verificable de endurecimiento.
   - `06-docker-installation.md` — repo oficial vs docker.io, validación NGINX, docker=root.
   - `06-defense-in-depth-rationale.md` — racional de las 4 capas de seguridad.
   - Formato: front-matter + contexto Goloca AI + decisión + trade-offs + diagrama + incidente + validación + deuda técnica. Tono de mentor con criterio explícito. Cross-links entre docs (uno apunta a `01-network-architecture.md`, aún inexistente — link planificado, no roto).

4. **`.gitattributes` añadido** (commit `243f3f3`). Detectado warning CRLF al hacer `git add` desde Windows. Verificado que `baseline-setup.sh` NO estaba dañado (`i/lf w/lf`). Creado `.gitattributes` que fuerza LF en `.sh`/`.yaml`/`.conf`/`Dockerfile`/`.service` (archivos que se ejecutan en Linux), CRLF en `.ps1`/`.bat`, binarios intactos. Es la solución portable (viaja con el repo) frente a `core.autocrlf` (por máquina). Repo renormalizado con `git add --renormalize .`.

5. **Bloque runbooks — 5 runbooks operacionales de S4 escritos y subidos** (`runbooks/`, commit `1a48d88`):
   - `06-vm-ssh-recovery-guestfish.md` — rescate de SSH editando disco offline (la joya del portfolio).
   - `06-systemd-enable-offline.md` — enable de servicio vía symlink manual en disco offline.
   - `03-storage-move-disk.md` — migración de disco entre pools (`qm move-disk`).
   - `06-ufw-remote-safe-apply.md` — UFW remoto con red de seguridad (`nohup sleep`).
   - `06-docker-install-validate.md` — Docker desde repo oficial + validación.
   - Formato autocontenido (ejecutables bajo presión sin leer nada más): síntoma → cuándo usar/no usar → precondiciones → procedimiento numerado → checklist → trampas comunes. Nomenclatura con prefijo de mini-proyecto, coherente con `docs/`.

6. **Estado del repo tras la sesión:** estructura `docs/` (6) + `runbooks/` (5) + `.gitattributes` + `baseline-setup.sh`, todo en `origin/main`. El portfolio de P1.3/P1.6 pasa de inexistente a completo.

**Lo que esta sesión NO hizo (deliberadamente):**
- No se adelantó P2: la parte de red (NGINX DMZ) se reharía tras la migración a `10.x`. Trabajo que se tiraría.
- No se extrajeron de las VMs las configs reales (`sshd_config.d`, cloud-init, ufw-rules) a archivos versionados. Pendiente: requiere SSH a VMs vivas, de menor valor de portfolio que los docs. Tarea atada para próxima sesión.

### Sesión 6 — 27 agosto 2026

**Duración:** ~1 hora.  
**Naturaleza:** reconexión tras 3 meses sin actividad en el proyecto (última sesión registrada: 24 mayo 2026). Sesión de auditoría y reconciliación, no de ejecución de mini-proyectos nuevos.

**Trabajo realizado:**

1. **Recuperación de contexto.** Repaso de `PROGRESS-LOG.md` y `ROADMAP.md` para retomar el estado documentado: P1 al 67%, bloqueado en P1.1/P1.2 por el cable de consola del FortiGate.

2. **Aviso del aprendiz:** entre sesiones ha estado usando el mismo hardware para "trastear con IA" en proyectos ajenos a Goloca AI, y sospechaba cambios no documentados en Proxmox, especialmente en discos y GPU.

3. **Auditoría completa del host Proxmox** (`lsblk`, `pvs`/`vgs`/`lvs`, `pvesm status`, `cat /etc/pve/storage.cfg`, `qm list`/`pct list` + `qm config`/`pct config` de cada uno, `lspci -nnk`, snapshots existentes, `ip a`). Hallazgos:
   - **VMs y storages del roadmap intactos:** `local-lvm-nvme1` sigue con los discos de bastion (110) y app01 (120), tal como quedó tras la migración D-10 de sesión 4. `local-lvm-nvme2` sigue vacío (0% uso). `backup-pny` sigue montado y prácticamente vacío (sin backups automatizados — DT-10 sigue abierta). Snapshots de P1.6 (`baseline-clean`, `baseline-with-docker`) intactos.
   - **Hallazgo no documentado — LXC 130 "ia-gpu".** Contenedor ajeno al roadmap, `onboot: 1`, 6 cores, 20 GB RAM, disco de 250 GB sobre `local-lvm-ssd-samsung` (el SSD Samsung, que el roadmap original reservaba para "VMs secundarias / workers K3s" de P3). Uso real del pool: 182,6 GB de 250 GB asignados (73%), dejando el pool Samsung al 40,58% global.
   - **GPU no está libre.** El driver `nvidia` está cargado a nivel del host Proxmox (no en una VM aislada). El LXC accede a la GPU compartiendo el driver del host vía bind-mount de device nodes (`/dev/nvidia0`, `nvidiactl`, `nvidia-uvm`, `nvidia-caps`) + reglas de cgroup2. Este modelo es incompatible con el plan original de P6 (passthrough VFIO/IOMMU exclusivo a una VM dedicada) — con una RTX 4060 (GPU de consumo, sin vGPU/SR-IOV/MIG) la asignación es excluyente: o la usa el host/LXC, o la usa una VM vía VFIO, nunca ambos a la vez.
   - **Red sin migrar.** Bastion y app01 siguen en `192.168.1.110`/`.120` (red doméstica), no en `10.20.0.x`. La migración de red (P1.1/P1.2, DT-12, DT-15, DT-21) no ha empezado pese a que el cable de consola del FortiGate ya llegó.

4. **Decisión — GPU:** se pospone cualquier acción sobre la GPU/LXC hasta llegar a P6. Cuando toque, se evaluará si las cargas actuales de "ia-gpu" se migran dentro de la VM de P6 (Ollama + NVIDIA Container Toolkit, tal como decía el plan original) o si el LXC se descarta sin más. No se toca ahora.

5. **Decisión — Recálculo del plan de almacenamiento (D-12).** El SSD Samsung (`nvme3n1`, 465 GB) queda **fuera del roadmap Goloca AI**, en exclusiva para "ia-gpu". Se reasigna el rol que tenía previsto ("VMs secundarias / workers K3s") al NVMe2 (`local-lvm-nvme2`), que estaba completamente libre y sin uso desde sesión 2. Nuevo mapa de almacenamiento:

   | Disco | Storage Proxmox | Rol en el roadmap | Libre actual |
   |---|---|---|---|
   | nvme0n1 (238 GB) | `local` + `local-lvm` | Sistema Proxmox, ISOs, templates, cloudinit. Sin VMs de carga. | ~136 GB (local-lvm) + ~51 GB (local) |
   | nvme1n1 (238 GB) | `local-lvm-nvme1` | Plataforma / VMs críticas: bastion-prod-01, app-prod-01 (ya alojadas) + monitor-prod-01 (P4) + VM de LLM local (P6) | ~213 GB |
   | nvme2n1 (238 GB) | `local-lvm-nvme2` | Clúster K3s (P3): k3s-master-01, k3s-worker-01(+extra) | ~230 GB (vacío) |
   | nvme3n1 Samsung (465 GB) | `local-lvm-ssd-samsung` | **Exclusivo ia-gpu.** Fuera del roadmap. No contar como disponible aunque el pool marque libre. | 267 GB libres en el pool, pero reservados para el crecimiento propio de ia-gpu, no para Goloca AI |
   | sda PNY (223 GB) | `backup-pny` | Backups (`vzdump` cuando se automatice en P4-P6), snapshots exportados. Sin cambios. | ~204 GB |

   **Razonamiento:** separar "plataforma/servicios singulares" (nvme1) de "plano de datos K3s" (nvme2) evita repetir el error de sobreaprovisionamiento de thin-pool ya visto en D-10 (sesión 4) — un clúster K3s con PVs de pgvector puede crecer de forma impredecible, y mezclarlo con bastion/app/monitor arriesga contención. La VM de LLM local de P6 se trata como servicio de plataforma (singular, no parte del clúster), por eso va en nvme1 y no en nvme2. Ninguna cifra de "libre" en `local-lvm-ssd-samsung` se cuenta para el roadmap: es capacidad de otro proyecto, no un colchón disponible.

6. **Lo que esta sesión NO hizo:** no se ha tocado el LXC ia-gpu (ni parado ni movido). No se ha iniciado la migración de red. No se ha ejecutado P1.1.

### Sesión 7 — 27-28 agosto 2026

**Duración:** ~3 horas.  
**Naturaleza:** primera sesión de ejecución de infraestructura desde mayo. Arranque de P1.1 y, como consecuencia no planificada pero necesaria, migración completa de la red del laboratorio a `10.20.0.0/24`.

**Trabajo realizado:**

1. **RECUPERACIÓN DEL FORTIGATE (cierra D-06).** El cable USB-RJ45 FTDI llegó. Consola serie en `COM5`, PuTTY, 9600 8N1 sin control de flujo.
   - **Incidente — diafonía en el cable de consola (técnica nueva → runbook).** Tras el primer arranque, la consola empezó a mostrar intentos de login espurios: el propio texto del banner de arranque reaparecía como si alguien lo tecleara (`Login incorrect` en bucle, con "usuarios" tipo `Serial number: FGT30E...`). No era entrada del operador: es acoplamiento TX→RX del cable, típico de cables de consola de baja calidad. **Diagnóstico:** el ruido persistía después del arranque, no solo durante la ráfaga inicial. **Resolución:** reasentar el conector RJ45 en el puerto Console y mover el extremo USB de un puerto frontal a uno trasero de la placa (mejor masa y blindaje), separándolo de cables de alimentación. El ruido cesó por completo.
   - **Cuenta `maintainer`:** número de serie `FGT30E<SERIAL-REDACTED>` → contraseña `bcpb` + serie. **Primer intento falló** (`Login incorrect`) por haber agotado la ventana de validez mientras se depuraba el cable. **Segundo intento, inmediatamente tras un ciclo de alimentación y tecleando en el primer prompt disponible: éxito.** Lección: `maintainer` solo es válida en los primeros instantes tras el arranque; no es una cuenta permanente.
   - **`execute factoryreset`** (el aprendiz decidió no inspeccionar la configuración previa: "basura, borrar todo"). Tras el reinicio, `admin` sin contraseña, con cambio obligatorio en el primer login.

2. **Corrección de dato del propio mentor.** Se interpretó inicialmente `Ver:05000016` del arranque como FortiOS 5.x de 2017. Es la versión de **BIOS/bootloader**. El SO real es **FortiOS v6.2.5, build1142 (agosto 2020)** según `get system status`. Relevante para buscar documentación y para DT-24.

3. **Configuración base del equipo.**
   - Hostname `fgt-prod-01` (verificado por el cambio de prompt, no por el eco).
   - NTP `fortiguard` con `ntpsync enable`, verificado con `get system ntp`.
   - **Zona horaria — fallo silencioso detectado por verificación.** El primer `set timezone 28` devolvió `Unknown action 0` y **no se guardó**: `get system global` seguía mostrando `(GMT-8:00) Pacific Time`, el valor de fábrica. Repetido línea a línea y verificado con `get system global | grep timezone` → `(GMT+1:00) Brussels, Copenhagen, Madrid, Paris`. **Lección operacional reforzada dos veces en esta sesión: en este equipo el eco de la consola serie no es prueba de que un comando se haya aplicado. Verificar siempre contra el estado guardado.**
   - **Pegado multilínea poco fiable a 9600 baudios:** los bloques `config...end` pegados de golpe se solapan y corrompen. Se pasó a introducir comandos de uno en uno.

4. **WAN operativa.** Cable del switch (que baja del HGU) a WAN1. `wan` obtuvo `192.168.1.33/24` por DHCP, `status: up`. `execute ping 8.8.8.8` → 0% de pérdida.

5. **INCIDENTE MAYOR — sin salida a Internet para los clientes de la LAN.**
   - **Síntoma:** el portátil conectado a `internal1` obtenía IP y llegaba a la GUI del FortiGate, pero no salía a Internet. `ping 8.8.8.8` perdía el 100% de los paquetes. El FortiGate sí salía (tráfico generado por él mismo).
   - **Primera hipótesis descartada:** política inexistente. Se creó `TEMP-lan-to-wan` (lan→wan, all/all, ACCEPT, NAT habilitado). **Siguió sin salir.** NAT verificado como activo.
   - **Log inútil:** `Log & Report → Forward Traffic` sin resultados. Se descartó como evidencia: el 30E reporta `Log hard disk: Not available`, solo tiene log en memoria.
   - **Causa raíz: solapamiento de subredes.** La interfaz `wan` (`192.168.1.33/24`) y la interfaz interna `lan` (`192.168.1.99/24`, de fábrica) estaban en **la misma red**. El FortiGate tenía `192.168.1.0/24` como red conectada en dos interfaces a la vez, dejando ambiguo el camino de retorno hacia los clientes internos: las respuestas se encaminaban por la interfaz equivocada y morían en ARP.
   - **Error de criterio del mentor, corregido en la propia sesión:** al ver por primera vez ese solapamiento se calificó de "feo pero no rompe nada ahora mismo". Era exactamente la causa del fallo. Queda anotado porque es representativo: un solapamiento de subredes en un firewall nunca es cosmético.
   - **Resolución:** renumerar la interfaz interna a `10.20.0.1/24`, que además era el destino previsto por el roadmap. DHCP reconfigurado a `10.20.0.100-200`, gateway `10.20.0.1`, DNS `1.1.1.1` (provisional). Salida a Internet inmediata.

6. **DECISIÓN DE TOPOLOGÍA — qué baja detrás del firewall y qué no.**
   - **Restricción física:** existe **un solo cable** entre el HGU (planta superior) y el TP-Link (planta inferior). Ese TP-Link no puede bajar detrás del FortiGate sin arrastrar consigo al AP.
   - **Decisión:** el TP-Link y el AP WiFi **se quedan en la red doméstica**, colgando del HGU. El FortiGate no reparte nada de la red doméstica. Solo bajan detrás del firewall las máquinas del laboratorio, usando los 4 puertos internos del propio FortiGate.
   - **Razón:** mover el AP metería todos los dispositivos WiFi de la casa (móviles, TV, IoT) dentro de `10.20.0.0/24`, que es la red de servidores — justo lo que el proyecto pretende evitar. Además, el WiFi doméstico pasaría a depender de que el FortiGate esté bien configurado, convirtiendo cada error de laboratorio en una incidencia doméstica. La zona WIFI (`10.99.0.0/24`) se construirá correctamente al partir el switch interno.
   - **Rechazada la petición de habilitar administración en la interfaz WAN** (`192.168.1.33`) para gestionar el FortiGate desde la red doméstica. Motivos: (a) P1.2 configura **DMZ Host** en el HGU, que reenvía todo el tráfico entrante al FortiGate — la GUI de administración quedaría expuesta a Internet; (b) P2 necesita NAT de 80/443 hacia el NGINX de la DMZ, en conflicto con el puerto de gestión; (c) crear una interfaz interna en `192.168.1.0/24` reproduciría a propósito el solapamiento que acababa de causar el incidente. Se ofreció la alternativa acotada (solo HTTPS + `trusted hosts`) y se descartó al no ser necesaria.

7. **MIGRACIÓN DEL HOST PROXMOX SIN PERDER ACCESO (técnica nueva → runbook).**
   - **Restricción:** el servidor no tiene monitor ni teclado conectados y enchufarlos es costoso. Cualquier error de red que lo dejara incomunicado obligaba a intervención física.
   - **Hallazgo previo — máscara incorrecta (resto de la sesión 2):** `vmbr0` tenía `192.168.1.101/32`, no `/24`. La línea `address 192.168.1.101` del fichero no llevaba prefijo e ifupdown lo interpretaba como `/32`. Funcionaba solo porque la línea `gateway` añadía la ruta necesaria; el host no tenía ruta directa a su propia red local.
   - **Hallazgo — interfaz WiFi:** el servidor tiene `wlp3s0` (actualmente `DOWN`). Vía de rescate potencial no explotada.
   - **Técnica aplicada — direccionamiento dual transitorio:** `ip addr add 10.20.0.10/24 dev vmbr0` **en caliente**, manteniendo la dirección antigua. El host responde en las dos redes simultáneamente. Persistido con una línea `up ip addr add ...` dentro del bloque `vmbr0` (aditiva, no destructiva) para sobrevivir a un reinicio a mitad de migración. Solo tras confirmar la nueva se retiró la vieja. **Cero ventanas ciegas y reversible en todo momento devolviendo el cable a su sitio.**
   - Recableado: PC estudio a `internal2`, Proxmox a `internal3` (en ese orden: primero la máquina que sirve de plataforma de verificación).
   - Ruta por defecto cambiada en caliente a `10.20.0.1`. Verificado `ping 8.8.8.8` con 5 ms.
   - `/etc/network/interfaces` reescrito limpio: `address 10.20.0.10/24` (máscara ya correcta), `gateway 10.20.0.1`, sin el apaño transitorio. Backup previo en `interfaces.pre-10x`.
   - **`/etc/hosts` ya apuntaba a `10.20.0.10`** desde la instalación original de la sesión 2. Llevaba tres meses señalando una dirección inexistente; la migración lo dejó consistente por primera vez. Cabo suelto cerrado por accidente.

8. **MIGRACIÓN DE LAS VMs CON `qemu-guest-agent` (técnica nueva → runbook).**
   - **Problema:** al migrar el host, las VMs 110 y 120 quedaron aisladas — su cloud-init las fijaba en `192.168.1.110/.120` con gateway `192.168.1.1`, red que ya no existe detrás del firewall. El LXC 130 (`ia-gpu`) usa DHCP y se recupera solo.
   - **Vías descartadas:** SSH (inalcanzables) y consola noVNC (cloud-init solo configuró clave SSH, sin contraseña de consola — exactamente el callejón sin salida de la sesión 4).
   - **Vía usada:** el **guest agent**, que habla con Proxmox por canal virtio y **no depende de la red**. `qm guest cmd <id> network-get-interfaces` para inventariar y `qm guest exec <id> -- <cmd>` para ejecutar dentro.
   - **Verificación preventiva del incidente de la sesión 4:** `qm guest exec {110,120} -- systemctl is-enabled ssh.service` → `enabled` en ambas antes de reiniciar. El arreglo de DT-17 ha aguantado 3 meses y varios reinicios.
   - **UFW actualizado ANTES de mover las IPs (DT-21 aplicada).** Si se hubiera cambiado la red primero, las VMs habrían arrancado bien pero rechazado el SSH del operador. Reglas añadidas sin borrar las viejas (red de seguridad): bastion acepta `10.20.0.0/24:2222`, app01 solo `10.20.0.40:2222` — fiel al patrón bastión.
   - `qm set <id> --ipconfig0 ip=...,gw=10.20.0.1` + `qm reboot`. **Confirmado que cloud-init SÍ reaplica la configuración de red al cambiar `ipconfig0` y reiniciar** (contrasta con lo observado en la sesión 4 con `cipassword`, que no se reaplicaba).
   - Resultado: `bastion-prod-01` en `10.20.0.40`, `app-prod-01` en `10.20.0.20`.

9. **Validación extremo a extremo.** `ssh -p 2222 ubuntu@10.20.0.40` desde el PC estudio (`10.20.0.101`): entrada correcta. Valida en una sola prueba la cadena completa — PC en la red del laboratorio → switch interno del FortiGate → bastión en su IP nueva → filtro UFW con la regla nueva.

**Deudas y desviaciones cerradas en esta sesión:** D-02, D-06, DT-12, y DT-21 aplicada (en forma transitoria).

**Lo que esta sesión NO hizo (queda para la siguiente):**
- Partir el switch interno (`lan`, tipo `hard-switch`) en las 4 zonas físicas del plan. La red sigue siendo **plana**: `10.20.0.0/24` para todo.
- Sustituir la política `TEMP-lan-to-wan` (permisiva, all/all/ACCEPT) por la matriz least-privilege del roadmap.
- Activar el DNS forwarder del FortiGate (DT-15 sigue abierta; Proxmox y clientes siguen con `8.8.8.8`).
- Configurar logging y objetos de red.
- Limpiar las reglas UFW obsoletas de `192.168.1.x` en ambas VMs.
- Actualizar `~/.ssh/config` en Windows, que sigue apuntando a las IPs viejas.
- Backup de la configuración del FortiGate.
- DT-22 (BIOS esperando Enter en el arranque): no se aprovechó el acceso físico al servidor.

---

## DESVIACIONES DEL PLAN ORIGINAL

Cambios respecto a lo que dice `ROADMAP.md`:

| ID | Desviación | Causa | Impacto | Estado |
|---|---|---|---|---|
| D-01 | Proxmox VE 9.2 instalado (no 8.x previsto) | Versión más reciente disponible | Positivo | Aceptado |
| D-02 | IP Proxmox temporalmente en 192.168.1.101 (no 10.20.0.10) | FortiGate sin configurar (bloqueado por cable) | Temporal. Requiere migración | ✅ RESUELTA sesión 7 (migrado a 10.20.0.10) |
| D-03 | 4 NVMe + 1 SATA SSD (no 2 NVMe + 1 SSD + 1 HDD) | Inventario real difiere | Más NVMe disponible. HDD 1 TB no aparece | Aceptado |
| D-04 | HDD 1 TB no detectado por Proxmox | Posiblemente desconectado físicamente | Backups van a SSD PNY | Pendiente verificación física |
| D-05 | P1.3 ejecutado antes de P1.1 y P1.2 | Bloqueo de FortiGate por cable | Orden adaptado | Aceptado provisional |
| D-06 | FortiGate de segunda mano con config previa | No documentado al inicio | Reset físico no funcionó. Requiere `maintainer` vía consola serie | ✅ RESUELTA sesión 7 (`maintainer` + `factoryreset`) |
| D-07 | VM 110 y 120 nacen con disco 3.5 GB pese al wizard | Clon de CloudImg hereda disco base | Resize manual post-clon | Resuelto en sesión 3 |
| D-08 | Clave SSH Ed25519 generada en Windows, no en Proxmox | Copiar de Proxmox a Windows rompió formato | Clave operativa = la de Windows | Aceptado |
| D-09 | app01 configurado 100% por UI (no cicustom snippet) | Decisión de hacer la 2ª VM por UI | Divergencia bastion/app01 | Resuelto en sesión 4 (baseline convergido + script) |
| D-10 | VMs nacieron en `local-lvm` (no `local-lvm-nvme1`) | Desviación de sesión 2 no aplicada al clonar | Sobreaprovisionamiento thin-pool, riesgo corrupción | Resuelto sesión 4 (`qm move-disk`) |
| D-11 | VS Code Server / disco app01 al 96% en sesión 3 | (ya cubierto en D-07) | — | Resuelto sesión 3 |
| **D-12** | **SSD Samsung (nvme3, 465 GB) ocupado por LXC "ia-gpu", ajeno al roadmap, con GPU compartida a nivel de host** | **Uso del hardware para proyectos personales de IA durante la pausa de 3 meses** | **El rol "VMs secundarias / K3s" previsto para el Samsung se reasigna a NVMe2. GPU no disponible para P6 tal como estaba planeada (VFIO exclusivo) hasta decidir qué pasa con ia-gpu** | **Aceptado sesión 6. Recalculado plan de almacenamiento. GPU pendiente de decisión en P6** |
| **D-13** | **AP WiFi y switch TP-Link se quedan en la red doméstica, no bajan detrás del FortiGate** | **Un solo cable físico entre el HGU y la planta inferior; bajar el switch arrastraría al AP** | **La zona WIFI (`10.99.0.0/24`) del plan no se alimenta del AP existente. Los dispositivos WiFi de la casa quedan fuera del laboratorio, lo cual es operacionalmente deseable** | **Aceptada sesión 7** |
| **D-14** | **Red del laboratorio plana en `10.20.0.0/24`; el switch interno del FortiGate sigue en modo `hard-switch`** | **Migración de red priorizada sobre la segmentación para recuperar conectividad** | **Las 4 zonas del plan (MGMT/SERVERS/DMZ/WIFI) todavía no existen. Estado transitorio** | **Aceptada sesión 7, se resuelve al completar P1.1** |

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
| DT-07 | Usuario en grupo docker = root | P3: RBAC K8s. P6: rootless Docker | Reafirmada sesión 4 |
| DT-08 | Sin Fail2ban configurado | P6: afinar puerto 2222 + integración FortiGate | Instalado, sin afinar |
| DT-09 | Sin gestión centralizada de secretos | P6: Vault + AWS Secrets Manager | Pendiente P6 |
| DT-10 | Sin backups automatizados de VMs | P4-P6: vzdump programado + S3 | Pendiente |

### Detectadas en ejecución (DT-11 a DT-22)

| ID | Deuda | Resolución | Estado |
|---|---|---|---|
| DT-11 | Entradas EFI residuales de Windows | `efibootmgr -B` | ✅ RESUELTA sesión 4 |
| DT-12 | IP Proxmox en 192.168.1.101 temporal | Migrar a 10.20.0.10 con FortiGate | ✅ RESUELTA sesión 7 |
| DT-13 | HDD 1 TB no detectado | Verificar conexión física | Pendiente |
| DT-14 | USB de instalación conectado (`/dev/sdb`) | Desconectar físicamente | ✅ RESUELTA sesión 4 |
| DT-15 | DNS por defecto Proxmox 8.8.8.8 | Cambiar al forwarder del FortiGate | Pendiente — el forwarder aún no está activado (sesión 7) |
| DT-16 | `/mnt/backup-pny` no en fstab | Añadir con `nofail` | ✅ RESUELTA (verificada sesión 4) |
| DT-17 | `ssh.socket` fuerza puerto, ignora sshd_config | `mask ssh.socket` + `enable ssh.service` | ✅ RESUELTA DE VERDAD sesión 4 (faltaba el enable) |
| DT-18 | Clon CloudImg hereda disco base ~3.5 GB | `qm disk resize`+growpart+resize2fs | ✅ RESUELTA sesión 3. P5: automatizar en Terraform |
| DT-19 | Hardening/baseline aplicado a mano post-clon | Script idempotente de baseline | ✅ RESUELTA sesión 4 (`baseline-setup.sh`) |
| DT-20 | Divergencia bastion (cicustom) vs app01 (UI) | Baseline único reproducible | ✅ RESUELTA sesión 4 (convergidas + script parametrizado) |
| DT-21 | Reglas UFW con origen transitorio `192.168.1.x` | Endurecer a `10.10.x` (bastion) / `10.20.0.40` (app01) post-FortiGate | 🔄 PARCIAL sesión 7: reglas `10.20.0.0/24` (bastion) y `10.20.0.40` (app01) añadidas y operativas. Falta borrar las viejas y endurecer a `10.10.x` cuando existan las zonas |
| DT-22 | BIOS se detiene en boot esperando Enter (sin monitor) | Acceso físico al BIOS: desactivar "wait on error/F1". Hacer junto a config FortiGate | Pendiente |
| **DT-23** | **Driver NVIDIA instalado a nivel de host Proxmox (no aislado en VM), GPU compartida con LXC "ia-gpu" vía device bind + cgroup2** | **P6: decidir si se migra a VFIO/IOMMU exclusivo hacia la VM de LLM local (implica desvincular el driver del host y las cargas de ia-gpu) o si se acepta el modelo compartido como desviación permanente** | **Nueva sesión 6. Sin resolución hasta P6** |
| **DT-24** | **FortiOS v6.2.5 (build1142, agosto 2020): versión antigua, fuera de soporte, con CVEs conocidas** | **Actualizar requiere cuenta de soporte de Fortinet, que un equipo de segunda mano probablemente no tenga. Evaluar el riesgo real antes de exponer nada a Internet en P1.2** | **Nueva sesión 7** |
| **DT-25** | **Política `TEMP-lan-to-wan` totalmente permisiva (all/all/ACCEPT + NAT)** | **Sustituir por la matriz least-privilege de la sección 8.1 del roadmap al completar P1.1** | **Nueva sesión 7** |
| **DT-26** | **Reglas UFW obsoletas de `192.168.1.x` sin borrar en ambas VMs** | **`ufw delete` de las reglas antiguas una vez confirmado el acceso estable por `10.20.0.x`** | **Nueva sesión 7** |
| **DT-27** | **`estudio` y portátil toman IP por DHCP, no reservada** | **El roadmap prevé `dev01` en `10.20.0.30` y `admin-ops` en `10.10.0.50`. Fijar por reserva DHCP al crear las zonas** | **Nueva sesión 7** |

---

## SNAPSHOTS PROXMOX ACTUALES

| VM | Snapshot | Contenido |
|---|---|---|
| 110 (bastion) | `pre-baseline-clean` | Estado tras migración a nvme1, SSH reparado, pre-baseline |
| 110 (bastion) | `baseline-clean` | 5 piezas baseline (sin Docker). SSH 2222 enabled |
| 120 (app01) | `pre-baseline-clean` | Estado tras migración a nvme1, SSH reparado, pre-baseline |
| 120 (app01) | `baseline-with-docker` | Baseline completo + Docker 29.5 + Compose v2 |

*(LXC 130 "ia-gpu" no tiene snapshots ni es parte del inventario versionado del roadmap.)*

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
| Recuperar SSH de una VM sin acceso editando el disco offline con `guestfish` | Pendiente | S4 |
| Habilitar un servicio systemd en disco offline (symlink en `*.target.wants/`) | Pendiente | S4 |
| Migrar disco de VM entre pools de almacenamiento (`qm move-disk --delete`) | Pendiente | S4 |
| Aplicar UFW en host remoto con red de seguridad (`nohup sleep && ufw disable`) | Pendiente | S4 |
| Instalar Docker Engine desde repo oficial (no docker.io) + validación NGINX | Pendiente | S4 |
| **Recuperar un FortiGate sin credenciales: consola serie + cuenta `maintainer` + `factoryreset`** | **Pendiente** | **S7** |
| **Diagnosticar diafonía (crosstalk TX/RX) en cable de consola serie** | **Pendiente** | **S7** |
| **Depurar "sin salida a Internet" causado por solapamiento de subredes WAN/LAN en FortiGate** | **Pendiente** | **S7** |
| **Migrar la IP de un host Proxmox sin perder acceso (direccionamiento dual en caliente)** | **Pendiente** | **S7** |
| **Reconfigurar la red de una VM aislada con `qemu-guest-agent` (`qm guest exec` / `qm set --ipconfig0`)** | **Pendiente** | **S7** |

---

## PRÓXIMOS PASOS INMEDIATOS

### Bloqueante crítico
- Ninguno.

### Riesgo abierto ahora mismo
- **No hay backup de la configuración del FortiGate.** Todo el trabajo de la sesión 7 en ese equipo vive solo en su flash. Si se resetea, se vuelve al cable de consola y a `maintainer` desde cero. **Hacerlo antes de tocar nada más** (GUI → `admin` → Configuration → Backup → Local PC, sin cifrar, guardar en `infrastructure/fortigate/backups/`).

### Completar P1.1 (pasos 3 a 10 de la sección 8.1 del roadmap)
1. **Partir el switch interno.** `lan` es hoy un `hard-switch` que une `internal1-4` en una sola red. Convertir cada puerto en interfaz independiente. **Paso de riesgo real**: se pierden accesos si se hace mal. Requisitos previos: backup hecho y cable de consola conectado.
2. Asignar direccionamiento por zona: MGMT `10.10.0.1/24`, SERVERS `10.20.0.1/24`, DMZ `10.30.0.1/24`, WIFI `10.99.0.1/24`.
3. DHCP por zona + reservas estáticas (cierra DT-27: `dev01` a `10.20.0.30`, `admin-ops` a `10.10.0.50`).
4. **Replantear la zona WIFI.** El AP se queda en la red doméstica (D-13), así que `10.99.0.0/24` queda sin cliente. Decidir: dejarla preparada y vacía, o reasignar el puerto.
5. DNS forwarding del FortiGate hacia Cloudflare `1.1.1.1` → cierra **DT-15** (y entonces apuntar el `resolv.conf` de Proxmox al FortiGate).
6. Objetos de red (addresses y address groups).
7. **Matriz de políticas least-privilege** de la sección 8.1 → sustituye `TEMP-lan-to-wan`, cierra **DT-25**.
8. Logging Memory (el 30E no tiene disco de logs) + implicit deny con log.
9. Validación: pings cruzados entre zonas confirmando permitidos y denegados.
10. Backup final de configuración.

### Limpieza pendiente de la sesión 7
- Borrar las reglas UFW obsoletas de `192.168.1.x` en VM 110 y 120 (**DT-26**).
- Actualizar `~/.ssh/config` en Windows: `goloca-bastion` → `10.20.0.40`, `goloca-app01` → `10.20.0.20` (ProxyJump), `goloca-pve` → `10.20.0.10`.
- Verificar que el LXC `ia-gpu` recuperó red por DHCP y sigue operativo.
- Decidir dónde va la Raspberry: sigue en la red doméstica colgando del TP-Link.
- Evaluar **DT-24** (FortiOS 6.2.5 fuera de soporte) antes de exponer nada a Internet en P1.2.
- **DT-22**: aprovechar el próximo acceso físico al servidor para desactivar la espera de Enter en el BIOS.

### P1.2 — SSL-VPN + DDNS
- DuckDNS + `config system ddns`.
- Portal SSL-VPN tunnel mode, pool `10.10.99.0/24`, puerto 10443.
- **DMZ Host en el HGU apuntando al FortiGate.** A partir de ese momento la WAN del FortiGate recibe tráfico de Internet: revisar antes que no haya administración expuesta y valorar DT-24.

### Cuando empiece P2
- Probar `baseline-setup.sh` sobre VM limpia (`db-prod-01`) → validar reproducibilidad real.

### Cuando empiece P3 (K3s)
- Crear `k3s-master-01` y `k3s-worker-01` sobre `local-lvm-nvme2` (rol asignado en sesión 6).

### Cuando empiece P6 (LLM local)
- Decidir el destino de `ia-gpu` (LXC 130) y resolver **DT-23** (driver a nivel host vs VFIO exclusivo). La VM de LLM se aloja en `local-lvm-nvme1`.

### Pendiente de subir a GitHub
- `PROGRESS-LOG.md` v1.6 (este archivo).
- Backup de configuración del FortiGate en `infrastructure/fortigate/backups/`.
- Docs de P1.1: `01-network-architecture.md`, `01-vlan-zoning-rationale.md`, `01-firewall-policy-matrix.md`.
- Los 5 runbooks nuevos de la sesión 7 (ver tabla de runbooks).
- **Configs reales extraídas de las VMs** (siguen viviendo solo dentro de ellas):
  - `infrastructure/proxmox/cloud-init/user-data-default.yaml`
  - `infrastructure/proxmox/network/interfaces` (ya migrado a 10.20.0.10/24)
  - `infrastructure/linux-baseline/sshd_config.d/00-goloca.conf`
  - `infrastructure/linux-baseline/ufw-rules-*.sh`, `journald-config/`, `unattended-upgrades/`
  - `infrastructure/docker/install-docker-ubuntu.sh`
- Docs/runbooks de P1.4 y P1.5 (provisioning, ProxyJump, VS Code) — aún no escritos.

---

## DECISIONES OPERACIONALES TOMADAS

| Fecha | Decisión | Justificación |
|---|---|---|
| 22-may | Avanzar P1.3 sin completar P1.1/P1.2 | Cable consola bloquea, Proxmox no |
| 22-may | IP temporal Proxmox 192.168.1.101 | Trabajo paralelo sin FortiGate |
| 23-may | `mask ssh.socket` (no override del puerto) | Solución robusta; override limpio en P6 |
| 23-may | Discos: bastion 20 GB, app01 40 GB | app01 corre Docker+PG+Redis en P2 |
| 23-may | Clave SSH operativa = la de Windows | La de Proxmox quedó con formato roto |
| 24-may | Recuperar SSH vía `guestfish` (no GRUB/cipassword) | Determinista, sin password ni timing. GRUB no capturable, cipassword no reaplica en reboot |
| 24-may | Migrar VMs a `local-lvm-nvme1` (opción A, no autoextend) | Corrige causa raíz (pool equivocado), no parchea síntoma. 16 GB de margen no bastan para autoextend |
| 24-may | UFW app01 estricto (solo bastión, no /24) | Fiel al patrón bastión: app01 solo accesible vía bastión. ProxyJump ya hace origen=bastión |
| 24-may | Baseline pieza a pieza (no script directo) | Didáctico: entender cada elemento antes de automatizar |
| 24-may | Script parametrizado por args (opción A, no 2 copias) | Un artefacto, evita reintroducir DT-20. Traduce limpio a Ansible en P5 |
| 24-may | No ejecutar baseline-setup.sh sobre VMs actuales | Ya tienen baseline a mano. Probar en VM limpia (P2/P3) tiene más valor |
| 24-may (S5) | No adelantar P2 en esta sesión | La red DMZ de P2 se reharía tras migrar a 10.x. Consolidar portfolio P1 en su lugar |
| 24-may (S5) | Docs con trade-offs explícitos (no specs secas) | Diferenciador de portfolio: el "por qué" separa criterio de tutorial copiado |
| 24-may (S5) | `.gitattributes` en repo (no `core.autocrlf`) | Portable: viaja con el repo, protege cualquier clon. Crítico Windows dev → Linux infra |
| 24-may (S5) | Runbooks autocontenidos (no enlazan a docs) | Documento de emergencia: debe funcionar solo, bajo presión, sin abrir nada más |
| 27-ago (S6) | No tocar el LXC "ia-gpu" ahora; decisión aplazada a P6 | El aprendiz quiere seguir usándolo mientras tanto; forzar una migración ahora sería trabajo desechable si las cargas cambian antes de P6 |
| 27-ago (S6) | Samsung SSD excluido en exclusiva para ia-gpu; NVMe2 asume el rol de storage K3s/secundarias | Evita contar como "libre" un espacio que en la práctica pertenece a otro proyecto; NVMe2 estaba vacío y sin uso asignado desde sesión 2 |
| 27-ago (S6) | VM de LLM local (P6) planificada en `local-lvm-nvme1`, no en nvme2 ni en Samsung | Es un servicio de plataforma singular, no parte del clúster K3s; mantiene la separación de tiers "plataforma" vs "cómputo K3s" |
| 27-ago (S7) | **Factory reset del FortiGate sin inspeccionar la configuración previa** | Equipo de segunda mano sin datos de valor; partir de un estado conocido elimina variables ocultas |
| 27-ago (S7) | **Renumerar la LAN a `10.20.0.1/24` en lugar de parchear el solapamiento** | Corrige la causa raíz y adelanta el direccionamiento que el roadmap ya exigía. Parchear habría dejado la ambigüedad de rutas latente |
| 27-ago (S7) | **AP y TP-Link permanecen en la red doméstica** | Un solo cable entre plantas obliga a elegir; meter el WiFi doméstico en la red de servidores contradice el objetivo del proyecto y convierte cada error de laboratorio en una incidencia de la casa |
| 27-ago (S7) | **Rechazado habilitar administración en la interfaz WAN** | Choca con el DMZ Host de P1.2 (expondría la GUI a Internet) y con el NAT de 80/443 de P2. Además reintroduciría el solapamiento de subredes recién corregido |
| 27-ago (S7) | **Direccionamiento dual transitorio para migrar Proxmox (no cambio directo)** | El servidor no tiene monitor ni teclado. Responder en las dos redes a la vez elimina la ventana ciega y permite revertir devolviendo el cable |
| 27-ago (S7) | **`qemu-guest-agent` para migrar las VMs, no SSH ni consola noVNC** | Canal virtio independiente de la red: funciona con la VM aislada y evita el callejón sin contraseña de consola que bloqueó la sesión 4 |
| 27-ago (S7) | **UFW actualizado ANTES de cambiar las IPs de las VMs** | Invertir el orden habría dejado las VMs arrancando bien pero rechazando el SSH del operador |
| 27-ago (S7) | **Verificar cada cambio del FortiGate contra el estado guardado, no contra el eco de consola** | El equipo aceptó visualmente comandos que no se aplicaron (timezone). A 9600 baudios el eco no es prueba de nada |

---

## MÉTRICAS DEL PROGRESO

| Métrica | Valor |
|---|---|
| Mini-proyectos P1 completados | 4 de 6 (P1.3, P1.4, P1.5, P1.6) |
| Mini-proyectos P1 en progreso | 1 (P1.1, ~40%) |
| Mini-proyectos P1 pendientes | 1 (P1.2) |
| Avance porcentual P1 | ~72% |
| Avance global roadmap | ~12% |
| Commits en GitHub | 7 (initial ×2, estructura, log S1-3, Terminado 1.6, docs P1.3/P1.6, .gitattributes, runbooks) — pendiente confirmar si sigue así tras 3 meses |
| Deudas técnicas registradas | 27 (DT-01 a DT-27) |
| Deudas técnicas resueltas | 8 (DT-11,12,14,16,17,18,19,20) + DT-21 parcial |
| Desviaciones del plan | 14 (D-01 a D-14); resueltas: D-02, D-06, D-07, D-09, D-10, D-11 |
| Incidentes mayores resueltos | 2 (pérdida SSH ambas VMs — S4; sin salida a Internet por solapamiento de subredes — S7) |
| Equipos detrás del firewall | 5 (Proxmox, bastion, app01, PC estudio, portátil) + LXC ia-gpu |
| Storages LVM operativos (roadmap) | 4 (3 thin-pool + 1 backup ext4) — más 1 storage adicional (`local-lvm-ssd-samsung`) fuera del roadmap, en uso por ia-gpu |
| VMs operativas (roadmap) | 2 (bastion, app01) en `local-lvm-nvme1` + 1 template (9000) |
| Recursos ajenos al roadmap detectados | 1 (LXC 130 "ia-gpu", GPU + 182,6 GB en Samsung SSD) |
| Snapshots activos | 4 (2 por VM) |
| Entregables de código | 1 (`baseline-setup.sh`, 142 líneas, idempotente) |
| Documentos de portfolio (docs/) | 6 (P1.3 ×2, P1.6 ×4) |
| Runbooks operacionales (runbooks/) | 5 (S4: guestfish, systemd offline, move-disk, UFW, Docker) |

---

## CHANGELOG DEL ARCHIVO

| Fecha | Versión | Cambios |
|---|---|---|
| 2026-05-22 | 1.0 | Creación. Volcado de sesiones 1 y 2. |
| 2026-05-22 | 1.1 | Detalle de storages LVM paso a paso. DT-16. Métricas. |
| 2026-05-23 | 1.2 | Sesión 3. P1.4 y P1.5 cerrados. Hardening SSH, ProxyJump, VS Code. D-07/08/09, DT-17/18/19/20. |
| 2026-05-24 | 1.3 | Sesión 4. **P1.3 cerrado 100%** (DT-11/14/16). **Incidente mayor SSH** (DT-17 mal cerrado, rescate guestfish ambas VMs). **Migración almacenamiento** local-lvm→nvme1 (D-10). **P1.6 completo** (baseline 6 piezas + Docker). **`baseline-setup.sh`** (cierra DT-19/20). DT-21/22 nuevas. P1 al 67%, global ~11%. 7 deudas resueltas. |
| 2026-05-24 | 1.4 | Sesión 5 (consolidación de portfolio, sin avance de infra). Corregido dato falso de commits (eran 7, no 1). **6 docs de P1.3/P1.6** subidos (`fb0133a`). **`.gitattributes`** para line endings Windows→Linux (`243f3f3`). **5 runbooks operacionales de S4** subidos (`1a48d88`). `docs/` y `runbooks/` pasan de vacías a pobladas. Pendiente: extraer configs reales de las VMs a archivos versionados. |
| 2026-08-28 | 1.6 | Sesión 7 (primera sesión de ejecución desde mayo). **FortiGate recuperado y operativo** (consola serie, diafonía de cable diagnosticada, `maintainer`, `factoryreset`, hostname/NTP/timezone) — cierra D-06. **Incidente mayor: sin salida a Internet por solapamiento de subredes WAN/LAN**, resuelto renumerando la LAN a `10.20.0.1/24`. **Migración completa del laboratorio a `10.20.0.0/24`**: Proxmox `.10` (direccionamiento dual en caliente, sin perder acceso), bastion `.40` y app01 `.20` (vía `qemu-guest-agent`, sin SSH ni consola), PC estudio y portátil por DHCP. Corregido el `/32` de `vmbr0` heredado de S2. Cierra D-02, DT-12; DT-21 aplicada parcialmente. Nuevas D-13/D-14 y DT-24 a DT-27. P1.1 al ~40%, P1 al ~72%. |
| 2026-08-27 | 1.5 | Sesión 6 (reconexión tras 3 meses). Auditoría completa de Proxmox. **Hallazgo D-12/DT-23:** LXC "ia-gpu" ajeno al roadmap ocupa el SSD Samsung (182,6 GB) y comparte la GPU a nivel de host, incompatible con el plan VFIO original de P6. **Recalculado el plan de almacenamiento:** Samsung excluido en exclusiva para ia-gpu; NVMe2 (antes vacío) asume el rol de storage para K3s/VMs secundarias de P3; VM de LLM local de P6 planificada en NVMe1 junto al resto de plataforma. Decisión sobre el futuro de ia-gpu y la GPU aplazada a P6. Cable de consola del FortiGate confirmado como ya disponible — P1.1/P1.2 sin bloqueador, pendientes de agenda. Red de bastion/app01 confirmada aún sin migrar a 10.x. |

---

## REGLA DE ACTUALIZACIÓN

Este archivo se actualiza:
- **Al inicio de cada sesión:** revisión rápida del estado actual.
- **Durante la sesión:** en cuanto se toma una decisión importante o se detecta una desviación.
- **Al final de cada sesión:** resumen consolidado.
- **Cada 2 semanas:** consolidación en el documento maestro `ROADMAP.md`.
