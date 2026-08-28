# ROADMAP DEVOPS — GOLOCA AI

**Documento maestro de hoja de ruta.**
**Versión:** 1.0
**Fecha de creación:** 21 mayo 2026
**Autor (mentor):** Arquitecto DevOps Senior · Mentor Técnico
**Duración total:** 6 meses
**Estado actual:** Pre-arranque Proyecto 1 (decisiones cerradas)

---

## 1. CONTEXTO DEL APRENDIZ Y OBJETIVO FINAL

### 1.1 Punto de partida (Nivel 0)

- Conocimientos: básicos/intermedios de Linux, redes, programación general.
- Ubicación: Madrid, España.
- Disponibilidad: 6 meses, dedicación parcial regular.

### 1.2 Objetivo final del roadmap

Al finalizar los 6 meses, el aprendiz debe poder optar a roles junior **remotos en Europa** en:

- DevOps Engineer Junior
- Cloud Engineer Junior
- Platform Engineer Junior
- SRE Junior
- Infraestructura Cloud Junior

Enfocado al ecosistema de **startups de IA tipo A** (AI-native SaaS, plataformas de agentes IA, RAG-based products), que es el arquetipo de mayor demanda en el mercado europeo 2026-2030.

### 1.3 Diferenciadores que el roadmap busca generar

1. Portfolio público en GitHub con infraestructura realista, no ejercicios académicos.
2. Capacidad operacional real: debugging, troubleshooting, observabilidad.
3. Stack alineado con plataformas de IA modernas (multi-tenancy, vector DBs, LLM serving, RAG).
4. Narrativa diferenciadora: **modo soberano on-premise con LLM local** aprovechando GPU RTX 4060.
5. Conocimiento de networking real (no solo "instalé Docker").

---

## 2. EMPRESA FICTICIA: GOLOCA AI

### 2.1 Descripción

Startup B2B con sede en Madrid, equipo distribuido España/Alemania/Estonia. Vende una plataforma de **agentes IA** que automatizan operaciones internas de empresas medianas europeas: atención al cliente nivel 1, análisis de contratos, generación de reportes financieros, gestión de tickets internos.

### 2.2 Modelo de negocio

SaaS multi-tenant. Cada cliente tiene datos aislados, agentes personalizados, y consume tokens facturados a final de mes. Dos modalidades:

- **Modo Cloud:** llamadas a APIs externas (OpenAI, Anthropic, Mistral). Más barato, datos del cliente salen.
- **Modo Sovereign:** LLM local (Llama 3.1, Qwen 2.5) en GPU on-premise. Más caro y complejo, obligatorio para clientes regulados (banca, healthcare, sector público bajo AI Act EU).

### 2.3 Stack técnico objetivo (6 meses)

| Componente | Tecnología | Proyecto |
|---|---|---|
| Perímetro de red | FortiGate 30E | P1 |
| Segmentación L2 | VLANs 802.1Q (troncal al hipervisor) | P1 |
| Hipervisor | Proxmox VE | P1 |
| Sistema base | Ubuntu Server 24.04 LTS | P1 |
| API gateway | NGINX + FastAPI (Python) | P2 |
| Cola de tareas | Redis Streams | P2 |
| Base de datos transaccional | PostgreSQL 16 | P2 |
| Vector DB (RAG) | PostgreSQL + pgvector | P3 |
| Orquestación | K3s → Kubernetes | P3 |
| Gestión paquetes | Helm | P3 |
| CI/CD | GitHub Actions | P4 |
| Escaneo vulnerabilidades | Trivy | P4 / P6 |
| Métricas | Prometheus | P4 |
| Logs centralizados | Loki | P4 |
| Visualización | Grafana | P4 |
| Cloud público | AWS (VPC, EC2, S3, RDS) | P5 |
| IaC | Terraform | P5 |
| Configuration mgmt | Ansible | P5 |
| Secrets | Vault o AWS Secrets Manager | P6 |
| Hardening OS | CIS Ubuntu benchmarks | P6 |
| Protección perimetral host | Fail2ban | P6 |
| LLM local | Ollama + Llama 3.1 8B | P6 |

### 2.4 Convenciones de naming (aplicables los 6 meses)

- **Dominio interno:** `goloca.lab`
- **Dominio público (DDNS):** `<DDNS-HOSTNAME>`
- **Repositorio GitHub:** `goloca-platform`
- **Hostnames:** `<rol>-<entorno>-<nn>.goloca.lab`
  - Ejemplos: `fgt-prod-01`, `pve-prod-01`, `bastion-prod-01`, `app-prod-01`, `db-prod-01`, `k3s-master-01`, `k3s-worker-01`
- **Entornos:** `prod`, `staging`, `dev` (de momento solo `prod`; los demás aparecerán en P4-P5)

---

## 3. INVENTARIO DE HARDWARE Y RED FÍSICA

### 3.1 PC servidor (host de virtualización)

- **CPU:** Intel Core i5 10ª generación
- **RAM:** 32 GB DDR4
- **GPU:** NVIDIA RTX 4060 (8 GB VRAM) — reservada para P6 (LLM local vía Ollama + NVIDIA Container Toolkit)
- **Almacenamiento:**
  - NVMe 240 GB #1 → Proxmox sistema + boot (`local`)
  - NVMe 240 GB #2 → VMs críticas (`local-lvm-nvme`)
  - SSD 500 GB → VMs secundarias / workers K3s (`local-lvm-ssd`)
  - HDD 1 TB → Backups, ISOs, snapshots, exports (`backup` dir)
  - Discos adicionales → Reserva para P6 (modelos LLM ~5-15 GB cada uno, vector DB persistente)
- **SO:** Pendiente formateo → **Proxmox VE 8.x bare-metal** (eliminando Windows Server actual)

- **Red:** una sola NIC integrada (`nic0`) + **adaptador USB 3.0-Gigabit**. La integrada actúa como troncal 802.1Q para las VMs; la USB, como interfaz de gestión del host en MGMT (ver 4.5).

### 3.2 PC Windows (workstation desarrollo)

- Permanece con Windows.
- Uso: VS Code Remote SSH, terminal, FortiClient VPN, herramientas dev.

### 3.3 Portátil auxiliar

- Workstation de administración.
- Cliente VPN para simular acceso remoto desde fuera.
- Mantiene SO actual.

### 3.4 Infraestructura de red

- **FortiGate 30E** (FortiOS 7.4+): núcleo perimetral. Configuración como router/firewall principal.
- **Switch D-Link DGS-1005P**: **NO gestionable** (sin VLAN tagging, sin L3). Situado **delante** del FortiGate, en la red doméstica: reparte la única bajada del HGU entre el punto de acceso WiFi y la WAN del FortiGate. No forma parte del laboratorio.
- **Access Point WiFi**: doméstico, sirviendo VLAN WIFI sin acceso a zonas internas.
- **Router HGU Movistar** (~6 años, probablemente Mitrastar GPT-2541GNAC o Askey RFT3505VW): proporciona conectividad WAN. **Doble NAT** con el FortiGate (ver decisión arquitectónica 4.4).

### 3.5 Conectividad de Internet

- **ISP:** Movistar
- **IP pública:** `203.0.113.10` (validada como **NO CGNAT**)
- **Naturaleza:** dinámica (casi seguro) → resuelto con DDNS DuckDNS
- **Implicación:** port forwarding viable, exposición externa posible

---

## 4. DECISIONES ARQUITECTÓNICAS CERRADAS

Estas decisiones están **bloqueadas**. No se replantean salvo cambio de hardware.

### 4.1 Segmentación de red — modelo híbrido

> **Revisada en sesión 7 (28 ago 2026).** La decisión original descartaba VLANs por completo. Se acotó su alcance al detectar que bloqueaba P2: ver el razonamiento abajo.

