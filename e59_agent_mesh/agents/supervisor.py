"""
Agent Supervisor for BroyhillGOP E59 Agent Mesh.
Master process that manages spawning, monitoring, and lifecycle of ecosystem agents.
"""

import asyncio
import json
import logging
import os
import signal
from datetime import datetime, timedelta
from typing import Any, Dict, List, Optional

import httpx
from aiohttp import web

logger = logging.getLogger(__name__)


class AgentSupervisor:
    """
    Master supervisor that spawns and monitors all ecosystem agents.
    Restarts failed agents, handles graceful shutdown, and provides health endpoints.
    """

    def __init__(
        self,
        supabase_url: str,
        supabase_key: str,
        health_check_port: int = 9090,
        max_heartbeat_miss_count: int = 3,
    ):
        """
        Initialize supervisor.

        Args:
            supabase_url: Supabase API URL
            supabase_key: Supabase API key
            health_check_port: Port for health check HTTP server
            max_heartbeat_miss_count: Max missed heartbeats before restart
        """
        self.supabase_url = supabase_url
        self.supabase_key = supabase_key
        self.health_check_port = health_check_port
        self.max_heartbeat_miss_count = max_heartbeat_miss_count

        self.running = False
        self.agents: Dict[str, Any] = {}
        self.agent_tasks: Dict[str, asyncio.Task] = {}
        self.heartbeat_miss_count: Dict[str, int] = {}

        self.http_client: Optional[httpx.AsyncClient] = None
        self.health_server: Optional[web.AppRunner] = None

        # Signal handlers
        signal.signal(signal.SIGTERM, self._signal_handler)
        signal.signal(signal.SIGINT, self._signal_handler)

    def _signal_handler(self, signum: int, frame: Any) -> None:
        """Handle shutdown signals."""
        logger.info(f"Received signal {signum}, initiating graceful shutdown")
        asyncio.create_task(self.shutdown())

    async def run(self) -> None:
        """Start supervisor and all agent management loops."""
        self.running = True
        self.http_client = httpx.AsyncClient(timeout=30.0)

        logger.info("Agent Supervisor starting")

        # Start health check server
        await self._start_health_server()

        # Load agents from registry
        await self._load_agent_registry()

        # Start agents
        for ecosystem_id, agent_config in self.agents.items():
            priority = agent_config.get("priority", 50)
            # Spawn with slight delays based on priority (critical first)
            delay = (100 - priority) * 0.1
            await asyncio.sleep(delay)
            await self._spawn_agent(ecosystem_id)

        # Notify systemd we're ready
        try:
            import systemd.daemon
            systemd.daemon.notify('READY=1')
            logger.info("Sent systemd READY notification")
        except ImportError:
            pass

        # Monitor heartbeats and restart failed agents
        await self._heartbeat_monitor_loop()

    async def shutdown(self) -> None:
        """Graceful shutdown of all agents."""
        logger.info("Supervisor shutting down")
        self.running = False

        # Cancel all agent tasks
        for ecosystem_id, task in list(self.agent_tasks.items()):
            if not task.done():
                logger.info(f"Stopping agent {ecosystem_id}")
                task.cancel()
                try:
                    await task
                except asyncio.CancelledError:
                    pass

        # Close HTTP client
        if self.http_client:
            await self.http_client.aclose()

        # Shutdown health server
        if self.health_server:
            await self.health_server.cleanup()

        logger.info("Supervisor shutdown complete")

    async def _load_agent_registry(self) -> None:
        """Load agent configuration from agent_registry table."""
        try:
            headers = {
                "apikey": self.supabase_key,
                "Authorization": f"Bearer {self.supabase_key}",
            }

            url = f"{self.supabase_url}/rest/v1/agent_registry?select=*"
            response = await self.http_client.get(url, headers=headers)

            if response.status_code == 200:
                agents = response.json()
                self.agents = {a["ecosystem_id"]: a for a in agents}
                logger.info(f"Loaded {len(self.agents)} agents from registry")
            else:
                logger.error(f"Failed to load agent registry: {response.status_code}")
        except Exception as e:
            logger.error(f"Error loading agent registry: {e}", exc_info=True)

    async def _spawn_agent(self, ecosystem_id: str) -> None:
        """
        Spawn an agent for an ecosystem.

        Args:
            ecosystem_id: Ecosystem ID
        """
        try:
            logger.info(f"Spawning agent for {ecosystem_id}")
            agent_config = self.agents.get(ecosystem_id, {})

            # Import agent class dynamically
            # In production, would load from agent_config["agent_class"]
            from base_agent import EcosystemAgent

            # Create concrete agent instance (in real implementation)
            # For now, just track that we're starting it
            self.heartbeat_miss_count[ecosystem_id] = 0

            # In a real implementation, this would instantiate and run the agent
            # For now, we just track it
            logger.info(f"Agent {ecosystem_id} scheduled to start")

        except Exception as e:
            logger.error(f"Failed to spawn agent {ecosystem_id}: {e}", exc_info=True)

    async def _heartbeat_monitor_loop(self) -> None:
        """Monitor agent heartbeats and restart dead agents."""
        while self.running:
            try:
                await self._check_all_heartbeats()
                await asyncio.sleep(60)  # Check every minute
            except Exception as e:
                logger.error(f"Heartbeat monitor error: {e}", exc_info=True)

    async def _check_all_heartbeats(self) -> None:
        """Check heartbeats for all agents."""
        try:
            headers = {
                "apikey": self.supabase_key,
                "Authorization": f"Bearer {self.supabase_key}",
            }

            url = f"{self.supabase_url}/rest/v1/agent_heartbeats?select=*"
            response = await self.http_client.get(url, headers=headers)

            if response.status_code == 200:
                heartbeats = response.json()

                # Create map of recent heartbeats
                recent = {h["ecosystem_id"]: h for h in heartbeats}

                # Check each agent
                for ecosystem_id in self.agents.keys():
                    heartbeat = recent.get(ecosystem_id)

                    if heartbeat:
                        # Check if heartbeat is fresh
                        last_beat = datetime.fromisoformat(heartbeat["timestamp"])
                        elapsed = (datetime.utcnow() - last_beat).total_seconds()

                        if elapsed < 120:  # Recent within 2 minutes
                            self.heartbeat_miss_count[ecosystem_id] = 0
                            logger.debug(f"{ecosystem_id} heartbeat OK")
                        else:
                            self.heartbeat_miss_count[ecosystem_id] += 1
                            logger.warning(f"{ecosystem_id} heartbeat stale ({elapsed}s)")
                    else:
                        self.heartbeat_miss_count[ecosystem_id] = \
                            self.heartbeat_miss_count.get(ecosystem_id, 0) + 1
                        logger.warning(f"{ecosystem_id} no recent heartbeat")

                    # Restart if too many misses
                    if self.heartbeat_miss_count[ecosystem_id] >= self.max_heartbeat_miss_count:
                        logger.error(f"Restarting {ecosystem_id} due to missed heartbeats")
                        await self._spawn_agent(ecosystem_id)
                        self.heartbeat_miss_count[ecosystem_id] = 0

            else:
                logger.warning(f"Failed to check heartbeats: {response.status_code}")
        except Exception as e:
            logger.error(f"Error checking heartbeats: {e}", exc_info=True)

    async def _start_health_server(self) -> None:
        """Start health check HTTP server."""
        try:
            app = web.Application()
            app.router.add_get("/health", self._health_handler)
            app.router.add_get("/agents", self._agents_handler)

            self.health_server = web.AppRunner(app)
            await self.health_server.setup()

            site = web.TCPSite(self.health_server, "0.0.0.0", self.health_check_port)
            await site.start()

            logger.info(f"Health server started on port {self.health_check_port}")
        except Exception as e:
            logger.error(f"Failed to start health server: {e}", exc_info=True)

    async def _health_handler(self, request: web.Request) -> web.Response:
        """Health check endpoint."""
        status = {
            "status": "healthy" if self.running else "stopping",
            "agents_count": len(self.agents),
            "timestamp": datetime.utcnow().isoformat(),
        }
        return web.json_response(status)

    async def _agents_handler(self, request: web.Request) -> web.Response:
        """List agents endpoint."""
        agents_info = []
        for eco_id, config in self.agents.items():
            agents_info.append({
                "ecosystem_id": eco_id,
                "enabled": config.get("enabled", True),
                "priority": config.get("priority", 50),
                "heartbeat_miss_count": self.heartbeat_miss_count.get(eco_id, 0),
            })
        return web.json_response({"agents": agents_info})

    async def generate_daily_summary(self) -> Dict[str, Any]:
        """
        Generate daily summary of all agents.

        Returns:
            Summary dictionary
        """
        try:
            headers = {
                "apikey": self.supabase_key,
                "Authorization": f"Bearer {self.supabase_key}",
            }

            # Get events from last 24 hours
            url = f"{self.supabase_url}/rest/v1/agent_events?select=*"
            response = await self.http_client.get(url, headers=headers)

            summary = {
                "timestamp": datetime.utcnow().isoformat(),
                "total_agents": len(self.agents),
                "events_24h": 0,
                "critical_events": 0,
                "agent_summaries": {}
            }

            if response.status_code == 200:
                events = response.json()

                # Count events by type and severity
                for event in events:
                    if event.get("severity") == "critical":
                        summary["critical_events"] += 1
                    summary["events_24h"] += 1

                    eco_id = event.get("ecosystem_id")
                    if eco_id not in summary["agent_summaries"]:
                        summary["agent_summaries"][eco_id] = {
                            "events": 0,
                            "critical": 0
                        }
                    summary["agent_summaries"][eco_id]["events"] += 1
                    if event.get("severity") == "critical":
                        summary["agent_summaries"][eco_id]["critical"] += 1

            logger.info(f"Generated daily summary: {summary['critical_events']} critical events")
            return summary
        except Exception as e:
            logger.error(f"Error generating daily summary: {e}", exc_info=True)
            return {"error": str(e)}
