#!/usr/bin/env python3
"""
============================================================================
BROYHILLGOP TELECOM: DROP COWBOY RVM PROVIDER
============================================================================
Ringless Voicemail (RVM) integration - PRIMARY PROVIDER
Cost: \$0.004/drop (95% cheaper than CallFire at \$0.075/drop)

100K drops: Drop Cowboy \$400 vs CallFire \$7,500 = \$7,100 savings

Author: BroyhillGOP Platform
Version: 2.0.0
============================================================================
"""
import os, json, logging, asyncio
from datetime import datetime
from typing import Dict, List, Optional
from dataclasses import dataclass
from enum import Enum
import aiohttp

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger('telecom.rvm')


class DropCowboyConfig:
    TEAM_ID = os.getenv("DROPCOWBOY_TEAM_ID", "")
    API_SECRET = os.getenv("DROPCOWBOY_API_SECRET", "")
    API_KEY = os.getenv("DROPCOWBOY_API_KEY", "")
    API_BASE = "https://api.dropcowboy.com/v1"
    DEFAULT_CALLER_ID = os.getenv("DROPCOWBOY_CALLER_ID", "")
    WEBHOOK_URL = os.getenv("DROPCOWBOY_WEBHOOK_URL", "https://broyhillgop.com/api/webhooks/dropcowboy")
    COST_PER_RVM = 0.004


class CallFireConfig:
    API_LOGIN = os.getenv("CALLFIRE_API_LOGIN", "")
    API_PASSWORD = os.getenv("CALLFIRE_API_PASSWORD", "")
    API_BASE = "https://api.callfire.com/v2"
    DEFAULT_CALLER_ID = os.getenv("CALLFIRE_CALLER_ID", "")
    COST_PER_RVM = 0.075


class RVMStatus(Enum):
    PENDING = "pending"
    QUEUED = "queued"
    DELIVERED = "delivered"
    LISTENED = "listened"
    FAILED = "failed"


@dataclass
class RVMDelivery:
    delivery_id: str
    campaign_id: str
    phone_number: str
    status: RVMStatus
    provider: str
    cost: float = 0.0


class DropCowboyRVMProvider:
    """Drop Cowboy RVM Provider - PRIMARY (\$0.004/drop)"""
    def __init__(self):
        self.config = DropCowboyConfig()
    
    def _get_headers(self) -> Dict:
        return {"Authorization": f"Bearer {self.config.API_KEY}", "Content-Type": "application/json"}
    
    def get_cost_per_message(self) -> float:
        return self.config.COST_PER_RVM
    
    async def send_rvm(self, phone: str, audio_url: str, caller_id: str = None) -> Dict:
        caller_id = caller_id or self.config.DEFAULT_CALLER_ID
        payload = {"team_id": self.config.TEAM_ID, "phone": phone, "caller_id": caller_id, "audio_url": audio_url, "callback_url": self.config.WEBHOOK_URL}
        async with aiohttp.ClientSession() as session:
            try:
                async with session.post(f"{self.config.API_BASE}/rvm/send", json=payload, headers=self._get_headers()) as response:
                    if response.status in [200, 201]:
                        data = await response.json()
                        logger.info(f"RVM sent to {phone} via Drop Cowboy")
                        return {"success": True, "delivery_id": data.get("id"), "provider": "dropcowboy", "status": "queued", "cost": self.config.COST_PER_RVM}
                    return {"success": False, "error": await response.text(), "provider": "dropcowboy"}
            except Exception as e:
                return {"success": False, "error": str(e), "provider": "dropcowboy"}
    
    async def send_bulk_rvm(self, recipients: List[str], audio_url: str, caller_id: str = None, campaign_name: str = None) -> Dict:
        caller_id = caller_id or self.config.DEFAULT_CALLER_ID
        campaign_name = campaign_name or f"BroyhillGOP_RVM_{datetime.now().strftime('%Y%m%d_%H%M%S')}"
        payload = {"team_id": self.config.TEAM_ID, "name": campaign_name, "caller_id": caller_id, "audio_url": audio_url, "phones": recipients, "callback_url": self.config.WEBHOOK_URL}
        async with aiohttp.ClientSession() as session:
            try:
                async with session.post(f"{self.config.API_BASE}/rvm/campaign", json=payload, headers=self._get_headers()) as response:
                    if response.status in [200, 201]:
                        data = await response.json()
                        total_cost = len(recipients) * self.config.COST_PER_RVM
                        logger.info(f"Drop Cowboy bulk RVM: {len(recipients)} recipients, \${total_cost:.2f}")
                        return {"success": True, "campaign_id": data.get("id"), "provider": "dropcowboy", "total_recipients": len(recipients), "estimated_cost": total_cost}
                    return {"success": False, "error": await response.text()}
            except Exception as e:
                return {"success": False, "error": str(e)}


