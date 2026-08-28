# RUNBOOK — Reconfigurar la red de una VM aislada con `qemu-guest-agent`

> **Tipo:** Recuperación y reconfiguración sin red
> **Severidad:** Media-Alta — la VM está viva pero es inalcanzable
> **Tiempo estimado:** 5 min por VM
> **Origen:** Sesión 7 · migración de `bastion-prod-01` y `app-prod-01` a la red nueva
> **Entorno:** Proxmox VE 9.2 · VMs Ubuntu 24.04 con cloud-init

---

## ⚠️ Cuándo usar este runbook

Cuando una VM está **encendida y sana pero incomunicada**, típicamente porque:

- El host migró de red y la VM conserva el direccionamiento antiguo.
- Se cambió la VLAN, el bridge o la configuración de red del hipervisor.
- Un cambio de firewall dentro de la VM cortó el acceso.

## Por qué no las vías habituales

| Vía | Por qué no sirve aquí |
|---|---|
| SSH | Precisamente lo que no funciona: la VM está en otra red |
| Consola noVNC | Requiere contraseña local. Si cloud-init solo inyectó clave SSH, **no hay ninguna** |
| Editar el disco offline (`guestfish`) | Funciona, pero obliga a apagar la VM |

El **guest agent** evita las tres: se comunica con Proxmox por un canal **virtio**, independiente de la red, y permite ejecutar órdenes dentro de la VM en caliente.

> Esta es la lección que costó cara en la sesión 4: con solo clave SSH configurada y sin contraseña de consola, una VM sin red es una VM sin ninguna vía de entrada — salvo que el guest agent esté instalado. Instalarlo en la plantilla es barato y evita ese callejón.

---

## Precondiciones

- `qemu-guest-agent` instalado y corriendo en la VM (`agent: enabled=1` en su configuración).
- Acceso al host Proxmox.

Comprobación rápida:

```bash
qm guest cmd <vmid> network-get-interfaces
```

Si devuelve JSON con las interfaces, el agente responde y puedes seguir. Si devuelve `QEMU guest agent is not running`, este runbook no aplica: usa el rescate por disco offline.

---

## Procedimiento

### Paso 1 — Inventariar el estado real de la VM

```bash
qm guest cmd 110 network-get-interfaces
```

Devuelve las interfaces con sus direcciones. Confirma dos cosas de golpe: que la VM está viva y que el canal de control funciona sin depender de la red.

### Paso 2 — Verificar que SSH arrancará tras el reinicio

**No te saltes este paso.** Vas a reiniciar la VM; si el servicio SSH está activo pero no habilitado, arrancará sin él y habrás cambiado un problema por otro peor.

```bash
qm guest exec 110 -- systemctl is-enabled ssh.service
```

Debe responder `enabled`. Si responde `disabled` o `masked`, corrígelo antes con el agente:

```bash
qm guest exec 110 -- systemctl enable ssh.service
```

### Paso 3 — Actualizar el firewall ANTES de cambiar la red

Este es el orden que importa. Si cambias la dirección primero, la VM arranca correctamente en su red nueva y **rechaza tu conexión**, porque sus reglas siguen permitiendo solo el origen antiguo.

Añade las reglas nuevas **sin borrar las viejas** (las antiguas quedarán inertes, y si te equivocas en la nueva no te quedas sin ninguna):

```bash
# bastión: SSH desde la red de gestión nueva
qm guest exec 110 -- ufw allow from 10.20.0.0/24 to any port 2222 proto tcp

# app01: SSH solo desde el bastión (patrón bastión estricto)
qm guest exec 120 -- ufw allow from 10.20.0.40 to any port 2222 proto tcp
```

Verifica:

```bash
qm guest exec 110 -- ufw status numbered
```

### Paso 4 — Cambiar el direccionamiento

```bash
qm set 110 --ipconfig0 ip=10.20.0.40/24,gw=10.20.0.1
qm reboot 110
```

Proxmox regenera la unidad de cloud-init con la configuración nueva.

### Paso 5 — Verificar

Espera unos 40 segundos y consulta de nuevo por el agente:

```bash
qm guest cmd 110 network-get-interfaces
```

`eth0` debe mostrar la dirección nueva.

> **Sobre si cloud-init reaplica:** sí lo hace para la configuración de red al cambiar `ipconfig0` y reiniciar — verificado en las dos VMs. No confundir con `cipassword`, que no se reaplica en reinicios posteriores.

**Si la dirección no cambia**, fuerza la configuración desde dentro con el agente, editando el netplan que genera cloud-init. No te has quedado fuera: el canal virtio sigue disponible.

### Paso 6 — Validar de extremo a extremo desde el cliente real

Desde la estación de trabajo, no desde el hipervisor:

```bash
ssh -p 2222 ubuntu@10.20.0.40
```

Esto valida en una sola prueba toda la cadena: estación en la red del laboratorio, conmutación en el firewall, VM en su dirección nueva y filtro UFW dejando pasar el origen correcto.

---

## Checklist de verificación

- [ ] El agente responde en todas las VMs implicadas.
- [ ] `systemctl is-enabled ssh.service` devuelve `enabled` **antes** de reiniciar.
- [ ] Las reglas UFW del origen nuevo están presentes antes de cambiar la dirección.
- [ ] `network-get-interfaces` confirma la dirección nueva tras el reinicio.
- [ ] SSH funciona desde el cliente real, no solo desde el hipervisor.
- [ ] Los contenedores o servicios de la VM siguen operativos.

---

## Trampas comunes

| Síntoma | Causa | Solución |
|---|---|---|
| `QEMU guest agent is not running` | Agente no instalado o parado | Rescate por disco offline con `guestfish` |
| La VM arranca en la red nueva pero rechaza SSH | UFW sigue permitiendo solo el origen antiguo | Ejecutar el paso 3 **antes** del paso 4 |
| Sin SSH tras reiniciar, aun con la red bien | `ssh.service` activo pero no habilitado | Paso 2, antes de reiniciar |
| La dirección no cambia tras `qm set` + reinicio | cloud-init no reaplicó | Editar el netplan desde dentro con `qm guest exec` |
| Un LXC se recupera solo y una VM no | El contenedor usaba DHCP | Ninguna: es el comportamiento esperado |

---

## Recomendación de diseño

Dos cosas que este procedimiento deja claras y conviene aplicar antes de necesitarlas:

1. **Instala `qemu-guest-agent` en la plantilla**, no VM por VM. Es la diferencia entre reconfigurar en caliente y tener que apagar y editar discos.
2. **Considera dejar una contraseña de consola** en las VMs de infraestructura, aunque el acceso normal sea por clave. La consola sin contraseña es una puerta que existe pero no se puede abrir.