La segmentación se resuelve de dos formas distintas según el tramo de red:

**a) Plano de gestión — segmentación por puertos físicos del FortiGate.**

- **Decisión:** los equipos físicos (workstations, NIC de gestión del hipervisor) se conectan a puertos del FortiGate agrupados por zona.
- **Razón:** el switch D-Link DGS-1005P no es gestionable y no puede transportar VLANs etiquetadas.
- **Deuda técnica (DT-02):** si hacen falta más zonas físicas, se requiere un switch gestionable (TP-Link TL-SG108E, ~25 €).

**b) Plano de datos — troncal 802.1Q hacia el hipervisor.**

- **Decisión:** el enlace entre `nic0` de Proxmox y el puerto `internal3` del FortiGate es un **troncal 802.1Q**. Cada zona que aloje máquinas virtuales viaja etiquetada por ese enlace.
- **Problema que resuelve:** Proxmox tiene **una sola NIC integrada**. Con segmentación puramente física, todas las VMs quedarían encerradas en la zona a la que esté puenteada esa NIC. Eso hacía **imposible** el reverse proxy NGINX en DMZ previsto en P2: la zona DMZ existiría como interfaz del FortiGate, pero ningún servidor podría alcanzarla.
- **Por qué esto no contradice la decisión (a):** el motivo de descartar VLANs era el switch no gestionable. En el enlace Proxmox ↔ FortiGate **no hay ningún switch de por medio** — es punto a punto. La restricción que justificaba la decisión no aplica a ese tramo.
- **Precedente en producción:** llevar un troncal al hipervisor y repartir VLANs dentro es el patrón estándar en VMware, Proxmox y cualquier virtualización con múltiples redes. La alternativa (una NIC física por zona) no escala.
- **Implicación formativa:** incorpora 802.1Q, bridges VLAN-aware y depuración de etiquetado al roadmap, que antes no lo cubría en ningún punto.

**Alternativa descartada:** segunda NIC USB 3.0-Gigabit dedicada a la DMZ. Funciona, pero exige un adaptador por zona, y un USB-Ethernet es frágil como infraestructura permanente. La USB NIC disponible se destina a un uso mejor (ver 4.5).

### 4.2 Hipervisor

- **Decisión:** Proxmox VE bare-metal sobre el PC servidor.
- **Razón:** estándar de facto en pymes europeas tras la adquisición VMware → Broadcom; KVM nativo; ecosistema Linux completo; defendible en entrevistas.
- **Trade-off conocido:** ZFS descartado por discos heterogéneos. Se usa **LVM-thin** sobre cada disco independientemente.

### 4.3 Empresa ficticia

- **Decisión:** Goloca AI (Plataforma de Agentes IA Empresariales — arquetipo A).
- **Razón:** máxima empleabilidad remota en Europa 2026-2030; stack transferible; narrativa "modo soberano" aprovecha la RTX 4060; resistente a la sustitución del propio rol DevOps por IA.

### 4.4 Topología de NAT con HGU Movistar

- **Decisión:** **Doble NAT con DMZ Host** (HGU envía todo el tráfico no solicitado al FortiGate).
- **Razón:** evita perder IPTV de Movistar si se usa; delega seguridad al FortiGate; configuración más simple que modo monopuesto/bridge.
- **Alternativa futura (opcional):** modo monopuesto del HGU si IPTV no se usa, eliminando el doble NAT.

### 4.5 Uso de la NIC USB — separación de plano de gestión y plano de datos

> **Revisada en sesión 7 (28 ago 2026).** El destino previsto para la NIC USB era dar al bastión una pata en MGMT. Con el troncal VLAN (4.1) eso ya no hace falta: el bastión llega a MGMT etiquetando. El adaptador se reasigna a algo de más valor.

- **Decisión:** la **NIC USB 3.0-Gigabit** se dedica a la **interfaz de gestión del propio host Proxmox**, conectada a la zona MGMT (`pve-prod-01` → `10.10.0.10`). La NIC integrada `nic0` queda como **troncal puro** para el tráfico de las VMs, sin IP de host.
- **Razón:** separa el plano de gestión del plano de datos. Un error en la configuración de VLANs, bridges o cortafuegos del plano de datos **no deja al hipervisor incomunicado**. Es especialmente relevante aquí: el servidor no tiene monitor ni teclado conectados y recuperarlo físicamente es costoso.
- **Precedente en producción:** interfaz de gestión dedicada y separada del tráfico de cargas es práctica estándar (equivalente al `vmk0` de gestión en ESXi o a una red de gestión out-of-band).
- **Resolución de DT-01:** el bastión pasa a MGMT mediante VLAN sobre el troncal, sin hardware adicional.

### 4.6 Repositorios sin suscripción de Proxmox

- **Decisión:** repositorios `no-subscription` documentados.
- **Razón:** laboratorio formativo, sin presupuesto.
- **Deuda técnica documentada:** en producción real se usa suscripción de pago para builds estables y soporte.

### 4.7 Usuario en grupo docker

- **Decisión:** `ubuntu` en grupo `docker` en app-prod-01.
- **Trade-off documentado:** equivale a root. Mitigado parcialmente por el patrón bastión + RBAC futuro en Kubernetes (P3).

---

## 5. ESQUEMA DE DIRECCIONAMIENTO

### 5.1 Zonas y subredes

> **Revisada en sesión 7.** Modelo híbrido: las zonas con equipos físicos viven en puertos del FortiGate; las zonas que solo contienen máquinas virtuales viven como VLAN sobre el troncal hacia Proxmox (ver 4.1).

| Zona | Dónde vive | VLAN ID | Subred | Propósito | Acceso desde Internet |
|---|---|---|---|---|---|
| WAN | WAN1 | — | 192.168.1.x (vía HGU) → 203.0.113.10 | Salida a Internet | N/A |
| **MGMT** | Grupo físico `internal1`+`internal2`+`internal4`, más VLAN 10 del troncal | 10 (solo tramo virtual) | `10.10.0.0/24` | Gestión: workstations, NIC de gestión de Proxmox, bastión | Solo vía SSL-VPN |
| **SERVERS** | VLAN sobre el troncal `internal3` | 20 | `10.20.0.0/24` | VMs de aplicación, base de datos, nodos K3s, observabilidad | Nunca directo |
| **DMZ** | VLAN sobre el troncal `internal3` | 30 | `10.30.0.0/24` | Reverse proxy NGINX (desde P2) | Solo 80/443 vía NAT |
| WIFI | *No implementada* | 99 (reservada) | `10.99.0.0/24` | — | — |
| VPN | `ssl.root` | — | `10.10.99.0/24` | Pool de acceso remoto | Solo vía SSL-VPN |

**Notas de diseño:**

- **MGMT abarca dos medios.** Los equipos físicos entran sin etiquetar por el grupo de puertos; las VMs que deban estar en MGMT (el bastión) entran etiquetadas en VLAN 10 por el troncal. Ambos tramos se unen en **un único dominio de difusión** mediante un *software switch* del FortiGate, de modo que comparten la misma subred y una sola IP de gateway (`10.10.0.1`). Sin esa unión habría dos interfaces distintas en `10.10.0.0/24`, y subredes solapadas en un FortiGate rompen el encaminamiento — verificado en la práctica durante la sesión 7.
- **SERVERS y DMZ no tienen puerto físico.** No lo necesitan: sus únicos miembros son máquinas virtuales, que llegan por el troncal. Si algún día hay un servidor físico en SERVERS, se le asigna un puerto y se une a la VLAN 20 por el mismo mecanismo de software switch.
- **WIFI no se implementa** (desviación D-13): el punto de acceso permanece en la red doméstica, delante del FortiGate, porque un solo cable une el HGU con la planta inferior y bajarlo metería todos los dispositivos WiFi de la vivienda dentro del laboratorio. La VLAN 99 queda reservada por si el escenario cambia.
- Queda **un puerto físico libre** para expansión (uplink a un switch gestionable, DT-02).

