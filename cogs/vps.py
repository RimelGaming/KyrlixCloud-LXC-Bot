import discord
from discord import app_commands
from discord.ext import commands
from config import config
from db import create_vps, delete_vps_record, get_next_port, get_user_vps, get_vps
from services.lxd import LXD, LXDException

def emb(title, description="", color=None):
    return discord.Embed(title=title, description=description, color=color or discord.Color.blurple())

class ManageView(discord.ui.View):
    def __init__(self, row):
        super().__init__(timeout=300); self.row = row

    async def interaction_check(self, interaction):
        if interaction.user.id != self.row["discord_user_id"]:
            await interaction.response.send_message("This VPS is not yours.", ephemeral=True); return False
        return True

    @discord.ui.button(label="Start", style=discord.ButtonStyle.success, emoji="▶️")
    async def start(self, i, b):
        await i.response.defer(ephemeral=True)
        try: await LXD().start(self.row["lxd_name"]); await i.followup.send("VPS started.", ephemeral=True)
        except LXDException as e: await i.followup.send(f"Start failed: `{e}`", ephemeral=True)

    @discord.ui.button(label="Stop", style=discord.ButtonStyle.danger, emoji="⏹️")
    async def stop(self, i, b):
        await i.response.defer(ephemeral=True)
        try: await LXD().stop(self.row["lxd_name"]); await i.followup.send("VPS stopped.", ephemeral=True)
        except LXDException as e: await i.followup.send(f"Stop failed: `{e}`", ephemeral=True)

    @discord.ui.button(label="Restart", style=discord.ButtonStyle.primary, emoji="🔄")
    async def restart(self, i, b):
        await i.response.defer(ephemeral=True)
        try: await LXD().restart(self.row["lxd_name"]); await i.followup.send("VPS restarted.", ephemeral=True)
        except LXDException as e: await i.followup.send(f"Restart failed: `{e}`", ephemeral=True)

    @discord.ui.button(label="Status", style=discord.ButtonStyle.secondary, emoji="📊")
    async def status(self, i, b):
        await i.response.defer(ephemeral=True)
        try:
            lxd=LXD(); state=await lxd.status(self.row["lxd_name"]); ip=await lxd.ip(self.row["lxd_name"])
            await i.followup.send(f"**{self.row['lxd_name']}**\nStatus: `{state}`\nIPv4: `{ip}`", ephemeral=True)
        except LXDException as e: await i.followup.send(f"Status failed: `{e}`", ephemeral=True)

    @discord.ui.button(label="SSH Info", style=discord.ButtonStyle.secondary, emoji="🔑")
    async def ssh(self, i, b):
        await i.response.send_message(f"```text\nssh root@{config.public_ip} -p {self.row['ssh_port']}\n```", ephemeral=True)

    @discord.ui.button(label="Delete", style=discord.ButtonStyle.danger, emoji="🗑️", row=1)
    async def delete(self, i, b):
        await i.response.send_message("Are you sure? This permanently deletes the container.", view=DeleteView(self.row), ephemeral=True)

class DeleteView(discord.ui.View):
    def __init__(self, row): super().__init__(timeout=60); self.row=row
    @discord.ui.button(label="Confirm Delete", style=discord.ButtonStyle.danger)
    async def confirm(self, i, b):
        if i.user.id != self.row["discord_user_id"]:
            await i.response.send_message("This VPS is not yours.", ephemeral=True); return
        await i.response.defer(ephemeral=True)
        try:
            await LXD().delete(self.row["lxd_name"]); await delete_vps_record(self.row["id"])
            await i.followup.send("VPS deleted.", ephemeral=True)
        except LXDException as e: await i.followup.send(f"Delete failed: `{e}`", ephemeral=True)
    @discord.ui.button(label="Cancel", style=discord.ButtonStyle.secondary)
    async def cancel(self, i, b): await i.response.edit_message(content="Deletion cancelled.", view=None)

