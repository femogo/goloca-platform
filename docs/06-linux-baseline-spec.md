# P1.6 — Especificación del Baseline Linux

> **Proyecto:** P1 · Infraestructura Base
> **Mini-proyecto:** 1.6 — Linux baseline + Docker
> **Hosts:** `bastion-prod-01` (110), `app-prod-01` (120) · Ubuntu 24.04 LTS
> **Estado:** Cerrado (sesión 4)
> **Documentos relacionados:** [`06-hardening-checklist.md`](06-hardening-checklist.md), [`06-defense-in-depth-rationale.md`](06-defense-in-depth-rationale.md), [`06-docker-installation.md`](06-docker-installation.md)

---

## 1. Contexto

Una VM recién clonada de una imagen cloud-init no es un servidor de producción. Es un punto de partida: arranca, tiene SSH por clave, y poco más. Falta todo lo que la hace operable, auditable y recuperable: logs que sobrevivan a un reinicio, parcheo de seguridad controlado, firewall en el host, herramientas de diagnóstico, y un estado conocido al que volver.

El baseline es el proceso de llevar `bastion-prod-01` y `app-prod-01` desde "VM que arranca" hasta "host de producción auditable". En Goloca AI, ninguna VM entra en servicio sin pasar por este baseline. Es la diferencia entre un laboratorio y una plataforma.

## 2. Componentes del baseline

El baseline se compone de seis piezas, aplicadas en orden. El orden importa: el firewall va después de asegurar el acceso SSH, no antes (ver sección 4).

| # | Pieza | bastion | app01 | Propósito |
|---|---|---|---|---|
| 1 | `apt full-upgrade` | ✅ | ✅ | Partir de un estado parcheado |
| 2 | journald persistente | ✅ | ✅ | Logs que sobreviven a reboots |
| 3 | unattended-upgrades | ✅ | ✅ | Parcheo de seguridad automático |
| 4 | UFW | ✅ | ✅ | Firewall en el host (capa 2 de defensa) |
| 5 | Herramientas de operación | ✅ | ✅ | Diagnóstico in situ |
| 6 | Docker Engine | — | ✅ | Runtime de contenedores (solo donde corre carga) |

La asimetría es deliberada: el bastión no corre cargas de aplicación, solo es punto de entrada SSH y futuro controlador Ansible. No lleva Docker. Meter Docker en el bastión ampliaría su superficie de ataque sin razón. Cada host lleva solo lo que su rol exige.

## 3. Detalle por pieza

### 3.1 journald persistente

Por defecto, Ubuntu 24.04 puede guardar los logs de journald solo en memoria (`Storage=auto` sin directorio `/var/log/journal`). Eso significa que **al reiniciar, los logs desaparecen**. Para un servidor de producción es inaceptable: cuando algo falla y reinicias, pierdes justo la evidencia que necesitas para el post-mortem.

Configuración aplicada vía drop-in `/etc/systemd/journald.conf.d/99-goloca.conf`:
- `Storage=persistent` — fuerza escritura a disco.
- `SystemMaxUse=2G` — techo de uso para no llenar el disco.
- `MaxRetentionSec=30day` — retención de 30 días.

Detalle real del proceso: se descubrió que en estas VMs journald ya persistía "por accidente" (`Storage=auto` + el directorio `/var/log/journal` existía). Funcionaba, pero por casualidad, no por diseño. Se hizo explícito con el drop-in. Un comportamiento correcto por accidente es una bomba de relojería: el día que alguien borra `/var/log/journal` o reconstruye la VM, deja de funcionar sin que nadie sepa por qué. La configuración explícita elimina esa ambigüedad.

Tras `usermod -aG adm ubuntu`, el usuario puede leer el journal completo. Esto resultó útil de inmediato: 10 boots de historial visibles permitieron el forense del incidente SSH (sección 5).

### 3.2 unattended-upgrades

Parcheo automático, pero **solo de seguridad**. La política por defecto de Ubuntu incluía también el repo general `noble` (actualizaciones funcionales, no solo de seguridad). Eso se comentó vía `sed`, dejando únicamente `${distro_id}:${distro_codename}-security`.

Razón del trade-off: las actualizaciones funcionales automáticas pueden romper cosas sin aviso (un cambio de comportamiento en un paquete, una dependencia que cambia). Las de seguridad son críticas y de bajo riesgo de ruptura. Se automatiza lo crítico y de bajo riesgo; lo funcional se aplica manualmente con control.

`Automatic-Reboot "false"`: el sistema parchea pero **no reinicia solo**. Un reinicio no supervisado de un servidor de producción es un riesgo (puede pillar una carga a medias, o no levantar). El reinicio es decisión humana. Validado con `--dry-run` que `Allowed origins` solo lista `-security`.