### 5.2 Tabla maestra de hosts

| Hostname | IP | Zona (medio) | Rol | Recursos | Proyecto |
|---|---|---|---|---|---|
| `fgt-prod-01` | 10.10.0.1 / 10.20.0.1 / 10.30.0.1 | Todas (router) | Firewall perimetral | Hardware | P1 |
| `pve-prod-01` | **10.10.0.10** | MGMT (NIC USB, `vmbr1`) | Gestión del hipervisor | Hardware (i5+32GB+RTX) | P1 |
| *(mismo equipo)* | sin IP | Troncal (`nic0`, `vmbr0` VLAN-aware) | Plano de datos de las VMs | — | P1 |
| `bastion-prod-01` | 10.20.0.40 hoy → **10.10.0.40** | SERVERS (VLAN 20) → MGMT (VLAN 10) | Bastión SSH + controlador Ansible | VM 1 vCPU / 2 GB / 20 GB | P1 (migración: DT-01) |
| `app-prod-01` | 10.20.0.20 | SERVERS (VLAN 20) | Host Docker | VM 2 vCPU / 4 GB / 40 GB | P1-P2 |
| `db-prod-01` (TBD) | 10.20.0.31 | SERVERS (VLAN 20) | PostgreSQL (o contenedor en app-prod-01) | VM o contenedor | P2-P3 |
| `nginx-dmz-01` (TBD) | 10.30.0.20 | DMZ (VLAN 30) | Reverse proxy TLS | VM o contenedor | P2 |
| `k3s-master-01` (TBD) | 10.20.0.50 | SERVERS (VLAN 20) | Plano de control K3s | VM 2 vCPU / 4 GB | P3 |
| `k3s-worker-01` (TBD) | 10.20.0.51 | SERVERS (VLAN 20) | Worker K3s | VM 2 vCPU / 4 GB | P3 |
| `monitor-prod-01` (TBD) | 10.20.0.60 | SERVERS (VLAN 20) | Prometheus + Grafana + Loki | VM 2 vCPU / 4 GB | P4 |
| `dev01` (PC estudio) | **10.10.0.30** | MGMT (puerto físico) | Workstation de desarrollo y administración | Hardware | Permanente |
| `admin-ops` (portátil) | 10.10.0.50 | MGMT (puerto físico) | Workstation de administración | Hardware | Permanente |
| `ia-gpu` (LXC 130) | DHCP | SERVERS (VLAN 20) | Contenedor ajeno al roadmap con acceso a GPU | LXC 6 vCPU / 20 GB / 250 GB | Fuera de alcance (D-12) |

> **Corrección respecto a versiones anteriores:** `dev01` y `db-prod-01` tenían ambos asignada la `10.20.0.30`. Resuelto: `dev01` pasa a MGMT (`10.10.0.30`) por ser una estación de administración, y `db-prod-01` a `10.20.0.31`.

---

## 6. TOPOLOGÍA FÍSICA Y LÓGICA

> **Actualizada en sesión 7** con la topología real verificada en funcionamiento.

```
                                INTERNET
                                    │
                                    ▼  IP pública dinámica 203.0.113.10
                                    │  (DDNS: <DDNS-HOSTNAME>)
                        ┌───────────────────────┐
                        │   HGU Movistar        │
                        │   (DMZ Host → FGT)    │
                        │   192.168.1.1/24      │
                        └───────────┬───────────┘
                                    │  un único cable entre plantas
                                    ▼
                        ┌───────────────────────┐
                        │  D-Link DGS-1005P     │   RED DOMÉSTICA
                        │  (switch no gestion.) │   192.168.1.0/24
                        └──────┬─────────┬──────┘
                               │         │
                        ┌──────▼───┐     │  no se toca: el WiFi de la
                        │  AP WiFi │     │  casa no entra al laboratorio
                        └──────────┘     │  (desviación D-13)
                                         │
                                         ▼ WAN1 (DHCP → 192.168.1.33)
        ╔════════════════════════════════════════════════════════════════╗
        ║                    FortiGate 30E · fgt-prod-01                  ║
        ║                                                                ║
        ║  Grupo MGMT (software switch)          Troncal 802.1Q          ║
        ║  internal1 + internal2 + internal4     internal3               ║
        ║  + VLAN 10 del troncal                                         ║
        ║         10.10.0.1/24                   VLAN 20 → 10.20.0.1/24  ║
        ║                                        VLAN 30 → 10.30.0.1/24  ║
        ║                                                                ║
        ║  SSL-VPN pool → 10.10.99.0/24                                  ║
        ╚═══┬═════════┬══════════════════════════════════┬═══════════════╝
            │         │                                  │
    internal1     internal2                         internal3
    (sin tag)     (sin tag)                        (troncal VLAN)
            │         │                                  │
     ┌──────▼───┐ ┌───▼────────┐                         │
     │ portátil │ │ PC estudio │                         │
     │admin-ops │ │   dev01    │                         │
     │10.10.0.50│ │ 10.10.0.30 │                         │
     └──────────┘ └────────────┘                         │
                                                         │
                        ┌────────────────────────────────▼─────────────┐
                        │        pve-prod-01  ·  Proxmox VE 9.2        │
                        │        i5 10ª gen · 32 GB · RTX 4060         │
                        │                                              │
                        │  NIC USB ──► internal4 (MGMT, sin tag)       │
                        │      └── vmbr1 · 10.10.0.10  ← GESTIÓN       │
                        │                                              │
                        │  nic0 ──► internal3 (troncal, sin IP)        │
                        │      └── vmbr0 VLAN-aware ← PLANO DE DATOS   │
                        │            │                                 │
                        │   ┌────────┼──────────────┬──────────────┐   │
                        │   │VLAN 20 │              │VLAN 30       │   │
                        │   ▼        ▼              ▼              │   │
                        │ ┌────────────┐ ┌────────────┐ ┌────────────┐ │
                        │ │  bastion   │ │  app01     │ │ nginx-dmz  │ │
                        │ │ 10.20.0.40 │ │10.20.0.20  │ │ 10.30.0.20 │ │
                        │ │  (→ MGMT   │ │  Docker    │ │   (P2)     │ │
                        │ │   DT-01)   │ │            │ │            │ │
                        │ └────────────┘ └────────────┘ └────────────┘ │
                        │                                              │
                        │ ┌────────────┐  ┌──────────────────────────┐ │
                        │ │  ia-gpu    │  │ P3: k3s-master/worker    │ │
                        │ │  LXC 130   │  │ P4: monitor-prod-01      │ │
                        │ │ (fuera del │  │ (VLAN 20)                │ │
                        │ │  roadmap)  │  └──────────────────────────┘ │
                        │ └────────────┘                               │
                        └──────────────────────────────────────────────┘
```

### 6.1 Flujo de tráfico — entrada web (desde P2)

```
Cliente Internet
   │ HTTPS 443
   ▼
HGU 192.168.1.1  ── DMZ Host ──►  FortiGate WAN1 192.168.1.33
   │
   ▼  VIP + política WAN → DMZ
FortiGate: NAT de destino hacia 10.30.0.20
   │
   ▼  etiquetado VLAN 30, sale por internal3
Proxmox nic0 (troncal) → vmbr0 → VM nginx-dmz-01
   │
   ▼  termina TLS, proxy inverso
   │  política DMZ → SERVERS (solo puerto de la API)
   ▼
app-prod-01 10.20.0.20 (VLAN 20)
```

Puntos de depuración en ese camino: reenvío del HGU, log de la política del FortiGate, etiquetado VLAN en `vmbr0`, certificado y `upstream` de NGINX, y healthcheck de la API. Cada salto tiene su propia forma de fallar y su propio registro donde comprobarlo.

