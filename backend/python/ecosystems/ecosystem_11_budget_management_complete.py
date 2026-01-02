#!/usr/bin/env python3
"""
================================================================================
ECOSYSTEM 11: BUDGET MANAGEMENT - COMPLETE FINANCIAL CONTROL SYSTEM
================================================================================
5-level budget hierarchy with real-time tracking, forecasting, variance analysis,
and multi-candidate allocation. Integrates with E28 Financial Dashboard.

Development Value: $85,000
================================================================================
"""

import os
import json
import logging
import uuid
from datetime import datetime, timedelta
from typing import Optional, List, Dict, Any, Tuple
from dataclasses import dataclass, field
from enum import Enum
from decimal import Decimal, ROUND_HALF_UP
import asyncio

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger('ecosystem11.budget_management')

# ============================================================================
# ENUMS
# ============================================================================

class BudgetLevel(Enum):
    PLATFORM = 'platform'      # NC GOP Platform level
    PARTY = 'party'            # State/County party
    CANDIDATE = 'candidate'    # Individual candidate
    CAMPAIGN = 'campaign'      # Specific campaign
    LINE_ITEM = 'line_item'    # Individual expense category

class BudgetCategory(Enum):
    ADVERTISING = 'advertising'
    DIGITAL = 'digital'
    DIRECT_MAIL = 'direct_mail'
    EVENTS = 'events'
    STAFF = 'staff'
    CONSULTING = 'consulting'
    TRAVEL = 'travel'
    OFFICE = 'office'
    FUNDRAISING = 'fundraising'
    COMPLIANCE = 'compliance'
    TECHNOLOGY = 'technology'
    VOTER_CONTACT = 'voter_contact'
    POLLING = 'polling'
    MEDIA_BUY = 'media_buy'
    PRODUCTION = 'production'
    OTHER = 'other'

class ExpenseStatus(Enum):
    DRAFT = 'draft'
    PENDING = 'pending'
    APPROVED = 'approved'
    REJECTED = 'rejected'
    PAID = 'paid'
    VOIDED = 'voided'

class BudgetPeriod(Enum):
    DAILY = 'daily'
    WEEKLY = 'weekly'
    MONTHLY = 'monthly'
    QUARTERLY = 'quarterly'
    ANNUAL = 'annual'
    CAMPAIGN_CYCLE = 'campaign_cycle'

class AlertSeverity(Enum):
    INFO = 'info'
    WARNING = 'warning'
    CRITICAL = 'critical'

# ============================================================================
# DATA CLASSES
# ============================================================================

@dataclass
class BudgetAllocation:
    allocation_id: str = field(default_factory=lambda: str(uuid.uuid4()))
    budget_id: str = ''
    category: BudgetCategory = BudgetCategory.OTHER
    allocated_amount: Decimal = Decimal('0.00')
    spent_amount: Decimal = Decimal('0.00')
    committed_amount: Decimal = Decimal('0.00')
    period: BudgetPeriod = BudgetPeriod.MONTHLY
    start_date: datetime = field(default_factory=datetime.now)
    end_date: Optional[datetime] = None
    notes: str = ''
    created_at: datetime = field(default_factory=datetime.now)
    
    @property
    def available(self) -> Decimal:
        return self.allocated_amount - self.spent_amount - self.committed_amount
    
    @property
    def utilization_pct(self) -> float:
        if self.allocated_amount == 0:
            return 0.0
        return float((self.spent_amount / self.allocated_amount) * 100)

@dataclass
class Budget:
    budget_id: str = field(default_factory=lambda: str(uuid.uuid4()))
    name: str = ''
    level: BudgetLevel = BudgetLevel.CANDIDATE
    parent_budget_id: Optional[str] = None
    candidate_id: Optional[str] = None
    total_budget: Decimal = Decimal('0.00')
    allocations: List[BudgetAllocation] = field(default_factory=list)
    fiscal_year: int = field(default_factory=lambda: datetime.now().year)
    is_active: bool = True
    created_at: datetime = field(default_factory=datetime.now)
    updated_at: datetime = field(default_factory=datetime.now)
    
    @property
    def total_allocated(self) -> Decimal:
        return sum(a.allocated_amount for a in self.allocations)
    
    @property
    def total_spent(self) -> Decimal:
        return sum(a.spent_amount for a in self.allocations)
    
    @property
    def total_committed(self) -> Decimal:
        return sum(a.committed_amount for a in self.allocations)
    
    @property
    def total_available(self) -> Decimal:
        return self.total_budget - self.total_spent - self.total_committed