Consecuencia documentada (DT, troubleshooting intencional del roadmap): `apt full-upgrade` puede instalar un kernel nuevo que no entra en vigor hasta el reboot. Hasta entonces, sigues corriendo el kernel viejo y potencialmente vulnerable. El parcheo sin reboot da una falsa sensación de seguridad si no se entiende esto.

### 3.3 UFW (ver sección 4 para el procedimiento crítico)

Firewall a nivel de host, segunda capa tras el FortiGate. Política `default deny incoming`. Reglas:
- **bastión:** SSH 2222 desde la red de gestión.
- **app01:** SSH 2222 **solo desde el bastión** (no desde toda la red).

La regla de app01 es estricta a propósito: fiel al patrón bastión, app01 no debe ser accesible directamente, solo a través del bastión. Como el ProxyJump ya hace que el origen real de las conexiones sea el bastión, restringir a la IP del bastión no rompe nada y cierra la puerta a accesos directos. Estado actual con orígenes transitorios `192.168.1.x` (DT-21), a endurecer a `10.x` tras el FortiGate.

### 3.4 Herramientas de operación

`htop`, `iotop`, `iftop`, `tcpdump`, `dnsutils`, `net-tools`, `jq`, `lsof`, `fail2ban` (instalado, sin configurar aún — DT-08).

No es relleno. Cada una cubre un eje de diagnóstico que vas a necesitar cuando algo falle a las 3 de la madrugada: CPU/memoria (htop), I/O de disco (iotop), tráfico de red por interfaz (iftop), captura de paquetes (tcpdump), resolución DNS (dnsutils), conexiones y puertos (lsof/net-tools), parseo de JSON de APIs (jq). Un servidor sin herramientas de diagnóstico es un servidor que solo puedes apagar y rezar cuando falla.

### 3.5 Docker Engine

Solo en app01. Detalle en [`06-docker-installation.md`](06-docker-installation.md).

## 4. Procedimiento crítico: aplicar UFW sin perder el acceso

Este es el paso donde más gente se deja fuera de su propio servidor. Merece su sección.

El riesgo: estás conectado por SSH. Activas un firewall con política `default deny incoming`. Si no has permitido SSH **antes** de activar, la regla deny corta tu propia sesión y todas las futuras. Te quedas fuera de un servidor remoto, sin más recurso que la consola física (o, en VM, la consola de Proxmox).

Orden correcto, no negociable:
1. Añadir la regla `allow` para SSH primero.
2. Verificar que la regla está.
3. Solo entonces, `ufw enable`.

Red de seguridad adicional aplicada (por ser un cambio de firewall en un host remoto): se lanzó en segundo plano `nohup sleep 300 && ufw --force disable`. Esto programa una desactivación automática del firewall a los 5 minutos. Si la nueva configuración deja fuera, en 5 minutos el firewall se desactiva solo y recuperas acceso. Si todo va bien, se cancela el `sleep` antes de que dispare.

La verificación se hizo con una **conexión nueva** (no la sesión SSH ya abierta). Una sesión abierta sigue funcionando aunque la regla esté mal, porque las conexiones establecidas no se reevalúan. Solo una conexión nueva prueba de verdad que la regla permite entrar. Probar con la sesión vieja es engañarse.

## 5. Incidente: pérdida de SSH en ambas VMs tras reboot

El aprendizaje operacional más caro de P1.6. Documentado en detalle porque es exactamente el tipo de fallo que separa a quien entiende systemd de quien copia comandos.

### 5.1 Síntoma

Al arrancar las VMs desde la UI de Proxmox (estaban apagadas), SSH rechazaba conexión en los puertos 22 y 2222, en **ambas** VMs. Las VMs estaban vivas: respondían a ping, arrancaban limpiamente a `multi-user.target`. Pero `ssh.service` no escuchaba.

### 5.2 Causa raíz

En P1.5 se resolvió un problema previo (DT-17): el `ssh.socket` de Ubuntu 24.04 ignora el `Port` definido en `sshd_config`. La solución fue `disable + mask ssh.socket` + `restart ssh.service`. Funcionó. Pero faltó un paso: **nunca se hizo `enable ssh.service`**.

`restart` arranca el servicio en memoria, aquí y ahora. `enable` crea el symlink en `multi-user.target.wants/` que hace que el servicio arranque **en el próximo boot**. Son ejes independientes: estado actual vs comportamiento en arranque. El servicio corría (restart), pero no estaba marcado para arrancar solo (sin enable). Funcionó hasta el primer reboot —que ocurrió en S4— y entonces no levantó.

DT-17 estaba mal cerrado. Parecía resuelto porque funcionaba, pero la prueba real de un cambio de arranque es un reboot, y ese reboot no se había hecho en P1.5.

