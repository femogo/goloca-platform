# PROGRESS LOG — GOLOCA AI INFRASTRUCTURE PLATFORM

> **Bitácora incremental** del avance del roadmap. Se actualiza en cada sesión de trabajo.  
> **Fuente de verdad estratégica:** `ROADMAP.md`  
> **Fuente de verdad operacional:** este archivo.

---

## ESTADO GLOBAL ACTUAL

**Fecha última actualización:** 27 agosto 2026 (v1.5 — fin sesión 6)  
**Proyecto activo:** P1 — Infraestructura Base, Networking Real y Virtualización  
**Mini-proyecto activo:** P1.1 — Segmentación FortiGate (cable de consola ya disponible, ejecución aún no iniciada)  
**Mini-proyectos bloqueados:** ninguno (el bloqueador del cable se resolvió; queda pendiente de agenda)  
**Foco sesión 6:** reconexión tras 3 meses de inactividad. Auditoría completa del estado real de Proxmox (discos, VMs, LXC, GPU) y reconciliación contra lo documentado. Detectada deriva no registrada: un LXC ajeno al roadmap ("ia-gpu") ocupa el SSD Samsung y comparte la GPU a nivel de host. Recalculado el plan de almacenamiento para el resto del roadmap. Sin avance de infraestructura del propio roadmap (FortiGate sigue sin configurar).

---

## RESUMEN EJECUTIVO DEL ESTADO

| Mini-Proyecto | Estado | Bloqueador |
|---|---|---|
| P1.1 — Segmentación FortiGate | ⏸️ PENDIENTE DE EJECUCIÓN | Ninguno (cable de consola ya llegó) |
| P1.2 — SSL-VPN + DDNS | ⏸️ PENDIENTE | Depende de P1.1 |
| P1.3 — Proxmox VE bare-metal | ✅ COMPLETADO | Cerrado 100% (DT-11/14/16 saldadas) |
| P1.4 — Template Ubuntu + Cloud-Init | ✅ COMPLETADO | — |
| P1.5 — Bastión + VS Code Remote SSH | ✅ COMPLETADO | — |
| P1.6 — Linux baseline + Docker | ✅ COMPLETADO | Cerrado en sesión 4 |

**P1 al 67% (4 de 6 mini-proyectos).** Solo restan P1.1 y P1.2. El bloqueador original (cable de consola) ya no existe — falta agendar la ejecución.

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
| D-10 | VMs nacieron en `local-lvm` (no `local-lvm-nvme1`) | Desviación de sesión 2 no aplicada al clonar | Sobreaprovisionamiento thin-pool, riesgo corrupción | Resuelto sesión 4 (`qm move-disk`) |
| D-11 | VS Code Server / disco app01 al 96% en sesión 3 | (ya cubierto en D-07) | — | Resuelto sesión 3 |
| **D-12** | **SSD Samsung (nvme3, 465 GB) ocupado por LXC "ia-gpu", ajeno al roadmap, con GPU compartida a nivel de host** | **Uso del hardware para proyectos personales de IA durante la pausa de 3 meses** | **El rol "VMs secundarias / K3s" previsto para el Samsung se reasigna a NVMe2. GPU no disponible para P6 tal como estaba planeada (VFIO exclusivo) hasta decidir qué pasa con ia-gpu** | **Aceptado sesión 6. Recalculado plan de almacenamiento. GPU pendiente de decisión en P6** |

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
| DT-12 | IP Proxmox en 192.168.1.101 temporal | Migrar a 10.20.0.10 con FortiGate | Pendiente (cable ya disponible, migración sin iniciar) |
| DT-13 | HDD 1 TB no detectado | Verificar conexión física | Pendiente |
| DT-14 | USB de instalación conectado (`/dev/sdb`) | Desconectar físicamente | ✅ RESUELTA sesión 4 |
| DT-15 | DNS por defecto Proxmox 8.8.8.8 | Cambiar a 10.10.0.1 con FortiGate forwarder | Pendiente (cable ya disponible, migración sin iniciar) |
| DT-16 | `/mnt/backup-pny` no en fstab | Añadir con `nofail` | ✅ RESUELTA (verificada sesión 4) |
| DT-17 | `ssh.socket` fuerza puerto, ignora sshd_config | `mask ssh.socket` + `enable ssh.service` | ✅ RESUELTA DE VERDAD sesión 4 (faltaba el enable) |
| DT-18 | Clon CloudImg hereda disco base ~3.5 GB | `qm disk resize`+growpart+resize2fs | ✅ RESUELTA sesión 3. P5: automatizar en Terraform |
| DT-19 | Hardening/baseline aplicado a mano post-clon | Script idempotente de baseline | ✅ RESUELTA sesión 4 (`baseline-setup.sh`) |
| DT-20 | Divergencia bastion (cicustom) vs app01 (UI) | Baseline único reproducible | ✅ RESUELTA sesión 4 (convergidas + script parametrizado) |
| DT-21 | Reglas UFW con origen transitorio `192.168.1.x` | Endurecer a `10.10.x` (bastion) / `10.20.0.40` (app01) post-FortiGate | Pendiente (cable ya disponible, migración sin iniciar) |
| DT-22 | BIOS se detiene en boot esperando Enter (sin monitor) | Acceso físico al BIOS: desactivar "wait on error/F1". Hacer junto a config FortiGate | Pendiente |
| **DT-23** | **Driver NVIDIA instalado a nivel de host Proxmox (no aislado en VM), GPU compartida con LXC "ia-gpu" vía device bind + cgroup2** | **P6: decidir si se migra a VFIO/IOMMU exclusivo hacia la VM de LLM local (implica desvincular el driver del host y las cargas de ia-gpu) o si se acepta el modelo compartido como desviación permanente** | **Nueva sesión 6. Sin resolución hasta P6** |

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

