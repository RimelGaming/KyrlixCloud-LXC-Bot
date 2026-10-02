#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# KyrlixCloud VPS Discord Bot Installer
# Made with love by Rimel
# ============================================================

APP_NAME="kyrlix-vps-discord-bot"
BASE_DIR="$(pwd)/vps-bot"
INSTALL_DIR="/opt/$APP_NAME"
SERVICE_NAME="$APP_NAME.service"

# ============================================================
# Colors
# ============================================================

RESET="\033[0m"
BOLD="\033[1m"

CYAN="\033[38;5;51m"
BLUE="\033[38;5;39m"
PURPLE="\033[38;5;141m"
GREEN="\033[38;5;82m"
YELLOW="\033[38;5;226m"
RED="\033[38;5;196m"
GRAY="\033[38;5;245m"
WHITE="\033[97m"

# ============================================================
# ASCII Art
# ============================================================

clear

echo -e "${CYAN}"
cat <<'EOF'
██╗  ██╗██╗   ██╗██████╗ ██╗     ██╗██╗  ██╗ ██████╗██╗      ██████╗ ██╗   ██╗██████╗
██║ ██╔╝╚██╗ ██╔╝██╔══██╗██║     ██║╚██╗██╔╝██╔════╝██║     ██╔═══██╗██║   ██║██╔══██╗
█████╔╝  ╚████╔╝ ██████╔╝██║     ██║ ╚███╔╝ ██║     ██║     ██║   ██║██║   ██║██████╔╝
██╔═██╗   ╚██╔╝  ██╔══██╗██║     ██║ ██╔██╗ ██║     ██║     ██║   ██║██║   ██║██╔══██╗
██║  ██╗   ██║   ██║  ██║███████╗██║██╔╝ ██╗╚██████╗███████╗╚██████╔╝╚██████╔╝██║  ██║
╚═╝  ╚═╝   ╚═╝   ╚═╝  ╚═╝╚══════╝╚═╝╚═╝  ╚═╝ ╚═════╝╚══════╝ ╚═════╝  ╚═════╝ ╚═╝  ╚═╝
EOF

echo -e "${RESET}"
echo -e "${BOLD}${WHITE}                         KyrlixCloud VPS Discord Bot${RESET}"
echo -e "${GRAY}                              Made by Rimel${RESET}"
echo
echo -e "${PURPLE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo

# ============================================================
# Helper functions
# ============================================================

info() {
    echo -e "${CYAN}➜${RESET} $1"
}

success() {
    echo -e "${GREEN}✔${RESET} $1"
}

warning() {
    echo -e "${YELLOW}⚠${RESET} $1"
}

error() {
    echo -e "${RED}✖${RESET} $1"
}

section() {
    echo
    echo -e "${BOLD}${BLUE}━━━ $1 ━━━${RESET}"
    echo
}

spinner() {
    local pid=$1
    local message="$2"
    local spin='|/-\'
    local i=0

    while kill -0 "$pid" 2>/dev/null; do
        printf "\r${CYAN}[%c]${RESET} %s" "${spin:i++%4:1}" "$message"
        sleep 0.1
    done

    printf "\r${GREEN}[✔]${RESET} %-70s\n" "$message"
}

run_with_spinner() {
    local message="$1"
    shift

    "$@" >/tmp/kyrlix-installer.log 2>&1 &
    local pid=$!

    spinner "$pid" "$message"

    if ! wait "$pid"; then
        echo
        error "Command failed:"
        echo -e "${GRAY}See /tmp/kyrlix-installer.log${RESET}"
        echo
        cat /tmp/kyrlix-installer.log
        exit 1
    fi
}

# ============================================================
# Root check
# ============================================================

if [[ $EUID -ne 0 ]]; then
    error "This installer must be run as root."
    echo
    echo -e "Run:"
    echo -e "${YELLOW}sudo bash installer.sh${RESET}"
    exit 1
fi

# ============================================================
# Configuration
# ============================================================

section "Bot Configuration"

read -rp "$(echo -e "${WHITE}Discord bot token:${RESET} ")" DISCORD_TOKEN

while [[ -z "$DISCORD_TOKEN" ]]; do
    warning "Discord bot token cannot be empty."
    read -rp "$(echo -e "${WHITE}Discord bot token:${RESET} ")" DISCORD_TOKEN