---

## 7. ESTRUCTURA GENERAL DEL ROADMAP — 6 PROYECTOS

Cada proyecto **reutiliza la infraestructura del anterior**. Nada se tira. La plataforma evoluciona como una empresa real.

```
PROYECTO 1  ──►  PROYECTO 2  ──►  PROYECTO 3  ──►  PROYECTO 4  ──►  PROYECTO 5  ──►  PROYECTO 6
 (Mes 1)         (Mes 2)          (Mes 3)          (Mes 4)          (Mes 5)          (Mes 6)

 Base Linux     Contenedores     Orquestación     CI/CD +          Cloud Híbrido    Seguridad
 Networking     Docker           K3s/K8s          Observabilidad   AWS + IaC        DR + HA
 FortiGate      Compose          Helm/Ingress     GH Actions       Terraform        DevSecOps
 Proxmox        NGINX/PG/Redis   Persistencia     Prom/Graf/Loki   VPN Site-to-Site Trivy/Hardening
                                                                                    + LLM local
```

### PROYECTO 1 · Mes 1 — Infraestructura Base, Networking Real y Virtualización

**Objetivo:** convertir el hardware en plataforma operativa. FortiGate como núcleo de seguridad, Proxmox como hipervisor, VMs Ubuntu endurecidas, flujo Windows → bastión → VMs vía VS Code. Cierra con un entorno Linux listo para Docker.

**Mini-proyectos:**
1.1 · Segmentación de red con FortiGate (2,5-3h)
1.2 · SSL-VPN + DDNS (2-2,5h)
1.3 · Proxmox VE bare-metal (2,5-3h)
1.4 · Template Ubuntu + cloud-init (2-2,5h)
1.5 · Bastion host + VS Code Remote SSH (1,5-2h)
1.6 · Linux baseline + Docker (2,5-3h)

**Duración total:** 13-16 horas.

### PROYECTO 2 · Mes 2 — Contenerización del Stack Aplicativo

**Objetivo:** levantar el stack de Goloca AI (API simulada + PostgreSQL + Redis + NGINX) en Docker y Docker Compose. Reverse proxy NGINX en DMZ con TLS, volúmenes persistentes, redes Docker segmentadas, healthchecks, primer enfrentamiento con debugging de red Docker y logs de contenedor.

**Tecnologías clave:** Docker Engine, Docker Compose, NGINX, PostgreSQL 16, Redis, FastAPI (Python stub de "agente"), Let's Encrypt vía certbot o acme.sh.

### PROYECTO 3 · Mes 3 — Orquestación con K3s

**Objetivo:** migrar el stack a un clúster K3s (1 master + 1-2 workers en VMs Proxmox). Ingress Controller, ConfigMaps, Secrets, PersistentVolumes, NetworkPolicies, RBAC. Helm Charts para empaquetar la aplicación. Introducción a pgvector para RAG.

**Tecnologías clave:** K3s, kubectl, Helm 3, Traefik o NGINX Ingress, MetalLB (para LoadBalancer en bare-metal), PostgreSQL + pgvector.

### PROYECTO 4 · Mes 4 — CI/CD y Observabilidad

**Objetivo:** pipelines GitHub Actions (build → test → scan Trivy → push a registry → deploy a K3s). Stack de observabilidad completo: Prometheus + Grafana + Loki + Alertmanager. Dashboards de negocio reales: tasa de éxito de agentes, latencia P95/P99, coste por interacción simulado, errores 5xx.

**Tecnologías clave:** GitHub Actions, Trivy, GitHub Container Registry (ghcr.io), Prometheus, Grafana, Loki, Alertmanager.

### PROYECTO 5 · Mes 5 — Cloud Híbrido AWS + IaC

**Objetivo:** extender la plataforma a AWS. VPC con subredes públicas/privadas, IAM con least privilege, EC2, S3 (backups del clúster local + almacenamiento de modelos), RDS opcional. Terraform con módulos, backend remoto (S3 + DynamoDB lock), gestión de tfstate. VPN site-to-site IPsec entre FortiGate y AWS Site-to-Site VPN. Ansible para configuración de instancias EC2.

**Tecnologías clave:** AWS (VPC, EC2, S3, IAM, RDS, Site-to-Site VPN), Terraform 1.x, Ansible, awscli.

### PROYECTO 6 · Mes 6 — Seguridad, Disaster Recovery y LLM Local

**Objetivo:** hardening CIS Ubuntu, Fail2ban en bastión, escaneo continuo con Trivy en pipelines, gestión de secretos (HashiCorp Vault o AWS Secrets Manager), backups automatizados, simulacro de DR (restaurar clúster desde cero), pruebas de carga con k6, alta disponibilidad básica del Ingress y PostgreSQL. **Despliegue de Ollama + Llama 3.1 8B en la RTX 4060** vía GPU passthrough a una VM dedicada, expuesto como servicio interno "modo soberano" de Goloca AI.

**Tecnologías clave:** CIS-CAT Lite o Lynis, Fail2ban, Trivy, Vault, k6, Ollama, NVIDIA Container Toolkit.

---

## 8. DESGLOSE DETALLADO DEL PROYECTO 1

> **Estado de las decisiones técnicas:** ✅ Todas cerradas. Listo para ejecutar.

### 8.1 Mini-Proyecto 1.1 — Segmentación de Red Real con FortiGate 30E

**Duración:** 5 - 6 horas (revisado al alza en sesión 7: la estimación original de 2,5-3 h no contemplaba la recuperación del equipo ni la migración de la red existente)

**Estado:** en progreso. Pasos 1, 2 y 2-bis completados en sesión 7.

**Objetivo:** convertir el FortiGate 30E en el núcleo perimetral real de la plataforma. Segmentación híbrida (puertos físicos para el plano de gestión, troncal 802.1Q para el plano de datos), políticas least-privilege y validación de conectividad selectiva.

**Tecnologías:** FortiGate 30E (FortiOS 6.2.5), consola serie, direccionamiento RFC 1918, **VLANs 802.1Q**, software switch, políticas, NAT, DHCP, logging.

**Problema empresarial:** Goloca AI procesa datos de clientes regulados. Una intrusión a través de un dispositivo doméstico comprometido no debe poder pivotar hacia la infraestructura de producción. Y el reverse proxy expuesto a Internet no debe compartir dominio de difusión con las bases de datos. La defensa en profundidad empieza en la capa de red.

**Pasos clave:**

*Fase A — recuperación y base (completada, sesión 7)*
1. Acceso por **consola serie** (el botón de reset físico no responde) y recuperación con la cuenta `maintainer`, cuya contraseña deriva del número de serie. `execute factoryreset`.
2. Identidad del equipo: contraseña de `admin`, hostname `fgt-prod-01`, NTP FortiGuard, zona horaria. **Verificar cada cambio contra la configuración guardada**, no contra el eco de la consola.
3. WAN1 en DHCP hacia el HGU. Verificar `ping` y resolución DNS.

*Fase B — migración de la red existente (completada, sesión 7)*
4. Renumerar la interfaz interna a `10.20.0.1/24`. **Crítico:** la LAN de fábrica (`192.168.1.99/24`) solapa con la red del HGU en WAN; dos interfaces en la misma subred rompen el encaminamiento del tráfico reenviado.
5. Política transitoria LAN→WAN con NAT para recuperar salida a Internet (se sustituye en la fase D).
6. Migrar el hipervisor y las VMs al nuevo direccionamiento sin perder acceso (ver runbooks de direccionamiento dual y `qemu-guest-agent`).

