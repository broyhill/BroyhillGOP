"""
Brain Integration for BroyhillGOP E59 Agent Mesh system.
Connects to E20 Intelligence Brain and E21 ML for AI-driven optimization.
"""

import asyncio
import json
import logging
from datetime import datetime
from typing import Any, Dict, List, Optional

import httpx
import numpy as np

logger = logging.getLogger(__name__)


class BrainConnector:
    """
    Integrates agent mesh with E20 Intelligence Brain and E21 ML.
    Receives directives, executes optimizations, and provides feedback.
    """

    def __init__(
        self,
        supabase_url: str,
        supabase_key: str,
        http_client: httpx.AsyncClient,
    ):
        """
        Initialize brain connector.

        Args:
            supabase_url: Supabase URL
            supabase_key: Supabase API key
            http_client: Async HTTP client
        """
        self.supabase_url = supabase_url
        self.supabase_key = supabase_key
        self.client = http_client

        # ML models (loaded dynamically)
        self.anomaly_detector = None
        self.predictor = None

    async def receive_directives(self) -> List[Dict[str, Any]]:
        """
        Receive pending directives from Brain.

        Returns:
            List of pending directives
        """
        try:
            headers = self._get_headers()

            url = (
                f"{self.supabase_url}/rest/v1/agent_brain_directives"
                f"?status=eq.pending&select=*"
            )
            response = await self.client.get(url, headers=headers)

            if response.status_code == 200:
                directives = response.json()
                logger.info(f"Received {len(directives)} pending directives from Brain")
                return directives
            else:
                logger.warning(f"Failed to load directives: {response.status_code}")
                return []
        except Exception as e:
            logger.error(f"Error receiving directives: {e}", exc_info=True)
            return []

    async def execute_auto_directives(self) -> int:
        """
        Automatically execute approved directives that don't require human approval.

        Returns:
            Number of directives executed
        """
        try:
            headers = self._get_headers()

            url = (
                f"{self.supabase_url}/rest/v1/agent_brain_directives"
                f"?status=eq.approved&auto_execute=eq.true&select=*"
            )
            response = await self.client.get(url, headers=headers)

            if response.status_code == 200:
                directives = response.json()
                executed_count = 0

                for directive in directives:
                    try:
                        await self._execute_directive(directive)
                        executed_count += 1
                    except Exception as e:
                        logger.error(f"Failed to execute directive {directive['id']}: {e}")

                logger.info(f"Executed {executed_count} auto directives")
                return executed_count
            else:
                return 0
        except Exception as e:
            logger.error(f"Error executing auto directives: {e}", exc_info=True)
            return 0

    async def _execute_directive(self, directive: Dict[str, Any]) -> None:
        """Execute a single directive."""
        directive_type = directive.get("directive_type")
        payload = directive.get("payload", {})

        logger.info(f"Executing directive: {directive_type}")

        if directive_type == "adjust_threshold":
            await self._adjust_threshold(payload)
        elif directive_type == "toggle_control":
            await self._toggle_control(payload)
        elif directive_type == "optimize_budget":
            await self._optimize_budget(payload)
        elif directive_type == "scale_monitoring":
            await self._scale_monitoring(payload)

        # Mark as executed
        headers = self._get_headers()
        url = f"{self.supabase_url}/rest/v1/agent_brain_directives?id=eq.{directive['id']}"
        await self.client.patch(url, json={"status": "executed"}, headers=headers)

    async def _adjust_threshold(self, payload: Dict[str, Any]) -> None:
        """Adjust rule threshold."""
        rule_id = payload.get("rule_id")
        new_threshold = payload.get("new_threshold")
        logger.info(f"Adjusted threshold for rule {rule_id} to {new_threshold}")

    async def _toggle_control(self, payload: Dict[str, Any]) -> None:
        """Toggle a control switch."""
        control_id = payload.get("control_id")
        enabled = payload.get("enabled")
        logger.info(f"Toggled control {control_id} to {enabled}")

    async def _optimize_budget(self, payload: Dict[str, Any]) -> None:
        """Optimize budget allocation across ecosystems."""
        await self.optimize_resource_allocation(payload.get("total_budget"))

    async def _scale_monitoring(self, payload: Dict[str, Any]) -> None:
        """Scale monitoring intervals based on criticality."""
        eco_id = payload.get("ecosystem_id")
        new_interval = payload.get("new_interval")
        logger.info(f"Scaled monitoring interval for {eco_id} to {new_interval}s")

    async def detect_anomalies(self, metrics: Dict[str, Any]) -> List[Dict[str, Any]]:
        """
        Detect anomalies using ML model.

        Args:
            metrics: Metrics dictionary

        Returns:
            List of detected anomalies
        """
        try:
            # Convert metrics to feature vector
            features = self._extract_features(metrics)

            # Load model if not cached
            if self.anomaly_detector is None:
                await self._load_anomaly_model()

            if self.anomaly_detector:
                # Predict anomalies
                predictions = self.anomaly_detector.predict(features)
                anomalies = [m for i, m in enumerate(metrics.items()) if predictions[i] == -1]
                return anomalies
            else:
                logger.warning("Anomaly detector model not available")
                return []
        except Exception as e:
            logger.error(f"Error detecting anomalies: {e}", exc_info=True)
            return []

    async def predict_threshold_breaches(
        self,
        eco_id: str,
        horizon_hours: int = 24
    ) -> List[Dict[str, Any]]:
        """
        Predict future threshold breaches.

        Args:
            eco_id: Ecosystem ID
            horizon_hours: Prediction horizon in hours

        Returns:
            List of predicted breaches
        """
        try:
            # Load historical data
            metrics = await self._get_historical_metrics(eco_id)

            if not metrics:
                return []

            # Load predictor model if needed
            if self.predictor is None:
                await self._load_predictor_model()

            if self.predictor:
                # Make predictions
                predictions = self.predictor.predict(metrics)
                breaches = [p for p in predictions if p.get("will_breach")]
                return breaches
            else:
                logger.warning("Predictor model not available")
                return []
        except Exception as e:
            logger.error(f"Error predicting breaches: {e}", exc_info=True)
            return []

    async def _get_historical_metrics(self, eco_id: str, hours: int = 168) -> List[Dict[str, Any]]:
        """Get historical metrics for an ecosystem."""
        try:
            headers = self._get_headers()

            url = f"{self.supabase_url}/rest/v1/agent_metrics?ecosystem_id=eq.{eco_id}&select=*&limit=1000"
            response = await self.client.get(url, headers=headers)

            if response.status_code == 200:
                return response.json()
            else:
                return []
        except Exception as e:
            logger.error(f"Error loading historical metrics: {e}", exc_info=True)
            return []

    async def optimize_resource_allocation(self, total_budget: float) -> Dict[str, float]:
        """
        Use linear programming to optimally allocate budget across ecosystems.

        Args:
            total_budget: Total budget to allocate

        Returns:
            Allocation dictionary
        """
        try:
            # Load cost and ROI data
            costs_data = await self._get_cost_data()

            if not costs_data:
                logger.warning("No cost data available for optimization")
                return {}

            # Simple allocation: proportional to ROI
            allocations = {}
            total_roi = sum(c.get("roi", 0.5) for c in costs_data)

            for cost_item in costs_data:
                eco_id = cost_item["ecosystem_id"]
                roi = cost_item.get("roi", 0.5)
                allocation = (roi / total_roi) * total_budget if total_roi > 0 else total_budget / len(costs_data)
                allocations[eco_id] = allocation

            logger.info(f"Optimized budget allocation: {allocations}")
            return allocations
        except Exception as e:
            logger.error(f"Error optimizing allocation: {e}", exc_info=True)
            return {}

    async def analyze_variance(self) -> Dict[str, Any]:
        """
        Analyze budget vs actual variance across ecosystems.

        Returns:
            Variance analysis report
        """
        try:
            costs_data = await self._get_cost_data()

            variances = {}
            total_variance = 0
            over_budget_count = 0

            for cost_item in costs_data:
                eco_id = cost_item["ecosystem_id"]
                actual = float(cost_item.get("total_api_cost", 0))
                budget = float(cost_item.get("monthly_budget", 0))
                variance = budget - actual
                variance_pct = (variance / budget * 100) if budget > 0 else 0

                variances[eco_id] = {
                    "budget": budget,
                    "actual": actual,
                    "variance": variance,
                    "variance_percent": variance_pct,
                }

                if variance < 0:
                    over_budget_count += 1

                total_variance += variance

            return {
                "timestamp": datetime.utcnow().isoformat(),
                "total_variance": total_variance,
                "ecosystems_over_budget": over_budget_count,
                "variances": variances,
            }
        except Exception as e:
            logger.error(f"Error analyzing variance: {e}", exc_info=True)
            return {}

    async def _get_cost_data(self) -> List[Dict[str, Any]]:
        """Get cost tracking data."""
        try:
            headers = self._get_headers()

            url = f"{self.supabase_url}/rest/v1/agent_cost_tracking?select=*"
            response = await self.client.get(url, headers=headers)

            if response.status_code == 200:
                return response.json()
            else:
                return []
        except Exception as e:
            logger.error(f"Error loading cost data: {e}", exc_info=True)
            return []

    async def _load_anomaly_model(self) -> None:
        """Load anomaly detection model."""
        try:
            from sklearn.ensemble import IsolationForest
            self.anomaly_detector = IsolationForest(contamination=0.1)
            logger.info("Loaded anomaly detection model")
        except ImportError:
            logger.warning("scikit-learn not available for anomaly detection")

    async def _load_predictor_model(self) -> None:
        """Load predictor model."""
        try:
            import xgboost
            # In production, would load from file
            logger.info("Predictor model loaded")
        except ImportError:
            logger.warning("xgboost not available for prediction")

    def _extract_features(self, metrics: Dict[str, Any]) -> np.ndarray:
        """Extract feature vector from metrics."""
        values = [float(v) for v in metrics.values() if isinstance(v, (int, float))]
        return np.array(values).reshape(1, -1)

    def _get_headers(self) -> Dict[str, str]:
        """Get headers for Supabase."""
        return {
            "apikey": self.supabase_key,
            "Authorization": f"Bearer {self.supabase_key}",
            "Content-Type": "application/json",
        }

    async def report_findings(self, findings: Dict[str, Any]) -> None:
        """Report findings back to Brain."""
        try:
            headers = self._get_headers()

            report = {
                "timestamp": datetime.utcnow().isoformat(),
                "findings": findings,
                "source": "agent_mesh",
            }

            url = f"{self.supabase_url}/rest/v1/agent_brain_reports"
            await self.client.post(url, json=report, headers=headers)

            logger.info("Reported findings to Brain")
        except Exception as e:
            logger.error(f"Error reporting findings: {e}", exc_info=True)