done

read -rp "$(echo -e "${WHITE}Discord guild/server ID ${GRAY}(optional)${WHITE}:${RESET} ")" GUILD_ID

read -rp "$(echo -e "${WHITE}Admin role ID ${GRAY}(optional)${WHITE}:${RESET} ")" ADMIN_ROLE_ID

# ============================================================
# VPS Configuration
# ============================================================

section "VPS Configuration"

read -rp "$(echo -e "${WHITE}Management VPS public IPv4:${RESET} ")" PUBLIC_IP

while [[ -z "$PUBLIC_IP" ]]; do
    warning "Public IPv4 cannot be empty."
    read -rp "$(echo -e "${WHITE}Management VPS public IPv4:${RESET} ")" PUBLIC_IP
done

read -rp "$(echo -e "${WHITE}LXD image ${GRAY}[ubuntu:24.04]${WHITE}:${RESET} ")" LXD_IMAGE
LXD_IMAGE=${LXD_IMAGE:-ubuntu:24.04}

read -rp "$(echo -e "${WHITE}Default vCPU ${GRAY}[2]${WHITE}:${RESET} ")" DEFAULT_CPU
DEFAULT_CPU=${DEFAULT_CPU:-2}

read -rp "$(echo -e "${WHITE}Default RAM ${GRAY}[2GiB]${WHITE}:${RESET} ")" DEFAULT_MEMORY
DEFAULT_MEMORY=${DEFAULT_MEMORY:-2GiB}

read -rp "$(echo -e "${WHITE}Default disk ${GRAY}[20GiB]${WHITE}:${RESET} ")" DEFAULT_DISK
DEFAULT_DISK=${DEFAULT_DISK:-20GiB}

read -rp "$(echo -e "${WHITE}SSH port start ${GRAY}[22000]${WHITE}:${RESET} ")" SSH_PORT_START
SSH_PORT_START=${SSH_PORT_START:-22000}

read -rp "$(echo -e "${WHITE}SSH port end ${GRAY}[22999]${WHITE}:${RESET} ")" SSH_PORT_END
SSH_PORT_END=${SSH_PORT_END:-22999}

read -rp "$(echo -e "${WHITE}Enable LXD SSH port forwarding? ${GRAY}[Y/n]${WHITE}:${RESET} ")" FORWARD
FORWARD=${FORWARD:-Y}

if [[ "$FORWARD" =~ ^[Nn]$ ]]; then
    ENABLE_PORT_FORWARD=false
else
    ENABLE_PORT_FORWARD=true
fi

# ============================================================
# Installation paths
# ============================================================

section "Preparing Installation"

info "Creating local project directory..."

mkdir -p "$BASE_DIR"
cd "$BASE_DIR"

success "Working directory: $BASE_DIR"

# ============================================================
# System dependencies
# ============================================================

section "Installing System Dependencies"

run_with_spinner \
    "Updating package lists..." \
    apt-get update

run_with_spinner \
    "Installing Python, pip, venv and LXD..." \
    apt-get install -y python3 python3-venv python3-pip lxd

USER_NAME="${SUDO_USER:-root}"

usermod -aG lxd "$USER_NAME" || true

success "System dependencies installed."

# ============================================================
# Copy project
# ============================================================

section "Installing KyrlixCloud VPS Bot"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

info "Creating installation directory..."

mkdir -p "$INSTALL_DIR"

info "Copying bot files..."

cp -a "$SCRIPT_DIR/." "$INSTALL_DIR/"

cd "$INSTALL_DIR"

success "Bot files copied to $INSTALL_DIR"

# ============================================================
# Python environment
# ============================================================

section "Setting Up Python Environment"

run_with_spinner \
    "Creating Python virtual environment..." \
    python3 -m venv .venv

run_with_spinner \
    "Updating pip..." \
    .venv/bin/pip install --upgrade pip

run_with_spinner \
    "Installing Python dependencies..." \
    .venv/bin/pip install -r requirements.txt

mkdir -p data

success "Python environment ready."

# ============================================================
# Environment configuration
# ============================================================

section "Creating Configuration"

cat > .env <<EOF
DISCORD_TOKEN=$DISCORD_TOKEN
GUILD_ID=$GUILD_ID
ADMIN_ROLE_ID=$ADMIN_ROLE_ID