*Fase C — segmentación (pendiente)*
7. **Sacar puertos del switch interno de uno en uno**, dejando para el final el puerto de la estación de gestión. Configurar el grupo MGMT (`10.10.0.1/24`) con DHCP y acceso administrativo.
8. **Convertir `internal3` en troncal 802.1Q** hacia `nic0` de Proxmox: subinterfaces VLAN 20 (SERVERS) y VLAN 30 (DMZ). Configurar `vmbr0` como VLAN-aware en Proxmox y asignar la VLAN correspondiente a cada VM.
9. **Conectar la NIC USB** de Proxmox al grupo MGMT y mover ahí la gestión del hipervisor (`10.10.0.10`), dejando `nic0` como troncal sin IP.
10. **Software switch** que una el grupo físico MGMT con la VLAN 10 del troncal, para que el bastión comparta dominio de difusión con las workstations sin crear dos interfaces en la misma subred (cierra DT-01).
11. DHCP y reservas estáticas por zona.
12. DNS forwarding del FortiGate hacia Cloudflare `1.1.1.1` (cierra DT-15).

*Fase D — políticas y cierre (pendiente)*
13. Objetos de red (addresses y address groups).
14. Matriz de políticas least-privilege (abajo), sustituyendo la política transitoria.
15. Logging en memoria (**el 30E no tiene disco de logs**: `Log hard disk: Not available`).
16. Validación: pings cruzados entre zonas confirmando lo permitido y lo denegado.
17. Backup de configuración **sanitizado** antes de versionar.

**Matriz de políticas firewall:**

| Nº | Src | Dst | Service | Action | NAT | Log |
|---|---|---|---|---|---|---|
| 0 | ssl.root (VPN) | grp-internal | SSH, HTTPS, ICMP | ALLOW | No | All |
| 1 | addr-net-mgmt | addr-host-pve | HTTPS, SSH | ALLOW | No | All |
| 2 | addr-net-mgmt | addr-net-servers | SSH, ICMP | ALLOW | No | All |
| 3 | addr-net-mgmt | addr-net-dmz | ALL | ALLOW | No | All |
| 4 | addr-net-mgmt | WAN | ALL | ALLOW | Yes | Denied only |
| 5 | addr-net-servers | WAN | DNS, NTP, HTTPS, HTTP | ALLOW | Yes | All |
| 6 | addr-net-servers | addr-net-mgmt | ANY | DENY | — | All |
| 7 | addr-net-dmz | addr-net-servers | (solo puerto de la API, se define en P2) | DENY de momento | — | All |
| 8 | addr-net-dmz | WAN | HTTPS, DNS | ALLOW | Yes | All |
| 9 | WAN | addr-host-nginx-dmz | HTTP, HTTPS (VIP) | ALLOW en P2 | DNAT | All |
| 99 | ANY | ANY | ANY | DENY | — | All |

> Las reglas 9 y 10 originales (zona WIFI) se retiran: la zona no se implementa (D-13). La regla 9 pasa a ser la entrada web de P2.

**Troubleshooting intencional:**
- **Subredes solapadas entre WAN y LAN** → el tráfico reenviado muere sin error claro y el log no muestra nada. *(Ocurrió de verdad en sesión 7.)*
- Olvidar el implicit deny con logging → tráfico anómalo sin forma de diagnosticarlo.
- Política mal ordenada → las reglas específicas deben preceder a las generales.
- **VLAN sin etiquetar en el bridge de Proxmox** → la VM arranca, tiene enlace, y no habla con nadie.
- **Etiqueta VLAN correcta pero puerto del FortiGate sin la subinterfaz** → tramas descartadas silenciosamente.
- Pérdida de acceso al FortiGate → recuperación por consola serie (única vía: el botón de reset no responde en este equipo).
- **Diafonía en el cable de consola** → intentos de login espurios generados por el propio eco del equipo.

**Entregable GitHub:** `infrastructure/fortigate/` con `policies/`, `address-objects.md`, `dhcp-reservations.md`, `vlan-design.md` y `backups/` (solo configuraciones sanitizadas). Documentación en `docs/01-*.md`. Runbooks de recuperación por consola y de depuración de VLANs.

**LinkedIn:** segmentación perimetral de una plataforma de IA multi-tenant, con separación de plano de gestión y plano de datos sobre un hipervisor de una sola NIC. Énfasis en least-privilege, troncal 802.1Q y en el incidente real de subredes solapadas.

---

### 8.2 Mini-Proyecto 1.2 — SSL-VPN + DDNS

**Duración:** 2 - 2,5 horas

**Objetivo:** acceso remoto al laboratorio sin exponer SSH. SSL-VPN en FortiGate. DDNS para sobrevivir cambios de IP pública del ISP. Validar desde datos móviles.

**Tecnologías:** FortiGate SSL-VPN (tunnel mode), FortiClient VPN, DuckDNS, certificado autofirmado.

**Problema empresarial:** ningún ingeniero de Goloca AI accede a infra desde casa por SSH directo. AI Act EU exige trazabilidad de accesos. Punto único de entrada autenticado.

**Pasos clave:**
1. Registro en DuckDNS, configuración DDNS en FortiGate vía CLI custom (`config system ddns`).
2. Verificación `nslookup <DDNS-HOSTNAME>` resuelve a 203.0.113.10.
3. Crear usuario local `juan.devops`, grupo `grp-vpn-admins`.
4. Configurar portal SSL-VPN tunnel mode, pool `10.10.99.10-50`.
5. Listen on WAN1 puerto **10443** (no 443 para evitar conflictos con futuro reverse proxy).
6. Política firewall 0 (regla VPN → internal).
7. Configurar DMZ Host en HGU Movistar apuntando a IP del FortiGate (192.168.1.x).
8. Instalar FortiClient, configurar perfil `goloca-prod`.
9. Test definitivo: portátil con datos móviles compartidos, conectar VPN, ping a 10.10.0.1.

**Troubleshooting intencional:**
- CGNAT no detectado → fallback a Cloudflare Tunnel.
- Port forwarding del HGU mal configurado → telnet fail desde fuera.
- DDNS no actualiza al cambiar IP → revisar event log.
- MTU del túnel demasiado alto → SSH cuelga en transferencias grandes.

**Entregable GitHub:** `infrastructure/fortigate/ssl-vpn/`, `runbooks/02-vpn-troubleshooting.md`.

**LinkedIn:** acceso remoto sin SSH directo. Discusión sobre VPN tradicional vs Zero Trust. Justificación regulatoria (AI Act).

---

### 8.3 Mini-Proyecto 1.3 — Proxmox VE Bare-Metal

**Duración:** 2,5 - 3 horas

**Objetivo:** PC servidor convertido en hipervisor Proxmox VE. Almacenamiento dividido (sistema NVMe1, VMs NVMe2/SSD, backups HDD). Red puenteada al FortiGate. Repos no-subscription.

**Tecnologías:** Proxmox VE 8.x, KVM/QEMU, LVM-Thin, Linux Bridge.

**Problema empresarial:** Goloca AI no opera sobre Windows. Necesidad de hipervisor reproducible operable por CLI. Proxmox = alternativa estándar a VMware tras adquisición Broadcom.

**Pasos clave:**
1. Backup de datos previos del Windows Server actual.
2. ISO Proxmox VE más reciente + USB booteable (Rufus en modo imagen DD).
3. BIOS: VT-x, VT-d/IOMMU habilitados, UEFI, Secure Boot off.
4. Instalación en NVMe 240 GB #1 con `ext4`. Hostname `pve-prod-01.goloca.lab`. IP `10.20.0.10/24`, gw `10.20.0.1`, DNS `10.10.0.1`.
5. Verificación acceso https://10.20.0.10:8006.
6. Cambio a repos `no-subscription`. `apt full-upgrade`.
7. **Storage adicional:**
   - NVMe2 240 GB → LVM-thin `local-lvm-nvme` (VMs críticas)
   - SSD 500 GB → LVM-thin `local-lvm-ssd` (VMs secundarias)
   - HDD 1 TB → directorio `/mnt/backup` montado, storage tipo `directory` llamado `backup` (Content: VZDump, ISO, Snippets)
