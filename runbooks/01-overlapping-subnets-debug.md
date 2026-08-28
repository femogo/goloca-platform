# RUNBOOK — Sin salida a Internet por subredes solapadas en un FortiGate

> **Tipo:** Diagnóstico de encaminamiento
> **Severidad:** Alta — los clientes internos no tienen conectividad y el fallo no deja rastro evidente
> **Tiempo estimado:** 10 min de diagnóstico, 10 min de corrección
> **Origen:** Incidente de la sesión 7
> **Entorno:** FortiGate 30E · FortiOS 6.2.5

---

## Síntoma

Un cliente conectado a una interfaz interna del firewall:

- Obtiene dirección por DHCP correctamente.
- Alcanza la interfaz de administración del propio firewall.
- **No tiene salida a Internet.** `ping` a una IP pública pierde el 100% de los paquetes.
- El error es `tiempo de espera agotado` o `host de destino inaccesible`, sin mensaje que apunte a nada.

Y, lo que más despista: **el propio firewall sí sale a Internet**. `execute ping 8.8.8.8` desde su CLI funciona con normalidad.

---

## Lo que hace perder tiempo

Esta es la parte que conviene interiorizar, porque el instinto lleva en la dirección equivocada.

| Hipótesis natural | Por qué parece razonable | Por qué no es |
|---|---|---|
| Falta una política LAN→WAN | Es el fallo más habitual | Crearla no cambia nada |
| El NAT no está activado | Sin NAT las respuestas no vuelven | El NAT ya estaba activado |
| El log dirá qué pasa | Es lo correcto en general | En un 30E no hay disco de logs (`Log hard disk: Not available`); el log vacío **no es evidencia de nada** |

Que el firewall sí tenga Internet refuerza la confusión, pero es esperable: ese tráfico lo **genera** él y sale por su interfaz WAN sin ambigüedad. Lo que falla es el tráfico **reenviado**, que es un camino distinto.

---

## Causa

Dos interfaces del firewall tienen direcciones en **la misma subred**. El caso típico se da de fábrica: la interfaz interna viene en `192.168.1.99/24` y el router doméstico al que se conecta la WAN reparte también `192.168.1.0/24`.

```
   wan  → 192.168.1.33/24   (DHCP del router doméstico)
   lan  → 192.168.1.99/24   (valor de fábrica)
              ▲
              └── la misma red conectada en dos interfaces
```

Con esa configuración, la tabla de rutas contiene `192.168.1.0/24` como red conectada **por dos caminos distintos**. Cuando hay que decidir por dónde devolver una respuesta a un cliente interno, la decisión es ambigua: si el firewall elige la interfaz WAN, emite la respuesta hacia el segmento del router doméstico, pregunta por ARP quién tiene esa dirección, nadie contesta, y el paquete se descarta en silencio.

De ahí el perfil del fallo: pérdida total, sin error explícito y sin entrada de log útil.

---

## Diagnóstico

### Paso 1 — Listar las interfaces y sus direcciones

```
get system interface
```

Busca **dos interfaces cuyas direcciones caigan dentro de la misma red**. Compara direcciones y máscaras, no solo el tercer octeto.

En el incidente original:

```
== [ wan ]
name: wan   mode: dhcp   ip: 192.168.1.33 255.255.255.0   status: up
== [ lan ]
name: lan   mode: static ip: 192.168.1.99 255.255.255.0   status: up
```

Ambas en `192.168.1.0/24`. Ahí está el problema.

### Paso 2 — Confirmar que la política y el NAT no son la causa

Antes de descartarlos, compruébalos una vez para no dejarlos como duda:

- La política LAN→WAN existe, con acción `ACCEPT`.
- El NAT está habilitado en esa política.

Si ambas cosas están bien y sigue sin haber salida, el solapamiento es la explicación.

> **No sigas leyendo el log buscando la respuesta.** Los descartes por ambigüedad de ruta no generan una entrada clara, y en modelos sin disco de logs puede no haber nada en absoluto.

---

## Corrección

La solución es **eliminar el solapamiento**, no parchearlo con rutas estáticas ni con reglas adicionales. Cambia la red interna a un rango que no colisione con el de la WAN.

### Paso 1 — Renumerar la interfaz interna

Desde la interfaz web, en la propia interfaz interna:

- Dirección y máscara nuevas, por ejemplo `10.20.0.1/255.255.255.0`.
- Ajustar el rango del servidor DHCP a la red nueva.
- Puerta de enlace: la propia dirección de la interfaz.
- **Verificar que siguen marcados HTTPS y PING** en el acceso administrativo, o perderás la interfaz web en la red nueva.

> Al guardar pierdes la conexión inmediatamente: tu dirección actual deja de ser válida. Es esperado, no es que se haya roto nada.

### Paso 2 — Renovar la dirección del cliente

```powershell
ipconfig /release
ipconfig /renew
```

### Paso 3 — Verificar

- El cliente obtiene dirección en la red nueva, con la puerta de enlace correcta.
- `ping 8.8.8.8` responde.
- La interfaz de administración responde en la dirección nueva.

---

## Checklist de verificación

- [ ] `get system interface` no muestra dos interfaces en la misma red.
- [ ] El cliente obtiene dirección por DHCP en el rango nuevo.
- [ ] La puerta de enlace del cliente es la interfaz interna del firewall.
- [ ] `ping` a una dirección pública responde desde el cliente.
- [ ] La interfaz de administración sigue siendo accesible.

---

## Prevención

- **Planifica el direccionamiento antes de conectar el equipo.** El rango de fábrica de muchos firewalls (`192.168.1.0/24`) coincide con el de la mayoría de routers domésticos, así que el solapamiento es el estado por defecto, no un caso raro.
- Usa rangos que no colisionen con nada habitual: `10.x` u `172.16-31.x` en lugar de `192.168.0.x` o `192.168.1.x`.
- Ante cualquier problema de conectividad en un equipo con varias interfaces, **la comprobación de subredes solapadas cuesta 10 segundos** y debería ir antes que revisar políticas.

---

## Nota sobre la lección

En el incidente original, el solapamiento se detectó a simple vista en una fase temprana y se descartó como "feo pero no rompe nada ahora mismo". Esa valoración fue errónea y costó una hora de diagnóstico.

**Un solapamiento de subredes en un dispositivo de encaminamiento no es un defecto cosmético.** Aunque no rompa el tráfico que estás observando en ese momento, deja el reenvío en un estado indefinido que se manifiesta después, en el peor momento y sin señales claras.