@dataclass
class Expense:
    expense_id: str = field(default_factory=lambda: str(uuid.uuid4()))
    budget_id: str = ''
    allocation_id: str = ''
    category: BudgetCategory = BudgetCategory.OTHER
    amount: Decimal = Decimal('0.00')
    vendor_name: str = ''
    description: str = ''
    status: ExpenseStatus = ExpenseStatus.DRAFT
    invoice_number: Optional[str] = None
    receipt_url: Optional[str] = None
    fec_category: Optional[str] = None
    submitted_by: str = ''
    approved_by: Optional[str] = None
    paid_date: Optional[datetime] = None
    created_at: datetime = field(default_factory=datetime.now)
    updated_at: datetime = field(default_factory=datetime.now)

@dataclass
class BudgetForecast:
    forecast_id: str = field(default_factory=lambda: str(uuid.uuid4()))
    budget_id: str = ''
    period: BudgetPeriod = BudgetPeriod.MONTHLY
    forecast_date: datetime = field(default_factory=datetime.now)
    projected_spend: Decimal = Decimal('0.00')
    projected_revenue: Decimal = Decimal('0.00')
    confidence_score: float = 0.0
    assumptions: Dict[str, Any] = field(default_factory=dict)
    created_at: datetime = field(default_factory=datetime.now)

@dataclass
class BudgetAlert:
    alert_id: str = field(default_factory=lambda: str(uuid.uuid4()))
    budget_id: str = ''
    allocation_id: Optional[str] = None
    severity: AlertSeverity = AlertSeverity.INFO
    alert_type: str = ''
    message: str = ''
    threshold_pct: float = 0.0
    current_pct: float = 0.0
    is_acknowledged: bool = False
    created_at: datetime = field(default_factory=datetime.now)

# ============================================================================
# BUDGET MANAGER
# ============================================================================