8. Bridge `vmbr0` puenteado a la NIC física (verificar en `/etc/network/interfaces`).
9. Descarga imagen cloud Ubuntu 24.04 (`ubuntu-24.04-server-cloudimg-amd64.img`) a `/var/lib/vz/template/iso/`.
10. Hardening básico SSH del propio Proxmox (puerto 2222, sin password, sin root login).

**Troubleshooting intencional:**
- VT-d off → P6 imposible (GPU passthrough).
- Red mal configurada → recuperación solo por consola física.
- Repo enterprise activo → `apt update` falla 401.
- ISO en `local-lvm` → no arranca VMs (content type incorrecto).

**Entregable GitHub:** `infrastructure/proxmox/` con network/, ssh/, post-install/. `docs/03-*.md`.

**LinkedIn:** PC convertido en hipervisor profesional. Decisiones: KVM vs vSphere, LVM-thin vs ZFS, bare-metal vs nested.

---

### 8.4 Mini-Proyecto 1.4 — Template Ubuntu + Cloud-Init

**Duración:** 2 - 2,5 horas

**Objetivo:** plantilla golden Ubuntu 24.04 LTS con cloud-init. VMs nuevas listas en <90 segundos. Aprovisionar `bastion-prod-01` y `app-prod-01`.

**Tecnologías:** Proxmox templates, cloud-init NoCloud datasource, qemu-guest-agent, Netplan.

**Problema empresarial:** aprovisionamiento manual inaceptable. Base mental para IaC (Terraform en P5).

**Pasos clave:**
1. `apt install cloud-image-utils libguestfs-tools` en Proxmox.
2. `virt-customize -a ubuntu-...img --install qemu-guest-agent`.
3. Crear VM 9000 con `qm create`, importar disco a `local-lvm-nvme`, configurar cloudinit drive.
4. `qm template 9000`.
5. Crear snippet `user-data-default.yaml` con usuario `ubuntu`, claves SSH públicas, paquetes base, hardening SSH inicial.
6. Habilitar content "Snippets" en storage `local`.
7. Clonar a VMID 110 (`bastion-prod-01`), recursos 1 vCPU/2GB/20GB, IP `10.20.0.40/24` (provisional en SERVERS hasta migración futura).
8. Clonar a VMID 120 (`app-prod-01`), recursos 2 vCPU/4GB/40GB, IP `10.20.0.20/24`.
9. Validación: SSH sin password con clave, `cloud-init status: done`, `hostnamectl`, `ip a`.

**Troubleshooting intencional:**
- Sin qemu-guest-agent → no IP en UI, sin backups consistentes en caliente.
- Linked clone vs full → si borras el template, clones rotos.
- IP duplicada → ARP conflict.
- Snippet sin permisos correctos → cloud-init silenciosamente ignorado.

**Entregable GitHub:** `infrastructure/proxmox/templates/`, `infrastructure/proxmox/cloud-init/`, `infrastructure/proxmox/vms/`. Script `create-ubuntu-template.sh`.

**LinkedIn:** plantilla golden, aprovisionamiento <90s. Patrón mental antes de Terraform.

---

### 8.5 Mini-Proyecto 1.5 — Bastion Host + VS Code Remote SSH

**Duración:** 1,5 - 2 horas

**Objetivo:** flujo definitivo de trabajo. Workstation → bastión → app via VS Code Remote SSH con ProxyJump. Auth exclusiva por clave Ed25519.

**Tecnologías:** OpenSSH (cliente Windows + servidor Linux), VS Code Remote SSH, ProxyJump.

**Problema empresarial:** en Goloca AI, servidores de aplicación no accesibles directamente. Bastión = único host con SSH expuesto a la red de gestión. Patrón análogo a AWS SSM Session Manager.

**Pasos clave:**
1. Generar claves Ed25519 separadas para PC Windows y portátil.
2. Actualizar `user-data-default.yaml` con claves públicas reales.
3. Recrear VMs 110 y 120 (patrón destroy-and-recreate sobre modify-in-place).
4. Hardening SSH adicional en cada VM (`/etc/ssh/sshd_config.d/99-goloca.conf`):
   - Port 2222
   - PasswordAuthentication no
   - PermitRootLogin no
   - AllowUsers ubuntu
   - MaxAuthTries 3
   - ClientAliveInterval 300
5. SSH config en workstation con entradas `goloca-bastion`, `goloca-app01` (con ProxyJump), `goloca-pve`.
6. VS Code Remote SSH connect a `goloca-app01`.
7. Validación de aislamiento: SSH directo desde fuera de MGMT debe fallar.

**Troubleshooting intencional:**
- Permisos `~/.ssh` mal en Windows → permission denied.
- Cliente OpenSSH antiguo no soporta ProxyJump.
- Política firewall solo permite TCP 22 cuando movimos a 2222.
- VS Code server falla por falta de glibc/wget en host destino.

**Entregable GitHub:** `infrastructure/linux-baseline/sshd_config.d/99-goloca.conf`. `docs/05-*.md`. Runbook de onboarding de nuevo ingeniero.

**LinkedIn:** bastión + ProxyJump. Equivalente a SSM Session Manager. Trazabilidad de accesos.

---

### 8.6 Mini-Proyecto 1.6 — Linux Baseline + Docker

**Duración:** 2,5 - 3 horas

**Objetivo:** `bastion-prod-01` y `app-prod-01` en estado base auditable. Hardening, journald persistente, parcheo automático, UFW en capas, herramientas de operación, Docker Engine en `app-prod-01`.

**Tecnologías:** systemd/journalctl, UFW, unattended-upgrades, Docker Engine (desde repo oficial), herramientas (htop, iotop, iftop, tcpdump, jq, etc.).

**Problema empresarial:** VM por cloud-init no es operable en producción. Hardening + observabilidad + parcheo controlado = baseline auditable.

**Pasos clave bastión:**
1. `apt full-upgrade`, verificación timedatectl.
2. Journald persistente: `/etc/systemd/journald.conf.d/99-goloca.conf` con `Storage=persistent`, `SystemMaxUse=2G`, `MaxRetentionSec=30day`.
3. Unattended-upgrades para `${distro_id}:${distro_codename}-security`, `Automatic-Reboot "false"` (decisión documentada).
4. UFW: default deny in, allow SSH desde 10.10.0.0/24 y 10.10.99.0/24 a TCP 2222. **Crítico: permitir SSH antes de habilitar UFW**.
5. Herramientas: htop, iotop, iftop, tcpdump, dnsutils, net-tools, jq, fail2ban (sin configurar aún).
6. Snapshot Proxmox: `qm snapshot 110 baseline-clean`.

**Pasos clave app:**
7. Repite pasos 1-6 con UFW ajustado: allow SSH desde 10.20.0.40 (bastión) y 10.10.99.0/24 (VPN).
8. Instalación Docker Engine desde `download.docker.com` (no `apt install docker.io`).
9. `usermod -aG docker ubuntu`.
10. Validación: `docker run --rm hello-world`, `docker info`.
11. Snapshot: `qm snapshot 120 baseline-with-docker`.

**Troubleshooting intencional:**
- UFW sin allow SSH → pérdida de acceso. Recuperación dolorosa (consola Proxmox, single-user mode).
- Journald no persistente → logs evaporados tras reboot.
- Docker reescribe iptables → contenedores expuestos pese a UFW. Patrón a corregir en P2.
- `apt full-upgrade` instala nuevo kernel sin reboot → sigues vulnerable.
- `/var/lib/docker` se llena → contenedores fallan.

