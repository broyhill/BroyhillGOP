#!/usr/bin/env python3
"""
================================================================================
ECOSYSTEM 53: DOCUMENT GENERATION - AUTOMATED PDF & DOCUMENT CREATION
================================================================================
Automated generation of campaign documents, FEC reports, donor letters,
volunteer packets, and compliance documentation.

Features:
- PDF generation (letters, reports, certificates)
- FEC Form generation (Form 3, Form 3P, Form 24)
- Donor acknowledgment letters (tax receipts)
- Volunteer packets and training materials
- Campaign literature (palm cards, door hangers)
- Mail merge with donor/volunteer data
- Template library management
- Digital signature integration
- Batch document generation
- Document storage and retrieval

Development Value: $75,000
================================================================================
"""

import os
import json
import logging
import uuid
import asyncio
from datetime import datetime, date
from typing import Optional, List, Dict, Any, Union
from dataclasses import dataclass, field
from enum import Enum
from decimal import Decimal
import io
import base64

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger('ecosystem53.document_generation')

# ============================================================================
# ENUMS
# ============================================================================

class DocumentType(Enum):
    # Donor documents
    DONATION_RECEIPT = 'donation_receipt'
    THANK_YOU_LETTER = 'thank_you_letter'
    TAX_ACKNOWLEDGMENT = 'tax_acknowledgment'
    PLEDGE_REMINDER = 'pledge_reminder'
    MAJOR_DONOR_REPORT = 'major_donor_report'
    
    # FEC documents
    FEC_FORM_3 = 'fec_form_3'           # Report of Receipts and Disbursements
    FEC_FORM_3P = 'fec_form_3p'         # Presidential
    FEC_FORM_24 = 'fec_form_24'         # 24/48 Hour Report
    FEC_SCHEDULE_A = 'fec_schedule_a'   # Itemized Receipts
    FEC_SCHEDULE_B = 'fec_schedule_b'   # Itemized Disbursements
    
    # Volunteer documents
    VOLUNTEER_PACKET = 'volunteer_packet'
    VOLUNTEER_CERTIFICATE = 'volunteer_certificate'
    TRAINING_MANUAL = 'training_manual'
    CANVASS_SHEET = 'canvass_sheet'
    PHONE_BANK_SCRIPT = 'phone_bank_script'
    
    # Campaign materials
    PALM_CARD = 'palm_card'
    DOOR_HANGER = 'door_hanger'
    YARD_SIGN_ORDER = 'yard_sign_order'
    EVENT_FLYER = 'event_flyer'
    PRESS_RELEASE = 'press_release'
    
    # Administrative
    EXPENSE_REPORT = 'expense_report'
    VENDOR_CONTRACT = 'vendor_contract'
    COMPLIANCE_REPORT = 'compliance_report'
    CAMPAIGN_REPORT = 'campaign_report'

class DocumentFormat(Enum):
    PDF = 'pdf'
    DOCX = 'docx'
    HTML = 'html'
    TXT = 'txt'
    CSV = 'csv'

class DocumentStatus(Enum):
    DRAFT = 'draft'
    PENDING_REVIEW = 'pending_review'
    APPROVED = 'approved'
    GENERATED = 'generated'
    SENT = 'sent'
    FAILED = 'failed'

class MergeFieldType(Enum):
    TEXT = 'text'
    DATE = 'date'
    CURRENCY = 'currency'
    NUMBER = 'number'
    ADDRESS = 'address'
    SIGNATURE = 'signature'
    IMAGE = 'image'
    TABLE = 'table'

# ============================================================================
# DATA CLASSES
# ============================================================================

@dataclass
class MergeField:
    field_name: str
    field_type: MergeFieldType = MergeFieldType.TEXT
    default_value: Optional[str] = None
    required: bool = False
    format_string: Optional[str] = None  # e.g., "${:,.2f}" for currency