---

## PRÓXIMOS PASOS INMEDIATOS

### Bloqueante crítico
- Ninguno. El cable USB-RJ45 FTDI ya llegó — falta agendar la sesión de ejecución de P1.1.

### Trabajo pendiente (P1.1 + P1.2 + migración de red)
1. Reset FortiGate vía consola serie + cuenta `maintainer`.
2. Configuración inicial FortiGate (P1.1): 4 zonas físicas, políticas least-privilege, NAT, DHCP, logging.
3. SSL-VPN + DDNS (P1.2).
4. Aprovechar el acceso físico al servidor para resolver DT-22 (BIOS boot sin Enter).
5. **Migración de red 192.168.1.x → 10.x:**
   - Proxmox: 192.168.1.101 → 10.20.0.10 (DT-12).
   - DNS Proxmox: 8.8.8.8 → 10.10.0.1 (DT-15).
   - VMs 110/120: reconfigurar `ipconfig0` a 10.20.0.x (actualmente en 192.168.1.110/.120). Reconfigurar `~/.ssh/config` en Windows.
   - **Endurecer reglas UFW (DT-21):** bastion → `10.10.0.0/24`+`10.10.99.0/24`; app01 → `10.20.0.40`+`10.10.99.0/24`.

### Cuando empiece P3 (K3s)
- Crear `k3s-master-01` y `k3s-worker-01` sobre `local-lvm-nvme2` (nuevo rol asignado en sesión 6 — ver tabla de almacenamiento recalculado). Probar ahí también `baseline-setup.sh` sobre VM limpia para validar reproducibilidad real.

### Cuando empiece P6 (LLM local)
- Decidir el destino de "ia-gpu" (LXC 130): migrar sus cargas dentro de la VM de P6 (Ollama + NVIDIA Container Toolkit) o descartarlo. Resolver DT-23 (driver a nivel host vs VFIO exclusivo a la VM). La VM de LLM se aloja en `local-lvm-nvme1`, no en el Samsung (reservado para ia-gpu) ni en nvme2 (reservado para K3s).

### Pendiente de subir a GitHub (lo que queda)
- `PROGRESS-LOG.md` v1.5 (este archivo, esta sesión).
- **Configs reales extraídas de las VMs** (no existen como archivos versionados, viven solo dentro de las VMs):
  - `infrastructure/proxmox/cloud-init/user-data-default.yaml`
  - `infrastructure/linux-baseline/sshd_config.d/00-goloca.conf`
  - `infrastructure/linux-baseline/ufw-rules-*.sh`, `journald-config/`, `unattended-upgrades/`
  - `infrastructure/docker/install-docker-ubuntu.sh`
  - Requiere SSH a VMs vivas (bastion/app01) + ProxyJump operativo.
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

---

## MÉTRICAS DEL PROGRESO

| Métrica | Valor |
|---|---|
| Mini-proyectos P1 completados | 4 de 6 (P1.3, P1.4, P1.5, P1.6) |
| Mini-proyectos P1 pendientes | 2 (P1.1, P1.2 — sin bloqueador, pendientes de ejecución) |
| Avance porcentual P1 | ~67% |
| Avance global roadmap | ~11% |
| Commits en GitHub | 7 (initial ×2, estructura, log S1-3, Terminado 1.6, docs P1.3/P1.6, .gitattributes, runbooks) — pendiente confirmar si sigue así tras 3 meses |
| Deudas técnicas registradas | 23 (DT-01 a DT-23) |
| Deudas técnicas resueltas | 7 (DT-11,14,16,17,18,19,20) |
| Desviaciones del plan | 12 (D-01 a D-12) |
| Storages LVM operativos (roadmap) | 4 (3 thin-pool + 1 backup ext4) — más 1 storage adicional (`local-lvm-ssd-samsung`) fuera del roadmap, en uso por ia-gpu |
| VMs operativas (roadmap) | 2 (bastion, app01) en `local-lvm-nvme1` + 1 template (9000) |
| Recursos ajenos al roadmap detectados | 1 (LXC 130 "ia-gpu", GPU + 182,6 GB en Samsung SSD) |
| Snapshots activos | 4 (2 por VM) |
| Incidentes mayores resueltos | 1 (pérdida SSH ambas VMs — DT-17) |
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
| 2026-08-27 | 1.5 | Sesión 6 (reconexión tras 3 meses). Auditoría completa de Proxmox. **Hallazgo D-12/DT-23:** LXC "ia-gpu" ajeno al roadmap ocupa el SSD Samsung (182,6 GB) y comparte la GPU a nivel de host, incompatible con el plan VFIO original de P6. **Recalculado el plan de almacenamiento:** Samsung excluido en exclusiva para ia-gpu; NVMe2 (antes vacío) asume el rol de storage para K3s/VMs secundarias de P3; VM de LLM local de P6 planificada en NVMe1 junto al resto de plataforma. Decisión sobre el futuro de ia-gpu y la GPU aplazada a P6. Cable de consola del FortiGate confirmado como ya disponible — P1.1/P1.2 sin bloqueador, pendientes de agenda. Red de bastion/app01 confirmada aún sin migrar a 10.x. |

---

## REGLA DE ACTUALIZACIÓN

Este archivo se actualiza:
- **Al inicio de cada sesión:** revisión rápida del estado actual.
- **Durante la sesión:** en cuanto se toma una decisión importante o se detecta una desviación.
- **Al final de cada sesión:** resumen consolidado.
- **Cada 2 semanas:** consolidación en el documento maestro `ROADMAP.md`.
