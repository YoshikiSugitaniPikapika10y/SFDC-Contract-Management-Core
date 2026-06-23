public without sharing class EstimateDocumentService {
    public static final String COMPANY_NAME = 'サンプル株式会社';

    public class LineDto {
        public String productName;
        public Decimal quantity;
        public String unit;
        public Decimal unitPrice;
        public Decimal amount;
        public String periodLabel;
        public String billingType;
        public String invoiceSetting;
        public String typeLabel;
    }

    public class DocumentContext {
        public ContractHistory__c history;
        public List<LineDto> lines;
        public Decimal lineTotal;
        public Decimal taxPercent;
        public Decimal taxAmount;
        public Decimal lineTotalInclTax;
        public String taxPercentLabel;
        public String companyName;
        public String addresseeName;
        public String masterNoteText;
        public String documentTitle;
        public String estimateDateLabel;
        public String validDateLabel;
        public String issueDateLabel;
        public String termLabel;
        public String typeLabel;
    }

    public class IssueResult {
        public Id contentVersionId;
        public String fileName;
        public Date issueDate;
    }

    public class EstimateDocumentException extends Exception {
    }

    public static DocumentContext loadContext(Id contractHistoryId) {
        if (contractHistoryId == null) {
            throw new EstimateDocumentException('契約履歴IDが指定されていません。');
        }

        List<ContractHistory__c> histories = [
            SELECT
                Id,
                Name,
                Type__c,
                historystatus__c,
                EstimateTitleName__c,
                EstimateDate__c,
                EstimateValidDate__c,
                EstimateIssueDate__c,
                Note__c,
                CurrentTermStartDate__c,
                CurrentTermEndDate__c,
                DeltaAmountSum__c,
                EstimateNoteMaster__r.NoteText__c,
                Opportunity__c,
                Opportunity__r.Name,
                ContractService__r.TaxPercent__c,
                ContractService__r.Account__r.Name,
                ContractService__r.BiilingAcccount__r.BillingAddressee__c
            FROM ContractHistory__c
            WHERE Id = :contractHistoryId
            WITH SYSTEM_MODE
            LIMIT 1
        ];
        if (histories.isEmpty()) {
            throw new EstimateDocumentException('契約履歴が見つかりません。');
        }

        DocumentContext context = new DocumentContext();
        context.history = histories[0];
        context.companyName = COMPANY_NAME;
        context.lines = loadLines(contractHistoryId);
        context.lineTotal = resolveLineTotal(context.history, context.lines);
        context.taxPercent = TaxCalculationUtil.resolveTaxPercent(
            context.history.ContractService__r == null
                ? null
                : context.history.ContractService__r.TaxPercent__c
        );
        context.taxAmount = TaxCalculationUtil.calculateTaxAmount(
            context.lineTotal,
            context.taxPercent
        );
        context.lineTotalInclTax = TaxCalculationUtil.calculateAmountInclTax(
            context.lineTotal,
            context.taxPercent
        );
        context.taxPercentLabel = TaxCalculationUtil.formatTaxPercentLabel(
            context.taxPercent
        );
        context.addresseeName = resolveAddresseeName(context.history);
        context.masterNoteText = context.history.EstimateNoteMaster__r == null
            ? null
            : context.history.EstimateNoteMaster__r.NoteText__c;
        context.documentTitle = resolveDocumentTitle(context.history);
        context.estimateDateLabel = formatDisplayDate(context.history.EstimateDate__c);
        context.validDateLabel = formatDisplayDate(context.history.EstimateValidDate__c);
        context.issueDateLabel = formatDisplayDate(context.history.EstimateIssueDate__c);
        context.termLabel = buildTermLabel(
            context.history.CurrentTermStartDate__c,
            context.history.CurrentTermEndDate__c
        );
        context.typeLabel = resolveHistoryTypeLabel(context.history.Type__c);
        return context;
    }

    public static IssueResult issueEstimateDocument(Id contractHistoryId) {
        DocumentContext context = loadContext(contractHistoryId);
        Date issueDate = ensureIssueDate(context.history);
        context.history.EstimateIssueDate__c = issueDate;
        context.issueDateLabel = formatDisplayDate(issueDate);

        String fileName = buildFileName(context.history, issueDate);
        Blob pdfBody = generatePdfBlob(contractHistoryId);
        Id contentVersionId = savePdfToRecord(contractHistoryId, fileName, pdfBody);

        IssueResult result = new IssueResult();
        result.contentVersionId = contentVersionId;
        result.fileName = fileName;
        result.issueDate = issueDate;
        return result;
    }

    public static Date ensureIssueDate(ContractHistory__c history) {
        if (history == null || history.Id == null) {
            throw new EstimateDocumentException('契約履歴が指定されていません。');
        }

        Date today = Date.today();
        ContractHistory__c updateRecord = new ContractHistory__c(Id = history.Id);
        Boolean needsUpdate = false;

        if (history.EstimateIssueDate__c == null) {
            updateRecord.EstimateIssueDate__c = today;
            history.EstimateIssueDate__c = today;
            needsUpdate = true;
        }

        if (history.EstimateDate__c == null) {
            updateRecord.EstimateDate__c = today;
            history.EstimateDate__c = today;
            needsUpdate = true;
        }

        if (needsUpdate) {
            SystemContextAccess.updateRecords(new List<SObject>{ updateRecord });
        }

        return history.EstimateIssueDate__c;
    }

    public static String buildFileName(ContractHistory__c history, Date issueDate) {
        String title = resolveDocumentTitle(history);
        String sanitizedTitle = sanitizeFileName(title);
        Date targetIssueDate = issueDate == null ? Date.today() : issueDate;
        return sanitizedTitle +
            '_' +
            formatFileDate(targetIssueDate) +
            '.pdf';
    }

    public static Id savePdfToRecord(Id recordId, String fileName, Blob pdfBody) {
        if (recordId == null) {
            throw new EstimateDocumentException('保存先の契約履歴IDが指定されていません。');
        }
        if (pdfBody == null || pdfBody.size() == 0) {
            throw new EstimateDocumentException('PDFデータが空です。');
        }

        String normalizedFileName = String.isBlank(fileName) ? 'estimate.pdf' : fileName;
        String title = normalizedFileName.endsWith('.pdf')
            ? normalizedFileName.substring(0, normalizedFileName.length() - 4)
            : normalizedFileName;

        ContentVersion contentVersion = new ContentVersion(
            Title = title,
            PathOnClient = normalizedFileName,
            VersionData = pdfBody
        );
        SystemContextAccess.insertRecords(new List<SObject>{ contentVersion });

        Id contentDocumentId = [
            SELECT ContentDocumentId
            FROM ContentVersion
            WHERE Id = :contentVersion.Id
            WITH SYSTEM_MODE
            LIMIT 1
        ]
        .ContentDocumentId;

        ContentDocumentLink documentLink = new ContentDocumentLink(
            ContentDocumentId = contentDocumentId,
            LinkedEntityId = recordId,
            ShareType = 'V',
            Visibility = 'AllUsers'
        );
        SystemContextAccess.insertRecords(new List<SObject>{ documentLink });
        return contentVersion.Id;
    }

    public static Blob generatePdfBlob(Id contractHistoryId) {
        if (Test.isRunningTest()) {
            return Blob.valueOf('%PDF-1.4 test');
        }

        PageReference pdfPage = Page.EstimateDocumentPdf;
        pdfPage.getParameters().put('id', contractHistoryId);
        return pdfPage.getContentAsPDF();
    }

    private static List<LineDto> loadLines(Id contractHistoryId) {
        List<LineDto> lines = new List<LineDto>();
        for (ContractProduct__c product : [
            SELECT
                Product__r.Name,
                Product__r.UnitName__c,
                Product__r.BillingType__c,
                Unit__c,
                UnitPrice__c,
                Quantity__c,
                StartDate__c,
                Enddate__c,
                InvoiceSetting__c,
                BillingType__c,
                Type__c,
                Amount__c
            FROM ContractProduct__c
            WHERE ContractHistory__c = :contractHistoryId
            WITH SYSTEM_MODE
            ORDER BY Name ASC
        ]) {
            LineDto line = new LineDto();
            line.productName = product.Product__r == null
                ? ''
                : product.Product__r.Name;
            line.quantity = product.Quantity__c == null ? 0 : product.Quantity__c;
            line.unitPrice = product.UnitPrice__c == null ? 0 : product.UnitPrice__c;
            line.amount = resolveLineAmount(
                product,
                line.billingType
            );
            line.billingType = String.isNotBlank(product.BillingType__c)
                ? product.BillingType__c
                : product.Product__r == null
                    ? ''
                    : product.Product__r.BillingType__c;
            line.invoiceSetting = ContractMetadataService.normalizeInvoiceSettingLabel(
                product.InvoiceSetting__c
            );
            line.unit = String.isNotBlank(product.Unit__c)
                ? product.Unit__c
                : buildDisplayUnit(
                      product.Product__r == null ? null : product.Product__r.UnitName__c,
                      line.billingType
                  );
            line.periodLabel = buildPeriodLabel(product.StartDate__c, product.Enddate__c);
            line.typeLabel = resolveProductTypeLabel(product.Type__c);
            lines.add(line);
        }
        return lines;
    }

    private static Decimal resolveLineAmount(
        ContractProduct__c product,
        String billingType
    ) {
        if (product.Amount__c != null) {
            return product.Amount__c;
        }
        Decimal calculatedAmount = ContractProductAmountUtil.calculateSignedAmount(
            product,
            billingType
        );
        return calculatedAmount == null ? 0 : calculatedAmount;
    }

    private static Decimal resolveLineTotal(
        ContractHistory__c history,
        List<LineDto> lines
    ) {
        if (history != null && history.DeltaAmountSum__c != null) {
            return history.DeltaAmountSum__c;
        }
        return sumLineAmounts(lines);
    }

    private static Decimal sumLineAmounts(List<LineDto> lines) {
        Decimal total = 0;
        if (lines == null) {
            return total;
        }
        for (LineDto line : lines) {
            total += line.amount == null ? 0 : line.amount;
        }
        return total;
    }

    private static String resolveDocumentTitle(ContractHistory__c history) {
        if (history == null) {
            return '見積書';
        }
        if (String.isNotBlank(history.EstimateTitleName__c)) {
            return history.EstimateTitleName__c.trim();
        }
        if (history.Opportunity__r != null && String.isNotBlank(history.Opportunity__r.Name)) {
            return history.Opportunity__r.Name.trim();
        }
        if (String.isNotBlank(history.Name)) {
            return history.Name.trim();
        }
        return '見積書';
    }

    private static String resolveAddresseeName(ContractHistory__c history) {
        if (
            history.ContractService__r != null &&
            history.ContractService__r.BiilingAcccount__r != null &&
            String.isNotBlank(
                history.ContractService__r.BiilingAcccount__r.BillingAddressee__c
            )
        ) {
            return history.ContractService__r.BiilingAcccount__r.BillingAddressee__c;
        }
        if (
            history.ContractService__r != null &&
            history.ContractService__r.Account__r != null &&
            String.isNotBlank(history.ContractService__r.Account__r.Name)
        ) {
            return history.ContractService__r.Account__r.Name;
        }
        return '';
    }

    private static String resolveHistoryTypeLabel(String historyType) {
        if (historyType == 'New') {
            return '新規';
        }
        if (historyType == 'Change') {
            return '変更';
        }
        if (historyType == 'Renew') {
            return '更新';
        }
        if (historyType == 'Cancel') {
            return '解約';
        }
        return historyType;
    }

    private static String resolveProductTypeLabel(String productType) {
        if (productType == 'New') {
            return '新規';
        }
        if (productType == 'Renew') {
            return '更新';
        }
        if (productType == 'Original') {
            return '変更前';
        }
        if (productType == 'Remake' || productType == 'derivative') {
            return '変更後';
        }
        return productType;
    }

    private static String buildDisplayUnit(String unitName, String billingType) {
        if (String.isBlank(unitName)) {
            return billingType == ContractMetadataService.RECURRING_BILLING_TYPE_LABEL
                ? '式・月'
                : '式';
        }
        if (billingType == ContractMetadataService.RECURRING_BILLING_TYPE_LABEL) {
            return unitName + '・月';
        }
        return unitName;
    }

    private static String buildPeriodLabel(Date startDate, Date endDate) {
        if (startDate == null && endDate == null) {
            return '';
        }
        if (startDate != null && endDate != null) {
            return formatDisplayDate(startDate) + ' 〜 ' + formatDisplayDate(endDate);
        }
        if (startDate != null) {
            return formatDisplayDate(startDate) + ' 〜';
        }
        return '〜 ' + formatDisplayDate(endDate);
    }

    private static String buildTermLabel(Date startDate, Date endDate) {
        return buildPeriodLabel(startDate, endDate);
    }

    public static String formatDisplayDate(Date value) {
        if (value == null) {
            return '';
        }
        return String.valueOf(value.year()) +
            '年' +
            String.valueOf(value.month()).leftPad(2, '0') +
            '月' +
            String.valueOf(value.day()).leftPad(2, '0') +
            '日';
    }

    public static String formatFileDate(Date value) {
        Date targetDate = value == null ? Date.today() : value;
        return String.valueOf(targetDate.year()) +
            '_' +
            String.valueOf(targetDate.month()).leftPad(2, '0') +
            '_' +
            String.valueOf(targetDate.day()).leftPad(2, '0');
    }

    public static String sanitizeFileName(String value) {
        if (String.isBlank(value)) {
            return '見積書';
        }
        String sanitized = value.trim();
        sanitized = sanitized.replaceAll('[\\\\/:*?"<>|]', '_');
        sanitized = sanitized.replaceAll('\\s+', '_');
        return String.isBlank(sanitized) ? '見積書' : sanitized;
    }
}