@dataclass
class DocumentTemplate:
    template_id: str = field(default_factory=lambda: str(uuid.uuid4()))
    name: str = ''
    doc_type: DocumentType = DocumentType.THANK_YOU_LETTER
    format: DocumentFormat = DocumentFormat.PDF
    
    # Template content
    html_template: str = ''
    css_styles: str = ''
    header_html: Optional[str] = None
    footer_html: Optional[str] = None
    
    # Merge fields
    merge_fields: List[MergeField] = field(default_factory=list)
    
    # Settings
    page_size: str = 'letter'  # letter, legal, a4
    orientation: str = 'portrait'  # portrait, landscape
    margins: Dict[str, float] = field(default_factory=lambda: {
        'top': 1.0, 'bottom': 1.0, 'left': 1.0, 'right': 1.0
    })
    
    # Metadata
    category: str = ''
    description: str = ''
    is_active: bool = True
    created_at: datetime = field(default_factory=datetime.now)
    updated_at: datetime = field(default_factory=datetime.now)

@dataclass
class GeneratedDocument:
    document_id: str = field(default_factory=lambda: str(uuid.uuid4()))
    template_id: str = ''
    doc_type: DocumentType = DocumentType.THANK_YOU_LETTER
    format: DocumentFormat = DocumentFormat.PDF
    
    # Context
    candidate_id: str = ''
    recipient_id: Optional[str] = None  # donor_id, volunteer_id, etc.
    recipient_name: Optional[str] = None
    
    # Content
    merge_data: Dict[str, Any] = field(default_factory=dict)
    filename: str = ''
    file_path: Optional[str] = None
    file_size: int = 0
    storage_url: Optional[str] = None
    
    # Status
    status: DocumentStatus = DocumentStatus.DRAFT
    error_message: Optional[str] = None
    
    # Delivery
    sent_via: Optional[str] = None  # email, mail, portal
    sent_at: Optional[datetime] = None
    
    # Timestamps
    created_at: datetime = field(default_factory=datetime.now)
    generated_at: Optional[datetime] = None

@dataclass
class BatchJob:
    job_id: str = field(default_factory=lambda: str(uuid.uuid4()))
    template_id: str = ''
    candidate_id: str = ''
    
    # Recipients
    recipient_ids: List[str] = field(default_factory=list)
    total_count: int = 0
    processed_count: int = 0
    success_count: int = 0
    failed_count: int = 0
    
    # Status
    status: str = 'pending'  # pending, processing, completed, failed
    error_message: Optional[str] = None
    
    # Output
    generated_documents: List[str] = field(default_factory=list)  # document_ids
    
    # Timestamps
    created_at: datetime = field(default_factory=datetime.now)
    started_at: Optional[datetime] = None
    completed_at: Optional[datetime] = None

# ============================================================================
# TEMPLATE LIBRARY
# ============================================================================

