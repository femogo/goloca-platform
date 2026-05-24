# P1.6 — Checklist de Hardening

> **Proyecto:** P1 · Infraestructura Base
> **Mini-proyecto:** 1.6 — Linux baseline + Docker
> **Hosts:** `bastion-prod-01` (110), `app-prod-01` (120) · Ubuntu 24.04 LTS
> **Estado:** Cerrado (sesión 4)
> **Documentos relacionados:** [`06-linux-baseline-spec.md`](06-linux-baseline-spec.md), [`06-defense-in-depth-rationale.md`](06-defense-in-depth-rationale.md)

---

## 1. Propósito

Checklist operativa del estado de endurecimiento de las VMs de P1. Cada ítem es verificable con un comando. El "por qué" de cada decisión está en [`06-defense-in-depth-rationale.md`](06-defense-in-depth-rationale.md); este documento es la referencia de **qué comprobar** para confirmar que un host cumple el baseline de seguridad.

## 2. SSH

| Ítem | Estado esperado | Verificación |
|---|---|---|
| Puerto no estándar | 2222 | `ss -tlnp \| grep 2222` |
| Autenticación por password | Deshabilitada | `sshd -T \| grep passwordauthentication` → `no` |
| Login de root | Deshabilitado | `sshd -T \| grep permitrootlogin` → `no` |
| Usuarios permitidos | Solo `ubuntu` | `sshd -T \| grep allowusers` |
| Intentos máximos de auth | 3 | `sshd -T \| grep maxauthtries` |
| Timeout de sesión inactiva | 300s | `sshd -T \| grep clientaliveinterval` |
| `ssh.socket` enmascarado | masked | `systemctl is-enabled ssh.socket` → `masked` |
| `ssh.service` habilitado | enabled + active | `systemctl is-enabled ssh.service && systemctl is-active ssh.service` |

El último ítem es el que falló en el incidente de S4 (DT-17). `enabled` y `active` son comprobaciones independientes: ambas tienen que dar verde. Ver el detalle del incidente en `06-linux-baseline-spec.md`.

Configuración aplicada vía drop-in: `/etc/ssh/sshd_config.d/00-goloca.conf` (no editando el `sshd_config` principal, que puede sobrescribirse en actualizaciones del paquete).

## 3. Firewall (UFW)

| Ítem | bastion | app01 | Verificación |
|---|---|---|---|
| Política incoming | deny | deny | `ufw status verbose \| grep Default` |
| Política outgoing | allow | allow | idem |
| SSH 2222 permitido | desde red MGMT | solo desde bastión | `ufw status numbered` |
| UFW activo | active | active | `ufw status \| head -1` |

**Pendiente de endurecer (DT-21):** los orígenes actuales son `192.168.1.x` (transitorios). Tras el FortiGate: bastión → `10.10.0.0/24` + `10.10.99.0/24`; app01 → `10.20.0.40` + `10.10.99.0/24`.

## 4. Logging

| Ítem | Estado esperado | Verificación |
|---|---|---|
| journald persistente | `Storage=persistent` | `journalctl --header \| grep -i persistent` o revisar `/var/log/journal` |
| Techo de uso | 2G | `cat /etc/systemd/journald.conf.d/99-goloca.conf` |
| Retención | 30 días | idem |
| Usuario lee journal | en grupo `adm` | `groups ubuntu \| grep adm` |
| Boots registrados | múltiples | `journalctl --list-boots` |

## 5. Parcheo

| Ítem | Estado esperado | Verificación |
|---|---|---|
| unattended-upgrades activo | enabled | `systemctl is-enabled unattended-upgrades` |
| Solo origen `-security` | sí | `unattended-upgrades --dry-run` → revisar `Allowed origins` |
| Reboot automático | desactivado | `grep Automatic-Reboot /etc/apt/apt.conf.d/50unattended-upgrades` → `false` |
| Sistema al día | 0 paquetes pendientes | `apt list --upgradable` |
| Kernel en ejecución = instalado | coinciden | `uname -r` vs `dpkg -l \| grep linux-image` |

El último ítem detecta la trampa del kernel: un `apt full-upgrade` instala kernel nuevo, pero hasta reboot sigues con el viejo. Si no coinciden, hay un reboot pendiente para cerrar vulnerabilidades de kernel.

## 6. Superficie de ataque

| Ítem | Estado esperado | Verificación |
|---|---|---|
| Puertos a la escucha | solo los necesarios | `ss -tlnp` |
| Servicios activos | mínimos para el rol | `systemctl list-units --type=service --state=running` |
| Docker | solo en app01 | `which docker` (debe fallar en bastión) |

Principio: cada puerto abierto y cada servicio corriendo es superficie de ataque. El bastión no corre Docker ni cargas; app01 sí. Lo que no aporta al rol, no se instala.

## 7. Estado de recuperación

| Ítem | Estado esperado | Verificación |
|---|---|---|
| Snapshot de baseline | existe | `qm listsnapshot <vmid>` (desde Proxmox) |
| Acceso de rescate documentado | runbook guestfish | ver `runbooks/` |

## 8. Deuda técnica de hardening

| ID | Deuda | Resolución |
|---|---|---|
| DT-08 | Fail2ban instalado pero sin configurar | P6: afinar para puerto 2222 + integración FortiGate |
| DT-21 | Orígenes UFW transitorios | Endurecer post-FortiGate |
| DT-07 | Usuario en grupo docker = root | P3 RBAC, P6 rootless |
| — | Sin CIS benchmark aplicado | P6: hardening CIS Ubuntu + Lynis/CIS-CAT |