**Entregable GitHub:** `infrastructure/linux-baseline/` con baseline-setup.sh, ufw-rules-*.sh, journald-config/, unattended-upgrades/. `infrastructure/docker/install-docker-ubuntu.sh`. Runbooks de bootstrap y recovery.

**LinkedIn:** dos VMs endurecidas listas para contenedores. Firewall en capas (FortiGate + UFW), journald persistente, parcheo controlado, Docker oficial. Reflexión sobre grupo docker = root.

---

## 9. ESTRUCTURA DEL REPOSITORIO GITHUB

```
goloca-platform/
├── README.md                              # Visión general, estado, diagramas
├── ROADMAP.md                             # Este documento (versión sintetizada)
├── docs/
│   ├── 01-network-architecture.md
│   ├── 01-vlan-zoning-rationale.md
│   ├── 01-firewall-policy-matrix.md
│   ├── 02-remote-access-architecture.md
│   ├── 02-ddns-rationale.md
│   ├── 02-ssl-vpn-design.md
│   ├── 03-proxmox-architecture-decision.md
│   ├── 03-proxmox-install-runbook.md
│   ├── 03-storage-design.md
│   ├── 04-vm-provisioning-strategy.md
│   ├── 04-cloud-init-rationale.md
│   ├── 04-vm-inventory.md
│   ├── 05-bastion-host-pattern.md
│   ├── 05-ssh-key-management.md
│   ├── 05-developer-workflow.md
│   ├── 06-linux-baseline-spec.md
│   ├── 06-hardening-checklist.md
│   ├── 06-docker-installation.md
│   ├── 06-defense-in-depth-rationale.md
│   └── diagrams/
│       ├── physical-topology.txt
│       └── network-flow.md
├── infrastructure/
│   ├── fortigate/
│   │   ├── address-objects.md
│   │   ├── dhcp-reservations.md
│   │   ├── policies/
│   │   ├── ssl-vpn/
│   │   └── backups/                       # Configs sanitizadas
│   ├── proxmox/
│   │   ├── network/
│   │   ├── ssh/
│   │   ├── post-install/
│   │   ├── templates/
│   │   ├── cloud-init/
│   │   └── vms/
│   ├── linux-baseline/
│   │   ├── baseline-setup.sh
│   │   ├── ufw-rules-bastion.sh
│   │   ├── ufw-rules-app.sh
│   │   ├── sshd_config.d/
│   │   ├── journald-config/
│   │   └── unattended-upgrades/
│   └── docker/
│       └── install-docker-ubuntu.sh
└── runbooks/
    ├── 01-fortigate-recovery.md
    ├── 02-vpn-troubleshooting.md
    ├── 02-ddns-failover.md
    ├── 03-proxmox-recovery.md
    ├── 04-vm-provisioning.md
    ├── 05-onboarding-new-engineer.md
    ├── 06-host-bootstrap.md
    └── 06-host-recovery.md
```

---

## 10. DEUDAS TÉCNICAS RECONOCIDAS

Documentadas para mostrar madurez técnica. Cada una tiene un plan de resolución en proyectos futuros.

| ID | Deuda | Resolución prevista |
|---|---|---|
| DT-01 | Bastión en zona SERVERS en lugar de MGMT | P1.1 fase C: migración vía VLAN 10 sobre el troncal + software switch. Ya no requiere hardware (revisado sesión 7) |
| DT-02 | Switch DGS-1005P no gestionable | Sustitución por un switch gestionable (~25 €) cuando haga falta más de una zona física adicional. El troncal VLAN reduce mucho la urgencia: solo aplica a equipos físicos, no a VMs |
| DT-03 | Proxmox repos no-subscription | En producción real → suscripción de pago |
| DT-04 | Usuarios VPN locales (no LDAP/AD) | P6: integración con IdP (Authentik, Keycloak, o AWS IAM Identity Center) |
| DT-05 | Doble NAT (HGU + FortiGate) | Opcional: HGU en monopuesto si no se usa IPTV |
| DT-06 | Certificado VPN autofirmado | P6: Let's Encrypt via acme.sh para el FortiGate |
| DT-07 | Usuario en grupo docker = root | P3: migración a Kubernetes con RBAC. P6: estudio de rootless Docker. |
| DT-08 | Sin Fail2ban configurado en P1 | P6: Fail2ban en bastión + integración con FortiGate Address Groups dinámicos |
| DT-09 | Sin gestión centralizada de secretos | P6: HashiCorp Vault on-premise + AWS Secrets Manager en cloud |
| DT-10 | Sin backups automatizados de VMs | P4-P6: `vzdump` programado + sincronización a HDD + sync a S3 |

---

## 11. CRITERIOS DE FINALIZACIÓN DEL ROADMAP

Al cerrar los 6 proyectos, el aprendiz tendrá:

1. **Portfolio público en GitHub** con 6 proyectos documentados, diagramas, runbooks y troubleshooting real.
2. **Infraestructura funcional** que puede mostrar en vivo en una entrevista (laboratorio operativo).
3. **Stack defendible** alineado con startups IA tipo A.
4. **Narrativa diferenciadora:** modo soberano con LLM local + cloud híbrido + multi-tenancy real.
5. **Capacidad demostrable** de:
   - Diseñar segmentación de red real
   - Configurar Linux endurecido desde cero
   - Operar Kubernetes en producción
   - Construir pipelines CI/CD con escaneo de seguridad
   - Desplegar observabilidad de extremo a extremo
   - Provisionar AWS con Terraform
   - Implementar disaster recovery
   - Operar GPUs para serving de LLM

---

## 12. METODOLOGÍA DEL MENTOR

Reglas operativas que rigen todas las interacciones de aprendizaje:

1. **Cada decisión técnica se justifica con trade-offs**, no con "porque sí".
2. **Cada mini-proyecto incluye troubleshooting intencional**: el aprendiz rompe cosas a propósito para aprender a diagnosticarlas.
3. **Validación obligatoria** después de cada despliegue: DNS, conectividad, certificados, permisos, logs, métricas, healthchecks.
4. **Nada se introduce sin necesidad real**: cada nueva tecnología se justifica con un problema concreto que la actual no resuelve.
5. **Documentación profesional desde el día 1**: README, diagramas, runbooks, justificación de decisiones.
6. **Reutilización constante**: lo del proyecto N se usa en el proyecto N+1.
7. **Producción real, no laboratorios artificiales**: persistencia, backups, observabilidad, seguridad básica, recuperación.

### 12.1 MODO GUIADO PASO A PASO (REGLA OPERATIVA CRÍTICA)

Esta es la regla más importante para todas las interacciones de ejecución del roadmap. Sobrescribe cualquier instinto del mentor de "entregar el mini-proyecto completo de golpe".

**Reglas obligatorias del modo guiado:**

1. **Un paso = una acción concreta y verificable.** El mentor entrega un único paso a la vez, no una lista completa de comandos ni un bloque entero de configuración. El aprendiz ejecuta, valida, y solo entonces se entrega el siguiente paso.

2. **Nada se da por sentado.** El mentor NO asume que el aprendiz sabe:
   - Cómo encender o resetear un equipo
   - Dónde están los botones físicos
   - Qué cables conectar y a qué puertos exactos
   - Cómo acceder a la BIOS, a una consola serie, a una UI web por primera vez
   - Qué credenciales por defecto tiene un equipo
   - Cómo se ve una pantalla, un menú, una respuesta esperada
   - Cualquier conocimiento que no se haya verificado explícitamente en una sesión anterior

3. **Antes de cada paso, el mentor explica:**
   - **Qué se va a hacer** en una frase clara
   - **Por qué** ese paso es necesario (vinculación al objetivo de Goloca AI)
   - **Cómo hacerlo** con instrucciones físicas/lógicas detalladas (botones, cables, comandos)
   - **Qué resultado esperar** para que el aprendiz sepa si funcionó
   - **Qué hacer si no funciona** (al menos las 2-3 causas más comunes)