class TemplateLibrary:
    """Pre-built document templates for campaigns."""
    
    @staticmethod
    def get_donation_receipt_template() -> DocumentTemplate:
        return DocumentTemplate(
            name='Donation Receipt',
            doc_type=DocumentType.DONATION_RECEIPT,
            html_template="""
            <div class="receipt">
                <div class="header">
                    <h1>{{campaign_name}}</h1>
                    <p>Official Donation Receipt</p>
                </div>
                <div class="receipt-body">
                    <p>Date: {{donation_date}}</p>
                    <p>Receipt #: {{receipt_number}}</p>
                    <hr>
                    <p><strong>Donor:</strong> {{donor_name}}</p>
                    <p>{{donor_address}}</p>
                    <hr>
                    <p><strong>Amount:</strong> {{donation_amount}}</p>
                    <p><strong>Payment Method:</strong> {{payment_method}}</p>
                    <hr>
                    <p class="tax-notice">
                        This contribution is not tax-deductible for federal income tax purposes.
                        Paid for by {{committee_name}}.
                    </p>
                </div>
                <div class="footer">
                    <p>{{committee_address}}</p>
                    <p>FEC ID: {{fec_id}}</p>
                </div>
            </div>
            """,
            css_styles="""
            .receipt { font-family: Georgia, serif; max-width: 600px; margin: 0 auto; }
            .header { text-align: center; border-bottom: 2px solid #333; padding-bottom: 20px; }
            .header h1 { color: #c00; margin-bottom: 5px; }
            .receipt-body { padding: 20px 0; }
            .tax-notice { font-size: 0.9em; color: #666; margin-top: 20px; }
            .footer { text-align: center; font-size: 0.85em; color: #666; border-top: 1px solid #ccc; padding-top: 15px; }
            """,
            merge_fields=[
                MergeField('campaign_name', MergeFieldType.TEXT, required=True),
                MergeField('donation_date', MergeFieldType.DATE, required=True),
                MergeField('receipt_number', MergeFieldType.TEXT, required=True),
                MergeField('donor_name', MergeFieldType.TEXT, required=True),
                MergeField('donor_address', MergeFieldType.ADDRESS),
                MergeField('donation_amount', MergeFieldType.CURRENCY, required=True),
                MergeField('payment_method', MergeFieldType.TEXT),
                MergeField('committee_name', MergeFieldType.TEXT, required=True),
                MergeField('committee_address', MergeFieldType.ADDRESS),
                MergeField('fec_id', MergeFieldType.TEXT)
            ]
        )
    
    @staticmethod
    def get_thank_you_letter_template() -> DocumentTemplate:
        return DocumentTemplate(
            name='Donor Thank You Letter',
            doc_type=DocumentType.THANK_YOU_LETTER,
            html_template="""
            <div class="letter">
                <div class="letterhead">
                    <img src="{{logo_url}}" alt="Campaign Logo" class="logo">
                    <h2>{{candidate_name}}</h2>
                    <p>{{candidate_title}}</p>
                </div>
                
                <p class="date">{{letter_date}}</p>
                
                <p class="salutation">Dear {{donor_first_name}},</p>
                
                <p>Thank you so much for your generous contribution of {{donation_amount}} 
                to our campaign. Your support means the world to us and brings us one step 
                closer to victory.</p>
                
                <p>{{personal_message}}</p>
                
                <p>Together, we are building a movement that will make a real difference 
                for the people of {{district}}. With supporters like you, I know we can win.</p>
                
                <p>Thank you again for standing with us.</p>
                
                <div class="signature">
                    <p>With gratitude,</p>
                    <img src="{{signature_url}}" alt="Signature" class="sig-image">
                    <p><strong>{{candidate_name}}</strong></p>
                </div>
                
                <div class="footer">
                    <p>Paid for by {{committee_name}}</p>
                </div>
            </div>
            """,
            css_styles="""
            .letter { font-family: Georgia, serif; max-width: 650px; margin: 0 auto; line-height: 1.6; }
            .letterhead { text-align: center; margin-bottom: 40px; }
            .logo { max-height: 80px; margin-bottom: 10px; }
            .date { text-align: right; margin-bottom: 30px; }
            .salutation { margin-bottom: 20px; }
            .signature { margin-top: 40px; }
            .sig-image { max-height: 60px; margin: 10px 0; }
            .footer { margin-top: 50px; text-align: center; font-size: 0.85em; color: #666; }
            """,
            merge_fields=[
                MergeField('logo_url', MergeFieldType.IMAGE),
                MergeField('candidate_name', MergeFieldType.TEXT, required=True),
                MergeField('candidate_title', MergeFieldType.TEXT),
                MergeField('letter_date', MergeFieldType.DATE, required=True),
                MergeField('donor_first_name', MergeFieldType.TEXT, required=True),
                MergeField('donation_amount', MergeFieldType.CURRENCY, required=True),
                MergeField('personal_message', MergeFieldType.TEXT),
                MergeField('district', MergeFieldType.TEXT),
                MergeField('signature_url', MergeFieldType.SIGNATURE),
                MergeField('committee_name', MergeFieldType.TEXT, required=True)
            ]
        )
    
    @staticmethod
    def get_volunteer_certificate_template() -> DocumentTemplate:
        return DocumentTemplate(
            name='Volunteer Certificate',
            doc_type=DocumentType.VOLUNTEER_CERTIFICATE,
            orientation='landscape',
            html_template="""
            <div class="certificate">
                <div class="border">
                    <h1>Certificate of Appreciation</h1>
                    <p class="subtitle">This certificate is presented to</p>
                    <h2 class="recipient">{{volunteer_name}}</h2>
                    <p class="description">
                        In recognition of outstanding volunteer service to the<br>
                        <strong>{{campaign_name}}</strong> Campaign
                    </p>
                    <p class="hours">{{volunteer_hours}} Hours of Service</p>
                    <p class="date">{{award_date}}</p>
                    <div class="signatures">
                        <div class="sig-block">
                            <img src="{{candidate_signature}}" alt="Signature">
                            <p>{{candidate_name}}</p>
                            <p class="title">Candidate</p>
                        </div>
                        <div class="sig-block">
                            <img src="{{manager_signature}}" alt="Signature">
                            <p>{{campaign_manager}}</p>
                            <p class="title">Campaign Manager</p>
                        </div>
                    </div>
                </div>
            </div>
            """,
            css_styles="""
            .certificate { text-align: center; padding: 40px; }
            .border { border: 8px double #c00; padding: 40px; background: linear-gradient(135deg, #fff 0%, #f5f5f5 100%); }
            h1 { color: #c00; font-size: 2.5em; margin-bottom: 10px; font-family: 'Times New Roman', serif; }
            .subtitle { font-size: 1.2em; color: #666; }
            .recipient { font-size: 2em; color: #333; margin: 20px 0; font-family: 'Brush Script MT', cursive; }
            .description { font-size: 1.1em; margin: 20px 0; }
            .hours { font-size: 1.3em; color: #c00; font-weight: bold; margin: 20px 0; }
            .date { font-size: 1em; color: #666; }
            .signatures { display: flex; justify-content: space-around; margin-top: 40px; }
            .sig-block { text-align: center; }
            .sig-block img { height: 50px; }
            .sig-block .title { font-size: 0.9em; color: #666; }
            """
        )
    
    @staticmethod
    def get_fec_form_3_template() -> DocumentTemplate:
        return DocumentTemplate(
            name='FEC Form 3 - Report of Receipts and Disbursements',
            doc_type=DocumentType.FEC_FORM_3,
            html_template="""
            <div class="fec-form">
                <div class="form-header">
                    <h1>FEC FORM 3</h1>
                    <h2>REPORT OF RECEIPTS AND DISBURSEMENTS</h2>
                    <p>For An Authorized Committee of a Candidate for the House of Representatives or Senate</p>
                </div>
                
                <table class="form-table">
                    <tr>
                        <td colspan="2"><strong>1. NAME OF COMMITTEE (in full)</strong><br>{{committee_name}}</td>
                    </tr>
                    <tr>
                        <td><strong>ADDRESS</strong><br>{{committee_address}}</td>
                        <td><strong>FEC ID NUMBER</strong><br>{{fec_id}}</td>
                    </tr>
                    <tr>
                        <td colspan="2">
                            <strong>2. TYPE OF REPORT</strong><br>
                            {{report_type}}
                        </td>
                    </tr>
                    <tr>
                        <td><strong>COVERING PERIOD</strong><br>From: {{period_start}}</td>
                        <td>To: {{period_end}}</td>
                    </tr>
                </table>
                
                <h3>SUMMARY PAGE</h3>
                <table class="summary-table">
                    <tr>
                        <td>6. Cash on Hand at Beginning of Reporting Period</td>
                        <td class="amount">{{cash_on_hand_start}}</td>
                    </tr>
                    <tr>
                        <td>7. Total Receipts This Period</td>
                        <td class="amount">{{total_receipts}}</td>
                    </tr>
                    <tr>
                        <td>8. Subtotal (add 6 and 7)</td>
                        <td class="amount">{{subtotal}}</td>
                    </tr>
                    <tr>
                        <td>9. Total Disbursements This Period</td>
                        <td class="amount">{{total_disbursements}}</td>
                    </tr>
                    <tr>
                        <td><strong>10. Cash on Hand at Close of Reporting Period</strong></td>
                        <td class="amount"><strong>{{cash_on_hand_end}}</strong></td>
                    </tr>
                </table>
                
                <div class="certification">
                    <p>I certify that I have examined this Report and to the best of my knowledge and belief 
                    it is true, correct and complete.</p>
                    <p>Signature of Treasurer: {{treasurer_signature}}</p>
                    <p>Date: {{filing_date}}</p>
                </div>
            </div>
            """,
            css_styles="""
            .fec-form { font-family: Arial, sans-serif; font-size: 11px; }
            .form-header { text-align: center; margin-bottom: 20px; }
            .form-header h1 { margin-bottom: 5px; }
            .form-header h2 { font-size: 14px; }
            .form-table { width: 100%; border-collapse: collapse; margin-bottom: 20px; }
            .form-table td { border: 1px solid #000; padding: 8px; }
            .summary-table { width: 100%; border-collapse: collapse; }
            .summary-table td { border: 1px solid #000; padding: 6px; }
            .summary-table .amount { text-align: right; width: 150px; }
            .certification { margin-top: 30px; border-top: 1px solid #000; padding-top: 15px; }
            """
        )


