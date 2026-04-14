"""
Control API for BroyhillGOP E59 Agent Mesh system.
FastAPI REST API for managing agents, rules, and controls.
"""

import json
import logging
from datetime import datetime, timedelta
from typing import Any, Dict, List, Optional

from fastapi import FastAPI, HTTPException, Query
import httpx

logger = logging.getLogger(__name__)


class ControlAPI:
    """
    FastAPI application for controlling agent mesh.
    Provides REST endpoints for agent management, rule configuration, and monitoring.
    """

    def __init__(self, supabase_url: str, supabase_key: str):
        """
        Initialize control API.

        Args:
            supabase_url: Supabase API URL
            supabase_key: Supabase API key
        """
        self.supabase_url = supabase_url
        self.supabase_key = supabase_key
        self.app = FastAPI(title="Agent Mesh Control API")
        self.client = httpx.AsyncClient(timeout=30.0)

        self._setup_routes()

    def _setup_routes(self) -> None:
        """Setup all API routes."""
        # Agent endpoints
        self.app.get("/agents")(self.list_agents)
        self.app.get("/agents/{eco_id}")(self.get_agent_detail)
        self.app.post("/agents/{eco_id}/toggle")(self.toggle_agent)

        # Rule endpoints
        self.app.get("/agents/{eco_id}/rules")(self.list_rules)
        self.app.post("/agents/{eco_id}/rules")(self.add_rule)
        self.app.put("/agents/{eco_id}/rules/{rule_id}")(self.update_rule)
        self.app.delete("/agents/{eco_id}/rules/{rule_id}")(self.delete_rule)
        self.app.post("/agents/{eco_id}/rules/{rule_id}/toggle")(self.toggle_rule)

        # Control endpoints
        self.app.get("/agents/{eco_id}/controls")(self.list_controls)
        self.app.put("/agents/{eco_id}/controls/{control_id}")(self.update_control)

        # Metrics and events
        self.app.get("/agents/{eco_id}/metrics")(self.get_metrics)
        self.app.get("/agents/{eco_id}/events")(self.get_events)
        self.app.post("/agents/{eco_id}/events/{event_id}/acknowledge")(self.acknowledge_event)

        # Dashboard
        self.app.get("/dashboard")(self.get_dashboard)
        self.app.get("/costs")(self.get_costs)

        # Brain directive
        self.app.post("/brain/directive")(self.submit_brain_directive)

    async def list_agents(self) -> Dict[str, Any]:
        """
        List all agents with status.

        Returns:
            List of agents with status
        """
        try:
            headers = self._get_headers()
            url = f"{self.supabase_url}/rest/v1/agent_registry?select=*"
            response = await self.client.get(url, headers=headers)

            if response.status_code == 200:
                agents = response.json()
                return {"agents": agents}
            else:
                raise HTTPException(status_code=500, detail="Failed to load agents")
        except Exception as e:
            logger.error(f"Error listing agents: {e}", exc_info=True)
            raise HTTPException(status_code=500, detail=str(e))

    async def get_agent_detail(self, eco_id: str) -> Dict[str, Any]:
        """Get detailed information about an agent."""
        try:
            headers = self._get_headers()

            # Get agent config
            url = f"{self.supabase_url}/rest/v1/agent_registry?ecosystem_id=eq.{eco_id}&select=*"
            resp = await self.client.get(url, headers=headers)

            if resp.status_code != 200 or not resp.json():
                raise HTTPException(status_code=404, detail="Agent not found")

            agent = resp.json()[0]

            # Get latest heartbeat
            url = f"{self.supabase_url}/rest/v1/agent_heartbeats?ecosystem_id=eq.{eco_id}&order=timestamp.desc&limit=1"
            resp = await self.client.get(url, headers=headers)
            heartbeat = resp.json()[0] if resp.json() else None

            agent["heartbeat"] = heartbeat

            return agent
        except HTTPException:
            raise
        except Exception as e:
            logger.error(f"Error getting agent detail: {e}", exc_info=True)
            raise HTTPException(status_code=500, detail=str(e))

    async def toggle_agent(self, eco_id: str) -> Dict[str, Any]:
        """Enable or disable an agent."""
        try:
            headers = self._get_headers()

            # Get current status
            url = f"{self.supabase_url}/rest/v1/agent_registry?ecosystem_id=eq.{eco_id}&select=enabled"
            resp = await self.client.get(url, headers=headers)

            if not resp.json():
                raise HTTPException(status_code=404, detail="Agent not found")

            current = resp.json()[0]["enabled"]

            # Toggle and update
            url = f"{self.supabase_url}/rest/v1/agent_registry?ecosystem_id=eq.{eco_id}"
            response = await self.client.patch(url, json={"enabled": not current}, headers=headers)

            if response.status_code in (200, 204):
                return {"ecosystem_id": eco_id, "enabled": not current}
            else:
                raise HTTPException(status_code=500, detail="Failed to toggle agent")
        except HTTPException:
            raise
        except Exception as e:
            logger.error(f"Error toggling agent: {e}", exc_info=True)
            raise HTTPException(status_code=500, detail=str(e))

    async def list_rules(self, eco_id: str) -> Dict[str, Any]:
        """List all rules for an ecosystem."""
        try:
            headers = self._get_headers()
            url = f"{self.supabase_url}/rest/v1/agent_rules?ecosystem_id=eq.{eco_id}&select=*"
            response = await self.client.get(url, headers=headers)

            if response.status_code == 200:
                return {"ecosystem_id": eco_id, "rules": response.json()}
            else:
                raise HTTPException(status_code=500, detail="Failed to load rules")
        except HTTPException:
            raise
        except Exception as e:
            logger.error(f"Error listing rules: {e}", exc_info=True)
            raise HTTPException(status_code=500, detail=str(e))

    async def add_rule(self, eco_id: str, rule: Dict[str, Any]) -> Dict[str, Any]:
        """Add a new rule."""
        try:
            headers = self._get_headers()

            rule["ecosystem_id"] = eco_id
            rule["created_at"] = datetime.utcnow().isoformat()
            rule["enabled"] = True

            url = f"{self.supabase_url}/rest/v1/agent_rules"
            response = await self.client.post(url, json=rule, headers=headers)

            if response.status_code in (200, 201):
                result = response.json()
                return result[0] if isinstance(result, list) else result
            else:
                raise HTTPException(status_code=500, detail="Failed to create rule")
        except HTTPException:
            raise
        except Exception as e:
            logger.error(f"Error adding rule: {e}", exc_info=True)
            raise HTTPException(status_code=500, detail=str(e))

    async def update_rule(self, eco_id: str, rule_id: str, updates: Dict[str, Any]) -> Dict[str, Any]:
        """Update a rule."""
        try:
            headers = self._get_headers()

            updates["updated_at"] = datetime.utcnow().isoformat()

            url = f"{self.supabase_url}/rest/v1/agent_rules?id=eq.{rule_id}&ecosystem_id=eq.{eco_id}"
            response = await self.client.patch(url, json=updates, headers=headers)

            if response.status_code in (200, 204):
                return {"rule_id": rule_id, "success": True}
            else:
                raise HTTPException(status_code=500, detail="Failed to update rule")
        except HTTPException:
            raise
        except Exception as e:
            logger.error(f"Error updating rule: {e}", exc_info=True)
            raise HTTPException(status_code=500, detail=str(e))

    async def delete_rule(self, eco_id: str, rule_id: str) -> Dict[str, Any]:
        """Delete a rule."""
        try:
            headers = self._get_headers()

            url = f"{self.supabase_url}/rest/v1/agent_rules?id=eq.{rule_id}&ecosystem_id=eq.{eco_id}"
            response = await self.client.delete(url, headers=headers)

            if response.status_code in (200, 204):
                return {"rule_id": rule_id, "deleted": True}
            else:
                raise HTTPException(status_code=500, detail="Failed to delete rule")
        except HTTPException:
            raise
        except Exception as e:
            logger.error(f"Error deleting rule: {e}", exc_info=True)
            raise HTTPException(status_code=500, detail=str(e))

    async def toggle_rule(self, eco_id: str, rule_id: str) -> Dict[str, Any]:
        """Enable or disable a rule."""
        try:
            headers = self._get_headers()

            # Get current status
            url = f"{self.supabase_url}/rest/v1/agent_rules?id=eq.{rule_id}&ecosystem_id=eq.{eco_id}&select=enabled"
            resp = await self.client.get(url, headers=headers)

            if not resp.json():
                raise HTTPException(status_code=404, detail="Rule not found")

            current = resp.json()[0]["enabled"]

            # Toggle
            url = f"{self.supabase_url}/rest/v1/agent_rules?id=eq.{rule_id}&ecosystem_id=eq.{eco_id}"
            response = await self.client.patch(url, json={"enabled": not current}, headers=headers)

            if response.status_code in (200, 204):
                return {"rule_id": rule_id, "enabled": not current}
            else:
                raise HTTPException(status_code=500, detail="Failed to toggle rule")
        except HTTPException:
            raise
        except Exception as e:
            logger.error(f"Error toggling rule: {e}", exc_info=True)
            raise HTTPException(status_code=500, detail=str(e))

    async def list_controls(self, eco_id: str) -> Dict[str, Any]:
        """List all controls (toggle switches) for an ecosystem."""
        try:
            headers = self._get_headers()
            url = f"{self.supabase_url}/rest/v1/agent_controls?ecosystem_id=eq.{eco_id}&select=*"
            response = await self.client.get(url, headers=headers)

            if response.status_code == 200:
                return {"ecosystem_id": eco_id, "controls": response.json()}
            else:
                raise HTTPException(status_code=500, detail="Failed to load controls")
        except HTTPException:
            raise
        except Exception as e:
            logger.error(f"Error listing controls: {e}", exc_info=True)
            raise HTTPException(status_code=500, detail=str(e))

    async def update_control(self, eco_id: str, control_id: str, value: Dict[str, Any]) -> Dict[str, Any]:
        """Update a control value."""
        try:
            headers = self._get_headers()

            value["updated_at"] = datetime.utcnow().isoformat()

            url = f"{self.supabase_url}/rest/v1/agent_controls?id=eq.{control_id}&ecosystem_id=eq.{eco_id}"
            response = await self.client.patch(url, json=value, headers=headers)

            if response.status_code in (200, 204):
                return {"control_id": control_id, "success": True}
            else:
                raise HTTPException(status_code=500, detail="Failed to update control")
        except HTTPException:
            raise
        except Exception as e:
            logger.error(f"Error updating control: {e}", exc_info=True)
            raise HTTPException(status_code=500, detail=str(e))

    async def get_metrics(self, eco_id: str, hours: int = Query(24)) -> Dict[str, Any]:
        """Get metrics for an ecosystem."""
        try:
            headers = self._get_headers()

            # Calculate timestamp
            since = (datetime.utcnow() - timedelta(hours=hours)).isoformat()

            url = f"{self.supabase_url}/rest/v1/agent_metrics?ecosystem_id=eq.{eco_id}&timestamp=gte.{since}&select=*"
            response = await self.client.get(url, headers=headers)

            if response.status_code == 200:
                return {"ecosystem_id": eco_id, "metrics": response.json()}
            else:
                raise HTTPException(status_code=500, detail="Failed to load metrics")
        except HTTPException:
            raise
        except Exception as e:
            logger.error(f"Error getting metrics: {e}", exc_info=True)
            raise HTTPException(status_code=500, detail=str(e))

    async def get_events(
        self,
        eco_id: str,
        severity: Optional[str] = None,
        hours: int = Query(24)
    ) -> Dict[str, Any]:
        """Get events for an ecosystem."""
        try:
            headers = self._get_headers()

            since = (datetime.utcnow() - timedelta(hours=hours)).isoformat()

            url = f"{self.supabase_url}/rest/v1/agent_events?ecosystem_id=eq.{eco_id}&timestamp=gte.{since}&select=*"
            if severity:
                url += f"&severity=eq.{severity}"

            response = await self.client.get(url, headers=headers)

            if response.status_code == 200:
                return {"ecosystem_id": eco_id, "events": response.json()}
            else:
                raise HTTPException(status_code=500, detail="Failed to load events")
        except HTTPException:
            raise
        except Exception as e:
            logger.error(f"Error getting events: {e}", exc_info=True)
            raise HTTPException(status_code=500, detail=str(e))

    async def acknowledge_event(self, eco_id: str, event_id: str) -> Dict[str, Any]:
        """Acknowledge an alert event."""
        try:
            headers = self._get_headers()

            url = f"{self.supabase_url}/rest/v1/agent_events?id=eq.{event_id}&ecosystem_id=eq.{eco_id}"
            response = await self.client.patch(
                url,
                json={"acknowledged": True, "acknowledged_at": datetime.utcnow().isoformat()},
                headers=headers
            )

            if response.status_code in (200, 204):
                return {"event_id": event_id, "acknowledged": True}
            else:
                raise HTTPException(status_code=500, detail="Failed to acknowledge event")
        except HTTPException:
            raise
        except Exception as e:
            logger.error(f"Error acknowledging event: {e}", exc_info=True)
            raise HTTPException(status_code=500, detail=str(e))

    async def get_dashboard(self) -> Dict[str, Any]:
        """Get cross-ecosystem summary for dashboard."""
        try:
            headers = self._get_headers()

            # Get all agents
            url = f"{self.supabase_url}/rest/v1/agent_registry?select=*"
            resp = await self.client.get(url, headers=headers)

            agents = resp.json() if resp.status_code == 200 else []

            # Get recent events
            since = (datetime.utcnow() - timedelta(hours=24)).isoformat()
            url = f"{self.supabase_url}/rest/v1/agent_events?timestamp=gte.{since}&select=ecosystem_id,severity"
            resp = await self.client.get(url, headers=headers)

            events = resp.json() if resp.status_code == 200 else []

            # Aggregate
            critical_count = sum(1 for e in events if e.get("severity") == "critical")
            warning_count = sum(1 for e in events if e.get("severity") == "warning")

            return {
                "total_agents": len(agents),
                "critical_events_24h": critical_count,
                "warning_events_24h": warning_count,
                "timestamp": datetime.utcnow().isoformat(),
            }
        except Exception as e:
            logger.error(f"Error getting dashboard: {e}", exc_info=True)
            raise HTTPException(status_code=500, detail=str(e))

    async def get_costs(self) -> Dict[str, Any]:
        """Get cost and variance report."""
        try:
            headers = self._get_headers()

            url = f"{self.supabase_url}/rest/v1/agent_cost_tracking?select=*"
            response = await self.client.get(url, headers=headers)

            if response.status_code == 200:
                costs = response.json()

                total_cost = sum(float(c.get("total_api_cost", 0)) for c in costs)
                total_budget = sum(float(c.get("monthly_budget", 0)) for c in costs)

                return {
                    "total_cost": total_cost,
                    "total_budget": total_budget,
                    "variance": total_budget - total_cost,
                    "variance_percent": ((total_budget - total_cost) / total_budget * 100) if total_budget > 0 else 0,
                    "ecosystems": costs,
                }
            else:
                raise HTTPException(status_code=500, detail="Failed to load cost data")
        except HTTPException:
            raise
        except Exception as e:
            logger.error(f"Error getting costs: {e}", exc_info=True)
            raise HTTPException(status_code=500, detail=str(e))

    async def submit_brain_directive(self, directive: Dict[str, Any]) -> Dict[str, Any]:
        """Submit a brain directive."""
        try:
            headers = self._get_headers()

            directive["status"] = "pending"
            directive["created_at"] = datetime.utcnow().isoformat()

            url = f"{self.supabase_url}/rest/v1/agent_brain_directives"
            response = await self.client.post(url, json=directive, headers=headers)

            if response.status_code in (200, 201):
                result = response.json()
                return result[0] if isinstance(result, list) else result
            else:
                raise HTTPException(status_code=500, detail="Failed to submit directive")
        except HTTPException:
            raise
        except Exception as e:
            logger.error(f"Error submitting directive: {e}", exc_info=True)
            raise HTTPException(status_code=500, detail=str(e))

    def _get_headers(self) -> Dict[str, str]:
        """Get common headers for Supabase requests."""
        return {
            "apikey": self.supabase_key,
            "Authorization": f"Bearer {self.supabase_key}",
            "Content-Type": "application/json",
        }

    async def close(self) -> None:
        """Close HTTP client."""
        if self.client:
            await self.client.aclose()
