# P1.1 — Arquitectura de red

> **Proyecto:** P1 · Infraestructura Base
> **Mini-proyecto:** 1.1 — Segmentación de red con FortiGate 30E
> **Estado:** En progreso (~40%) · fases A y B completadas en sesión 7
> **Documentos relacionados:** [`01-vlan-zoning-rationale.md`](01-vlan-zoning-rationale.md) · [`06-defense-in-depth-rationale.md`](06-defense-in-depth-rationale.md)

---

## 1. Problema de negocio

Goloca AI procesa datos de clientes en sectores regulados. El modelo de amenaza que gobierna el diseño no es un ataque dirigido sofisticado, sino el escenario realista: **un dispositivo doméstico comprometido —una bombilla, un televisor, una cámara— sirviendo de punto de entrada para pivotar hacia la infraestructura que sostiene datos de clientes.**

Un laboratorio conectado a la misma red plana que los dispositivos de una vivienda no es defendible. La segmentación de red es la primera capa de defensa y la que hace que las demás importen.

Una vez expuesto un reverse proxy a Internet (P2), aparece un segundo requisito: ese proxy es el componente con mayor superficie de ataque de la plataforma y **no debe compartir dominio de difusión con la base de datos**. Si cae, debe caer solo.

---

## 2. Estado actual (sesión 7)

Lo que está funcionando:

```
        INTERNET
            │
      HGU Movistar ──┬── AP WiFi          RED DOMÉSTICA
      192.168.1.1    │                    192.168.1.0/24
                     │  (D-Link, no gestionable)
                     ▼ WAN1 · DHCP → 192.168.1.33
    ┌────────────────────────────────────────┐
    │      FortiGate 30E · fgt-prod-01       │
    │                                        │
    │   lan (hard-switch internal1-4)        │
    │            10.20.0.1/24                │
    │   DHCP 10.20.0.100-200                 │
    │   Política TEMP-lan-to-wan (all/all)   │
    └───┬────────┬───────────┬───────────────┘
        │        │           │
   internal1  internal2  internal3
        │        │           │
   portátil   PC estudio   Proxmox 10.20.0.10
   .100         .101         │
                             ├── bastion-prod-01  10.20.0.40
                             ├── app-prod-01      10.20.0.20
                             └── ia-gpu (LXC)     DHCP
```

**Conseguido:** todo el laboratorio vive detrás del cortafuegos, separado de la red doméstica. El pivote desde un dispositivo doméstico comprometido está cortado.

**Todavía no:** la red interna es **plana**. Los cuatro puertos internos forman un único switch lógico, así que dentro del laboratorio no hay separación entre estaciones de trabajo, servidores y futura DMZ. Y la política de salida es transitoria y completamente permisiva (`all/all/ACCEPT`, deuda DT-25).

En términos del modelo de amenaza: el pivote **desde fuera** está resuelto; el pivote **lateral dentro** no.

---

## 3. Arquitectura objetivo

Segmentación híbrida, por las razones que se desarrollan en [`01-vlan-zoning-rationale.md`](01-vlan-zoning-rationale.md):

| Zona | Medio | VLAN | Subred | Miembros |
|---|---|---|---|---|
| **MGMT** | Grupo de puertos físicos + VLAN 10 del troncal | 10 (tramo virtual) | `10.10.0.1/24` | Estaciones de trabajo, NIC de gestión de Proxmox, bastión |
| **SERVERS** | VLAN sobre el troncal | 20 | `10.20.0.1/24` | VMs de aplicación, base de datos, K3s, observabilidad |
| **DMZ** | VLAN sobre el troncal | 30 | `10.30.0.1/24` | Reverse proxy NGINX (P2) |
| **WIFI** | No se implementa (D-13) | 99 reservada | `10.99.0.0/24` | — |
| **VPN** | `ssl.root` | — | `10.10.99.0/24` | Pool de acceso remoto (P1.2) |

### 3.1 Por qué MGMT abarca dos medios

Las estaciones de trabajo son equipos físicos: entran sin etiquetar por puertos del cortafuegos. El bastión es una máquina virtual: llega etiquetado en VLAN 10 por el troncal.

Ambos tramos deben pertenecer a **la misma subred**, o el bastión deja de estar en la red de gestión. La forma correcta de unirlos es un **software switch** del FortiGate que agrupe el conjunto de puertos físicos y la subinterfaz VLAN 10 en un único dominio de difusión, con una sola dirección de puerta de enlace.

