import asyncio, re
from config import config

class LXDException(Exception): pass

class LXD:
    async def run(self, *args, timeout=120):
        proc = await asyncio.create_subprocess_exec(
            "lxc", *args, stdout=asyncio.subprocess.PIPE, stderr=asyncio.subprocess.PIPE)
        try:
            stdout, stderr = await asyncio.wait_for(proc.communicate(), timeout)
        except asyncio.TimeoutError:
            proc.kill(); await proc.wait()
            raise LXDException("LXD command timed out.")
        out = stdout.decode(errors="replace").strip()
        err = stderr.decode(errors="replace").strip()
        if proc.returncode != 0:
            raise LXDException(err or out or f"lxc exited with {proc.returncode}")
        return out

    async def create(self, name):
        await self.run("launch", config.lxd_image, name, "--profile", config.lxd_profile, "--project", config.lxd_project)
        await self.run("config", "set", name, "limits.cpu", str(config.default_cpu), "--project", config.lxd_project)
        await self.run("config", "set", name, "limits.memory", config.default_memory, "--project", config.lxd_project)
        await self.run("config", "device", "override", name, "root", f"size={config.default_disk}", "--project", config.lxd_project)
        await self.run("restart", name, "--project", config.lxd_project)

    async def delete(self, name): await self.run("delete", name, "--force", "--project", config.lxd_project)
    async def start(self, name): await self.run("start", name, "--project", config.lxd_project)
    async def stop(self, name): await self.run("stop", name, "--project", config.lxd_project)
    async def restart(self, name): await self.run("restart", name, "--project", config.lxd_project)

    async def status(self, name):
        return await self.run("list", name, "--format", "csv", "-c", "ns", "--project", config.lxd_project)

    async def ip(self, name):
        out = await self.run("list", name, "--format", "csv", "-c", "4", "--project", config.lxd_project)
        for item in re.split(r",|\n", out):
            item = item.strip()
            if re.fullmatch(r"\d{1,3}(?:\.\d{1,3}){3}", item): return item
        return "Not assigned"

    async def add_forward(self, name, host_port):
        if not config.enable_port_forward: return
        # Verify syntax for your installed LXD with: lxc network forward --help
        ip = await self.ip(name)
        if ip == "Not assigned": raise LXDException("Container has no IPv4 address yet.")
        await self.run("network", "forward", "create", "lxdbr0", "--listen-address", "0.0.0.0", "--project", config.lxd_project)
        await self.run("network", "forward", "port", "add", "lxdbr0", "0.0.0.0", "tcp", str(host_port), "22", "--project", config.lxd_project)
      