class VPS(commands.GroupCog, group_name="vps", group_description="Manage your LXD VPS"):
    def __init__(self, bot): self.bot=bot; self.lxd=LXD()

    @app_commands.command(name="deploy", description="Deploy a new LXD VPS.")
    async def deploy(self, i):
        await i.response.defer(ephemeral=True); port=await get_next_port(); name=f"vps-{i.user.id}-{port}"
        try:
            await self.lxd.create(name); await self.lxd.add_forward(name, port)
            vid=await create_vps(i.user.id,name,port,config.lxd_image,config.default_cpu,config.default_memory,config.default_disk)
            ip=await self.lxd.ip(name)
            e=emb("🚀 VPS Deployed", color=discord.Color.green())
            e.add_field(name="VPS ID",value=f"`{vid}`"); e.add_field(name="Container",value=f"`{name}`")
            e.add_field(name="IPv4",value=f"`{ip}`"); e.add_field(name="SSH",value=f"`{config.public_ip}:{port}`",inline=False)
            e.add_field(name="SSH Command",value=f"```bash\nssh root@{config.public_ip} -p {port}\n```",inline=False)
            await i.followup.send(embed=e,ephemeral=True)
        except Exception as e:
            try: await self.lxd.delete(name)
            except Exception: pass
            await i.followup.send(f"Deployment failed: `{e}`",ephemeral=True)

    @app_commands.command(name="my", description="List your VPS instances.")
    async def my(self,i):
        rows=await get_user_vps(i.user.id)
        if not rows: await i.response.send_message("You don't have any VPS.",ephemeral=True); return
        lines=[]
        for r in rows:
            try: state=await self.lxd.status(r["lxd_name"])
            except Exception: state="unknown"
            lines.append(f"**#{r['id']} — {r['lxd_name']}**\nStatus: `{state}` • SSH: `{config.public_ip}:{r['ssh_port']}`")
        await i.response.send_message(embed=emb("🖥️ My VPS","\n\n".join(lines)),ephemeral=True)

    @app_commands.command(name="manage", description="Open your VPS management panel.")
    async def manage(self,i):
        rows=await get_user_vps(i.user.id)
        if not rows: await i.response.send_message("You don't have any VPS.",ephemeral=True); return
        if len(rows)==1: await self.show_manage(i,rows[0]); return
        await i.response.send_message("Select a VPS to manage:",view=VPSSelectView(rows),ephemeral=True)

    async def show_manage(self,i,row):
        try: state=await self.lxd.status(row["lxd_name"]); ip=await self.lxd.ip(row["lxd_name"])
        except Exception: state,ip="unknown","unknown"
        e=emb("🖥️ VPS Management")
        for n,v in [("VPS",f"`#{row['id']}`"),("Status",f"`{state}`"),("IPv4",f"`{ip}`"),("CPU",f"`{row['cpu']} vCPU`"),("RAM",f"`{row['memory']}`"),("Disk",f"`{row['disk']}`"),("SSH",f"`{config.public_ip}:{row['ssh_port']}`")]: e.add_field(name=n,value=v,inline=n not in ("SSH",))
        await i.response.send_message(embed=e,view=ManageView(row),ephemeral=True)

class VPSSelect(discord.ui.Select):
    def __init__(self,rows):
        super().__init__(placeholder="Choose a VPS...",options=[discord.SelectOption(label=f"VPS #{r['id']}",description=f"{r['lxd_name']} • port {r['ssh_port']}",value=str(r["id"])) for r in rows[:25]])
    async def callback(self,i):
        row=await get_vps(int(self.values[0])); cog=i.client.get_cog("VPS")
        if not row or row["discord_user_id"]!=i.user.id: await i.response.send_message("VPS not found.",ephemeral=True); return
        await cog.show_manage(i,row)

class VPSSelectView(discord.ui.View):
    def __init__(self,rows): super().__init__(timeout=120); self.add_item(VPSSelect(rows))
                               
