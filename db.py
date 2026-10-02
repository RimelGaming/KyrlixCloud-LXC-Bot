from pathlib import Path
import aiosqlite
from config import config

SCHEMA = '''
CREATE TABLE IF NOT EXISTS vps (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    discord_user_id INTEGER NOT NULL,
    lxd_name TEXT NOT NULL UNIQUE,
    ssh_port INTEGER UNIQUE NOT NULL,
    image TEXT NOT NULL,
    cpu INTEGER NOT NULL,
    memory TEXT NOT NULL,
    disk TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'unknown',
    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS idx_vps_owner ON vps(discord_user_id);
'''

async def init_db():
    Path(config.database_path).parent.mkdir(parents=True, exist_ok=True)
    async with aiosqlite.connect(config.database_path) as db:
        await db.executescript(SCHEMA)
        await db.commit()

async def create_vps(user_id, lxd_name, ssh_port, image, cpu, memory, disk):
    async with aiosqlite.connect(config.database_path) as db:
        cur = await db.execute(
            "INSERT INTO vps (discord_user_id,lxd_name,ssh_port,image,cpu,memory,disk) VALUES (?,?,?,?,?,?,?)",
            (user_id, lxd_name, ssh_port, image, cpu, memory, disk))
        await db.commit()
        return cur.lastrowid

async def get_vps(vps_id):
    async with aiosqlite.connect(config.database_path) as db:
        db.row_factory = aiosqlite.Row
        cur = await db.execute("SELECT * FROM vps WHERE id=?", (vps_id,))
        return await cur.fetchone()

async def get_user_vps(user_id):
    async with aiosqlite.connect(config.database_path) as db:
        db.row_factory = aiosqlite.Row
        cur = await db.execute("SELECT * FROM vps WHERE discord_user_id=? ORDER BY id DESC", (user_id,))
        return await cur.fetchall()

async def get_next_port():
    async with aiosqlite.connect(config.database_path) as db:
        cur = await db.execute("SELECT ssh_port FROM vps ORDER BY ssh_port")
        used = {row[0] for row in await cur.fetchall()}
    for port in range(config.ssh_port_start, config.ssh_port_end + 1):
        if port not in used: return port
    raise RuntimeError("No SSH ports are available.")

async def delete_vps_record(vps_id):
    async with aiosqlite.connect(config.database_path) as db:
        await db.execute("DELETE FROM vps WHERE id=?", (vps_id,))
        await db.commit()
