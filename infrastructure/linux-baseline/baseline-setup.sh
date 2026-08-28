#!/usr/bin/env bash
#
# baseline-setup.sh — Goloca AI · Linux baseline reproducible (P1.6)
# -----------------------------------------------------------------------------
# Deja una VM Ubuntu 24.04 (cloud-init) en estado base auditable y operable.
# Idempotente: puede ejecutarse N veces; converge siempre al mismo estado.
#
# Cierra DT-19 (hardening/baseline aplicado a mano) y DT-20 (divergencia
# bastion/app01): un único artefacto, parametrizado por rol.
#
# USO:
#   sudo ./baseline-setup.sh <rol> <origen_ssh_ufw>
#
#   <rol>             bastion | app
#                     'app' instala además Docker Engine; 'bastion' no.
#   <origen_ssh_ufw>  CIDR o IP origen permitida para SSH/2222 en UFW.
#                     bastion (entrada MGMT):  10.20.0.0/24
#                     app     (tras bastión):  10.20.0.40
#
# EJEMPLOS:
#   sudo ./baseline-setup.sh bastion 10.20.0.0/24
#   sudo ./baseline-setup.sh app     10.20.0.40
#
# NOTA: estos orígenes corresponden a la red plana actual. Cuando existan las
# zonas del FortiGate, endurecer a 10.10.0.0/24 + 10.10.99.0/24 (DT-21).
#
# REQUISITOS: ejecutar como root (sudo). Ubuntu 24.04 LTS. Salida a internet.
# -----------------------------------------------------------------------------

set -euo pipefail

# --- Parámetros y validación ------------------------------------------------
ROLE="${1:-}"
SSH_ALLOWED_FROM="${2:-}"
SSH_PORT=2222
JOURNAL_DROPIN="/etc/systemd/journald.conf.d/99-goloca.conf"
UNATTENDED="/etc/apt/apt.conf.d/50unattended-upgrades"
AUTO_UPGRADES="/etc/apt/apt.conf.d/20auto-upgrades"

log()  { printf '\n\033[1;36m[baseline]\033[0m %s\n' "$*"; }
die()  { printf '\n\033[1;31m[error]\033[0m %s\n' "$*" >&2; exit 1; }

[ "$(id -u)" -eq 0 ] || die "Debe ejecutarse como root (usa sudo)."
case "$ROLE" in
  bastion|app) ;;
  *) die "Rol inválido: '$ROLE'. Usa 'bastion' o 'app'." ;;
esac
[ -n "$SSH_ALLOWED_FROM" ] || die "Falta el origen SSH para UFW (arg 2)."

export DEBIAN_FRONTEND=noninteractive
log "Iniciando baseline · rol=$ROLE · ssh_from=$SSH_ALLOWED_FROM"

# --- Pieza 1: sistema al día ------------------------------------------------
log "[1/6] apt update + full-upgrade"
apt-get update -qq
apt-get full-upgrade -y -qq

# --- Pieza 2: journald persistente ------------------------------------------
log "[2/6] journald persistente (Storage=persistent, 2G, 30 días)"
mkdir -p "$(dirname "$JOURNAL_DROPIN")"
cat > "$JOURNAL_DROPIN" <<'EOF'
[Journal]
Storage=persistent
SystemMaxUse=2G
MaxRetentionSec=30day
EOF
systemctl restart systemd-journald
# Acceso de operador a logs del sistema sin sudo
usermod -aG adm ubuntu

# --- Pieza 3: unattended-upgrades (solo seguridad, sin reboot auto) ---------
log "[3/6] unattended-upgrades (solo -security, Automatic-Reboot=false)"
apt-get install -y -qq unattended-upgrades
# Backup una sola vez (idempotente)
[ -f "${UNATTENDED}.bak" ] || cp "$UNATTENDED" "${UNATTENDED}.bak"
# Comentar el origen general (deja solo los -security). Idempotente: sed sobre
# la línea no-comentada; si ya está comentada, no hay coincidencia y no actúa.
sed -i 's|^\(\s*\)"\${distro_id}:\${distro_codename}";|\1// "${distro_id}:${distro_codename}"; // goloca: solo seguridad|' "$UNATTENDED"
# Control explícito de reboot + limpieza de huérfanos (solo si no está ya)
grep -q 'Automatic-Reboot "false"' "$UNATTENDED" || cat >> "$UNATTENDED" <<'EOF'

// goloca: control explicito de reboot
Unattended-Upgrade::Automatic-Reboot "false";
Unattended-Upgrade::Remove-Unused-Dependencies "true";
EOF
# Interruptor diario
cat > "$AUTO_UPGRADES" <<'EOF'
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
EOF

# --- Pieza 4: UFW (firewall de host, parametrizado por rol) -----------------
log "[4/6] UFW · deny incoming · allow SSH/$SSH_PORT desde $SSH_ALLOWED_FROM"
apt-get install -y -qq ufw
ufw default deny incoming
ufw default allow outgoing
# Regla SSH idempotente: 'ufw allow' no duplica reglas equivalentes.
ufw allow from "$SSH_ALLOWED_FROM" to any port "$SSH_PORT" proto tcp \
  comment "SSH ${ROLE} - transitorio, endurecer post-FortiGate (DT-21)"
# --force: no interactivo. La regla SSH ya está puesta -> no autobloqueo.
ufw --force enable

# --- Pieza 5: herramientas de operación -------------------------------------
log "[5/6] herramientas de diagnóstico + fail2ban (sin afinar -> P6/DT-08)"
apt-get install -y -qq \
  htop iotop iftop tcpdump dnsutils net-tools jq lsof fail2ban

# --- Pieza 6: Docker Engine (SOLO rol 'app', repo oficial) ------------------
if [ "$ROLE" = "app" ]; then
  log "[6/6] Docker Engine (repo oficial download.docker.com)"
  apt-get install -y -qq ca-certificates curl gnupg
  install -m 0755 -d /etc/apt/keyrings
  if [ ! -f /etc/apt/keyrings/docker.asc ]; then
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
      -o /etc/apt/keyrings/docker.asc
    chmod a+r /etc/apt/keyrings/docker.asc
  fi
  cat > /etc/apt/sources.list.d/docker.list <<EOF
deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable
EOF
  apt-get update -qq
  apt-get install -y -qq \
    docker-ce docker-ce-cli containerd.io \
    docker-buildx-plugin docker-compose-plugin
  # DT-07: grupo docker == root efectivo. Mitigado por patrón bastión;
  # revisar rootless Docker en P6.
  usermod -aG docker ubuntu
  systemctl enable --now docker
else
  log "[6/6] Docker omitido (rol '$ROLE' no ejecuta cargas)"
fi

# --- Cierre -----------------------------------------------------------------
log "Baseline aplicado. Verificaciones recomendadas:"
cat <<'EOF'
  systemctl is-enabled ssh.service        -> enabled
  systemctl is-active  systemd-journald   -> active
  ufw status verbose                      -> active, deny incoming, regla SSH
  [app] docker run --rm hello-world       -> Hello from Docker!
  Reconectar la sesión SSH para refrescar grupos (adm/docker).
EOF
log "Hecho."