class BudgetManager:
    """Core budget management with 5-level hierarchy."""
    
    def __init__(self, supabase_client=None):
        self.supabase = supabase_client
        self.budgets: Dict[str, Budget] = {}
        self.expenses: Dict[str, Expense] = {}
        self.alerts: List[BudgetAlert] = []
        
        # Alert thresholds
        self.alert_thresholds = {
            'warning': 75.0,   # 75% utilized
            'critical': 90.0,  # 90% utilized
            'overspend': 100.0 # Over budget
        }
    
    async def create_budget(
        self,
        name: str,
        level: BudgetLevel,
        total_budget: Decimal,
        candidate_id: Optional[str] = None,
        parent_budget_id: Optional[str] = None
    ) -> Budget:
        """Create a new budget at any level."""
        budget = Budget(
            name=name,
            level=level,
            total_budget=total_budget,
            candidate_id=candidate_id,
            parent_budget_id=parent_budget_id
        )
        
        self.budgets[budget.budget_id] = budget
        
        if self.supabase:
            await self._save_budget_to_db(budget)
        
        logger.info(f"Created budget: {name} (${total_budget:,.2f}) at {level.value} level")
        return budget
    
    async def allocate_funds(
        self,
        budget_id: str,
        category: BudgetCategory,
        amount: Decimal,
        period: BudgetPeriod = BudgetPeriod.MONTHLY,
        start_date: Optional[datetime] = None,
        end_date: Optional[datetime] = None
    ) -> BudgetAllocation:
        """Allocate funds to a specific category."""
        budget = self.budgets.get(budget_id)
        if not budget:
            raise ValueError(f"Budget {budget_id} not found")
        
        # Check if allocation would exceed total budget
        current_allocated = budget.total_allocated
        if current_allocated + amount > budget.total_budget:
            raise ValueError(
                f"Allocation of ${amount:,.2f} would exceed budget. "
                f"Available: ${budget.total_budget - current_allocated:,.2f}"
            )
        
        allocation = BudgetAllocation(
            budget_id=budget_id,
            category=category,
            allocated_amount=amount,
            period=period,
            start_date=start_date or datetime.now(),
            end_date=end_date
        )
        
        budget.allocations.append(allocation)
        
        if self.supabase:
            await self._save_allocation_to_db(allocation)
        
        logger.info(f"Allocated ${amount:,.2f} to {category.value} in budget {budget.name}")
        return allocation
    
    async def submit_expense(
        self,
        budget_id: str,
        category: BudgetCategory,
        amount: Decimal,
        vendor_name: str,
        description: str,
        submitted_by: str,
        invoice_number: Optional[str] = None,
        receipt_url: Optional[str] = None
    ) -> Expense:
        """Submit an expense for approval."""
        budget = self.budgets.get(budget_id)
        if not budget:
            raise ValueError(f"Budget {budget_id} not found")
        
        # Find matching allocation
        allocation = next(
            (a for a in budget.allocations if a.category == category),
            None
        )
        
        if not allocation:
            raise ValueError(f"No allocation found for category {category.value}")
        
        # Check available funds
        if amount > allocation.available:
            logger.warning(
                f"Expense ${amount:,.2f} exceeds available ${allocation.available:,.2f} "
                f"in {category.value}"
            )
        
        expense = Expense(
            budget_id=budget_id,
            allocation_id=allocation.allocation_id,
            category=category,
            amount=amount,
            vendor_name=vendor_name,
            description=description,
            submitted_by=submitted_by,
            invoice_number=invoice_number,
            receipt_url=receipt_url,
            status=ExpenseStatus.PENDING
        )
        
        # Add to committed (not spent yet)
        allocation.committed_amount += amount
        
        self.expenses[expense.expense_id] = expense
        
        if self.supabase:
            await self._save_expense_to_db(expense)
        
        # Check for alerts
        await self._check_budget_alerts(budget, allocation)
        
        logger.info(f"Expense submitted: ${amount:,.2f} to {vendor_name}")
        return expense
    
    async def approve_expense(
        self,
        expense_id: str,
        approved_by: str
    ) -> Expense:
        """Approve a pending expense."""
        expense = self.expenses.get(expense_id)
        if not expense:
            raise ValueError(f"Expense {expense_id} not found")
        
        if expense.status != ExpenseStatus.PENDING:
            raise ValueError(f"Expense is not pending (status: {expense.status.value})")
        
        expense.status = ExpenseStatus.APPROVED
        expense.approved_by = approved_by
        expense.updated_at = datetime.now()
        
        if self.supabase:
            await self._update_expense_in_db(expense)
        
        logger.info(f"Expense {expense_id} approved by {approved_by}")
        return expense
    
    async def pay_expense(
        self,
        expense_id: str
    ) -> Expense:
        """Mark expense as paid - moves from committed to spent."""
        expense = self.expenses.get(expense_id)
        if not expense:
            raise ValueError(f"Expense {expense_id} not found")
        
        if expense.status != ExpenseStatus.APPROVED:
            raise ValueError(f"Expense must be approved before payment")
        
        # Get allocation and move from committed to spent
        budget = self.budgets.get(expense.budget_id)
        allocation = next(
            (a for a in budget.allocations if a.allocation_id == expense.allocation_id),
            None
        )
        
        if allocation:
            allocation.committed_amount -= expense.amount
            allocation.spent_amount += expense.amount
        
        expense.status = ExpenseStatus.PAID
        expense.paid_date = datetime.now()
        expense.updated_at = datetime.now()
        
        if self.supabase:
            await self._update_expense_in_db(expense)
            await self._save_allocation_to_db(allocation)
        
        logger.info(f"Expense {expense_id} paid: ${expense.amount:,.2f}")
        return expense
    
    async def reject_expense(
        self,
        expense_id: str,
        rejected_by: str,
        reason: str
    ) -> Expense:
        """Reject a pending expense."""
        expense = self.expenses.get(expense_id)
        if not expense:
            raise ValueError(f"Expense {expense_id} not found")
        
        # Release committed funds
        budget = self.budgets.get(expense.budget_id)
        allocation = next(
            (a for a in budget.allocations if a.allocation_id == expense.allocation_id),
            None
        )
        
        if allocation:
            allocation.committed_amount -= expense.amount
        
        expense.status = ExpenseStatus.REJECTED
        expense.updated_at = datetime.now()
        
        if self.supabase:
            await self._update_expense_in_db(expense)
        
        logger.info(f"Expense {expense_id} rejected by {rejected_by}: {reason}")
        return expense

    # =========================================================================
    # REPORTING & ANALYTICS
    # =========================================================================
    
    def get_budget_summary(self, budget_id: str) -> Dict[str, Any]:
        """Get comprehensive budget summary."""
        budget = self.budgets.get(budget_id)
        if not budget:
            return {}
        
        return {
            'budget_id': budget.budget_id,
            'name': budget.name,
            'level': budget.level.value,
            'total_budget': float(budget.total_budget),
            'total_allocated': float(budget.total_allocated),
            'total_spent': float(budget.total_spent),
            'total_committed': float(budget.total_committed),
            'total_available': float(budget.total_available),
            'utilization_pct': (
                float(budget.total_spent / budget.total_budget * 100)
                if budget.total_budget > 0 else 0
            ),
            'allocations': [
                {
                    'category': a.category.value,
                    'allocated': float(a.allocated_amount),
                    'spent': float(a.spent_amount),
                    'committed': float(a.committed_amount),
                    'available': float(a.available),
                    'utilization_pct': a.utilization_pct
                }
                for a in budget.allocations
            ],
            'fiscal_year': budget.fiscal_year,
            'is_active': budget.is_active
        }
    
    def get_category_breakdown(self, budget_id: str) -> Dict[str, Dict[str, float]]:
        """Get spending breakdown by category."""
        budget = self.budgets.get(budget_id)
        if not budget:
            return {}
        
        breakdown = {}
        for allocation in budget.allocations:
            breakdown[allocation.category.value] = {
                'allocated': float(allocation.allocated_amount),
                'spent': float(allocation.spent_amount),
                'committed': float(allocation.committed_amount),
                'available': float(allocation.available),
                'pct_of_total': (
                    float(allocation.allocated_amount / budget.total_budget * 100)
                    if budget.total_budget > 0 else 0
                )
            }
        
        return breakdown
    
    def get_variance_report(self, budget_id: str) -> Dict[str, Any]:
        """Calculate budget variance (planned vs actual)."""
        budget = self.budgets.get(budget_id)
        if not budget:
            return {}
        
        variances = []
        for allocation in budget.allocations:
            # Calculate expected spend based on time elapsed
            if allocation.end_date and allocation.start_date:
                total_days = (allocation.end_date - allocation.start_date).days
                elapsed_days = (datetime.now() - allocation.start_date).days
                expected_pct = min(elapsed_days / total_days, 1.0) if total_days > 0 else 1.0
            else:
                expected_pct = 1.0
            
            expected_spend = allocation.allocated_amount * Decimal(str(expected_pct))
            variance = allocation.spent_amount - expected_spend
            variance_pct = (
                float(variance / expected_spend * 100)
                if expected_spend > 0 else 0
            )
            
            variances.append({
                'category': allocation.category.value,
                'allocated': float(allocation.allocated_amount),
                'expected_spend': float(expected_spend),
                'actual_spend': float(allocation.spent_amount),
                'variance': float(variance),
                'variance_pct': variance_pct,
                'status': 'over' if variance > 0 else 'under' if variance < 0 else 'on_track'
            })
        
        total_expected = sum(v['expected_spend'] for v in variances)
        total_actual = float(budget.total_spent)
        
        return {
            'budget_id': budget_id,
            'name': budget.name,
            'total_variance': total_actual - total_expected,
            'total_variance_pct': (
                (total_actual - total_expected) / total_expected * 100
                if total_expected > 0 else 0
            ),
            'category_variances': variances,
            'generated_at': datetime.now().isoformat()
        }

    # =========================================================================
    # FORECASTING
    # =========================================================================
    
    async def generate_forecast(
        self,
        budget_id: str,
        periods_ahead: int = 3,
        period: BudgetPeriod = BudgetPeriod.MONTHLY
    ) -> List[BudgetForecast]:
        """Generate spend forecast based on historical patterns."""
        budget = self.budgets.get(budget_id)
        if not budget:
            return []
        
        # Get historical expenses
        budget_expenses = [
            e for e in self.expenses.values()
            if e.budget_id == budget_id and e.status == ExpenseStatus.PAID
        ]
        
        if not budget_expenses:
            logger.warning(f"No historical data for forecast in budget {budget_id}")
            return []
        
        # Calculate average monthly spend
        total_spent = sum(e.amount for e in budget_expenses)
        date_range = max(
            (datetime.now() - min(e.created_at for e in budget_expenses)).days,
            30
        )
        avg_daily_spend = total_spent / Decimal(str(date_range))
        
        forecasts = []
        for i in range(1, periods_ahead + 1):
            if period == BudgetPeriod.MONTHLY:
                days_in_period = 30
                forecast_date = datetime.now() + timedelta(days=30 * i)
            elif period == BudgetPeriod.WEEKLY:
                days_in_period = 7
                forecast_date = datetime.now() + timedelta(days=7 * i)
            else:
                days_in_period = 30
                forecast_date = datetime.now() + timedelta(days=30 * i)
            
            projected_spend = avg_daily_spend * Decimal(str(days_in_period))
            
            # Confidence decreases with distance
            confidence = max(0.5, 1.0 - (i * 0.1))
            
            forecast = BudgetForecast(
                budget_id=budget_id,
                period=period,
                forecast_date=forecast_date,
                projected_spend=projected_spend.quantize(Decimal('0.01')),
                confidence_score=confidence,
                assumptions={
                    'method': 'historical_average',
                    'data_points': len(budget_expenses),
                    'avg_daily_spend': float(avg_daily_spend)
                }
            )
            forecasts.append(forecast)
        
        logger.info(f"Generated {len(forecasts)} forecasts for budget {budget.name}")
        return forecasts

    # =========================================================================
    # ALERTS
    # =========================================================================
    
    async def _check_budget_alerts(
        self,
        budget: Budget,
        allocation: Optional[BudgetAllocation] = None
    ):
        """Check and generate budget alerts."""
        # Check overall budget
        overall_pct = (
            float((budget.total_spent + budget.total_committed) / budget.total_budget * 100)
            if budget.total_budget > 0 else 0
        )
        
        if overall_pct >= self.alert_thresholds['overspend']:
            await self._create_alert(
                budget.budget_id,
                None,
                AlertSeverity.CRITICAL,
                'budget_overspend',
                f"Budget {budget.name} has exceeded 100% utilization",
                100.0,
                overall_pct
            )
        elif overall_pct >= self.alert_thresholds['critical']:
            await self._create_alert(
                budget.budget_id,
                None,
                AlertSeverity.CRITICAL,
                'budget_critical',
                f"Budget {budget.name} is at {overall_pct:.1f}% utilization",
                self.alert_thresholds['critical'],
                overall_pct
            )
        elif overall_pct >= self.alert_thresholds['warning']:
            await self._create_alert(
                budget.budget_id,
                None,
                AlertSeverity.WARNING,
                'budget_warning',
                f"Budget {budget.name} is at {overall_pct:.1f}% utilization",
                self.alert_thresholds['warning'],
                overall_pct
            )
        
        # Check specific allocation if provided
        if allocation:
            alloc_pct = (
                float((allocation.spent_amount + allocation.committed_amount) / 
                      allocation.allocated_amount * 100)
                if allocation.allocated_amount > 0 else 0
            )
            
            if alloc_pct >= self.alert_thresholds['critical']:
                await self._create_alert(
                    budget.budget_id,
                    allocation.allocation_id,
                    AlertSeverity.WARNING,
                    'allocation_critical',
                    f"{allocation.category.value} allocation at {alloc_pct:.1f}%",
                    self.alert_thresholds['critical'],
                    alloc_pct
                )
    
    async def _create_alert(
        self,
        budget_id: str,
        allocation_id: Optional[str],
        severity: AlertSeverity,
        alert_type: str,
        message: str,
        threshold_pct: float,
        current_pct: float
    ):
        """Create a budget alert."""
        # Check for duplicate recent alert
        recent_alerts = [
            a for a in self.alerts
            if a.budget_id == budget_id
            and a.alert_type == alert_type
            and (datetime.now() - a.created_at).seconds < 3600
        ]
        
        if recent_alerts:
            return  # Don't duplicate
        
        alert = BudgetAlert(
            budget_id=budget_id,
            allocation_id=allocation_id,
            severity=severity,
            alert_type=alert_type,
            message=message,
            threshold_pct=threshold_pct,
            current_pct=current_pct
        )
        
        self.alerts.append(alert)
        
        if self.supabase:
            await self._save_alert_to_db(alert)
        
        logger.warning(f"Budget Alert [{severity.value}]: {message}")
    
    def get_active_alerts(self, budget_id: Optional[str] = None) -> List[Dict[str, Any]]:
        """Get unacknowledged alerts."""
        alerts = [a for a in self.alerts if not a.is_acknowledged]
        
        if budget_id:
            alerts = [a for a in alerts if a.budget_id == budget_id]
        
        return [
            {
                'alert_id': a.alert_id,
                'budget_id': a.budget_id,
                'severity': a.severity.value,
                'alert_type': a.alert_type,
                'message': a.message,
                'threshold_pct': a.threshold_pct,
                'current_pct': a.current_pct,
                'created_at': a.created_at.isoformat()
            }
            for a in sorted(alerts, key=lambda x: x.created_at, reverse=True)
        ]

    # =========================================================================
    # DATABASE OPERATIONS
    # =========================================================================
    
    async def _save_budget_to_db(self, budget: Budget):
        if not self.supabase:
            return
        try:
            await self.supabase.table('e11_budgets').upsert({
                'budget_id': budget.budget_id,
                'name': budget.name,
                'level': budget.level.value,
                'parent_budget_id': budget.parent_budget_id,
                'candidate_id': budget.candidate_id,
                'total_budget': float(budget.total_budget),
                'fiscal_year': budget.fiscal_year,
                'is_active': budget.is_active,
                'created_at': budget.created_at.isoformat(),
                'updated_at': budget.updated_at.isoformat()
            }).execute()
        except Exception as e:
            logger.error(f"Failed to save budget: {e}")
    
    async def _save_allocation_to_db(self, allocation: BudgetAllocation):
        if not self.supabase:
            return
        try:
            await self.supabase.table('e11_budget_allocations').upsert({
                'allocation_id': allocation.allocation_id,
                'budget_id': allocation.budget_id,
                'category': allocation.category.value,
                'allocated_amount': float(allocation.allocated_amount),
                'spent_amount': float(allocation.spent_amount),
                'committed_amount': float(allocation.committed_amount),
                'period': allocation.period.value,
                'start_date': allocation.start_date.isoformat(),
                'end_date': allocation.end_date.isoformat() if allocation.end_date else None,
                'created_at': allocation.created_at.isoformat()
            }).execute()
        except Exception as e:
            logger.error(f"Failed to save allocation: {e}")
    
    async def _save_expense_to_db(self, expense: Expense):
        if not self.supabase:
            return
        try:
            await self.supabase.table('e11_expenses').upsert({
                'expense_id': expense.expense_id,
                'budget_id': expense.budget_id,
                'allocation_id': expense.allocation_id,
                'category': expense.category.value,
                'amount': float(expense.amount),
                'vendor_name': expense.vendor_name,
                'description': expense.description,
                'status': expense.status.value,
                'invoice_number': expense.invoice_number,
                'receipt_url': expense.receipt_url,
                'submitted_by': expense.submitted_by,
                'approved_by': expense.approved_by,
                'paid_date': expense.paid_date.isoformat() if expense.paid_date else None,
                'created_at': expense.created_at.isoformat(),
                'updated_at': expense.updated_at.isoformat()
            }).execute()
        except Exception as e:
            logger.error(f"Failed to save expense: {e}")
    
    async def _update_expense_in_db(self, expense: Expense):
        await self._save_expense_to_db(expense)
    
    async def _save_alert_to_db(self, alert: BudgetAlert):
        if not self.supabase:
            return
        try:
            await self.supabase.table('e11_budget_alerts').insert({
                'alert_id': alert.alert_id,
                'budget_id': alert.budget_id,
                'allocation_id': alert.allocation_id,
                'severity': alert.severity.value,
                'alert_type': alert.alert_type,
                'message': alert.message,
                'threshold_pct': alert.threshold_pct,
                'current_pct': alert.current_pct,
                'is_acknowledged': alert.is_acknowledged,
                'created_at': alert.created_at.isoformat()
            }).execute()
        except Exception as e:
            logger.error(f"Failed to save alert: {e}")


