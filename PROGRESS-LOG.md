# PROGRESS LOG — GOLOCA AI INFRASTRUCTURE PLATFORM

> **Bitácora incremental** del avance del roadmap. Se actualiza en cada sesión de trabajo.  
> **Fuente de verdad estratégica:** `ROADMAP.md`  
> **Fuente de verdad operacional:** este archivo.

---

## ESTADO GLOBAL ACTUAL

**Fecha última actualización:** 23 mayo 2026 (v1.2 — fin sesión 3)  
**Proyecto activo:** P1 — Infraestructura Base, Networking Real y Virtualización  
**Mini-proyecto activo:** P1.6 — Linux baseline + Docker (siguiente)  
**Mini-proyectos bloqueados:** P1.1 y P1.2 (FortiGate, esperando cable de consola)

---

## RESUMEN EJECUTIVO DEL ESTADO

| Mini-Proyecto | Estado | Bloqueador |
|---|---|---|
| P1.1 — Segmentación FortiGate | ⏸️ BLOQUEADO | Cable de consola en pedido |
| P1.2 — SSL-VPN + DDNS | ⏸️ PENDIENTE | Depende de P1.1 |
| P1.3 — Proxmox VE bare-metal | ✅ COMPLETADO | DT-16 aún pendiente (fstab) |
| P1.4 — Template Ubuntu + Cloud-Init | ✅ COMPLETADO | — |
| P1.5 — Bastión + VS Code Remote SSH | ✅ COMPLETADO | — |
| P1.6 — Linux baseline + Docker | 🟡 SIGUIENTE | Depende de P1.5 (cerrado) |

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

**Duración:** ~3 horas (en curso).  
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

10. **Configuración de almacenamiento (ejecutada paso a paso vía CLI):**

    Los discos venían con particiones residuales (el instalador Proxmox los había tocado, y el PNY tenía un Ubuntu LVM viejo). Hubo que limpiarlos antes de crear los thin-pools. Secuencia real ejecutada:

    **Para cada NVMe adicional (nvme1, nvme2, nvme3):**
    ```bash
    wipefs -af /dev/nvmeXn1        # Borra firmas de filesystem
    sgdisk -Z /dev/nvmeXn1         # Destruye tabla de particiones GPT
    pvcreate /dev/nvmeXn1          # Crea Physical Volume
    vgcreate vg-XXXX /dev/nvmeXn1  # Crea Volume Group
    lvcreate -L XXXG -n vm-data vg-XXXX        # Crea Logical Volume
    lvconvert --type thin-pool vg-XXXX/vm-data # Lo convierte a thin-pool
    ```
    Durante el `lvcreate` saltaron warnings de firma vfat residual en 3 offsets (82, 0, 510) → respondido `y` para limpiar.

    **Para el SSD PNY (`/dev/sda`):** estaba EN USO por el sistema (tenía `ubuntu-vg/ubuntu-lv` montado de un Ubuntu anterior). Falló el primer intento de `mkfs.ext4` con "device is in use". Resolución:
    ```bash
    umount /dev/sda
    lvremove -f ubuntu-vg          # Eliminar el LVM viejo
    pvremove /dev/sda
    pvcreate /dev/sda
    vgcreate vg-backup /dev/sda
    lvcreate -L 220G -n backup vg-backup
    mkfs.ext4 /dev/vg-backup/backup
    mkdir -p /mnt/backup-pny
    mount /dev/vg-backup/backup /mnt/backup-pny
    ```

    **Resultado final verificado (`lvs` / `vgs`):**
      - `vg-nvme1/vm-data` → thin-pool 230 GB → registrado como `local-lvm-nvme1`
      - `vg-nvme2/vm-data` → thin-pool 230 GB → registrado como `local-lvm-nvme2`
      - `vg-samsung/vm-data` → thin-pool 450 GB → registrado como `local-lvm-ssd-samsung`
      - `vg-backup/backup` → ext4 220 GB montado en `/mnt/backup-pny` → registrado como `backup-pny` (Content: Copias de seguridad / VZDump)

    **Pendiente operativo:** el montaje de `/mnt/backup-pny` NO se ha añadido a `/etc/fstab`. Tras un reboot, el disco de backup NO se montará automáticamente. **Hay que añadir la línea a fstab antes de dar P1.3 por cerrado** (ver DT-16).

11. **Boot Manager residual de Windows Server detectado.** Al reiniciar tras instalación, BIOS muestra opciones múltiples. Resolución: seleccionar manualmente entrada de Proxmox. **PENDIENTE limpiar entradas EFI antiguas con `efibootmgr -b N -B`.**

