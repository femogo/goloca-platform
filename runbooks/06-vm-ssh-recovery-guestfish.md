# RUNBOOK — Recuperar SSH de una VM sin acceso editando el disco offline (guestfish)

> **Tipo:** Recuperación de emergencia
> **Severidad:** Alta — VM inaccesible por SSH, sin consola utilizable
> **Tiempo estimado:** 10-15 min por VM
> **Origen:** Incidente sesión 4 (DT-17) — pérdida de SSH en bastion y app01 tras reboot
> **Entorno:** Proxmox VE 9.2, VMs Ubuntu 24.04 cloud-init

---

## ⚠️ Cuándo usar este runbook

Úsalo si **TODO** esto es cierto:

- Una VM responde a ping y arranca (llega a `multi-user.target`), pero **SSH rechaza conexión** en todos los puertos.
- **No tienes contraseña de consola** (cloud-init configuró solo clave SSH, sin password).
- La consola de Proxmox (noVNC) pide login que no puedes dar.
- GRUB no es capturable de forma fiable (timing del Esc poco fiable, o sin acceso visual al arranque).

Si tienes contraseña de consola, NO uses esto: entra por la consola noVNC de Proxmox y arregla en caliente. Este runbook es para el caso sin password, donde editar el disco offline es la única vía determinista.

## Causa típica que resuelve

El servicio `ssh.service` corre tras un `restart` pero **no está habilitado** (`enable`) para el arranque: falta el symlink en `multi-user.target.wants/`. Funciona hasta el primer reboot, luego no levanta. Es el caso del incidente DT-17, pero el procedimiento sirve para cualquier reparación de archivos del sistema en una VM inaccesible.

## Precondiciones

- Acceso SSH/consola al **host Proxmox** (no a la VM — al hipervisor).
- `libguestfs-tools` instalado en Proxmox. Verificar: `which guestfish`. Si falta: `apt install libguestfs-tools` (ya estaba instalado de P1.4 para inyectar qemu-guest-agent).
- Conocer el **VMID** de la VM afectada (ej. 110 bastion, 120 app01).

---

## Procedimiento

### Paso 1 — Apagar la VM (obligatorio)

`guestfish` **no debe** montar el disco de una VM encendida: corrupción garantizada del sistema de archivos. La VM tiene que estar apagada.

```bash
qm stop <VMID>
qm status <VMID>      # debe devolver: status: stopped
```

Si `qm stop` no responde (VM colgada), forzar: `qm stop <VMID> --skiplock` o, en último caso, `qm reset` y luego stop.

### Paso 2 — Identificar el disco de la VM

```bash
qm config <VMID> | grep -E '^(scsi|virtio|sata|ide)[0-9]'
```

Localiza la línea del disco de sistema (normalmente `scsi0` o `scsi1`), algo como:
```
scsi1: local-lvm-nvme1:vm-110-disk-0,size=20G
```
Anota el nombre del volumen: `local-lvm-nvme1:vm-110-disk-0`.

### Paso 3 — Abrir el disco con guestfish

```bash
guestfish --rw -a /dev/<VG>/vm-<VMID>-disk-0
```

Para LVM-thin, la ruta del dispositivo suele ser `/dev/<volume-group>/vm-<VMID>-disk-0`. Si no la conoces, localízala:
```bash
lvs | grep vm-<VMID>
```

Dentro del prompt `><fs>`:

```
run
list-filesystems
```

`list-filesystems` muestra las particiones. Identifica la raíz (la que tiene el sistema, normalmente `/dev/sda1` dentro del contexto de guestfish).

### Paso 4 — Montar la raíz

```
mount /dev/sda1 /
```

(Ajusta `/dev/sda1` a lo que devolvió `list-filesystems`.)

### Paso 5 — Confirmar el diagnóstico

Verifica que el symlink de arranque NO existe (esto confirma la causa):

```
ls-l /etc/systemd/system/multi-user.target.wants/
```

Si `ssh.service` **no aparece** en el listado, ese es el problema: el servicio no está habilitado para el arranque.