La alternativa —dos interfaces distintas, ambas en `10.10.0.0/24`— produce subredes solapadas, que en un FortiGate dejan el reenvío en estado indefinido. Esto no es teoría: ocurrió en la sesión 7 con las interfaces WAN y LAN, y costó una hora de diagnóstico. Ver [`../runbooks/01-overlapping-subnets-debug.md`](../runbooks/01-overlapping-subnets-debug.md).

### 3.2 Por qué la zona WiFi no existe

El diseño original aislaba los dispositivos domésticos en una zona WIFI detrás del cortafuegos. Se descartó al conocer la instalación real: **un solo cable une el router del operador con la planta inferior**. Bajar el punto de acceso detrás del FortiGate obligaría a meter todos los dispositivos WiFi de la vivienda dentro del laboratorio.

Eso sería contraproducente por dos motivos. Contradice el objetivo —el IoT acabaría *dentro* del perímetro en lugar de fuera— y convierte cada error de configuración del laboratorio en una incidencia doméstica.

La solución es la simétrica: el punto de acceso se queda **delante** del cortafuegos y el laboratorio entero vive detrás. Para el modelo de amenaza el resultado es equivalente o mejor. La VLAN 99 queda reservada por si el escenario cambia.

---

## 4. Flujo de tráfico

### 4.1 Salida a Internet desde el laboratorio

```
VM en SERVERS (VLAN 20)
   │ etiquetado 802.1Q
   ▼
vmbr0 (VLAN-aware) → nic0 → internal3 (troncal)
   │
   ▼ el FortiGate desencapsula, evalúa política SERVERS→WAN
NAT de origen a 192.168.1.33
   │
   ▼
HGU 192.168.1.1 → NAT a la IP pública → Internet
```

Doble NAT (FortiGate y HGU). Aceptado conscientemente: evita perder los servicios del operador y delega la seguridad en el FortiGate. Deuda DT-05.

### 4.2 Entrada web desde Internet (a partir de P2)

```
Cliente → HTTPS 443
   ▼
HGU ── DMZ Host ──► FortiGate WAN1
   ▼ VIP + política WAN→DMZ, NAT de destino
10.30.0.20 (VLAN 30)
   ▼ etiquetado, sale por internal3
Proxmox → vmbr0 → VM nginx-dmz-01
   ▼ termina TLS, proxy inverso
   ▼ política DMZ→SERVERS, solo el puerto de la API
app-prod-01 10.20.0.20 (VLAN 20)
```

**Dónde se depura cada salto:** reenvío del HGU · log de política del FortiGate · etiquetado VLAN en `vmbr0` (`bridge vlan show`) · certificado y `upstream` de NGINX · healthcheck de la API. Cada salto falla de forma distinta y tiene su propio registro.

---

## 5. Decisiones de direccionamiento

- **Rangos `10.x`, no `192.168.x`.** El rango de fábrica de muchos cortafuegos coincide con el de la mayoría de routers domésticos. Elegir `10.x` evita por construcción el solapamiento que causó el incidente de la sesión 7.
- **Una subred `/24` por zona.** Sobredimensionado para el número real de hosts, pero legible: el tercer octeto identifica la zona de un vistazo, lo que ahorra tiempo leyendo logs y reglas.
- **Hosts de infraestructura con dirección fija fuera del rango DHCP.** El rango `.100-.200` queda para clientes; la infraestructura vive por debajo.

---

## 6. Deuda técnica

| ID | Deuda | Resolución prevista |
|---|---|---|
| DT-24 | FortiOS 6.2.5 fuera de soporte, con CVEs conocidas | Evaluar antes de exponer la WAN a Internet en P1.2 |
| DT-25 | Política `TEMP-lan-to-wan` totalmente permisiva | Sustituir por la matriz least-privilege al completar P1.1 |
| DT-26 | Reglas UFW obsoletas de la red antigua sin borrar | `ufw delete` tras confirmar estabilidad |
| DT-27 | Estaciones con dirección por DHCP, no reservada | Reservas al crear las zonas |
| DT-15 | Clientes con DNS `8.8.8.8` | Activar el forwarder del FortiGate |
| DT-02 | Switch no gestionable | Switch gestionable si hacen falta más zonas físicas |
| DT-05 | Doble NAT | Opcional: HGU en monopuesto |
