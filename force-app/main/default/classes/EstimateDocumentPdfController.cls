public with sharing class EstimateDocumentPdfController {
    public String addresseeName { get; private set; }
    public String companyName { get; private set; }
    public String documentTitle { get; private set; }
    public String estimateDateLabel { get; private set; }
    public String validDateLabel { get; private set; }
    public String issueDateLabel { get; private set; }
    public String termLabel { get; private set; }
    public String typeLabel { get; private set; }
    public String noteText { get; private set; }
    public String historyName { get; private set; }
    public Decimal lineTotal { get; private set; }
    public Decimal taxAmount { get; private set; }
    public Decimal lineTotalInclTax { get; private set; }
    public String taxPercentLabel { get; private set; }
    public List<LineView> lines { get; private set; }
    public Boolean hasContext { get; private set; }

    public class LineView {
        public String productName { get; set; }
        public Decimal quantity { get; set; }
        public String unit { get; set; }
        public Decimal unitPrice { get; set; }
        public Decimal amount { get; set; }
        public String periodLabel { get; set; }
        public String invoiceSetting { get; set; }
        public String typeLabel { get; set; }
    }

    public EstimateDocumentPdfController() {
        Id recordId = parseRecordId();
        if (recordId == null) {
            hasContext = false;
            lines = new List<LineView>();
            return;
        }
        bindContext(EstimateDocumentService.loadContext(recordId));
    }

    public PageReference issuePdf() {
        Id recordId = parseRecordId();
        if (recordId == null) {
            ApexPages.addMessage(
                new ApexPages.Message(
                    ApexPages.Severity.ERROR,
                    '契約履歴IDが指定されていません。'
                )
            );
            return null;
        }

        try {
            EstimateDocumentService.issueEstimateDocument(recordId);
            PageReference pdfPage = Page.EstimateDocumentPdf;
            pdfPage.getParameters().put('id', recordId);
            pdfPage.setRedirect(true);
            return pdfPage;
        } catch (Exception ex) {
            ApexPages.addMessage(
                new ApexPages.Message(
                    ApexPages.Severity.ERROR,
                    ex.getMessage()
                )
            );
            return null;
        }
    }

    private void bindContext(EstimateDocumentService.DocumentContext context) {
        hasContext = context != null;
        if (context == null) {
            lines = new List<LineView>();
            return;
        }

        addresseeName = context.addresseeName;
        companyName = context.companyName;
        documentTitle = context.documentTitle;
        estimateDateLabel = context.estimateDateLabel;
        validDateLabel = context.validDateLabel;
        issueDateLabel = context.issueDateLabel;
        termLabel = context.termLabel;
        typeLabel = context.typeLabel;
        noteText = context.history == null ? null : context.history.Note__c;
        historyName = context.history == null ? null : context.history.Name;
        lineTotal = context.lineTotal;
        taxAmount = context.taxAmount;
        lineTotalInclTax = context.lineTotalInclTax;
        taxPercentLabel = context.taxPercentLabel;

        lines = new List<LineView>();
        if (context.lines == null) {
            return;
        }
        for (EstimateDocumentService.LineDto line : context.lines) {
            LineView view = new LineView();
            view.productName = line.productName;
            view.quantity = line.quantity;
            view.unit = line.unit;
            view.unitPrice = line.unitPrice;
            view.amount = line.amount;
            view.periodLabel = line.periodLabel;
            view.invoiceSetting = line.invoiceSetting;
            view.typeLabel = line.typeLabel;
            lines.add(view);
        }
    }

    private Id parseRecordId() {
        String rawId = ApexPages.currentPage().getParameters().get('id');
        if (String.isBlank(rawId)) {
            return null;
        }
        try {
            return (Id) rawId;
        } catch (Exception ex) {
            return null;
        }
    }
}