# ============================================================================
# FEC COMPLIANCE INTEGRATION
# ============================================================================

class FECBudgetCompliance:
    """FEC compliance checking for campaign budgets."""
    
    # FEC contribution limits (2024 cycle)
    CONTRIBUTION_LIMITS = {
        'individual_to_candidate': 3300,
        'individual_to_pac': 5000,
        'individual_to_party': 41300,
        'pac_to_candidate': 5000
    }
    
    # Reportable expense thresholds
    ITEMIZATION_THRESHOLD = 200
    
    @staticmethod
    def categorize_expense_for_fec(expense: Expense) -> str:
        """Map expense category to FEC category."""
        fec_mapping = {
            BudgetCategory.ADVERTISING: 'Advertising',
            BudgetCategory.DIGITAL: 'Digital Advertising',
            BudgetCategory.DIRECT_MAIL: 'Direct Mail',
            BudgetCategory.EVENTS: 'Event Expenses',
            BudgetCategory.STAFF: 'Payroll',
            BudgetCategory.CONSULTING: 'Consulting',
            BudgetCategory.TRAVEL: 'Travel',
            BudgetCategory.OFFICE: 'Office Expenses',
            BudgetCategory.FUNDRAISING: 'Fundraising',
            BudgetCategory.COMPLIANCE: 'Legal/Compliance',
            BudgetCategory.TECHNOLOGY: 'Technology',
            BudgetCategory.VOTER_CONTACT: 'Voter Contact',
            BudgetCategory.POLLING: 'Polling',
            BudgetCategory.MEDIA_BUY: 'Media Buy',
            BudgetCategory.PRODUCTION: 'Production',
            BudgetCategory.OTHER: 'Other'
        }
        return fec_mapping.get(expense.category, 'Other')
    
    @staticmethod
    def requires_itemization(expense: Expense) -> bool:
        """Check if expense requires itemized reporting."""
        return float(expense.amount) >= FECBudgetCompliance.ITEMIZATION_THRESHOLD
    
    @staticmethod
    def generate_disbursement_record(expense: Expense) -> Dict[str, Any]:
        """Generate FEC disbursement record format."""
        return {
            'disbursement_date': expense.paid_date.strftime('%Y%m%d') if expense.paid_date else '',
            'recipient_name': expense.vendor_name,
            'recipient_city': '',  # Would need vendor address
            'recipient_state': '',
            'recipient_zip': '',
            'disbursement_purpose': expense.description[:100],
            'disbursement_category': FECBudgetCompliance.categorize_expense_for_fec(expense),
            'amount': float(expense.amount),
            'memo_code': '',
            'memo_text': expense.description
        }


