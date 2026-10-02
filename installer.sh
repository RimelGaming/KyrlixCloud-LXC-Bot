#!/usr/bin/env bash
set -euo pipefail
APP_NAME="kyrlix-vps-discord-bot"
INSTALL_DIR="/opt/$APP_NAME"
SERVICE_NAME="$APP_NAME.service"
REPO_URL="https://github.com/RimelGaming/KyrlixCloud-LXC-Bot"

if [[ $EUID -ne 0 ]]; then echo "Run: sudo bash installer.sh"; exit 1; fi

printf '\033[36m'
cat <<'BANNER'
 _  __                _  _          ____  _                      _ 
| |/ /  _   _  _ __  | |(_)__  __  / ___|| |  ___   _   _   __| |
| ' /  | | | || '__| | || |\ \/ / | |    | | / _ \ | | | | / _` |
| . \  | |_| || |    | || | >  <  | |___ | || (_) || |_| || (_| |
|_|\_\  \__, ||_|    |_||_|/_/\_\  \____||_| \___/  \__,_| \__,_|
        |___/
BANNER
printf '\033[0m'
echo "                                              made by Rimel"
echo
echo "=== KyrlixCloud VPS Discord Bot Installer ==="
read -rp "Discord bot token: " DISCORD_TOKEN
while [[ -z "$DISCORD_TOKEN" ]]; do read -rp "Discord bot token: " DISCORD_TOKEN; done
read -rp "Discord guild/server ID (optional): " GUILD_ID
read -rp "Admin role ID (optional): " ADMIN_ROLE_ID
read -rp "Management VPS public IPv4: " PUBLIC_IP
while [[ -z "$PUBLIC_IP" ]]; do read -rp "Management VPS public IPv4: " PUBLIC_IP; done
read -rp "LXD image [ubuntu:24.04]: " LXD_IMAGE; LXD_IMAGE=${LXD_IMAGE:-ubuntu:24.04}
read -rp "Default vCPU [2]: " DEFAULT_CPU; DEFAULT_CPU=${DEFAULT_CPU:-2}
read -rp "Default RAM [2GiB]: " DEFAULT_MEMORY; DEFAULT_MEMORY=${DEFAULT_MEMORY:-2GiB}
read -rp "Default disk [20GiB]: " DEFAULT_DISK; DEFAULT_DISK=${DEFAULT_DISK:-20GiB}
read -rp "SSH port start [22000]: " SSH_PORT_START; SSH_PORT_START=${SSH_PORT_START:-22000}
read -rp "SSH port end [22999]: " SSH_PORT_END; SSH_PORT_END=${SSH_PORT_END:-22999}
read -rp "Enable LXD SSH port forwarding? [Y/n]: " FORWARD; FORWARD=${FORWARD:-Y}
[[ "$FORWARD" =~ ^[Nn]$ ]] && ENABLE_PORT_FORWARD=false || ENABLE_PORT_FORWARD=true

apt-get update
apt-get install -y git python3 python3-venv python3-pip lxd
USER_NAME="${SUDO_USER:-root}"
usermod -aG lxd "$USER_NAME" || true

# Download the bot straight into the install directory and use those files
if [[ -d "$INSTALL_DIR/.git" ]]; then
  git -C "$INSTALL_DIR" pull --ff-only
elif [[ -e "$INSTALL_DIR" && -n "$(ls -A "$INSTALL_DIR" 2>/dev/null)" ]]; then
  echo "$INSTALL_DIR exists and is not a git repo. Move or remove it, then re-run."
  exit 1
else
  git clone "$REPO_URL" "$INSTALL_DIR"
fi

cd "$INSTALL_DIR"
python3 -m venv .venv
.venv/bin/pip install --upgrade pip
.venv/bin/pip install -r requirements.txt
mkdir -p data

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

sed -e "s/YOUR_LINUX_USER/$USER_NAME/g" \
    -e "s#WorkingDirectory=/opt/kyrlix-vps-discord-bot#WorkingDirectory=$INSTALL_DIR#g" \
    -e "s#EnvironmentFile=/opt/kyrlix-vps-discord-bot/.env#EnvironmentFile=$INSTALL_DIR/.env#g" \
    -e "s#ExecStart=/opt/kyrlix-vps-discord-bot/.venv/bin/python /opt/kyrlix-vps-discord-bot/bot.py#ExecStart=$INSTALL_DIR/.venv/bin/python $INSTALL_DIR/bot.py#g" \
    -e "s#ReadWritePaths=/opt/kyrlix-vps-discord-bot/data#ReadWritePaths=$INSTALL_DIR/data#g" \
    systemd/kyrlix-vps-discord-bot.service.example > "/etc/systemd/system/$SERVICE_NAME"

systemctl daemon-reload
systemctl enable --now "$SERVICE_NAME"

echo
echo "Installed successfully."
echo "Status: systemctl status $SERVICE_NAME"
echo "Logs:   journalctl -u $SERVICE_NAME -f"
echo
echo "If this is a new LXD group membership, log out/in before testing lxc manually."