12. **Inicio P1.4 — Template Ubuntu:**
    - Primer intento: imagen no estaba descargada (se asumió por error que sí).
    - Lanzada descarga de `ubuntu-24.04-server-cloudimg-amd64.img` desde cloud-images.ubuntu.com a `/var/lib/vz/template/iso/`.

13. **Pausa formativa — explicación de conceptos.** El aprendiz pidió entender qué había hecho (no solo ejecutar comandos). Se explicaron en profundidad: qué es un hipervisor, thin vs thick provisioning, jerarquía PV→VG→LV, por qué se usan Volume Groups aunque haya 1 disco por función (expansión futura sin downtime, `vgextend`/`lvextend`/`pvmove`), por qué el disco de backup va sin LVM (storage plano), y la correspondencia Proxmox↔AWS (LVM≈EBS, thin-pool≈gp3, directory≈S3, VZDump≈snapshots, LXC≈ECS, KVM≈EC2).

14. **Pausa estratégica — visión de producto.** Se explicó el "para qué" último de Goloca AI: plataforma de agentes IA para empresas medianas europeas reguladas, modo Sovereign (LLM local) como diferenciador frente a AI Act EU, multi-tenancy, RAG con pgvector, y cómo cada mini-proyecto del roadmap desbloquea una capacidad comercial nueva. Referencias reales de mercado: Mistral, DeepL, Aleph Alpha, Helsing, Pleias.

15. **Creación de este PROGRESS-LOG.md** como memoria operacional persistente del proyecto, separada del ROADMAP.md estratégico.

### Sesión 3 — 23 mayo 2026 (mañana)

**Duración:** ~3 horas.  
**Trabajo realizado:**

1. **P1.4 CERRADO — Template Ubuntu + Cloud-Init.**
   - Imagen `ubuntu-24.04-server-cloudimg-amd64.img` descargada a `/var/lib/vz/template/iso/` (599 MB → 1.1 GB tras inyección de qemu-guest-agent).
   - `libguestfs-tools` instalado. `virt-customize` inyectó `qemu-guest-agent` offline en la imagen base (`--install qemu-guest-agent --run-command "systemctl enable qemu-guest-agent"`).
   - Snippet cloud-init creado en `/var/lib/vz/snippets/ubuntu-base.yaml`. Hubo que crear el directorio `snippets/` (no existía → `mkdir -p`).
   - Clave SSH Ed25519 generada finalmente EN WINDOWS (`C:\Users\Fer\.ssh\id_ed25519`). La clave generada antes en Proxmox se descartó: copiarla a Windows rompió el formato (`invalid format`).
   - Template 9000 (`ubuntu-24-tpl`): disco vacío inicial de 30 GB descartado (`qm unlink`), imagen real importada a `scsi1`, cloud-init drive en `ide2`, convertido a template (`qm template 9000` renombró el disco a `base-9000-disk-2`).
   - VM 110 (`bastion-prod-01`) clonada con `--full`, cicustom + ipconfig0 vía CLI. Arranque OK, SSH por clave OK. IP `192.168.1.110`.
   - VM 120 (`app-prod-01`) clonada vía UI (Full Clone desde template 9000). Cloud-Init configurado vía UI (User=ubuntu, SSH key, IP) + Regenerate Image. Recursos 2 vCPU / 4 GB. IP `192.168.1.120`.
   - **Incidente:** primer intento de VM 120 se creó como VM vacía (wizard Create VM, sin importar imagen del template) → no arrancaba bien, sin SSH. Se destruyó (`qm destroy 120`) y se rehízo como Full Clone del template.

2. **P1.5 CERRADO — Bastión + VS Code Remote SSH.**
   - Hardening SSH en ambas VMs: `/etc/ssh/sshd_config.d/00-goloca.conf` (Port 2222, PasswordAuthentication no, PermitRootLogin no, AllowUsers ubuntu, MaxAuthTries 3, X11Forwarding no).
   - **Troubleshooting mayor (DT-17):** en Ubuntu 24.04, `ssh.socket` (systemd socket activation) define el puerto e IGNORA el `Port` de sshd_config. SSH seguía en 22 pese a config válida (`sshd -t` OK). Resuelto con `systemctl disable --now ssh.socket` + `systemctl mask ssh.socket` + `systemctl restart ssh.service`. Aplicado en bastion Y app01.
   - SSH config en Windows (`C:\Users\Fer\.ssh\config`): aliases `goloca-bastion`, `goloca-app01` (con ProxyJump a goloca-bastion), `goloca-pve`.
   - ProxyJump verificado: Windows → bastión (2222) → app01 (2222) en un solo comando (`ssh goloca-app01`).
   - VS Code Remote SSH conectado a `goloca-app01` vía ProxyJump. Terminal integrada confirmada dentro de app-prod-01.