# ============================================================================
# MULTI-CANDIDATE ALLOCATION
# ============================================================================

class MultiCandidateAllocator:
    """Allocate shared expenses across multiple candidates."""
    
    def __init__(self, budget_manager: BudgetManager):
        self.budget_manager = budget_manager
    
    async def allocate_shared_expense(
        self,
        total_amount: Decimal,
        candidate_budgets: List[str],
        allocation_method: str = 'equal',
        weights: Optional[Dict[str, float]] = None,
        vendor_name: str = '',
        description: str = '',
        category: BudgetCategory = BudgetCategory.OTHER
    ) -> List[Expense]:
        """
        Allocate a shared expense across multiple candidates.
        
        Methods:
        - 'equal': Split equally
        - 'weighted': Use provided weights
        - 'budget_proportional': Based on total budget size
        """
        if not candidate_budgets:
            raise ValueError("No candidate budgets provided")
        
        # Calculate allocation amounts
        allocations = {}
        
        if allocation_method == 'equal':
            per_candidate = total_amount / Decimal(str(len(candidate_budgets)))
            for budget_id in candidate_budgets:
                allocations[budget_id] = per_candidate
        
        elif allocation_method == 'weighted':
            if not weights:
                raise ValueError("Weights required for weighted allocation")
            total_weight = sum(weights.values())
            for budget_id in candidate_budgets:
                weight = weights.get(budget_id, 0)
                allocations[budget_id] = total_amount * Decimal(str(weight / total_weight))
        
        elif allocation_method == 'budget_proportional':
            total_budget = sum(
                self.budget_manager.budgets[b].total_budget
                for b in candidate_budgets
                if b in self.budget_manager.budgets
            )
            for budget_id in candidate_budgets:
                if budget_id in self.budget_manager.budgets:
                    budget = self.budget_manager.budgets[budget_id]
                    proportion = budget.total_budget / total_budget
                    allocations[budget_id] = total_amount * proportion
        
        # Create expenses for each candidate
        expenses = []
        for budget_id, amount in allocations.items():
            expense = await self.budget_manager.submit_expense(
                budget_id=budget_id,
                category=category,
                amount=amount.quantize(Decimal('0.01'), rounding=ROUND_HALF_UP),
                vendor_name=vendor_name,
                description=f"[SHARED] {description}",
                submitted_by='system'
            )
            expenses.append(expense)
        
        logger.info(
            f"Allocated ${total_amount:,.2f} across {len(candidate_budgets)} candidates "
            f"using {allocation_method} method"
        )
        
        return expenses


