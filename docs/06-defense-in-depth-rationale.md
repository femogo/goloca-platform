# P1.6 — Defensa en Profundidad: el Racional

> **Proyecto:** P1 · Infraestructura Base
> **Mini-proyecto:** 1.6 — Linux baseline + Docker (transversal a todo P1)
> **Estado:** Cerrado (sesión 4)
> **Documentos relacionados:** [`06-hardening-checklist.md`](06-hardening-checklist.md), [`06-linux-baseline-spec.md`](06-linux-baseline-spec.md), [`01-network-architecture.md`](01-network-architecture.md)

---

## 1. Por qué este documento existe

Cualquiera puede listar medidas de seguridad: firewall, SSH por clave, parcheo, bastión. La diferencia entre seguir una checklist y entender seguridad está en saber **por qué cada capa existe, qué ataque detiene, y qué pasa cuando falla**. Este documento es el racional de las decisiones de seguridad de P1, no su catálogo. El catálogo está en `06-hardening-checklist.md`.

La premisa: ninguna capa de seguridad es perfecta. Cada una falla en algún escenario. La defensa en profundidad no busca una muralla infranqueable —no existe— sino varias capas independientes, de modo que comprometer una no comprometa el sistema. El atacante tiene que vencerlas todas; tú solo necesitas que una resista.

## 2. El modelo de amenaza de Goloca AI

Antes de defender hay que saber de qué. Goloca AI procesa datos sensibles de clientes regulados (banca, healthcare, sector público bajo AI Act EU). El escenario de amenaza realista para un laboratorio doméstico que simula esto:

- **Un dispositivo IoT doméstico comprometido** (cámara, enchufe inteligente, TV) en la misma red física. Es el vector más realista: nadie hackea el FortiGate de frente, comprometen la bombilla WiFi barata y desde ahí pivotan.
- **Una credencial filtrada o débil** que da un primer punto de apoyo.
- **Un contenedor o servicio mal configurado** expuesto sin querer.

El diseño no asume un atacante que ataca de frente la puerta principal. Asume que **el atacante ya está dentro de la red doméstica** y quiere pivotar hacia la infraestructura de producción. Cada capa busca cortar ese pivote.

## 3. Las capas, de fuera hacia dentro

```
   INTERNET
      │
      ▼
 ┌─────────────────────────────────────────────┐
 │ CAPA 1 — Perímetro (FortiGate)              │  ← P1.1 (pendiente)
 │ Segmentación por zonas, políticas L-P,      │
 │ deny-all implícito, logging de denegaciones │
 └─────────────────────┬───────────────────────┘
                       │
 ┌─────────────────────▼───────────────────────┐
 │ CAPA 2 — Acceso (Bastión + SSL-VPN)         │  ← P1.2/P1.5
 │ Punto único de entrada, sin SSH directo,    │
 │ ProxyJump, trazabilidad de accesos          │
 └─────────────────────┬───────────────────────┘
                       │
 ┌─────────────────────▼───────────────────────┐
 │ CAPA 3 — Host (UFW + SSH hardening)         │  ← P1.6
 │ Firewall por host, SSH por clave en 2222,   │
 │ superficie de ataque mínima                 │
 └─────────────────────┬───────────────────────┘
                       │
 ┌─────────────────────▼───────────────────────┐
 │ CAPA 4 — Sistema (parcheo + logging + RBAC) │  ← P1.6 / futuro
 │ unattended-upgrades, journald, principio    │
 │ de menor privilegio                         │
 └──────────────────────────────────────────────┘
```

### 3.1 Capa 1 — Perímetro (FortiGate)

La segmentación de red es la primera capa y la más importante contra el pivote. Si el dispositivo IoT comprometido no comparte dominio de difusión con los servidores y las políticas del FortiGate niegan ese tráfico, el atacante en la bombilla no puede ni ver el servidor de aplicación. No es que no pueda entrar: es que el tráfico ni siquiera se enruta.

> **Revisión de sesión 7.** El diseño original aislaba los dispositivos domésticos en una zona WIFI (`10.99.0.0/24`) detrás del FortiGate. Esa zona **no se implementa** (desviación D-13): un solo cable une el HGU con la planta inferior, y bajar el punto de acceso metería todos los dispositivos de la vivienda dentro del laboratorio. El aislamiento se consigue por el otro lado — el AP se queda **delante** del FortiGate, en la red doméstica, y el laboratorio entero vive detrás. El resultado para el modelo de amenaza es equivalente: el IoT comprometido está fuera del perímetro, no dentro de una zona restringida.

Detalle de diseño: la política implícita final es `deny all` **con logging**. No basta con denegar; hay que registrar la denegación. Una intrusión que rebota contra el deny-all sin logging es una intrusión invisible. El log de denegaciones es lo que convierte un firewall en un sensor.