DATABASE_PATH=$INSTALL_DIR/data/vpsbot.db

LXD_REMOTE=local
LXD_PROFILE=default
LXD_IMAGE=$LXD_IMAGE
LXD_PROJECT=default

DEFAULT_CPU=$DEFAULT_CPU
DEFAULT_MEMORY=$DEFAULT_MEMORY
DEFAULT_DISK=$DEFAULT_DISK

PUBLIC_IP=$PUBLIC_IP

SSH_PORT_START=$SSH_PORT_START
SSH_PORT_END=$SSH_PORT_END

ENABLE_PORT_FORWARD=$ENABLE_PORT_FORWARD
EOF

chmod 600 .env

success ".env created securely."

# ============================================================
# Systemd service
# ============================================================

section "Configuring Systemd"

if [[ ! -f "systemd/kyrlix-vps-discord-bot.service.example" ]]; then
    error "Systemd service template not found:"
    echo "systemd/kyrlix-vps-discord-bot.service.example"
    exit 1
fi

sed \
    -e "s/YOUR_LINUX_USER/$USER_NAME/g" \
    -e "s#WorkingDirectory=/opt/kyrlix-vps-discord-bot#WorkingDirectory=$INSTALL_DIR#g" \
    -e "s#EnvironmentFile=/opt/kyrlix-vps-discord-bot/.env#EnvironmentFile=$INSTALL_DIR/.env#g" \
    -e "s#ExecStart=/opt/kyrlix-vps-discord-bot/.venv/bin/python /opt/kyrlix-vps-discord-bot/bot.py#ExecStart=$INSTALL_DIR/.venv/bin/python $INSTALL_DIR/bot.py#g" \
    -e "s#ReadWritePaths=/opt/kyrlix-vps-discord-bot/data#ReadWritePaths=$INSTALL_DIR/data#g" \
    systemd/kyrlix-vps-discord-bot.service.example \
    > "/etc/systemd/system/$SERVICE_NAME"

run_with_spinner \
    "Reloading systemd..." \
    systemctl daemon-reload

run_with_spinner \
    "Enabling KyrlixCloud VPS Bot..." \
    systemctl enable "$SERVICE_NAME"

run_with_spinner \
    "Starting KyrlixCloud VPS Bot..." \
    systemctl start "$SERVICE_NAME"

# ============================================================
# Final status
# ============================================================

section "Installation Complete"

if systemctl is-active --quiet "$SERVICE_NAME"; then
    success "KyrlixCloud VPS Discord Bot is running!"
else
    warning "The bot service was installed but is not currently running."
fi

echo
echo -e "${BOLD}${CYAN}Installation Details${RESET}"
echo -e "${GRAY}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo -e "${WHITE}Bot directory:${RESET} $INSTALL_DIR"
echo -e "${WHITE}Service:${RESET}       $SERVICE_NAME"
echo -e "${WHITE}Database:${RESET}      $INSTALL_DIR/data/vpsbot.db"
echo -e "${WHITE}Config:${RESET}        $INSTALL_DIR/.env"
echo

echo -e "${BOLD}${CYAN}Useful Commands${RESET}"
echo -e "${GRAY}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo -e "${WHITE}Status:${RESET}"
echo "  systemctl status $SERVICE_NAME"
echo
echo -e "${WHITE}Logs:${RESET}"
echo "  journalctl -u $SERVICE_NAME -f"
echo
echo -e "${WHITE}Restart:${RESET}"
echo "  systemctl restart $SERVICE_NAME"
echo
echo -e "${WHITE}Stop:${RESET}"
echo "  systemctl stop $SERVICE_NAME"
echo

if [[ "$USER_NAME" != "root" ]]; then
    warning "The user '$USER_NAME' was added to the LXD group."
    echo -e "${GRAY}Log out and back in before testing 'lxc' manually if required.${RESET}"
fi

echo
echo -e "${PURPLE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo -e "${BOLD}${CYAN}                    KyrlixCloud${RESET}"
echo -e "${GRAY}                       Made by Rimel${RESET}"
echo -e "${PURPLE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo
echo -e "${GREEN}✔ Installation finished successfully.${RESET}"
echo
