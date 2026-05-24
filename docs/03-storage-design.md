# P1.3 — Diseño de Almacenamiento del Hipervisor

> **Proyecto:** P1 · Infraestructura Base
> **Mini-proyecto:** 1.3 — Proxmox VE bare-metal
> **Host:** `pve-prod-01` (Proxmox VE 9.2)
> **Estado:** Cerrado (sesión 4)
> **Documento relacionado:** [`03-proxmox-architecture-decision.md`](03-proxmox-architecture-decision.md)

---

## 1. Contexto

Goloca AI opera una plataforma de agentes IA multi-tenant. La capa de virtualización tiene que sostener, a lo largo del roadmap, cargas con perfiles de I/O muy distintos: VMs de aplicación con base de datos transaccional (P2), nodos de un clúster K3s (P3), un stack de observabilidad que escribe métricas y logs de forma continua (P4) y, en P6, una VM con modelos LLM de varios GB.

No todas esas cargas merecen el mismo disco. Meterlas todas en el mismo pool es la decisión por defecto de quien no piensa en I/O, y se paga en producción cuando el `vzdump` nocturno satura el disco donde corre la base de datos. El diseño de almacenamiento de `pve-prod-01` parte de clasificar el hardware por velocidad y propósito, no por "lo que había".

## 2. Inventario real de discos

El inventario difiere de la planificación inicial del roadmap (desviación D-03). El plan asumía 2 NVMe + 1 SSD + 1 HDD de 1 TB. La realidad detectada por Proxmox:

| Dispositivo | Tamaño | Tipo | Asignación | Storage Proxmox |
|---|---|---|---|---|
| `/dev/nvme0n1` | 238 GB | NVMe | SO Proxmox + boot | `local` (dir) + `local-lvm` |
| `/dev/nvme1n1` | 238 GB | NVMe | VMs críticas | `local-lvm-nvme1` (thin) |
| `/dev/nvme2n1` | 238 GB | NVMe | VMs secundarias / reserva | `local-lvm-nvme2` (thin) |
| `/dev/nvme3n1` | 465 GB | NVMe Samsung | VMs de capacidad | `local-lvm-ssd-samsung` (thin) |
| `/dev/sda` | 223 GB | SATA SSD PNY | Backups, ISOs, snapshots | `backup-pny` (dir, ext4) |

El HDD de 1 TB previsto **no fue detectado** (D-04). Probablemente desconectado físicamente. Pendiente de verificación cuando haya acceso físico al servidor (junto a la resolución de DT-22). Mientras tanto, los backups van al SSD PNY, que es más rápido pero de menor capacidad — trade-off aceptable para un laboratorio, pero documentado como deuda: en producción los backups nunca comparten criticidad con el almacenamiento primario, y un SSD de 223 GB no sostiene una política de retención larga.

## 3. Decisión central: LVM-thin sobre discos individuales (no ZFS)

### 3.1 La disyuntiva

Proxmox soporta dos modelos de almacenamiento serios para este escenario: **ZFS** (pool unificado con redundancia, snapshots nativos, compresión, checksums) y **LVM-thin** (thin provisioning por volumen lógico, sin redundancia entre discos).

ZFS es, sobre el papel, superior: integridad de datos por checksums, snapshots instantáneos, compresión transparente, y la capacidad de agrupar varios discos en un solo pool con redundancia (RAIDZ, mirror). Es lo que usaría en producción con hardware homogéneo.

### 3.2 Por qué se descartó ZFS aquí

El factor decisivo es la **heterogeneidad del hardware**:

- ZFS rinde y protege bien cuando los discos de un vdev son **iguales** (mismo tamaño, mismo tipo). Un mirror o RAIDZ se dimensiona al disco más pequeño y asume rendimiento homogéneo.
- Aquí hay 3 NVMe de 238 GB, 1 NVMe de 465 GB y 1 SATA SSD de 223 GB. Cinco discos, tres tamaños, dos interfaces. No hay forma limpia de armar un vdev ZFS con redundancia sin desperdiciar capacidad masivamente (el de 465 GB se truncaría a 238) o sin mezclar NVMe con SATA en el mismo pool, lo que degrada el rendimiento al ritmo del eslabón más lento.
- ZFS es voraz en RAM (regla informal: ~1 GB por TB, más ARC). Con 32 GB totales y la RTX 4060 reservada para LLM en P6, cada GB que ZFS reserva para ARC es un GB que no tienen las VMs. En un host con RAM como cuello de botella declarado, esto es relevante.

### 3.3 Por qué LVM-thin

LVM-thin trata cada disco como un pool independiente. Eso encaja con hardware heterogéneo: cada disco se aprovecha a su tamaño y velocidad reales, sin truncar al más pequeño ni mezclar interfaces. El thin provisioning permite sobreaprovisionar (asignar más espacio virtual del físico disponible) — útil en laboratorio, peligroso si no se vigila (ver sección 5).

| Criterio | ZFS | LVM-thin (elegido) |
|---|---|---|
| Hardware heterogéneo | Mal encaje (trunca/degrada) | Encaje natural (disco a disco) |
| Consumo de RAM | Alto (ARC) | Mínimo |
| Integridad por checksums | Sí | No |
| Snapshots | Nativos, instantáneos | Sí (vía thin pool) |
| Redundancia entre discos | Sí (RAIDZ/mirror) | No (sin RAID) |
| Riesgo de sobreaprovisionamiento | Controlado | Requiere vigilancia manual |

**Trade-off asumido:** se renuncia a redundancia y checksums a cambio de aprovechar el hardware real sin desperdicio y sin presión de RAM. En un laboratorio formativo sin datos de cliente reales, es aceptable. En producción con datos regulados (el escenario que Goloca AI simula), esto sería inaceptable: ahí iría ZFS sobre discos homogéneos, o almacenamiento compartido con redundancia. Queda documentado como decisión consciente, no como descuido.

## 4. Segmentación por criticidad

El reparto de cargas sobre los storages sigue la lógica de aislar I/O por criticidad:

```
                    pve-prod-01 (Proxmox VE 9.2)
                            │
   ┌────────────┬───────────┼────────────┬──────────────┐
   ▼            ▼           ▼            ▼              ▼
 nvme0n1     nvme1n1     nvme2n1      nvme3n1         sda
 238 GB      238 GB      238 GB       465 GB        223 GB
   │            │           │            │              │
 SO +        VMs         VMs         VMs de         Backups
 local-lvm   críticas    secundarias capacidad      ISOs
   │         (110,120)   /reserva     (futuro)      Snapshots
   │            │                                      │
 NO usar     VMs P1                                 vzdump
 para VMs    actuales                               (NO crítico
 (ver §5)                                            junto a SO)
```

La regla operativa: **el disco del SO (`nvme0n1` / `local-lvm`) no aloja VMs.** Tiene que quedar holgado para el propio Proxmox, sus logs, y el storage `local` (ISOs, snippets, plantillas). Mezclar VMs ahí compite con el sistema por I/O y espacio. Esta regla se violó en la práctica y causó un incidente — sección 5.

## 5. Incidente: sobreaprovisionamiento del thin-pool `local-lvm`

Este es el aprendizaje operacional más valioso del mini-proyecto, por eso se documenta en detalle.

### 5.1 Síntoma

Al crear los snapshots `pre-baseline-clean` de las VMs en S4, LVM emitió warnings de sobreaprovisionamiento del thin-pool `pve/data` (`local-lvm`): la suma de los volúmenes asignados (159 GB) superaba el tamaño del pool, con solo 16 GB libres en el volume group y **sin** `thin_pool_autoextend_threshold` configurado.

### 5.2 Por qué es peligroso

