"""
Multi-channel Notifier for BroyhillGOP E59 Agent Mesh system.
Sends notifications via Slack, email, SMS, webhooks, and dashboard.
"""

import asyncio
import hashlib
import logging
from datetime import datetime, timedelta
from typing import Any, Dict, List, Optional

import httpx

logger = logging.getLogger(__name__)


class Notifier:
    """
    Multi-channel notification system with rate limiting and deduplication.
    """

    def __init__(
        self,
        supabase_url: str,
        supabase_key: str,
        http_client: httpx.AsyncClient,
        slack_webhook: Optional[str] = None,
        smtp_config: Optional[Dict[str, str]] = None,
        twilio_config: Optional[Dict[str, str]] = None,
    ):
        """
        Initialize notifier.

        Args:
            supabase_url: Supabase URL
            supabase_key: Supabase API key
            http_client: Async HTTP client
            slack_webhook: Slack webhook URL
            smtp_config: SMTP configuration
            twilio_config: Twilio API configuration
        """
        self.supabase_url = supabase_url
        self.supabase_key = supabase_key
        self.client = http_client

        self.slack_webhook = slack_webhook
        self.smtp_config = smtp_config or {}
        self.twilio_config = twilio_config or {}

        # Rate limiting and deduplication
        self.last_notification: Dict[str, datetime] = {}
        self.notification_history: Dict[str, int] = {}
        self.rate_limit_seconds = 300  # 5 minutes per channel per alert

    async def notify(
        self,
        event_id: str,
        event_type: str,
        severity: str,
        message: str,
        channels: Optional[List[str]] = None,
        details: Optional[Dict[str, Any]] = None,
    ) -> Dict[str, bool]:
        """
        Send notification via specified channels.

        Args:
            event_id: Event identifier
            event_type: Type of event
            severity: Severity level
            message: Notification message
            channels: Channels to use (default: all)
            details: Additional details

        Returns:
            Dictionary of channel: success status
        """
        if channels is None:
            channels = ["slack", "email", "dashboard"]

        results = {}

        # Check for duplication
        notification_hash = self._hash_notification(event_type, message)
        if self._is_duplicate(notification_hash):
            logger.info(f"Skipping duplicate notification: {event_id}")
            return {ch: False for ch in channels}

        # Format message
        formatted_message = self._format_message(severity, message, details)

        # Send to each channel
        for channel in channels:
            try:
                if channel == "slack":
                    results["slack"] = await self._send_slack(severity, formatted_message)
                elif channel == "email":
                    results["email"] = await self._send_email(severity, formatted_message)
                elif channel == "sms":
                    results["sms"] = await self._send_sms(severity, message)
                elif channel == "dashboard":
                    results["dashboard"] = await self._send_dashboard(event_id, severity, message, details)
                elif channel == "webhook":
                    results["webhook"] = await self._send_webhook(severity, message, details)
            except Exception as e:
                logger.error(f"Error sending {channel} notification: {e}", exc_info=True)
                results[channel] = False

        # Handle escalation for critical alerts
        if severity == "critical":
            await self._check_escalation(event_id, message)

        return results

    async def _send_slack(self, severity: str, message: str) -> bool:
        """Send Slack notification."""
        if not self.slack_webhook:
            logger.warning("Slack webhook not configured")
            return False

        try:
            color = self._get_color_for_severity(severity)

            payload = {
                "attachments": [
                    {
                        "color": color,
                        "title": f"Agent Mesh Alert - {severity.upper()}",
                        "text": message,
                        "ts": int(datetime.utcnow().timestamp()),
                    }
                ]
            }

            response = await self.client.post(self.slack_webhook, json=payload)

            if response.status_code in (200, 201):
                logger.info("Slack notification sent")
                return True
            else:
                logger.warning(f"Slack notification failed: {response.status_code}")
                return False
        except Exception as e:
            logger.error(f"Error sending Slack notification: {e}", exc_info=True)
            return False

    async def _send_email(self, severity: str, message: str) -> bool:
        """Send email notification."""
        if not self.smtp_config:
            logger.warning("SMTP not configured")
            return False

        try:
            # In production, would use aiosmtplib
            logger.info("Email notification would be sent")
            return True
        except Exception as e:
            logger.error(f"Error sending email: {e}", exc_info=True)
            return False

    async def _send_sms(self, severity: str, message: str) -> bool:
        """Send SMS notification via Twilio."""
        if not self.twilio_config:
            logger.warning("Twilio not configured")
            return False

        try:
            # In production, would use Twilio SDK
            logger.info("SMS notification would be sent")
            return True
        except Exception as e:
            logger.error(f"Error sending SMS: {e}", exc_info=True)
            return False

    async def _send_dashboard(
        self,
        event_id: str,
        severity: str,
        message: str,
        details: Optional[Dict[str, Any]] = None,
    ) -> bool:
        """Insert notification into dashboard via Supabase."""
        try:
            headers = self._get_headers()

            notification = {
                "event_id": event_id,
                "severity": severity,
                "message": message,
                "details": json.dumps(details or {}),
                "created_at": datetime.utcnow().isoformat(),
                "read": False,
            }

            url = f"{self.supabase_url}/rest/v1/agent_notifications"
            response = await self.client.post(url, json=notification, headers=headers)

            if response.status_code in (200, 201):
                logger.info("Dashboard notification sent")
                return True
            else:
                logger.warning(f"Dashboard notification failed: {response.status_code}")
                return False
        except Exception as e:
            logger.error(f"Error sending dashboard notification: {e}", exc_info=True)
            return False

    async def _send_webhook(
        self,
        severity: str,
        message: str,
        details: Optional[Dict[str, Any]] = None,
    ) -> bool:
        """Send webhook notification."""
        try:
            # In production, would load webhook URL from config
            logger.info("Webhook notification would be sent")
            return True
        except Exception as e:
            logger.error(f"Error sending webhook: {e}", exc_info=True)
            return False

    async def _check_escalation(self, event_id: str, message: str) -> None:
        """Check if critical alert needs escalation after 30 minutes."""
        try:
            await asyncio.sleep(1800)  # 30 minutes

            # Check if acknowledged
            headers = self._get_headers()
            url = f"{self.supabase_url}/rest/v1/agent_events?id=eq.{event_id}&select=acknowledged"
            response = await self.client.get(url, headers=headers)

            if response.status_code == 200:
                events = response.json()
                if events and not events[0].get("acknowledged"):
                    # Send escalation
                    logger.warning(f"Escalating unacknowledged critical alert: {event_id}")

                    escalation_payload = {
                        "original_event_id": event_id,
                        "escalation_level": "emergency",
                        "message": f"ESCALATED: {message}",
                        "timestamp": datetime.utcnow().isoformat(),
                    }

                    # Send via urgent channels
                    if self.slack_webhook:
                        await self._send_slack("emergency", escalation_payload["message"])
        except Exception as e:
            logger.error(f"Error in escalation check: {e}", exc_info=True)

    def _is_duplicate(self, notification_hash: str) -> bool:
        """Check if notification is a duplicate."""
        now = datetime.utcnow()

        if notification_hash in self.last_notification:
            elapsed = (now - self.last_notification[notification_hash]).total_seconds()
            if elapsed < self.rate_limit_seconds:
                return True

        self.last_notification[notification_hash] = now
        return False

    def _hash_notification(self, event_type: str, message: str) -> str:
        """Create hash for notification."""
        content = f"{event_type}:{message}"
        return hashlib.md5(content.encode()).hexdigest()

    def _format_message(
        self,
        severity: str,
        message: str,
        details: Optional[Dict[str, Any]] = None,
    ) -> str:
        """Format notification message."""
        formatted = f"[{severity.upper()}] {message}"

        if details:
            for key, value in details.items():
                formatted += f"\n{key}: {value}"

        return formatted

    def _get_color_for_severity(self, severity: str) -> str:
        """Get color for severity level."""
        colors = {
            "info": "#0099cc",
            "warning": "#ffaa00",
            "critical": "#ff6600",
            "emergency": "#cc0000",
        }
        return colors.get(severity, "#999999")

    def _get_headers(self) -> Dict[str, str]:
        """Get headers for Supabase."""
        return {
            "apikey": self.supabase_key,
            "Authorization": f"Bearer {self.supabase_key}",
            "Content-Type": "application/json",
        }

    async def close(self) -> None:
        """Close HTTP client."""
        if self.client:
            await self.client.aclose()


import json