3. **Troubleshooting de disco (DT-18):** VS Code Server falló con `No space left on device` (código 28). Causa: el clon de un template CloudImg hereda el disco base (~3.5 GB, partición raíz de 2.4 GB), NO el tamaño del wizard. Disco app01 al 96%.
   - Resolución app01: `qm disk resize 120 scsi1 +37G` → `growpart /dev/sda 1` → `resize2fs /dev/sda1` (en caliente, sin reboot). Resultado: 39 GB, 6% uso.
   - Resolución bastion (preventiva): `qm disk resize 110 scsi1 +17G` → growpart → resize2fs. Resultado: 19 GB, 11% uso.

4. **Corrección de hostname:** bastion arrancó como `ubuntu-base` (hostname fijo del snippet `ubuntu-base.yaml`). Corregido con `hostnamectl set-hostname bastion-prod-01`. app01 ya tenía hostname correcto: la Cloud-Init UI + Regenerate Image lo sobrescribe; el snippet cicustom NO se aplicó en app01 porque se configuró todo por UI.

---

## DESVIACIONES DEL PLAN ORIGINAL
Cambios respecto a lo que dice `ROADMAP.md`:

| ID | Desviación | Causa | Impacto | Estado |
|---|---|---|---|---|
| D-01 | Proxmox VE 9.2 instalado (no 8.x previsto) | Versión más reciente disponible | Positivo. Más estable y con mejoras. | Aceptado |
| D-02 | IP Proxmox temporalmente en 192.168.1.101 (no 10.20.0.10) | FortiGate aún sin configurar (bloqueado por cable) | Temporal. Requiere migración cuando FortiGate funcione. | Aceptado provisional |
| D-03 | 4 NVMe + 1 SATA SSD detectados (no 2 NVMe + 1 SSD + 1 SSD + 1 HDD previsto) | Inventario real difiere del planificado | Más almacenamiento NVMe disponible. HDD 1 TB no aparece. | Aceptado |
| D-04 | HDD 1 TB no detectado por Proxmox | Posiblemente desconectado físicamente | Backups irán a SSD PNY en lugar de HDD | Pendiente verificación física |
| D-05 | P1.3 ejecutado antes de P1.1 y P1.2 | Bloqueo de FortiGate por cable de consola | Orden de trabajo adaptado | Aceptado provisional |
| D-06 | FortiGate fue equipo de segunda mano con configuración previa | No documentado al inicio del roadmap | Reset físico no funcionó. Requiere acceso `maintainer` vía consola serie | Diagnóstico cerrado, pendiente cable |
| D-07 | VM 110 y 120 nacen con disco 3.5 GB pese al wizard | Clon de CloudImg hereda disco base del template | Requiere resize manual post-clon (qm disk resize + growpart + resize2fs) | Resuelto en sesión 3 |
| D-08 | Clave SSH Ed25519 generada en Windows, no en Proxmox | Copiar la clave de Proxmox a Windows rompió el formato | La clave operativa es la de Windows; la de Proxmox quedó huérfana | Aceptado |
| D-09 | app01 configurado 100% por UI (Cloud-Init UI + Regenerate), no por cicustom snippet | Decisión de hacer la segunda VM por UI | app01 NO usa el snippet ubuntu-base.yaml; bastion SÍ | Aceptado — divergencia a unificar en P1.6 |

---

## DEUDAS TÉCNICAS NUEVAS DETECTADAS EN ESTA EJECUCIÓN