Confirma que el servicio sí existe en el sistema:
```
ls-l /usr/lib/systemd/system/ssh.service
```
Debe existir. (En algunas versiones la ruta es `/lib/systemd/system/ssh.service` — `/lib` suele ser symlink a `/usr/lib`.)

### Paso 6 — Crear el symlink (el "enable" manual)

Esto es exactamente lo que hace `systemctl enable ssh.service`, pero a mano sobre el disco offline:

```
ln-s /usr/lib/systemd/system/ssh.service /etc/systemd/system/multi-user.target.wants/ssh.service
```

> Nota de sintaxis guestfish: los comandos van sin guion entre verbo y argumento en la forma corta (`ln-s`, `ls-l`), distinto de bash. Si tu versión de guestfish da error, usa la forma con espacios dentro de un `command` o consulta `help ln`.

### Paso 7 — Verificar el symlink creado

```
ls-l /etc/systemd/system/multi-user.target.wants/
```

Ahora `ssh.service` debe aparecer apuntando a `/usr/lib/systemd/system/ssh.service`.

### Paso 8 — Salir limpiamente

```
umount /
exit
```

`umount` antes de `exit` garantiza que los cambios se escriben al disco. No te saltes el umount.

### Paso 9 — Arrancar y verificar

```bash
qm start <VMID>
```

Espera ~30s al arranque. Luego, desde donde tengas acceso de red a la VM:

```bash
ssh -p 2222 ubuntu@<IP_VM>
```

Una vez dentro, **verifica las dos dimensiones** (esta es la lección del incidente):

```bash
systemctl is-enabled ssh.service    # debe devolver: enabled
systemctl is-active ssh.service     # debe devolver: active
```

`enabled` confirma que arrancará en futuros reboots. `active` confirma que corre ahora. Ambas tienen que dar verde. Si solo verificas una, repites el error que causó el incidente.

### Paso 10 — Prueba de fuego: reboot

No declares resuelto sin esto. El incidente original "funcionaba" hasta el reboot.

```bash
sudo reboot
```

Espera, reconecta por SSH. Si entra, está resuelto de verdad.

---

## Verificación final (checklist)

- [ ] VM arranca y responde a ping
- [ ] SSH conecta en puerto 2222
- [ ] `systemctl is-enabled ssh.service` → `enabled`
- [ ] `systemctl is-active ssh.service` → `active`
- [ ] SSH sigue conectando **tras un reboot**

## Trampas comunes

| Síntoma | Causa | Solución |
|---|---|---|
| `guestfish` da error al abrir | VM encendida, o disco en uso | Confirmar `qm status` = stopped |
| `list-filesystems` no muestra `/dev/sda1` | Esquema de particiones distinto | Usar la partición que liste como raíz (busca la que tenga `/etc`) |
| Symlink creado pero SSH sigue sin levantar | Otra causa además del enable | Revisar `journalctl -u ssh` tras arranque; puede ser `ssh.socket` no enmascarado (ver runbook de puerto SSH) |
| Cambios no persisten tras `exit` | Falta `umount /` | Repetir y hacer `umount /` antes de `exit` |
| Sintaxis `ln-s` rechazada | Versión de guestfish | `help ln` para la forma correcta de tu versión |

## Por qué este método y no otros

- **No GRUB / single-user:** requiere capturar el arranque por timing, poco fiable sin acceso visual estable. Determinista solo con consola física buena.
- **No reset de password vía cloud-init (`cipassword`):** cloud-init no reaplica config en reboots posteriores al primero. No funciona en una VM ya provisionada.
- **guestfish (elegido):** determinista, sin depender de password ni de timing de arranque. Edita el estado real del disco. Funciona siempre que tengas acceso al host Proxmox.

## Aplicabilidad más allá de SSH

Este procedimiento (apagar → guestfish → montar → editar → umount → arrancar) sirve para reparar **cualquier** archivo del sistema en una VM inaccesible: arreglar un `/etc/fstab` que impide el boot, corregir un `sshd_config` roto, resetear permisos, recuperar de un cambio que dejó la VM sin acceso. El caso SSH es solo la instancia que lo motivó.
