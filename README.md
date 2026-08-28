# Goloca AI — DevOps Infrastructure Platform

**Laboratorio formativo de 6 meses. Infraestructura real, no ejercicios académicos.**

## Descripción

Construcción desde cero de la plataforma de infraestructura para **Goloca AI**, una startup ficticia de agentes IA empresariales. El objetivo es operar una plataforma multi-tenant, escalable y segura bajo los principios de:

- **Networking real:** segmentación perimetral, firewall, VPN de acceso remoto
- **Virtualización:** Proxmox VE bare-metal, templates cloud-init
- **Contenedores:** Docker Compose, orquestación con K3s
- **Observabilidad:** Prometheus, Grafana, Loki
- **CI/CD:** GitHub Actions, escaneo de vulnerabilidades
- **Cloud híbrido:** AWS + Terraform + Ansible
- **Seguridad:** hardening Linux, Fail2ban, gestión de secretos
- **IA local:** LLM on-premise (Ollama + Llama 3.1) en GPU

## Roadmap — 6 Proyectos

| Proyecto | Mes | Temas Clave | Estado |
|---|---|---|---|
| **P1** | Mes 1 | Networking, FortiGate, Proxmox, VMs Ubuntu | 🔄 En progreso |
| **P2** | Mes 2 | Docker, Docker Compose, NGINX, PostgreSQL, Redis | ⏳ Próximo |
| **P3** | Mes 3 | K3s, Kubernetes, Helm, pgvector | ⏳ Futuro |
| **P4** | Mes 4 | GitHub Actions, Trivy, Prometheus, Grafana, Loki | ⏳ Futuro |
| **P5** | Mes 5 | AWS, VPC, Terraform, Ansible, Site-to-Site VPN | ⏳ Futuro |
| **P6** | Mes 6 | Hardening CIS, Fail2ban, Vault, DR, Ollama | ⏳ Futuro |

## Estructura del Repositorio

goloca-platform/
├── README.md                          # Este archivo
├── ROADMAP.md                         # Guía técnica completa (6 meses)
├── .gitignore                         # Archivos ignorados por Git
├── docs/                              # Documentación técnica
│   ├── 01-network-architecture.md
│   ├── 02-remote-access-architecture.md
│   ├── 03-proxmox-setup.md
│   ├── 04-vm-provisioning.md
│   ├── 05-bastion-host-pattern.md
│   ├── 06-linux-baseline.md
│   └── diagrams/                      # Diagramas ASCII/mermaid
├── infrastructure/
│   ├── fortigate/                     # Configuraciones FortiGate 30E
│   ├── proxmox/                       # Configuraciones Proxmox VE
│   ├── linux-baseline/                # Scripts de hardening
│   └── docker/                        # Dockerfiles, docker-compose.yml
├── runbooks/                          # Procedimientos operacionales
│   ├── 01-fortigate-recovery.md
│   ├── 02-vpn-troubleshooting.md
│   ├── 03-proxmox-recovery.md
│   └── ...
└── scripts/                           # Automatización (bash, Python)
└── setup-*.sh

## Hardware

| Componente | Especificación |
|---|---|
| **Host Proxmox** | Intel i5 10ª gen, 32 GB RAM, RTX 4060, 2x NVMe 240GB + SSD 500GB + HDD 1TB |
| **Firewall** | FortiGate 30E (FortiOS 7.4+) |
| **Switch** | D-Link DGS-1005P (L2, no gestionable) |
| **Workstations** | PC Windows (dev), Portátil Windows (admin) |

## Stack Técnico

**Fase 1 (Actual):**
- FortiGate 30E + SSL-VPN + DDNS
- Proxmox VE 8.x + LVM-thin
- Ubuntu Server 24.04 LTS
- OpenSSH + VS Code Remote SSH
- Docker Engine

**Fase 2-3:**
- Docker Compose, NGINX, PostgreSQL 16, Redis
- K3s, Kubernetes, Helm
- Traefik Ingress, MetalLB

**Fase 4-6:**
- GitHub Actions, Trivy, Prometheus, Grafana, Loki
- AWS (VPC, EC2, S3, RDS, Site-to-Site VPN)
- Terraform, Ansible
- HashiCorp Vault, Ollama + Llama 3.1

## Cómo Empezar

**Documentación:**
1. Lee `ROADMAP.md` para entender la visión completa.
2. Explora `docs/` para documentación técnica de cada proyecto.
3. Consulta `runbooks/` para procedimientos operacionales.

**Replicar el Laboratorio:**
- El proyecto está diseñado para ser reproducible.
- Consulta `infrastructure/` para configuraciones sanitizadas.
- Scripts de bootstrap en `scripts/`.

**Estado Actual (Proyecto 1):**
- ✅ FortiGate configurado con segmentación de red
- ✅ SSL-VPN + DDNS operativo
- ✅ Proxmox VE bare-metal instalado
- ✅ VMs Ubuntu endurecidas y listas para contenedores
- 🔄 Mini-proyectos 1.1-1.6 en ejecución paso a paso

## Objetivo Final

Portfolio profesional demostrando capacidad de:
- Diseñar redes corporativas segmentadas
- Operar infraestructura Linux en producción
- Desplegar y orquestar contenedores
- Automatizar con IaC (Terraform, Ansible)
- Implementar CI/CD real con escaneo de seguridad
- Depurar y solucionar problemas en sistemas distribuidos
- Manejar GPU para serving de LLMs

**Target:** DevOps Junior / Cloud Engineer Junior / Platform Engineer Junior en startups IA europeas.

## Nota sobre datos sensibles

Este repositorio documenta infraestructura real en funcionamiento, por lo que la
información que permitiría localizarla o acceder a ella se sustituye
deliberadamente por marcadores:

| Marcador | Sustituye a |
|---|---|
| `203.0.113.10` | La IP pública real (rango RFC 5737, reservado para documentación) |
| `<DDNS-HOSTNAME>` | El nombre DDNS real del laboratorio |
| `FGT30E<SERIAL-REDACTED>` | El número de serie del FortiGate |

El serial se redacta porque la cuenta de recuperación `maintainer` de FortiOS
deriva su contraseña de él.

Las copias de configuración de red se publican **sanitizadas**: los hashes de
credenciales (`set password ENC ...`) y las claves privadas de certificados nunca
se versionan. Ver `infrastructure/fortigate/backups/README.md`.

El direccionamiento privado (`10.x`, `192.168.x`) sí se documenta íntegro: es
RFC 1918, no es accesible desde Internet, y es precisamente el contenido técnico
que este portfolio pretende mostrar.

## Contacto

- **Autor:** Fernando Morales (@femogo)
- **Proyecto:** Goloca AI Infrastructure Platform
- **Duración:** Enero — Junio 2026 (6 meses)
- **Estado:** En progreso

---

**Última actualización:** 21 de mayo de 2026