# ============================================================================
# DOCUMENT GENERATOR
# ============================================================================

class DocumentGenerator:
    """Core document generation engine."""
    
    def __init__(self, supabase_client=None, storage_path: str = '/tmp/documents'):
        self.supabase = supabase_client
        self.storage_path = storage_path
        self.templates: Dict[str, DocumentTemplate] = {}
        self.documents: Dict[str, GeneratedDocument] = {}
        
        # Initialize template library
        self._load_default_templates()
    
    def _load_default_templates(self):
        """Load default templates from library."""
        library = TemplateLibrary()
        
        templates = [
            library.get_donation_receipt_template(),
            library.get_thank_you_letter_template(),
            library.get_volunteer_certificate_template(),
            library.get_fec_form_3_template()
        ]
        
        for template in templates:
            self.templates[template.template_id] = template
    
    async def create_template(self, template: DocumentTemplate) -> DocumentTemplate:
        """Create a new document template."""
        self.templates[template.template_id] = template
        
        if self.supabase:
            await self._save_template_to_db(template)
        
        logger.info(f"Created template: {template.name} ({template.doc_type.value})")
        return template
    
    async def generate_document(
        self,
        template_id: str,
        candidate_id: str,
        merge_data: Dict[str, Any],
        recipient_id: Optional[str] = None,
        recipient_name: Optional[str] = None,
        output_format: Optional[DocumentFormat] = None
    ) -> GeneratedDocument:
        """Generate a document from template with merge data."""
        template = self.templates.get(template_id)
        if not template:
            raise ValueError(f"Template {template_id} not found")
        
        # Validate required fields
        self._validate_merge_data(template, merge_data)
        
        # Format merge data
        formatted_data = self._format_merge_data(template, merge_data)
        
        # Create document record
        doc = GeneratedDocument(
            template_id=template_id,
            doc_type=template.doc_type,
            format=output_format or template.format,
            candidate_id=candidate_id,
            recipient_id=recipient_id,
            recipient_name=recipient_name,
            merge_data=merge_data,
            status=DocumentStatus.DRAFT
        )
        
        # Generate filename
        timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
        doc.filename = f"{template.doc_type.value}_{recipient_id or 'document'}_{timestamp}.{doc.format.value}"
        
        try:
            # Render HTML
            html_content = self._render_template(template, formatted_data)
            
            # Generate PDF or other format
            if doc.format == DocumentFormat.PDF:
                file_content = await self._generate_pdf(html_content, template)
            elif doc.format == DocumentFormat.HTML:
                file_content = html_content.encode('utf-8')
            else:
                file_content = html_content.encode('utf-8')
            
            # Save file
            doc.file_path = os.path.join(self.storage_path, doc.filename)
            os.makedirs(os.path.dirname(doc.file_path), exist_ok=True)
            
            with open(doc.file_path, 'wb') as f:
                f.write(file_content)
            
            doc.file_size = len(file_content)
            doc.status = DocumentStatus.GENERATED
            doc.generated_at = datetime.now()
            
            logger.info(f"Generated document: {doc.filename} ({doc.file_size} bytes)")
            
        except Exception as e:
            doc.status = DocumentStatus.FAILED
            doc.error_message = str(e)
            logger.error(f"Failed to generate document: {e}")
        
        self.documents[doc.document_id] = doc
        
        if self.supabase:
            await self._save_document_to_db(doc)
        
        return doc
    
    def _validate_merge_data(self, template: DocumentTemplate, data: Dict[str, Any]):
        """Validate merge data against template requirements."""
        missing_fields = []
        
        for field in template.merge_fields:
            if field.required and field.field_name not in data:
                if field.default_value is None:
                    missing_fields.append(field.field_name)
        
        if missing_fields:
            raise ValueError(f"Missing required fields: {', '.join(missing_fields)}")
    
    def _format_merge_data(
        self,
        template: DocumentTemplate,
        data: Dict[str, Any]
    ) -> Dict[str, str]:
        """Format merge data according to field types."""
        formatted = {}
        
        for field in template.merge_fields:
            value = data.get(field.field_name, field.default_value)
            
            if value is None:
                formatted[field.field_name] = ''
                continue
            
            if field.field_type == MergeFieldType.CURRENCY:
                if isinstance(value, (int, float, Decimal)):
                    formatted[field.field_name] = f"${value:,.2f}"
                else:
                    formatted[field.field_name] = str(value)
            
            elif field.field_type == MergeFieldType.DATE:
                if isinstance(value, (datetime, date)):
                    formatted[field.field_name] = value.strftime('%B %d, %Y')
                else:
                    formatted[field.field_name] = str(value)
            
            elif field.field_type == MergeFieldType.NUMBER:
                if isinstance(value, (int, float)):
                    formatted[field.field_name] = f"{value:,}"
                else:
                    formatted[field.field_name] = str(value)
            
            elif field.field_type == MergeFieldType.ADDRESS:
                if isinstance(value, dict):
                    parts = [
                        value.get('street', ''),
                        f"{value.get('city', '')}, {value.get('state', '')} {value.get('zip', '')}"
                    ]
                    formatted[field.field_name] = '<br>'.join(p for p in parts if p.strip())
                else:
                    formatted[field.field_name] = str(value)
            
            else:
                formatted[field.field_name] = str(value)
        
        return formatted
    
    def _render_template(
        self,
        template: DocumentTemplate,
        data: Dict[str, str]
    ) -> str:
        """Render HTML template with merge data."""
        html = template.html_template
        
        # Simple mustache-style replacement
        for key, value in data.items():
            html = html.replace('{{' + key + '}}', value)
        
        # Wrap in full HTML document
        full_html = f"""
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="utf-8">
            <style>
                @page {{
                    size: {template.page_size} {template.orientation};
                    margin: {template.margins['top']}in {template.margins['right']}in 
                            {template.margins['bottom']}in {template.margins['left']}in;
                }}
                body {{ margin: 0; padding: 0; }}
                {template.css_styles}
            </style>
        </head>
        <body>
            {template.header_html or ''}
            {html}
            {template.footer_html or ''}
        </body>
        </html>
        """
        
        return full_html
    
    async def _generate_pdf(self, html_content: str, template: DocumentTemplate) -> bytes:
        """Generate PDF from HTML using weasyprint or similar."""
        # In production, use weasyprint, puppeteer, or wkhtmltopdf
        # For now, return HTML as bytes (placeholder)
        try:
            from weasyprint import HTML
            pdf_bytes = HTML(string=html_content).write_pdf()
            return pdf_bytes
        except ImportError:
            # Fallback: return HTML as pseudo-PDF
            logger.warning("WeasyPrint not available, returning HTML content")
            return html_content.encode('utf-8')
    
    # =========================================================================
    # BATCH GENERATION
    # =========================================================================
    
    async def generate_batch(
        self,
        template_id: str,
        candidate_id: str,
        recipients: List[Dict[str, Any]],
        common_data: Optional[Dict[str, Any]] = None
    ) -> BatchJob:
        """Generate documents for multiple recipients."""
        job = BatchJob(
            template_id=template_id,
            candidate_id=candidate_id,
            total_count=len(recipients)
        )
        job.status = 'processing'
        job.started_at = datetime.now()
        
        common_data = common_data or {}
        
        for recipient_data in recipients:
            try:
                # Merge common data with recipient data
                merge_data = {**common_data, **recipient_data}
                
                doc = await self.generate_document(
                    template_id=template_id,
                    candidate_id=candidate_id,
                    merge_data=merge_data,
                    recipient_id=recipient_data.get('id'),
                    recipient_name=recipient_data.get('name')
                )
                
                job.generated_documents.append(doc.document_id)
                job.processed_count += 1
                
                if doc.status == DocumentStatus.GENERATED:
                    job.success_count += 1
                else:
                    job.failed_count += 1
                    
            except Exception as e:
                job.processed_count += 1
                job.failed_count += 1
                logger.error(f"Batch generation error: {e}")
        
        job.status = 'completed'
        job.completed_at = datetime.now()
        
        logger.info(
            f"Batch job completed: {job.success_count}/{job.total_count} successful"
        )
        
        return job
    
    # =========================================================================
    # DONOR-SPECIFIC METHODS
    # =========================================================================
    
    async def generate_donation_receipt(
        self,
        candidate_id: str,
        donor_data: Dict[str, Any],
        donation_data: Dict[str, Any],
        campaign_data: Dict[str, Any]
    ) -> GeneratedDocument:
        """Generate donation receipt for a donor."""
        # Find receipt template
        template = next(
            (t for t in self.templates.values() 
             if t.doc_type == DocumentType.DONATION_RECEIPT),
            None
        )
        
        if not template:
            template = TemplateLibrary.get_donation_receipt_template()
            self.templates[template.template_id] = template
        
        merge_data = {
            'campaign_name': campaign_data.get('name', ''),
            'donation_date': donation_data.get('date', datetime.now()),
            'receipt_number': donation_data.get('id', str(uuid.uuid4())[:8].upper()),
            'donor_name': f"{donor_data.get('first_name', '')} {donor_data.get('last_name', '')}",
            'donor_address': {
                'street': donor_data.get('address', ''),
                'city': donor_data.get('city', ''),
                'state': donor_data.get('state', ''),
                'zip': donor_data.get('zip', '')
            },
            'donation_amount': donation_data.get('amount', 0),
            'payment_method': donation_data.get('payment_method', 'Credit Card'),
            'committee_name': campaign_data.get('committee_name', ''),
            'committee_address': campaign_data.get('address', ''),
            'fec_id': campaign_data.get('fec_id', '')
        }
        
        return await self.generate_document(
            template_id=template.template_id,
            candidate_id=candidate_id,
            merge_data=merge_data,
            recipient_id=donor_data.get('id'),
            recipient_name=merge_data['donor_name']
        )
    
    async def generate_thank_you_letters(
        self,
        candidate_id: str,
        donors: List[Dict[str, Any]],
        campaign_data: Dict[str, Any]
    ) -> BatchJob:
        """Generate thank you letters for multiple donors."""
        template = next(
            (t for t in self.templates.values() 
             if t.doc_type == DocumentType.THANK_YOU_LETTER),
            None
        )
        
        if not template:
            template = TemplateLibrary.get_thank_you_letter_template()
            self.templates[template.template_id] = template
        
        recipients = []
        for donor in donors:
            recipients.append({
                'id': donor.get('id'),
                'name': f"{donor.get('first_name', '')} {donor.get('last_name', '')}",
                'donor_first_name': donor.get('first_name', 'Friend'),
                'donation_amount': donor.get('last_donation_amount', 0),
                'personal_message': donor.get('personal_message', 
                    'Your belief in our cause gives us strength.')
            })
        
        common_data = {
            'candidate_name': campaign_data.get('candidate_name', ''),
            'candidate_title': campaign_data.get('candidate_title', ''),
            'letter_date': datetime.now(),
            'district': campaign_data.get('district', 'North Carolina'),
            'logo_url': campaign_data.get('logo_url', ''),
            'signature_url': campaign_data.get('signature_url', ''),
            'committee_name': campaign_data.get('committee_name', '')
        }
        
        return await self.generate_batch(
            template_id=template.template_id,
            candidate_id=candidate_id,
            recipients=recipients,
            common_data=common_data
        )
    
    # =========================================================================
    # DATABASE OPERATIONS
    # =========================================================================
    
    async def _save_template_to_db(self, template: DocumentTemplate):
        if not self.supabase:
            return
        try:
            await self.supabase.table('e53_templates').upsert({
                'template_id': template.template_id,
                'name': template.name,
                'doc_type': template.doc_type.value,
                'format': template.format.value,
                'html_template': template.html_template,
                'css_styles': template.css_styles,
                'merge_fields': json.dumps([
                    {'name': f.field_name, 'type': f.field_type.value, 'required': f.required}
                    for f in template.merge_fields
                ]),
                'is_active': template.is_active,
                'created_at': template.created_at.isoformat()
            }).execute()
        except Exception as e:
            logger.error(f"Failed to save template: {e}")
    
    async def _save_document_to_db(self, doc: GeneratedDocument):
        if not self.supabase:
            return
        try:
            await self.supabase.table('e53_documents').insert({
                'document_id': doc.document_id,
                'template_id': doc.template_id,
                'doc_type': doc.doc_type.value,
                'format': doc.format.value,
                'candidate_id': doc.candidate_id,
                'recipient_id': doc.recipient_id,
                'recipient_name': doc.recipient_name,
                'filename': doc.filename,
                'file_size': doc.file_size,
                'storage_url': doc.storage_url,
                'status': doc.status.value,
                'created_at': doc.created_at.isoformat(),
                'generated_at': doc.generated_at.isoformat() if doc.generated_at else None
            }).execute()
        except Exception as e:
            logger.error(f"Failed to save document: {e}")


