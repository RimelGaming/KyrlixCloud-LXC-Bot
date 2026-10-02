import os
from dataclasses import dataclass
from dotenv import load_dotenv

load_dotenv()

def env_int(name, default):
    value = os.getenv(name, "")
    return int(value) if value else default

@dataclass(frozen=True)
class Config:
    discord_token: str = os.getenv("DISCORD_TOKEN", "")
    guild_id: int = env_int("GUILD_ID", 0)
    admin_role_id: int = env_int("ADMIN_ROLE_ID", 0)
    database_path: str = os.getenv("DATABASE_PATH", "data/vpsbot.db")
    lxd_remote: str = os.getenv("LXD_REMOTE", "local")
    lxd_profile: str = os.getenv("LXD_PROFILE", "default")
    lxd_image: str = os.getenv("LXD_IMAGE", "ubuntu:24.04")
    lxd_project: str = os.getenv("LXD_PROJECT", "default")
    default_cpu: int = env_int("DEFAULT_CPU", 2)
    default_memory: str = os.getenv("DEFAULT_MEMORY", "2GiB")
    default_disk: str = os.getenv("DEFAULT_DISK", "20GiB")
    public_ip: str = os.getenv("PUBLIC_IP", "")
    ssh_port_start: int = env_int("SSH_PORT_START", 22000)
    ssh_port_end: int = env_int("SSH_PORT_END", 22999)
    enable_port_forward: bool = os.getenv("ENABLE_PORT_FORWARD", "true").lower() == "true"

config = Config()
