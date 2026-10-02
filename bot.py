import discord
from discord.ext import commands
from config import config
from db import init_db
from cogs.vps import VPS

class VPSBot(commands.Bot):
    def __init__(self):
        super().__init__(command_prefix="!", intents=discord.Intents.default())
    async def setup_hook(self):
        await init_db(); await self.add_cog(VPS(self))
        if config.guild_id:
            guild=discord.Object(id=config.guild_id)
            self.tree.copy_global_to(guild=guild); await self.tree.sync(guild=guild)
        else: await self.tree.sync()
        print("Slash commands synced.")
    async def on_ready(self): print(f"Logged in as {self.user} ({self.user.id})")

bot=VPSBot()
if not config.discord_token: raise RuntimeError("DISCORD_TOKEN is missing from .env")
bot.run(config.discord_token)