class CallFireRVMProvider:
    """CallFire RVM Provider - BACKUP (\$0.075/drop)"""
    def __init__(self):
        self.config = CallFireConfig()
    
    def _get_auth(self):
        return aiohttp.BasicAuth(self.config.API_LOGIN, self.config.API_PASSWORD)
    
    def get_cost_per_message(self) -> float:
        return self.config.COST_PER_RVM
    
    async def send_rvm(self, phone: str, audio_url: str, caller_id: str = None) -> Dict:
        caller_id = caller_id or self.config.DEFAULT_CALLER_ID
        payload = {"name": f"RVM_{datetime.now().strftime('%Y%m%d_%H%M%S')}", "fromNumber": caller_id, "answeringMachineConfig": "AM_ONLY", "recipients": [{"phoneNumber": phone}], "sounds": {"machineSound": audio_url}}
        async with aiohttp.ClientSession() as session:
            try:
                async with session.post(f"{self.config.API_BASE}/calls/broadcasts", json=payload, auth=self._get_auth(), headers={"Content-Type": "application/json"}) as response:
                    if response.status in [200, 201]:
                        data = await response.json()
                        await session.post(f"{self.config.API_BASE}/calls/broadcasts/{data.get('id')}/start", auth=self._get_auth())
                        return {"success": True, "delivery_id": str(data.get("id")), "provider": "callfire", "status": "queued", "cost": self.config.COST_PER_RVM}
                    return {"success": False, "error": await response.text(), "provider": "callfire"}
            except Exception as e:
                return {"success": False, "error": str(e), "provider": "callfire"}


class RVMService:
    """RVM Service with automatic failover - Drop Cowboy PRIMARY, CallFire BACKUP"""
    def __init__(self):
        self.providers = [DropCowboyRVMProvider(), CallFireRVMProvider()]
    
    async def send_rvm(self, phone: str, audio_url: str, caller_id: str = None) -> Dict:
        for provider in self.providers:
            try:
                result = await provider.send_rvm(phone, audio_url, caller_id)
                if result.get("success"):
                    logger.info(f"RVM sent via {result.get('provider')} @ \${provider.get_cost_per_message()}/drop")
                    return result
            except Exception as e:
                logger.warning(f"{provider.__class__.__name__} failed: {e}")
        return {"success": False, "error": "All providers failed"}
    
    async def send_bulk_rvm(self, recipients: List[str], audio_url: str, caller_id: str = None, campaign_name: str = None, provider: str = "dropcowboy") -> Dict:
        if provider == "dropcowboy":
            return await DropCowboyRVMProvider().send_bulk_rvm(recipients, audio_url, caller_id, campaign_name)
        return await CallFireRVMProvider().send_rvm(recipients[0], audio_url, caller_id)
    
    def estimate_cost(self, recipient_count: int, provider: str = "dropcowboy") -> Dict:
        costs = {"dropcowboy": 0.004, "callfire": 0.075}
        cost_per = costs.get(provider, 0.004)
        total = recipient_count * cost_per
        return {"provider": provider, "recipient_count": recipient_count, "cost_per_drop": cost_per, "total_cost": total, "savings_vs_callfire": (recipient_count * 0.075) - total if provider == "dropcowboy" else 0}


_rvm_service = None
def get_rvm_service() -> RVMService:
    global _rvm_service
    if _rvm_service is None: _rvm_service = RVMService()
    return _rvm_service

def get_primary_provider() -> DropCowboyRVMProvider:
    return DropCowboyRVMProvider()

if __name__ == "__main__":
    print("RVM Provider: Drop Cowboy PRIMARY (\$0.004/drop)")
    print("Backup: CallFire (\$0.075/drop)")
    service = RVMService()
    est = service.estimate_cost(100000)
    print(f"100K drops: \${est['total_cost']:,.2f} (saves \${est['savings_vs_callfire']:,.2f} vs CallFire)")
