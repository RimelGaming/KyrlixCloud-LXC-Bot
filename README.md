# KyrlixCloud VPS Discord Bot

Python Discord bot for deploying and managing LXD/LXC VPS containers from Discord.

## Features

- `/vps deploy`
- `/vps my`
- `/vps manage`
- Interactive Start / Stop / Restart / Status / SSH Info / Delete
- LXD/LXC provisioning
- SQLite database
- Automatic SSH port allocation
- Optional SSH port forwarding
- Per-user ownership checks
- Interactive installer
- systemd 24/7 service
- Public-repository-safe configuration

## Install

```bash
mkdir vps-bot
cd vps-bot
git clone https://github.com/RimelGaming/KyrlixCloud-LXC-Bot
sudo bash installer.sh
```

The installer asks for the Discord bot token, guild ID, public IPv4, resource
defaults, and SSH port range, then creates `.env`, installs dependencies and
starts the systemd service.

## Useful commands

```bash
sudo systemctl status kyrlix-vps-discord-bot
sudo systemctl restart kyrlix-vps-discord-bot
sudo journalctl -u kyrlix-vps-discord-bot -f
```

## SSH

A VPS can be exposed through the management VPS as:

```text
PUBLIC_IP:22000 -> container:22
```

Users receive an SSH command such as:

```bash
ssh root@203.0.113.5 -p 22000
```

Open the configured port range in your firewall/security group.

## Security

`.env` is ignored by Git. Never commit a Discord token, private key, password,
database, or other secret.

The bot does not expose arbitrary host shell commands to Discord.

Before production/customer use, add quotas, billing, rate limits, audit logs,
backups, abuse controls, monitoring, and robust network-forward cleanup.

## LXD compatibility

Network-forward syntax can vary by LXD release. Verify your installation with:

```bash
lxc network forward --help
```

and test deployment on a disposable container before production.

## License

MIT — see `LICENSE`.