| ID | Deuda | Resolución |
|---|---|---|
| DT-11 | Entradas EFI residuales del Windows Server anterior | Ejecutar `efibootmgr -B` para limpiar al final de P1.3 |
| DT-12 | IP Proxmox en 192.168.1.101 temporal | Migrar a 10.20.0.10 cuando FortiGate esté operativo |
| DT-13 | HDD 1 TB no detectado | Verificar conexión física en próxima visita al servidor |
| DT-14 | USB de instalación Proxmox aún conectado al servidor (visible como `/dev/sdb` 28.9 GB) | Desconectarlo después de validar arranque |
| DT-15 | DNS por defecto Proxmox 8.8.8.8 (no 10.10.0.1 previsto) | Cambiar cuando FortiGate sea DNS forwarder |
| DT-16 | `/mnt/backup-pny` montado manualmente, NO en `/etc/fstab` | Añadir entrada a fstab con `nofail` antes de cerrar P1.3. Si no, el backup no monta tras reboot |
| DT-17 | Ubuntu 24.04 socket activation (`ssh.socket`) fuerza el puerto SSH e ignora `sshd_config`. Resuelto con `mask ssh.socket` | Documentar en runbook 05. En P6 evaluar override del socket (más limpio que mask) |
| DT-18 | Clon de template CloudImg hereda disco base (~3.5 GB), no el tamaño deseado. Requiere `qm disk resize` + `growpart` + `resize2fs` | P5: automatizar con Terraform (`disk_size` en el recurso) |
| DT-19 | Hardening SSH (puerto 2222 + opciones) se aplica a mano post-clon, no está en el aprovisionamiento | P1.6: mover hardening a script de baseline idempotente o al snippet cloud-init |
| DT-20 | Divergencia bastion/app01: bastion usa snippet cicustom, app01 usa Cloud-Init UI. Aprovisionamiento no homogéneo | P1.6: definir un único método de baseline reproducible para ambas |

---

## RUNBOOKS GENERADOS DURANTE LA EJECUCIÓN

| Runbook | Pendiente de documentar en repo | Origen |
|---|---|---|
| Cómo cambiar IP de Proxmox tras instalación (editar `/etc/network/interfaces` + `systemctl restart networking`) | Sí | Sesión 2 |
| Cómo crear thin-pool LVM en disco NVMe (pvcreate→vgcreate→lvcreate→lvconvert) | Sí | Sesión 2 |
| Cómo limpiar disco con particiones previas (`wipefs -af`, `sgdisk -Z`) | Sí | Sesión 2 |
| Cómo liberar un disco "en uso" con LVM viejo montado (`umount`→`lvremove -f`→`pvremove`) | Sí | Sesión 2 |
| Cómo resolver "host key changed" en SSH tras cambio de IP (`ssh-keygen -R <ip>`) | Sí | Sesión 2 |
| Cómo recuperar de Boot Manager mostrando opciones múltiples post-reinstalación (seleccionar entrada Proxmox; limpiar EFI con `efibootmgr -B`) | Sí | Sesión 2 |
| Cómo descartar el aviso "no tienes suscripción válida" de Proxmox | Sí | Sesión 2 |
| Cómo forzar el puerto SSH en Ubuntu 24.04 (disable + mask ssh.socket; no basta sshd_config) | Sí | Sesión 3 |
| Cómo expandir disco de VM clonada de CloudImg (qm disk resize → growpart → resize2fs, en caliente) | Sí | Sesión 3 |
| Cómo configurar ProxyJump en Windows (~/.ssh/config) para Workstation → bastión → app | Sí | Sesión 3 |
| Cómo conectar VS Code Remote SSH a host detrás de bastión vía ProxyJump | Sí | Sesión 3 |
| Cómo corregir hostname heredado del snippet cloud-init (hostnamectl set-hostname) | Sí | Sesión 3 |

---

## PRÓXIMOS PASOS INMEDIATOS

### Bloqueante crítico
- Llegada del cable USB-RJ45 FTDI (1-3 días). Imprescindible para desbloquear P1.1.

### Trabajo siguiente (P1.6 — Linux baseline + Docker)
0. **Saldar primero las deudas de aprovisionamiento** DT-19 (hardening SSH manual) y DT-20 (divergencia bastion cicustom vs app01 UI) → definir un único baseline reproducible.
1. journald persistente en ambas VMs.
2. unattended-upgrades (solo security, Automatic-Reboot false).
3. UFW en capas (allow SSH 2222 ANTES de habilitar).
4. Herramientas de operación (htop, iotop, iftop, tcpdump, jq, etc.).
5. Docker Engine en app-prod-01 (repo oficial download.docker.com, NO apt docker.io).
6. `usermod -aG docker ubuntu` + validación `docker run hello-world`.
7. Snapshots Proxmox: `baseline-clean` (bastion) y `baseline-with-docker` (app01).

### Cierre pendiente de P1.3 (antes de darlo 100% por cerrado)
- Añadir `/mnt/backup-pny` a `/etc/fstab` con opción `nofail` (DT-16).
- Desconectar USB de instalación (`/dev/sdb`, DT-14).
- Limpiar entradas EFI residuales de Windows (DT-11).

