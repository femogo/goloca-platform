# RUNBOOK — Aplicar UFW en un host remoto sin perder el acceso

> **Tipo:** Cambio de firewall remoto
> **Severidad:** Alta — un error te deja fuera del servidor
> **Tiempo estimado:** 10 min
> **Origen:** Sesión 4 (P1.6)
> **Entorno:** Ubuntu 24.04, acceso por SSH

---

## ⚠️ Cuándo usar este runbook

Siempre que vayas a **activar o modificar UFW en un host al que accedes por SSH** y no tengas consola física/noVNC a mano para recuperarte. Es decir: casi siempre en infraestructura remota.

## El riesgo que evita

Activas UFW con política `default deny incoming`. Si la regla que permite tu SSH no está **antes** de activar, el deny corta tu sesión y todas las futuras. Te quedas fuera de un servidor remoto. La única recuperación es consola física o, en VM, la consola del hipervisor — lento y doloroso, a veces imposible si es cloud.

El error es tan común que tiene nombre informal: "lockout". Este runbook lo previene con dos mecanismos: **orden correcto** y **red de seguridad temporizada**.

## Precondiciones

- Sesión SSH activa al host.
- Saber desde qué **origen** debe permitirse SSH (IP o subred) y en qué **puerto** (aquí 2222).
- Permisos sudo.

---

## Procedimiento

### Paso 1 — Montar la red de seguridad ANTES de tocar nada

Programa una desactivación automática de UFW dentro de 5 minutos, en segundo plano:

```bash
sudo bash -c 'nohup sleep 300 && ufw --force disable' &
```

Qué hace: si en 5 minutos no has cancelado este proceso, UFW se desactiva solo. Si tu configuración te deja fuera, esperas 5 minutos y recuperas acceso sin tocar consola física. Es un "deadman switch".

Anota el momento. Tienes 5 minutos para confirmar que todo funciona antes de que dispare (o lo cancelas tú antes, paso 7).

### Paso 2 — Añadir la regla de SSH PRIMERO

**Antes** de habilitar UFW, permite tu SSH. Ejemplo para puerto 2222 desde una subred de gestión:

```bash
sudo ufw allow from <origen> to any port 2222 proto tcp
```

Ejemplos reales:
```bash
# bastión: SSH desde toda la red de gestión
sudo ufw allow from 192.168.1.0/24 to any port 2222 proto tcp

# app01: SSH SOLO desde el bastión (patrón estricto)
sudo ufw allow from 192.168.1.110 to any port 2222 proto tcp
```

### Paso 3 — Verificar que la regla está antes de activar

```bash
sudo ufw show added
```

Confirma visualmente que la regla de SSH 2222 aparece. Si no está, NO actives UFW. Repite el paso 2.

### Paso 4 — Definir políticas por defecto

```bash
sudo ufw default deny incoming
sudo ufw default allow outgoing
```

`deny incoming`: nada entra salvo lo permitido explícitamente. `allow outgoing`: el host puede salir (DNS, updates, etc.).

### Paso 5 — Activar UFW

```bash
sudo ufw --force enable
```

`--force` evita el prompt interactivo (que en un script colgaría). En este punto, si la regla del paso 2 está bien, tu sesión actual sigue viva.

### Paso 6 — Verificar con una conexión NUEVA (no la sesión abierta)

Este es el paso que la gente se salta y por eso se confía de más. Tu sesión SSH actual **sigue funcionando aunque la regla esté mal**, porque las conexiones ya establecidas no se reevalúan contra el firewall. Solo una conexión **nueva** prueba que la regla permite entrar.

Desde otra terminal (o tu workstation), abre una conexión nueva:

```bash
ssh -p 2222 ubuntu@<IP_HOST>
```

Si entra → la regla funciona. Si NO entra → tienes ~5 min hasta que la red de seguridad desactive UFW; usa ese tiempo para diagnosticar desde la sesión vieja (que sigue viva).

### Paso 7 — Cancelar la red de seguridad

Solo cuando hayas confirmado acceso con conexión nueva (paso 6). Mata el proceso del `sleep`:

```bash
sudo pkill -f 'sleep 300'
```

Verifica que ya no está:
```bash
ps aux | grep 'sleep 300' | grep -v grep
```

No debe devolver nada (salvo el propio grep, que ya filtramos). Si el `sleep` sigue vivo, UFW se desactivará y tendrás que reactivarlo — repítelo desde paso 5.

### Paso 8 — Estado final

```bash
sudo ufw status verbose
```

Confirma: `Status: active`, política `deny (incoming)`, y tu regla de SSH listada.

---

## Verificación final (checklist)

- [ ] Regla SSH añadida antes de activar
- [ ] UFW `active` con `deny incoming` por defecto
- [ ] **Conexión SSH nueva** entra correctamente
- [ ] Red de seguridad (`sleep 300`) cancelada
- [ ] `ufw status verbose` muestra el estado esperado

## Trampas comunes

| Síntoma | Causa | Solución |
|---|---|---|
| Te quedas fuera tras enable | Regla SSH no estaba antes | Esperar a que la red de seguridad desactive UFW (5 min), reintentar bien |
| "Funciona" pero solo en la sesión vieja | No probaste conexión nueva | Probar SIEMPRE con conexión nueva (paso 6) |
| Red de seguridad disparó sola | Tardaste >5 min en confirmar | Reactivar UFW (paso 5); subir el `sleep` a 600 si necesitas más margen |
| `pkill` no encuentra el sleep | Sintaxis del patrón | `ps aux \| grep sleep`, matar por PID con `kill <PID>` |
| Docker expone puertos pese a UFW | Docker reescribe iptables | Problema aparte (DOCKER-USER chain); UFW no controla puertos publicados por Docker |

## Nota sobre el patrón de orígenes

Las reglas de este runbook usan orígenes `192.168.1.x` porque el laboratorio aún corre en esa red (FortiGate pendiente). Cuando la infraestructura migre a `10.x`, las reglas se endurecen:
- bastión → `10.10.0.0/24` (MGMT) + `10.10.99.0/24` (VPN)
- app01 → `10.20.0.40` (solo el bastión) + `10.10.99.0/24` (VPN)

El procedimiento es idéntico; solo cambia el `<origen>` de la regla del paso 2.