# ============================================================================
# MAIN ENTRY POINT
# ============================================================================

async def main():
    """Demo the budget management system."""
    manager = BudgetManager()
    
    # Create a candidate budget
    budget = await manager.create_budget(
        name="Dave Boliek for NC Supreme Court",
        level=BudgetLevel.CANDIDATE,
        total_budget=Decimal('250000.00'),
        candidate_id='dave-boliek-001'
    )
    
    # Allocate funds by category
    await manager.allocate_funds(
        budget.budget_id,
        BudgetCategory.ADVERTISING,
        Decimal('75000.00')
    )
    await manager.allocate_funds(
        budget.budget_id,
        BudgetCategory.DIRECT_MAIL,
        Decimal('50000.00')
    )
    await manager.allocate_funds(
        budget.budget_id,
        BudgetCategory.DIGITAL,
        Decimal('40000.00')
    )
    await manager.allocate_funds(
        budget.budget_id,
        BudgetCategory.EVENTS,
        Decimal('25000.00')
    )
    await manager.allocate_funds(
        budget.budget_id,
        BudgetCategory.STAFF,
        Decimal('35000.00')
    )
    await manager.allocate_funds(
        budget.budget_id,
        BudgetCategory.CONSULTING,
        Decimal('25000.00')
    )
    
    # Submit some expenses
    expense1 = await manager.submit_expense(
        budget.budget_id,
        BudgetCategory.ADVERTISING,
        Decimal('5000.00'),
        'WRAL-TV',
        'TV spot - 30 second ad buy',
        'campaign_manager'
    )
    
    expense2 = await manager.submit_expense(
        budget.budget_id,
        BudgetCategory.DIRECT_MAIL,
        Decimal('8500.00'),
        'Heritage Printing',
        'Voter guide mailer - 50,000 pieces',
        'campaign_manager'
    )
    
    # Approve and pay expenses
    await manager.approve_expense(expense1.expense_id, 'eddie_broyhill')
    await manager.pay_expense(expense1.expense_id)
    
    # Get reports
    summary = manager.get_budget_summary(budget.budget_id)
    print("\n=== BUDGET SUMMARY ===")
    print(json.dumps(summary, indent=2))
    
    variance = manager.get_variance_report(budget.budget_id)
    print("\n=== VARIANCE REPORT ===")
    print(json.dumps(variance, indent=2))
    
    alerts = manager.get_active_alerts(budget.budget_id)
    print("\n=== ACTIVE ALERTS ===")
    print(json.dumps(alerts, indent=2))
    
    # Generate forecast
    forecasts = await manager.generate_forecast(budget.budget_id, periods_ahead=3)
    print("\n=== SPENDING FORECAST ===")
    for f in forecasts:
        print(f"  {f.forecast_date.strftime('%B %Y')}: ${f.projected_spend:,.2f} (confidence: {f.confidence_score:.0%})")


if __name__ == '__main__':
    asyncio.run(main())