En un thin-pool, el espacio se asigna bajo demanda. Sobreaprovisionar significa prometer más espacio del que existe físicamente. Mientras las VMs no escriban hasta el límite, no pasa nada. Pero si el pool llega al **100% de uso físico**, las escrituras siguientes fallan de forma que LVM no puede resolver con elegancia: **corrupción del sistema de archivos de las VMs alojadas.** No es un disco lleno que da un error limpio "no space left"; es un thin-pool agotado que deja las VMs en estado inconsistente.

### 5.3 Causa raíz

Desviación D-10. Ambas VMs (110 bastion, 120 app01) nacieron en `local-lvm` —el thin-pool del disco del SO, 140 GB— en lugar de `local-lvm-nvme1` —el disco de 230 GB dedicado y vacío—. La decisión de sesión 2 era explícitamente **no** usar `local-lvm` para VMs (sección 4, regla operativa). Al clonar las VMs en S3, esa regla no se respetó. El error no se manifestó hasta S4, cuando los snapshots empujaron el pool contra su límite.

### 5.4 Resolución: corregir la causa, no parchear el síntoma

Había dos caminos:

| Opción | Acción | Por qué se eligió / descartó |
|---|---|---|
| **A — Mover VMs (elegida)** | `qm move-disk {110,120} scsi1 local-lvm-nvme1 --delete 1` | Corrige la causa raíz: las VMs acaban en el pool correcto, con 230 GB dedicados. El símil correcto |
| **B — Autoextend** | Configurar `thin_pool_autoextend_threshold` para que el pool crezca solo | Parche del síntoma. Además, con solo 16 GB libres en el VG, no hay margen real para que el autoextend salve nada. Falsa sensación de seguridad |

Se ejecutó la opción A. El uso real movido fue ~12 GB (el sobreaprovisionamiento era *potencial*, no actual — las VMs aún no habían escrito tanto, lo que explica por qué no había reventado ya). Tras el movimiento: `local-lvm` volvió al 3.18% de uso (solo los cloudinit drives de 4 MB), ambas VMs en `local-lvm-nvme1`, snapshots rehechos sin warnings.

Un detalle de verificación que importa: el symlink de `ssh.service` (la reparación del incidente SSH, ver runbook correspondiente) **sobrevivió al move** porque vive dentro del sistema de archivos de la VM, que `qm move-disk` copia íntegro. Mover el disco de una VM no toca su contenido lógico.

### 5.5 Lección

Sobreaprovisionar un thin-pool no es un error si se vigila el uso físico real. El error fue alojar VMs en el pool equivocado (el del SO) por no aplicar una decisión ya tomada. La corrección correcta ataca la causa (pool equivocado) en lugar del síntoma (pool lleno). Parchear con autoextend habría dejado la bomba activa con una mecha más larga.

## 6. Validación

Comprobaciones ejecutadas tras cerrar el diseño de almacenamiento:

- `pvs` / `vgs` / `lvs` — los 4 thin-pools presentes y con el tamaño esperado.
- `lvs -a` — uso de cada pool por debajo de umbrales de riesgo tras la migración.
- `df -h` — `/mnt/backup-pny` montado y con espacio.
- `cat /etc/fstab` + `blkid` — montaje del backup por UUID con `nofail` confirmado (DT-16), de modo que un fallo del disco de backup no impide el arranque del host.
- `qm config {110,120}` — ambos discos `scsi1` apuntando a `local-lvm-nvme1`.

## 7. Deuda técnica derivada

| ID | Deuda | Resolución prevista |
|---|---|---|
| DT-13 | HDD 1 TB no detectado | Verificar conexión física (acceso físico pendiente) |
| D-04 | Backups en SSD PNY (no en HDD dedicado) | Reubicar a HDD cuando se recupere; en prod, almacenamiento de backup separado |
| — | Sin redundancia entre discos | Aceptado para lab. En prod: ZFS homogéneo o storage compartido |
| DT-10 | Sin backups automatizados | P4-P6: `vzdump` programado + sync a S3 |
