# RUNBOOK — Habilitar un servicio systemd en un disco offline (symlink manual)

> **Tipo:** Reparación de configuración offline
> **Severidad:** Media-Alta — servicio no arranca tras reboot
> **Tiempo estimado:** 5 min (asumiendo disco ya montado con guestfish)
> **Origen:** Incidente sesión 4 (DT-17)
> **Entorno:** Proxmox VE 9.2, VMs Ubuntu 24.04

---

## ⚠️ Cuándo usar este runbook

Cuando necesitas que un servicio systemd **arranque automáticamente** en una VM pero no puedes ejecutar `systemctl enable` dentro de ella (VM inaccesible, o estás reparando su disco offline). Es la pieza conceptual que está detrás del runbook de rescate SSH con guestfish, aislada para reutilizarla con cualquier servicio.

## El concepto: qué hace `systemctl enable` por dentro

`systemctl enable <servicio>` no es magia. Hace una sola cosa observable: crea un **symlink** del archivo de unidad del servicio dentro del directorio `.wants/` del target en el que debe arrancar. Para servicios normales, ese target es `multi-user.target`.

```
systemctl enable ssh.service
        ≡
ln -s /usr/lib/systemd/system/ssh.service \
      /etc/systemd/system/multi-user.target.wants/ssh.service
```

En el arranque, systemd lee `multi-user.target.wants/` y arranca todo lo que encuentre enlazado ahí. Sin el symlink, el servicio existe pero nadie lo arranca. **Por eso `enable` se puede hacer a mano**: solo es crear ese symlink, y un symlink se puede crear sobre un disco offline.

## Distinción crítica: enable vs start (active vs enabled)

Dos ejes independientes que se confunden constantemente:

| | `active` (corre ahora) | `enabled` (arranca en boot) |
|---|---|---|
| `start` / `restart` | ✅ lo cambia | ❌ no lo toca |
| `enable` | ❌ no lo toca | ✅ lo cambia |

Un servicio puede estar **active pero not-enabled** (corre ahora, no arrancará tras reboot — la bomba de relojería del incidente DT-17) o **enabled pero not-active** (arrancará, pero ahora mismo no corre). Reparar el arranque exige tocar el eje `enabled`, que es el symlink.

---

## Procedimiento

Asume que ya tienes el disco de la VM montado en guestfish (ver runbook de rescate SSH, pasos 1-4) o accedes al sistema de archivos por otra vía offline.

### Paso 1 — Localizar el archivo de unidad del servicio

```
ls-l /usr/lib/systemd/system/<servicio>.service
```

Debe existir. Si no está ahí, prueba `/lib/systemd/system/` (suele ser symlink a `/usr/lib`) o `/etc/systemd/system/` (unidades locales). Anota la ruta real.

### Paso 2 — Comprobar si ya está enlazado

```
ls-l /etc/systemd/system/multi-user.target.wants/
```

Si el servicio **ya aparece**, no es un problema de enable — el fallo está en otra parte (revisa logs tras arranque). Si **no aparece**, continúa.

### Paso 3 — Crear el directorio si no existe

```
mkdir-p /etc/systemd/system/multi-user.target.wants
```

(En una VM normal ya existe, pero `mkdir-p` no falla si está.)

### Paso 4 — Crear el symlink

```
ln-s /usr/lib/systemd/system/<servicio>.service /etc/systemd/system/multi-user.target.wants/<servicio>.service
```

El primer argumento es el destino (dónde apunta), el segundo dónde se crea el enlace. Igual que `ln -s` en bash.

### Paso 5 — Verificar

```
ls-l /etc/systemd/system/multi-user.target.wants/
```

El servicio debe aparecer como symlink (`->`) apuntando al archivo de unidad.

### Paso 6 — Cerrar y arrancar

```
umount /
exit
```
```bash
qm start <VMID>
```

### Paso 7 — Verificar dentro de la VM

```bash
systemctl is-enabled <servicio>.service   # enabled
systemctl is-active <servicio>.service    # active
sudo reboot && # reconectar: confirmar que persiste
```

---

## Verificación final (checklist)

- [ ] Symlink presente en `multi-user.target.wants/`
- [ ] `is-enabled` → `enabled`
- [ ] `is-active` → `active`
- [ ] Servicio persiste tras reboot

## Trampas comunes

| Síntoma | Causa | Solución |
|---|---|---|
| Symlink creado, `is-enabled` dice `static` | El servicio no admite enable normal (no tiene `[Install]`) | Distinto problema; revisar la unidad |
| `is-enabled` dice `enabled` pero `is-active` `inactive` | El servicio está habilitado pero falló al arrancar | Revisar `journalctl -u <servicio>` |
| Symlink apunta a ruta inexistente | Ruta del archivo de unidad equivocada en paso 1 | Recrear apuntando a la ruta real |
| Servicio quería otro target | No todos arrancan en multi-user | Verificar `WantedBy=` en la sección `[Install]` de la unidad |

## Nota sobre el target correcto

La mayoría de servicios de red/sistema arrancan en `multi-user.target` (equivalente al runlevel 3, sistema multiusuario sin GUI). Si un servicio define `WantedBy=otra.target` en su sección `[Install]`, el symlink va en `otra.target.wants/`, no en multi-user. Para servidores headless (sin entorno gráfico), multi-user es lo normal.
