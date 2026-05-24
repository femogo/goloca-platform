# RUNBOOK — Migrar el disco de una VM entre pools de almacenamiento (qm move-disk)

> **Tipo:** Operación de almacenamiento
> **Severidad:** Media — corrige riesgo de corrupción por sobreaprovisionamiento
> **Tiempo estimado:** 5-15 min según tamaño del disco
> **Origen:** Sesión 4 (desviación D-10) — VMs nacidas en pool equivocado
> **Entorno:** Proxmox VE 9.2, almacenamiento LVM-thin

---

## ⚠️ Cuándo usar este runbook

- Una VM está en el pool de almacenamiento equivocado (ej. en `local-lvm`, el disco del SO, en lugar de un pool dedicado).
- Aparecen **warnings de sobreaprovisionamiento** de un thin-pool: la suma de volúmenes asignados supera el tamaño físico del pool.
- Necesitas redistribuir VMs entre discos por capacidad o rendimiento.

## Por qué importa (el riesgo real)

En un thin-pool LVM, el espacio se asigna bajo demanda. Sobreaprovisionar (prometer más espacio del físico) no falla mientras las VMs no escriban hasta el límite. Pero si el pool llega al **100% de uso físico real**, las escrituras siguientes no dan un error limpio — provocan **corrupción del sistema de archivos** de las VMs alojadas. Mover la VM a un pool con espacio real es la corrección de causa raíz; subir el `autoextend` es parchear el síntoma.

## Precondiciones

- Acceso al host Proxmox.
- Pool de destino con **espacio físico suficiente** para el disco (verificar antes, paso 1).
- La VM puede estar encendida o apagada (`qm move-disk` soporta migración en caliente), pero **apagada es más seguro** para evitar I/O concurrente. Recomendado: apagar si la VM no es crítica en ese momento.

---

## Procedimiento

### Paso 1 — Verificar espacio en origen y destino

Ver el uso de todos los pools:

```bash
pvesm status
```

Confirma que el pool de **destino** tiene espacio libre suficiente para el disco que vas a mover. Mira también el `lvs` para el detalle del thin-pool:

```bash
lvs -a
```

Fíjate en la columna `Data%` del pool de origen — si está alto, confirma el riesgo que estás corrigiendo.

### Paso 2 — Identificar el disco a mover

```bash
qm config <VMID> | grep -E '^(scsi|virtio|sata)[0-9]'
```

Identifica el disco de datos (no el cloudinit drive, que suele ser `ide2` y es de 4 MB — ese no se mueve, es regenerable). Anota el identificador, ej. `scsi1`.

### Paso 3 — (Recomendado) Apagar la VM

```bash
qm stop <VMID>
qm status <VMID>      # status: stopped
```

Migración en caliente es posible pero añade riesgo de I/O concurrente. Si la VM no presta servicio crítico ahora, apágala.

### Paso 4 — Mover el disco

```bash
qm move-disk <VMID> <disco> <pool-destino> --delete 1
```

Ejemplo real del incidente:
```bash
qm move-disk 110 scsi1 local-lvm-nvme1 --delete 1
```

- `<disco>`: el identificador del paso 2 (`scsi1`).
- `<pool-destino>`: nombre del storage destino (`local-lvm-nvme1`).
- `--delete 1`: **borra el disco origen tras copiar**. Sin esto, te quedan dos copias y el espacio del origen no se libera — que es justo lo que querías resolver.

Proxmox copia el disco bloque a bloque al nuevo pool y, al terminar, borra el original y actualiza la config de la VM automáticamente.

### Paso 5 — Verificar la migración

```bash
qm config <VMID> | grep <disco>
```

El disco debe apuntar ahora al pool destino:
```
scsi1: local-lvm-nvme1:vm-110-disk-0,size=20G
```

Confirma que el pool origen se liberó:
```bash
lvs -a | grep <VMID>
pvesm status
```

El `Data%` del pool origen debe haber bajado.

### Paso 6 — Arrancar y verificar la VM

```bash
qm start <VMID>
```

Verifica que la VM arranca normal y que su contenido está intacto. **Punto importante:** `qm move-disk` copia el sistema de archivos **íntegro** — cualquier cambio dentro de la VM (configs, symlinks de systemd, datos) sobrevive al move, porque es una copia bit a bit del volumen. No se pierde nada del interior.

---

## Verificación final (checklist)

- [ ] `qm config` muestra el disco en el pool destino
- [ ] Pool origen liberado (`Data%` bajó, `lvs` ya no lista el volumen viejo)
- [ ] VM arranca correctamente
- [ ] Contenido de la VM intacto (servicios, datos, configs)
- [ ] Snapshots rehechos si los anteriores estaban en el pool viejo (ver nota)

## Trampas comunes

| Síntoma | Causa | Solución |
|---|---|---|
| `move-disk` falla por espacio | Destino sin sitio físico | Verificar `pvesm status` antes; elegir otro pool |
| Quedan dos copias del disco | Olvidaste `--delete 1` | `qm move-disk` no se puede deshacer fácil; borrar el volumen huérfano manualmente con cuidado |
| Snapshots viejos siguen en pool origen | Los snapshots no migran con `move-disk` | Borrar y rehacer snapshots en el pool nuevo |
| Cloudinit drive sigue en pool viejo | Es `ide2`, no se movió | Irrelevante (4 MB, regenerable); ignorar o mover aparte |

## Nota sobre snapshots

`qm move-disk` mueve el disco activo, pero los **snapshots existentes pueden quedar anclados al pool de origen**. Si el objetivo era vaciar el pool de origen del todo, hay que borrar los snapshots viejos y rehacerlos sobre el disco ya migrado. En el incidente de S4, los snapshots `pre-baseline-clean` se rehicieron tras el move, ya en `local-lvm-nvme1`, sin los warnings de sobreaprovisionamiento que tenían en el pool viejo.

## Por qué mover y no autoextend

| Opción | Qué hace | Veredicto |
|---|---|---|
| `qm move-disk` (elegida) | Lleva la VM al pool correcto con espacio real | Corrige la causa: pool equivocado |
| `thin_pool_autoextend_threshold` | El pool crece solo al llegar a un umbral | Parchea el síntoma; además inútil si el VG tiene poco margen libre (16 GB no bastan) |

Mover ataca el origen del problema (la VM nunca debió estar en el pool del SO). Autoextend deja la VM donde no debe y confía en que el pool crezca a tiempo — falsa seguridad.