4. **Después de cada paso, el aprendiz reporta el resultado.**
   - Si el resultado coincide con el esperado → el mentor confirma y entrega el siguiente paso.
   - Si el resultado NO coincide → el mentor diagnostica antes de avanzar. Nunca se avanza sobre un paso que no ha funcionado.

5. **El aprendiz puede preguntar en cualquier momento.** Si dice "no entiendo X", "no encuentro Y", "qué cable es Z", el mentor responde con detalle antes de avanzar. Las preguntas no son interrupciones, son parte del flujo.

6. **El aprendiz tiene autonomía para pedir más contexto.** Si en algún momento dice "ahora explícame todo este bloque entero antes de seguir", el mentor cambia temporalmente a modo explicativo y luego vuelve al modo guiado.

7. **Granularidad de los pasos según el aprendiz.** Por defecto, el mentor entrega pasos pequeños (1 acción, 1-3 minutos de ejecución). Si el aprendiz indica "puedo hacer pasos más grandes", se ajusta. Si dice "más pequeño", también.

8. **Recordatorios y resúmenes intermitentes.** Cada cierto número de pasos (típicamente cada 5-7), el mentor hace un resumen breve del progreso dentro del mini-proyecto, indicando qué se ha hecho, qué queda, y dónde estamos en el roadmap general.

9. **Sin saltos al siguiente mini-proyecto sin verificación de cierre.** Al finalizar un mini-proyecto, el mentor presenta una checklist de verificación final con todos los criterios del entregable. Solo cuando todos están en verde, se inicia el siguiente.

10. **Estado persistente.** El mentor debe mantener consciencia de en qué paso exacto del roadmap está el aprendiz en cualquier momento de la conversación. Si el aprendiz vuelve después de días, el mentor debe poder recuperar el contexto preguntando "¿en qué paso te quedaste?".

**Ejemplo de paso bien formulado vs mal formulado:**

❌ **MAL (modo "tutorial"):**
> "Resetea el FortiGate, accede vía 192.168.1.99, cambia la contraseña, configura el hostname, NTP y zona horaria."

✅ **BIEN (modo guiado):**
> **Paso 1.1.1 — Reset físico del FortiGate**
>
> **Qué:** vamos a borrar cualquier configuración previa del FortiGate y dejarlo en estado de fábrica.
>
> **Por qué:** no sabes qué configuración tiene ahora ni cuál era la contraseña anterior. Empezar limpio elimina sorpresas.
>
> **Cómo:**
> 1. Asegúrate de que el FortiGate **NO está conectado a la corriente todavía**. Si está enchufado, desconéctalo.
> 2. Localiza el botón de **RESET** en el equipo. Está en el panel trasero, es un agujerito pequeño que requiere un clip o un palillo para presionarlo. NO es ninguno de los botones grandes de la parte frontal.
> 3. ¿Lo has encontrado? Confírmame antes de seguir.
>
> **Resultado esperado:** simplemente confirmas que lo ves. Aún no hacemos nada.
>
> **Si no lo encuentras:** dime qué modelo exacto pone en la pegatina del equipo y te paso una foto/referencia.

11. **Foto / captura de pantalla bajo petición.** Si el aprendiz pide aclaración visual ("¿este es el botón?", "¿la pantalla debe verse así?"), el mentor puede sugerir buscar imágenes oficiales o describir con más detalle. El aprendiz también puede pegar capturas de su propia pantalla para verificación.

12. **No mezclar fases.** Si el paso actual es físico (cablear, pulsar botón), no se intercala con configuración lógica (comandos, UI). Cada paso es una sola naturaleza de acción.

---

## 13. PRÓXIMOS PASOS INMEDIATOS

### Estado de decisiones (todas cerradas)

| Decisión | Valor |
|---|---|
| Switch | Opción B — segmentación por puertos físicos del FortiGate |
| Hipervisor | Proxmox VE 8.x bare-metal en PC servidor |
| CGNAT | No hay (IP pública 203.0.113.10 directa) |
| ISP | Movistar HGU 6+ años → DMZ Host hacia FortiGate |
| Empresa ficticia | Goloca AI (Plataforma de Agentes IA Empresariales) |
| Bastión MGMT | Provisional en SERVERS, migración futura con adaptador USB-Ethernet |
| Almacenamiento | LVM-thin sobre discos individuales (NVMe1 sistema, NVMe2 críticas, SSD secundarias, HDD backups) |
| Metodología de ejecución | **Modo guiado paso a paso** (ver sección 12.1) |

### Siguiente acción

Arrancar **Mini-Proyecto 1.1** en modo guiado paso a paso. El mentor entrega el primer paso (reset físico del FortiGate, que actualmente está apagado y sin configurar) y espera confirmación antes de avanzar.

### Estado de progreso del aprendiz

> Esta sección se actualiza dinámicamente conforme el aprendiz avanza. Sirve para que el mentor (en cualquier sesión futura, incluso días después) pueda retomar el contexto exacto.

- **Proyecto actual:** P1 — Infraestructura Base (~72%)
- **Mini-proyecto actual:** 1.1 — Segmentación de Red con FortiGate 30E (~40%)
- **Paso actual:** fases A y B completadas (equipo recuperado, red migrada a `10.20.0.0/24`). Siguiente: fase C — partir el switch interno y montar el troncal 802.1Q.
- **Mini-proyectos cerrados:** 1.3, 1.4, 1.5, 1.6
- **Bloqueos conocidos:** ninguno
- **Última sesión:** 7 (28 agosto 2026)
- **Detalle operacional:** ver `PROGRESS-LOG.md`

---

## 14. CHANGELOG

| Versión | Fecha | Cambios |
|---|---|---|
| 1.0 | 21 mayo 2026 | Versión inicial. Decisiones cerradas tras debate de empresa, hardware y networking. |
| 1.2 | 21 mayo 2026 | Renombrado empresa ficticia de GOLOCA AI a Goloca AI. Actualizado naming completo: repo, dominio, hostnames, DDNS, configs. |
| 1.3 | 28 agosto 2026 | **Revisión arquitectónica tras la sesión 7.** Detectado que Proxmox tiene una sola NIC, lo que hacía imposible alojar el NGINX de la DMZ previsto en P2. **Sección 4.1 reescrita como modelo híbrido**: puertos físicos para el plano de gestión, **troncal 802.1Q** para el plano de datos hacia el hipervisor (el veto original a las VLANs se justificaba por el switch no gestionable, que no interviene en el enlace punto a punto Proxmox↔FortiGate). **Sección 4.5 reescrita**: la NIC USB se reasigna a interfaz de gestión dedicada del hipervisor, separando plano de gestión y de datos; cierra DT-01 sin hardware extra. **Secciones 5.1, 5.2 y 6 rehechas** con el mapa de zonas real (MGMT en grupo de puertos, SERVERS en VLAN 20, DMZ en VLAN 30, WIFI no implementada por D-13) y nuevo diagrama de topología más flujo de tráfico web. Corregido conflicto de IP entre `dev01` y `db-prod-01`. **Sección 8.1 reescrita** en cuatro fases con el estado real, duración revisada a 5-6 h y troubleshooting ampliado con los fallos encontrados en la práctica. Añadido 802.1Q al stack técnico. Datos sensibles (IP pública, DDNS, número de serie) sustituidos por marcadores al hacer público el repositorio. |
| 1.1 | 21 mayo 2026 | Añadida sección 12.1 (**Modo Guiado Paso a Paso**) como regla operativa crítica del mentor. Actualizada sección 13 con tracking de progreso dinámico. El roadmap ahora se ejecuta paso a paso con verificación tras cada acción, sin asumir conocimiento previo sobre acciones físicas (encendido, reset, cableado) ni interfaces específicas. |