**Estado (sesión 7):** el FortiGate ya está en servicio y todo el laboratorio vive detrás de él en `10.20.0.0/24`, separado de la red doméstica. La capa existe, pero **a medias**: la red interna sigue siendo plana (sin zonas MGMT/SERVERS/DMZ) y la política de salida es transitoria y permisiva (`all/all/ACCEPT`, DT-25). El pivote desde la red doméstica está cortado; el pivote *lateral* dentro del laboratorio, todavía no.

### 3.2 Capa 2 — Acceso (Bastión)

El bastión es el único host con SSH alcanzable desde la red de gestión. Todo lo demás (app01, futuros nodos K3s) solo se alcanza **a través** del bastión, vía ProxyJump. Esto comprime la superficie de acceso a un solo punto: un único host que auditar, endurecer y vigilar.

Es el equivalente on-premise de AWS SSM Session Manager: en vez de exponer SSH de cada instancia, un único punto de entrada controlado. Si comprometes app01, no llegaste por SSH directo —no existe esa ruta—; tuviste que pasar por el bastión, que deja rastro.

El AI Act EU exige trazabilidad de accesos a sistemas que procesan datos regulados. Un punto único de entrada es la base técnica de esa trazabilidad: un solo sitio donde mirar quién entró y cuándo.

### 3.3 Capa 3 — Host (UFW + SSH)

Aunque el FortiGate ya filtra a nivel de red, cada host lleva su propio firewall (UFW). Esto es defensa en profundidad pura: si el FortiGate se configura mal, o un atacante ya está en la zona SERVERS, el UFW del host es la siguiente capa. Dos firewalls independientes (perímetro + host) tienen que fallar para que el host quede expuesto.

El SSH endurecido (puerto 2222, solo clave, sin root, máximo 3 intentos) eleva el coste de un ataque de credenciales. No lo hace imposible —nada lo hace— pero convierte un escaneo automatizado trivial en un ataque que requiere esfuerzo dirigido. La mayoría de los ataques son oportunistas; subir el coste por encima del umbral del atacante oportunista filtra el 99% del ruido.

La regla estricta de app01 (SSH solo desde el bastión, no desde toda la red) es la aplicación del menor privilegio a nivel de red de host: app01 no necesita aceptar SSH de nadie más que el bastión, así que no lo acepta.

### 3.4 Capa 4 — Sistema

Parcheo (unattended-upgrades de seguridad), logging persistente (journald), y el principio de menor privilegio en cuanto a usuarios y servicios. Esta capa asume que el atacante ya ejecuta código en el host y busca limitar qué puede hacer y garantizar que quede rastro.

Aquí vive la tensión documentada de DT-07: el usuario en el grupo `docker` es root efectivo, lo que viola el menor privilegio. Se acepta temporalmente por comodidad operativa en un host de acceso restringido (capa 2 lo protege), con resolución planificada en P3/P6. La defensa en profundidad permite estos trade-offs precisamente porque ninguna capa carga sola con la seguridad: la debilidad de la capa 4 (docker=root) está mitigada por la fortaleza de la capa 2 (solo se llega vía bastión).

## 4. El principio que une todo: asumir el fallo

La idea central, repetida en cada capa: **asumir que la capa anterior puede fallar.**

- El FortiGate puede estar mal configurado → por eso UFW en cada host.
- El UFW puede tener un hueco → por eso SSH solo por clave.
- La clave puede filtrarse → por eso acceso solo vía bastión, con rastro.
- El bastión puede comprometerse → por eso segmentación de red que limita el pivote.

Cada capa es independiente y asume que las demás no existen. Eso es lo que la hace robusta. Un diseño donde las capas dependen unas de otras cae entero cuando cae una. Un diseño de capas independientes degrada poco a poco: pierdes una capa, sigues teniendo las demás.

## 5. Lo que P1 todavía no cubre (honestidad del modelo)

La defensa en profundidad bien entendida incluye saber dónde están los huecos:

| Hueco | Capa afectada | Resolución |
|---|---|---|
| FortiGate no operativo (lab en 192.168.1.x) | Capa 1 ausente | P1.1, bloqueado por hardware |
| Fail2ban instalado sin configurar | Capa 3 incompleta | P6 |
| Sin gestión centralizada de secretos | Capa 4 | P6: Vault / AWS Secrets Manager |
| docker = root | Capa 4 (menor privilegio) | P3 RBAC / P6 rootless |
| Sin IDS/IPS | Transversal | Fuera de alcance del roadmap |
| Usuarios VPN locales (no IdP) | Capa 2 | P6: Authentik/Keycloak |

Un modelo de seguridad que no documenta sus propios huecos es marketing, no ingeniería. Estos huecos son conocidos, tienen dueño y fecha. Esa es la diferencia entre seguridad real y teatro de seguridad.