### 5.3 Diagnóstico

Complicación: cloud-init solo configuró clave SSH, **sin contraseña de consola**. Sin SSH y sin password, la consola de Proxmox pedía login que no se podía dar. GRUB no era capturable por timing del Esc. Se descartó resetear password vía `cipassword` de cloud-init, porque cloud-init no reaplica la config en reboots posteriores (solo en el primer boot).

### 5.4 Resolución: editar el disco offline con guestfish

La solución determinista, sin depender de password ni de timing: editar el sistema de archivos de la VM **apagada**, desde el host Proxmox, con `guestfish` (libguestfs, ya instalado de P1.4).

Procedimiento (detalle completo en el runbook correspondiente):
1. VM apagada.
2. `guestfish` monta el disco de la VM, `/dev/sda1`.
3. Confirmar la ausencia del symlink en `multi-user.target.wants/`.
4. Crear el symlink: `ln -s /usr/lib/systemd/system/ssh.service → multi-user.target.wants/ssh.service`. Esto es exactamente lo que `systemctl enable` hace, pero hecho a mano sobre el disco offline.
5. Aplicado en **ambas** VMs (app01 también había reiniciado y caído en el mismo fallo).

### 5.5 Verificación y lección

`systemctl is-enabled ssh.service` → `enabled`, `is-active` → `active` en ambas. Probado que persiste tras reboot (esta vez sí se hizo el reboot de verificación).

**Lección:** `restart` ≠ `enable`. Son ejes ortogonales. Un servicio puede estar activo y no habilitado (corre ahora, no arranca solo) o habilitado y no activo (arrancará, no corre ahora). Verificar un cambio de arranque sin reiniciar es no verificarlo. DT-17 se reclasificó como resuelto de verdad solo tras el reboot de prueba.

## 6. Convergencia y reproducibilidad: el script de baseline

### 6.1 El problema que resuelve

Las dos VMs llegaron al baseline por caminos distintos: el bastión vía cloud-init snippet (cicustom), app01 configurado por UI (D-09). Eso generó divergencia (DT-20): dos hosts que deberían ser idénticos en su baseline, configurados a mano de dos formas distintas. La divergencia es el origen del "en mi servidor funciona": configuraciones que difieren sin que nadie lo documente.

### 6.2 La solución: un único script parametrizado

`baseline-setup.sh` captura las seis piezas en un solo artefacto idempotente, parametrizado por rol:

```bash
sudo ./baseline-setup.sh <bastion|app> <origen_ssh_ufw>
```

Decisiones de diseño:
- **Un script, no dos copias** (opción A). Dos copias reintroducen DT-20: divergen en cuanto alguien toca una y no la otra. Un script con un parámetro de rol mantiene una sola fuente de verdad.
- **Idempotente:** `set -euo pipefail`, validación de argumentos, y comprobaciones antes de cada cambio (`grep -q ||`, `[ -f ]`, reglas UFW que no se duplican). Ejecutarlo dos veces no rompe nada ni duplica config.
- **Validado** con `bash -n` y `shellcheck` (2 falsos positivos esperados: SC2016 por las comillas simples deliberadas del `sed`, SC1091 por el `source` de `/etc/os-release`).

### 6.3 Por qué no se ejecutó sobre las VMs actuales

El script **no** se corrió sobre bastion/app01: ya tenían el baseline aplicado a mano. Ejecutarlo ahí no aportaría (idempotente, no cambiaría nada) y arriesgaría tocar un estado que funciona. El valor real del script es la **reproducibilidad sobre VMs limpias**: se probará en P2 (db-prod-01) y P3 (nodos K3s). Ahí demostrará que el baseline es reproducible de verdad, no solo documentado.

Este script es el puente mental hacia la gestión de configuración (Ansible, P5). Un script idempotente parametrizado por rol traduce casi directamente a un playbook con roles. No es trabajo tirado: es el primer escalón de la automatización de configuración.

## 7. Estado final (snapshots)

| VM | Snapshot | Contenido |
|---|---|---|
| 110 bastion | `baseline-clean` | 5 piezas (sin Docker), SSH 2222 enabled |
| 120 app01 | `baseline-with-docker` | Baseline completo + Docker 29.5 + Compose v2 |

Cada VM tiene un punto de retorno conocido. Si algo se rompe en P2, se vuelve al snapshot en segundos.

## 8. Deuda técnica derivada

| ID | Deuda | Estado |
|---|---|---|
| DT-08 | Fail2ban instalado, sin configurar | Pendiente P6 |
| DT-21 | Orígenes UFW transitorios `192.168.1.x` | Endurecer a `10.x` tras FortiGate |
| DT-07 | Usuario en grupo docker = root efectivo | P3 RBAC, P6 rootless |
