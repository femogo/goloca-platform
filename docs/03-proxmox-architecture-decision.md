# P1.3 — Decisión de Arquitectura: Proxmox VE como Hipervisor

> **Proyecto:** P1 · Infraestructura Base
> **Mini-proyecto:** 1.3 — Proxmox VE bare-metal
> **Host:** `pve-prod-01` (Proxmox VE 9.2)
> **Estado:** Cerrado (sesión 4)
> **Documentos relacionados:** [`03-storage-design.md`](03-storage-design.md)

---

## 1. Contexto

El PC servidor del laboratorio (Intel i5 10ª gen, 32 GB RAM, RTX 4060) venía con Windows Server. Goloca AI no opera sobre Windows: su stack es Linux de extremo a extremo (contenedores, K3s, observabilidad, LLM local). La primera decisión de infraestructura es qué capa de virtualización pone debajo de todo. Esa elección condiciona los seis meses de roadmap, porque todo lo demás —VMs, clúster, GPU passthrough en P6— se construye encima.

La pregunta no es "¿qué hipervisor sé usar?" sino "¿qué hipervisor es defendible en una entrevista para un rol DevOps junior en una startup de IA europea en 2026?". Son preguntas distintas y la segunda manda.

## 2. La disyuntiva

Tres candidatos reales para virtualización bare-metal en este hardware:

| Opción | Naturaleza | Encaje con el objetivo |
|---|---|---|
| **Hyper-V** | Hipervisor de Microsoft (rol de Windows Server) | El candidato ya lo domina (4 años de experiencia previa). Pero atado al ecosistema Windows, poco presente en startups Linux-native |
| **VMware vSphere/ESXi** | Estándar histórico de la industria | Tras la adquisición por Broadcom (2023), cambios de licenciamiento agresivos han provocado una fuga masiva hacia alternativas. Cada vez menos defendible como apuesta de futuro |
| **Proxmox VE** | Hipervisor open-source basado en KVM/QEMU + LXC, gestión web + CLI | Se ha convertido en la alternativa de facto a VMware en pymes europeas. KVM nativo. Ecosistema Linux completo |

## 3. Decisión: Proxmox VE bare-metal

Se elige Proxmox VE, instalado directamente sobre el hardware (bare-metal), eliminando Windows Server.

### 3.1 Por qué Proxmox y no Hyper-V

El candidato ya sabe Hyper-V. Elegir lo que ya dominas es cómodo y, aquí, equivocado. El objetivo del roadmap no es demostrar lo que ya sabe (sysadmin Windows) sino construir el perfil que aún no tiene (DevOps Linux-native). Hyper-V refuerza el perfil de salida, no el de llegada.

Además, hay una razón técnica dura: **P6 requiere GPU passthrough de la RTX 4060 a una VM** para servir un LLM local con Ollama. El passthrough de GPU (VFIO/IOMMU) es territorio nativo de KVM/Linux. Hacerlo sobre Hyper-V es posible pero tortuoso y mal documentado. Proxmox lo soporta de forma estándar. La narrativa "modo soberano con LLM local" —el diferenciador clave del portfolio— depende de esta capacidad.

### 3.2 Por qué Proxmox y no VMware

VMware sigue siendo técnicamente excelente, pero apostar el aprendizaje por él en 2026 es apostar contra la corriente del mercado. El cambio de licenciamiento de Broadcom ha empujado a un éxodo documentado de pymes hacia Proxmox. Para un perfil que busca empleabilidad en startups europeas —entornos sensibles al coste, que es justo donde VMware se volvió caro—, Proxmox es lo que se van a encontrar en producción. Aprender la herramienta que el mercado está adoptando, no la que está abandonando.

### 3.3 Por qué bare-metal y no nested/Type-2

Se consideró virtualización anidada (Proxmox dentro de VMware Workstation/VirtualBox sobre Windows) para conservar Windows como SO base. Se descartó:

- **Rendimiento:** cada capa de virtualización añade overhead. Anidar penaliza I/O y CPU, justo en un host con RAM como cuello de botella.
- **GPU passthrough:** prácticamente inviable en configuración anidada. Mataría P6.
- **Realismo:** ningún hipervisor de producción corre anidado sobre un SO de escritorio. El laboratorio debe parecerse a producción.

El coste de bare-metal es perder Windows en esa máquina. Aceptable: el rol de workstation Windows lo cubre el otro PC (dev01), según el inventario de hardware.

## 4. Trade-offs asumidos

| Decisión | Se gana | Se renuncia a |
|---|---|---|
| Proxmox sobre Hyper-V | Stack Linux-native, GPU passthrough viable, perfil de llegada | Comodidad de usar lo ya conocido |
| Proxmox sobre VMware | Alineación con el mercado actual, sin coste de licencia | Madurez y soporte enterprise de vSphere |
| Bare-metal sobre nested | Rendimiento, passthrough, realismo | Windows en el host servidor |
| Repos `no-subscription` | Sin coste de licencia para el lab | Builds enterprise estables + soporte oficial (DT-03) |

La decisión de repos `no-subscription` (DT-03) merece mención: en el lab es correcto. En producción real, Proxmox se opera con suscripción de pago, que da acceso al repo enterprise (builds más testeados) y soporte. Documentado como deuda consciente, no como atajo ignorante.

## 5. Implementación (resumen)

El procedimiento detallado vive en el runbook de instalación. Resumen de lo que define la arquitectura:

- **Instalación** sobre `/dev/nvme0n1` (238 GB) con `ext4`, hostname `pve-prod-01.goloca.lab`.
- **Red:** bridge `vmbr0` puenteado a la NIC física. Inicialmente previsto en `10.20.0.10/24`, temporalmente en `192.168.1.101/24` hasta que el FortiGate esté operativo (desviación D-02). Migración pendiente (DT-12).
- **BIOS:** VT-x, VT-d/IOMMU habilitados (VT-d es condición necesaria para el GPU passthrough de P6 — sin él, P6 es imposible).
- **Almacenamiento:** ver [`03-storage-design.md`](03-storage-design.md).
- **Hardening SSH** del propio host: puerto no estándar, sin login de root, autenticación por clave.

## 6. Validación

- Acceso web `https://192.168.1.101:8006` operativo.
- `pveversion` confirma Proxmox VE 9.2.
- `lscpu` / `dmesg | grep -i iommu` confirman virtualización por hardware e IOMMU activos (verificación temprana de que P6 será viable).
- Bridge `vmbr0` levantado y puenteado, conectividad de salida verificada.

## 7. Deuda técnica derivada

| ID | Deuda | Resolución |
|---|---|---|
| DT-03 | Repos no-subscription | Suscripción de pago en prod real |
| DT-12 | IP en 192.168.1.101 temporal | Migrar a 10.20.0.10 tras FortiGate |
| DT-22 | BIOS se detiene en boot esperando Enter | Acceso físico al BIOS para desactivar "wait on error" |