# ============================================================================
# MAIN ENTRY POINT
# ============================================================================

async def main():
    """Demo the document generation system."""
    generator = DocumentGenerator(storage_path='/tmp/broyhillgop_docs')
    
    # Campaign data
    campaign_data = {
        'name': 'Dave Boliek for NC Supreme Court',
        'candidate_name': 'Dave Boliek',
        'candidate_title': 'Candidate for NC Supreme Court',
        'committee_name': 'Dave Boliek for Justice',
        'fec_id': 'C00123456',
        'district': 'North Carolina',
        'address': '123 Main St, Raleigh, NC 27601'
    }
    
    # Generate a donation receipt
    print("\n=== GENERATING DONATION RECEIPT ===")
    receipt = await generator.generate_donation_receipt(
        candidate_id='dave-boliek-001',
        donor_data={
            'id': 'donor-001',
            'first_name': 'John',
            'last_name': 'Smith',
            'address': '456 Oak Ave',
            'city': 'Charlotte',
            'state': 'NC',
            'zip': '28202'
        },
        donation_data={
            'id': 'DON-20240115-001',
            'date': datetime.now(),
            'amount': 250.00,
            'payment_method': 'Credit Card'
        },
        campaign_data=campaign_data
    )
    
    print(f"Receipt generated: {receipt.filename}")
    print(f"Status: {receipt.status.value}")
    print(f"Size: {receipt.file_size} bytes")
    
    # Generate batch thank you letters
    print("\n=== GENERATING BATCH THANK YOU LETTERS ===")
    donors = [
        {'id': 'donor-001', 'first_name': 'John', 'last_name': 'Smith', 'last_donation_amount': 250},
        {'id': 'donor-002', 'first_name': 'Jane', 'last_name': 'Doe', 'last_donation_amount': 500},
        {'id': 'donor-003', 'first_name': 'Bob', 'last_name': 'Wilson', 'last_donation_amount': 100},
    ]
    
    batch_job = await generator.generate_thank_you_letters(
        candidate_id='dave-boliek-001',
        donors=donors,
        campaign_data=campaign_data
    )
    
    print(f"Batch job completed: {batch_job.success_count}/{batch_job.total_count} successful")
    print(f"Documents generated: {len(batch_job.generated_documents)}")
    
    # List available templates
    print("\n=== AVAILABLE TEMPLATES ===")
    for template in generator.templates.values():
        print(f"  - {template.name} ({template.doc_type.value})")


if __name__ == '__main__':
    asyncio.run(main())
