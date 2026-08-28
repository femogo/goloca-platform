# RUNBOOK — Migrar la IP de un host Proxmox sin perder el acceso

> **Tipo:** Cambio de red en caliente sobre host remoto
> **Severidad:** Alta — un error deja el hipervisor inalcanzable y obliga a intervención física
> **Tiempo estimado:** 15 min
> **Origen:** Sesión 7 · migración de `192.168.1.101` a `10.20.0.10` (DT-12)
> **Entorno:** Proxmox VE 9.2 · Debian con `ifupdown2` · bridge `vmbr0`

---

## ⚠️ Cuándo usar este runbook

Cuando hay que cambiar la dirección de un host Proxmox **al que solo se accede por red**, especialmente si:

- No tiene monitor ni teclado conectados, o conectarlos es costoso.
- El cambio implica además mover físicamente el cable a otro segmento.
- Hay VMs corriendo que no quieres detener.

## El problema que resuelve

El procedimiento ingenuo —editar `/etc/network/interfaces`, reiniciar la red— tiene una ventana ciega: entre que la dirección vieja deja de responder y la nueva empieza a funcionar, **no tienes forma de comprobar nada ni de corregir un error**. Si la configuración nueva está mal, o el cable no está donde creías, el host queda incomunicado.

Con direccionamiento dual esa ventana no existe: el host responde en **las dos redes a la vez** hasta que confirmas que la nueva funciona.

---

## Precondiciones

- Acceso SSH funcionando por la dirección actual.
- Conocer el nombre real del bridge y de la interfaz física (**no lo asumas**).
- Saber a qué puerto físico irá el cable después.

---

## Procedimiento

### Paso 1 — Inspeccionar la configuración real

```bash
ip -br a
cat /etc/network/interfaces
```

Anota el nombre del bridge (`vmbr0` es lo habitual, pero verifícalo) y la interfaz física que tiene puenteada.

> **Comprueba también la máscara.** En el caso original apareció `192.168.1.101/32` en vez de `/24`: la línea `address` del fichero no llevaba prefijo e `ifupdown` lo interpretó como `/32`. Funcionaba de casualidad porque la línea `gateway` añadía la ruta necesaria, pero el host no tenía ruta directa a su propia red local. Errores así solo se ven mirando.

### Paso 2 — Añadir la dirección nueva en caliente

```bash
ip addr add 10.20.0.10/24 dev vmbr0
```

Este comando **añade, no reemplaza**. La sesión SSH en curso no se corta.

Verifica:

```bash
ip -br a show vmbr0
```

Debe listar ambas direcciones.

### Paso 3 — Persistir la dirección nueva

Sin esto, un reinicio a mitad de migración deja el host solo con la dirección vieja, en un segmento donde ya no existe.

```bash
cp /etc/network/interfaces /etc/network/interfaces.pre-migracion
sed -i '/bridge-fd 0/a\        up ip addr add 10.20.0.10/24 dev vmbr0' /etc/network/interfaces
cat /etc/network/interfaces
```

Se usa una línea `up ...` porque es **aditiva**: no toca la configuración existente, así que un error tipográfico no puede dejar el host sin la dirección con la que estás conectado.

### Paso 4 — Mover el cable

Cambia el cable al puerto del segmento nuevo.

**Qué pasa en ese momento:** la puerta de enlace antigua deja de ser alcanzable, así que el host se queda sin ruta por defecto — sin Internet, sin actualizaciones. Pero **sigue respondiendo en la dirección nueva** a cualquier equipo de esa misma red, porque esa ruta es directa y no pasa por la puerta de enlace.

Traducción práctica: puedes entrar por SSH desde otra máquina del segmento nuevo aunque la ruta por defecto esté rota.

> Si algo va mal, **devuelve el cable a su sitio**: la dirección antigua sigue configurada y el host vuelve a ser alcanzable como antes.

### Paso 5 — Entrar por la dirección nueva y corregir la ruta por defecto

Desde un equipo del segmento nuevo:

```bash
ssh root@10.20.0.10
```

Ya dentro:

```bash
ip route del default
ip route add default via 10.20.0.1
ping -c 3 8.8.8.8
```

La sesión SSH no se corta al cambiar la ruta por defecto, porque el tráfico hacia tu equipo es local al segmento y no la usa.

### Paso 6 — Escribir la configuración definitiva

Con acceso ya confirmado por la red nueva, deja el fichero limpio: sin la dirección vieja y sin el apaño transitorio.

```bash
cat > /etc/network/interfaces <<'FIN'
auto lo
iface lo inet loopback

iface nic0 inet manual

auto vmbr0
iface vmbr0 inet static
        address 10.20.0.10/24
        gateway 10.20.0.1
        bridge-ports nic0
        bridge-stp off
        bridge-fd 0

source /etc/network/interfaces.d/*
FIN
```

Ajusta los nombres de interfaz a los que anotaste en el paso 1. **Escribe la máscara explícitamente** en la línea `address`.

No hace falta recargar la red: el estado en memoria ya es el correcto y el fichero solo tiene que estar listo para el próximo arranque.

### Paso 7 — Retirar la dirección antigua

```bash
ip addr del 192.168.1.101/32 dev vmbr0
ip -br a show vmbr0
```

Debe quedar solo la nueva, coincidiendo con el fichero.

### Paso 8 — Revisar `/etc/hosts`

```bash
cat /etc/hosts
```

Proxmox usa este fichero para determinar la dirección de su propio nodo. Si sigue apuntando a la dirección antigua, hay operaciones (certificados, enlaces de la interfaz web, cualquier gestión de clúster futura) que quedan señalando a una dirección muerta.

---

## Checklist de verificación

- [ ] `ip -br a show vmbr0` muestra únicamente la dirección nueva, con la máscara correcta.
- [ ] El contenido de `/etc/network/interfaces` coincide con el estado en memoria.
- [ ] `ping` a una dirección pública responde.
- [ ] `/etc/hosts` apunta a la dirección nueva.
- [ ] La interfaz web responde en `https://<nueva>:8006`.
- [ ] Existe copia del fichero anterior (`interfaces.pre-migracion`).

---

## Trampas comunes

| Síntoma | Causa | Solución |
|---|---|---|
| El host queda inalcanzable tras el cambio | Se reemplazó la dirección en vez de añadir una segunda | Devolver el cable al segmento antiguo |
| Aparece `/32` en vez de `/24` | Línea `address` sin prefijo | Escribir siempre `address x.x.x.x/24` |
| Sin Internet tras mover el cable | Ruta por defecto apuntando a una puerta de enlace inalcanzable | `ip route del default` + `add default via <nueva>` |
| Las VMs pierden red tras la migración | Su configuración apunta al direccionamiento antiguo | Ver [`04-vm-network-reconfig-guest-agent.md`](04-vm-network-reconfig-guest-agent.md) |
| Avisos raros de certificado o de clúster | `/etc/hosts` desactualizado | Corregir la entrada del nodo |

---

## Nota sobre alternativas

Si el host tiene una **segunda interfaz** (incluida una WiFi integrada, aunque esté inactiva), configurarla previamente en otra red es una vía de rescate adicional que hace todo el procedimiento aún más seguro. Merece la pena comprobar con `ip -br a` qué interfaces existen antes de empezar: en el caso original apareció una `wlp3s0` que nadie había tenido en cuenta.