### Trabajo post-cable
1. Reset FortiGate vía consola serie + cuenta `maintainer`.
2. Configuración inicial FortiGate (P1.1).
3. SSL-VPN + DDNS (P1.2).
4. Migración de Proxmox de 192.168.1.101 → 10.20.0.10.
5. Migración de VMs creadas (110, 120) a la red 10.20.0.x — recordar reconfigurar ipconfig0 y ~/.ssh/config en Windows.

---

## DECISIONES OPERACIONALES TOMADAS

| Fecha | Decisión | Justificación |
|---|---|---|
| 22-may | Avanzar P1.3 sin completar P1.1/P1.2 | Cable consola bloquea, Proxmox no | 
| 22-may | IP temporal Proxmox 192.168.1.101 | Permite trabajo paralelo sin FortiGate |
| 22-may | NO conectar VMs aún a `local-lvm` por defecto (140 GB) | Reservar para Proxmox interno; usar `local-lvm-nvme1` para primeras VMs |
| 22-may | VMs en P1.4 nacerán en `192.168.1.x` (no `10.20.0.x`) | Coherencia con la red temporal de Proxmox |
| 23-may | Mantener `99-goloca.conf` renombrado a `00-goloca.conf` | Carga temprana en el include de sshd; no resolvió el problema (era el socket) pero se deja por orden |
| 23-may | `mask ssh.socket` en lugar de override del puerto del socket | Solución rápida y robusta; el override más limpio se evalúa en P6 (DT-17) |
| 23-may | Discos: bastion 20 GB, app01 40 GB | app01 corre Docker+PG+Redis en P2 (más espacio); bastion solo orquesta |
| 23-may | Clave SSH operativa = la de Windows | La generada en Proxmox se descartó por formato roto al copiar |

---

## MÉTRICAS DEL PROGRESO

| Métrica | Valor |
|---|---|
| Mini-proyectos P1 completados | 3 de 6 (P1.3, P1.4, P1.5) |
| Mini-proyectos P1 en curso | 0 |
| Mini-proyectos P1 bloqueados | 2 (P1.1, P1.2) |
| Avance porcentual P1 | ~50% |
| Avance global roadmap | ~8% |
| Commits en GitHub | 1 (initial) — pendiente subir PROGRESS-LOG + trabajo P1.4/P1.5 |
| Deudas técnicas registradas | 20 (DT-01 a DT-20) |
| Desviaciones del plan original | 9 (D-01 a D-09) |
| Storages LVM operativos | 4 (3 thin-pool + 1 backup ext4) |
| Capacidad total de almacenamiento VM | 910 GB thin (230+230+450) + 140 GB pve = ~1.05 TB |
| VMs operativas | 2 (bastion-prod-01, app-prod-01) + 1 template (9000) |

---

## CHANGELOG DEL ARCHIVO

| Fecha | Versión | Cambios |
|---|---|---|
| 2026-05-22 | 1.0 | Creación del archivo. Volcado completo del estado tras sesiones 1 y 2. |
| 2026-05-22 | 1.1 | Detalle real de creación de storages LVM paso a paso (incl. troubleshooting de disco en uso y firmas vfat). Añadidas entradas 13-15 de cronología (pausas formativa y estratégica + creación del log). DT-16 (fstab pendiente). Runbooks ampliados con comandos exactos. Métricas actualizadas (16 deudas, 4 storages, ~1.05 TB). |
| 2026-05-23 | 1.2 | Sesión 3. P1.4 y P1.5 CERRADOS. Template 9000 + bastion-prod-01 (110) + app-prod-01 (120) operativas en 192.168.1.x. Hardening SSH 2222 (troubleshooting socket activation Ubuntu 24.04), ProxyJump, VS Code Remote SSH. Expansión de discos (troubleshooting No space left). Hostname corregido. Añadidas D-07/08/09 y DT-17/18/19/20. 5 runbooks nuevos. Métricas: 3/6 P1, ~50% P1, ~8% global, 20 deudas, 9 desviaciones, 2 VMs + 1 template. |

---

## REGLA DE ACTUALIZACIÓN

Este archivo se actualiza:
- **Al inicio de cada sesión:** revisión rápida del estado actual.
- **Durante la sesión:** en cuanto se toma una decisión importante o se detecta una desviación.
- **Al final de cada sesión:** resumen consolidado de lo realizado.
- **Cada 2 semanas:** consolidación de cambios en el documento maestro `ROADMAP.md`.
