public without sharing class OrderCreateController {
    private static final String HISTORY_STATUS_ESTIMATE = 'Estimate';
    private static final String HISTORY_STATUS_ORDERED = 'Ordered';

    public class OrderContextDto {
        @AuraEnabled
        public Id contractHistoryId;

        @AuraEnabled
        public Id contractServiceId;

        @AuraEnabled
        public String historyName;

        @AuraEnabled
        public String historyType;

        @AuraEnabled
        public String historyStatus;

        @AuraEnabled
        public Decimal version;

        @AuraEnabled
        public String termStartDate;

        @AuraEnabled
        public String termEndDate;

        @AuraEnabled
        public String effectiveDate;

        @AuraEnabled
        public String contractServiceName;

        @AuraEnabled
        public String accountName;

        @AuraEnabled
        public Id billingAccountId;

        @AuraEnabled
        public String billingAccountName;

        @AuraEnabled
        public String billingCustomerAccountName;

        @AuraEnabled
        public String billingAddressee;

        @AuraEnabled
        public String billingEmailTo;

        @AuraEnabled
        public String billingEmailCc;

        @AuraEnabled
        public String billingEmailBcc;

        @AuraEnabled
        public EstimateCreateController.BillingAccountInvoiceSettingsDto billingSettings;

        @AuraEnabled
        public Map<String, Object> historyCustomFields;

        @AuraEnabled
        public Map<String, Object> billingCustomFields;

        @AuraEnabled
        public List<ProductLineDto> products;

        @AuraEnabled
        public Boolean isOrdered;

        @AuraEnabled
        public Boolean canOrder;

        @AuraEnabled
        public Boolean canRevert;

        @AuraEnabled
        public String revertBlockedReason;
    }

    public class ProductLineDto {
        @AuraEnabled
        public String productName;

        @AuraEnabled
        public Decimal quantity;

        @AuraEnabled
        public Decimal unitPrice;

        @AuraEnabled
        public String unit;

        @AuraEnabled
        public String billingType;

        @AuraEnabled
        public String invoiceSetting;

        @AuraEnabled
        public String startDate;

        @AuraEnabled
        public String endDate;

        @AuraEnabled
        public Decimal lineAmount;
    }

    public class OrderSaveResult {
        @AuraEnabled
        public Id contractHistoryId;

        @AuraEnabled
        public String historyStatus;
    }

    public class InvoicePreviewDto {
        @AuraEnabled
        public Decimal unlockedTotal;

        @AuraEnabled
        public Decimal lockedTotal;

        @AuraEnabled
        public Decimal unlockedTaxTotal;

        @AuraEnabled
        public Decimal lockedTaxTotal;

        @AuraEnabled
        public Integer unlockedCount;

        @AuraEnabled
        public Integer lockedCount;

        @AuraEnabled
        public List<InvoiceDateBlockDto> blocks;
    }

    public class InvoiceDateBlockDto {
        @AuraEnabled
        public String invoiceDate;

        @AuraEnabled
        public String paymentScheduledDate;

        @AuraEnabled
        public Decimal subtotal;

        @AuraEnabled
        public Decimal lockedSubtotal;

        @AuraEnabled
        public Decimal taxSubtotal;

        @AuraEnabled
        public Decimal taxLockedSubtotal;

        @AuraEnabled
        public List<InvoiceLineDto> lines;
    }

    public class InvoiceLineDto {
        @AuraEnabled
        public Id id;

        @AuraEnabled
        public String productName;

        @AuraEnabled
        public String periodLabel;

        @AuraEnabled
        public Decimal amount;

        @AuraEnabled
        public Decimal taxAmount;

        @AuraEnabled
        public Boolean isAdjustment;

        @AuraEnabled
        public Boolean locked;

        @AuraEnabled
        public String historyVersionLabel;

        @AuraEnabled
        public String paymentScheduledDate;
    }

    @AuraEnabled
    public static OrderContextDto getOrderContext(Id contractHistoryId) {
        if (contractHistoryId == null) {
            throw new AuraHandledException('契約履歴IDが指定されていません。');
        }

        List<ContractHistory__c> histories = queryContractHistoryForOrderContext(
            contractHistoryId
        );
        if (histories.isEmpty()) {
            throw new AuraHandledException('契約履歴が見つかりません。');
        }

        ContractHistory__c history = histories[0];
        OrderContextDto dto = new OrderContextDto();
        dto.contractHistoryId = history.Id;
        dto.contractServiceId = history.ContractService__c;
        dto.historyName = history.Name;
        dto.historyType = history.Type__c;
        dto.historyStatus = history.historystatus__c;
        dto.version = history.Version__c;
        dto.termStartDate = formatDate(history.CurrentTermStartDate__c);
        dto.termEndDate = formatDate(history.CurrentTermEndDate__c);
        dto.effectiveDate = formatDate(history.EffectiveDate__c);
        dto.contractServiceName = history.ContractService__r.Name;
        dto.accountName = history.ContractService__r.Account__r == null
            ? null
            : history.ContractService__r.Account__r.Name;
        dto.billingAccountId = history.ContractService__r.BiilingAcccount__c;
        dto.billingAccountName = history.ContractService__r.BiilingAcccount__r == null
            ? null
            : history.ContractService__r.BiilingAcccount__r.Name;
        dto.billingCustomerAccountName =
            history.ContractService__r.BiilingAcccount__r == null ||
            history.ContractService__r.BiilingAcccount__r.Account__r == null
                ? null
                : history.ContractService__r.BiilingAcccount__r.Account__r.Name;
        if (history.ContractService__r.BiilingAcccount__r != null) {
            BillingAccount__c billingAccount =
                history.ContractService__r.BiilingAcccount__r;
            dto.billingEmailTo = billingAccount.BillingEmailTo__c;
            dto.billingEmailCc = billingAccount.BillingEmailCc__c;
            dto.billingEmailBcc = billingAccount.BillingEmailBcc__c;
            dto.billingAddressee = billingAccount.BillingAddressee__c;
        }
        dto.isOrdered = history.historystatus__c == HISTORY_STATUS_ORDERED;
        dto.canOrder = history.historystatus__c == HISTORY_STATUS_ESTIMATE;
        dto.revertBlockedReason = buildRevertBlockedReason(
            history.Id,
            history.historystatus__c
        );
        dto.canRevert =
            history.historystatus__c == HISTORY_STATUS_ORDERED &&
            String.isBlank(dto.revertBlockedReason);
        dto.products = loadProductLines(history.Id);
        dto.billingSettings = buildBillingSettings(
            history.ContractService__r.BiilingAcccount__r
        );
        dto.historyCustomFields =
            OrderWizardFieldService.buildHistoryCustomFieldValues(history);
        dto.billingCustomFields = buildBillingCustomFields(
            history.ContractService__r.BiilingAcccount__r
        );
        return dto;
    }

    @AuraEnabled
    public static OrderSaveResult saveOrderStep1(
        Id contractHistoryId,
        String historyCustomFieldsJson
    ) {
        ContractHistory__c history = loadEstimateHistory(contractHistoryId);
        OrderWizardFieldService.applyHistoryFields(
            history,
            parseCustomFields(historyCustomFieldsJson)
        );
        SystemContextAccess.updateRecords(new List<ContractHistory__c>{ history });

        OrderSaveResult result = new OrderSaveResult();
        result.contractHistoryId = history.Id;
        result.historyStatus = history.historystatus__c;
        return result;
    }

    @AuraEnabled
    public static OrderSaveResult saveOrderStep2(
        Id contractHistoryId,
        String billingCustomFieldsJson
    ) {
        ContractHistory__c history = loadEstimateHistory(contractHistoryId);
        saveBillingAccountFields(
            history.ContractService__c,
            parseCustomFields(billingCustomFieldsJson)
        );

        OrderSaveResult result = new OrderSaveResult();
        result.contractHistoryId = history.Id;
        result.historyStatus = history.historystatus__c;
        return result;
    }

    @AuraEnabled
    public static OrderSaveResult revertOrder(Id contractHistoryId) {
        ContractHistory__c history = loadOrderedHistory(contractHistoryId);
        String blockedReason = buildRevertBlockedReason(
            history.Id,
            history.historystatus__c
        );
        if (String.isNotBlank(blockedReason)) {
            throw new AuraHandledException(blockedReason);
        }

        history.historystatus__c = HISTORY_STATUS_ESTIMATE;
        try {
            SystemContextAccess.updateRecords(new List<ContractHistory__c>{ history });
        } catch (DmlException ex) {
            throw new AuraHandledException(extractDmlMessage(ex));
        } catch (Exception ex) {
            throw new AuraHandledException(
                String.isNotBlank(ex.getMessage())
                    ? ex.getMessage()
                    : '差し戻し処理中にエラーが発生しました。'
            );
        }

        OrderSaveResult result = new OrderSaveResult();
        result.contractHistoryId = history.Id;
        result.historyStatus = HISTORY_STATUS_ESTIMATE;
        return result;
    }

    @AuraEnabled
    public static OrderSaveResult confirmOrder(
        Id contractHistoryId,
        String billingCustomFieldsJson
    ) {
        ContractHistory__c history = loadEstimateHistory(contractHistoryId);
        validateReadyForOrder(history);
        saveBillingAccountFields(
            history.ContractService__c,
            parseCustomFields(billingCustomFieldsJson)
        );

        history.historystatus__c = HISTORY_STATUS_ORDERED;
        SystemContextAccess.updateRecords(new List<ContractHistory__c>{ history });

        OrderSaveResult result = new OrderSaveResult();
        result.contractHistoryId = history.Id;
        result.historyStatus = HISTORY_STATUS_ORDERED;
        return result;
    }

    @AuraEnabled
    public static InvoicePreviewDto getInvoicePreview(Id contractHistoryId) {
        if (contractHistoryId == null) {
            return emptyPreview();
        }

        Id contractServiceId = resolveContractServiceId(contractHistoryId);
        if (contractServiceId == null) {
            return emptyPreview();
        }

        List<InvoiceProduct__c> products = [
            SELECT
                Id,
                ContractProduct__r.Product__r.Name,
                StartDate__c,
                Enddate__c,
                Amount__c,
                TaxAmount__c,
                InvoiceDate__c,
                PaymentScheduledDate__c,
                ActualInvoiceDate__c,
                LatestExportDate__c,
                invoicetype__c,
                ContractProduct__r.Type__c,
                ContractHistory__r.Version__c
            FROM InvoiceProduct__c
            WHERE ContractHistory__r.ContractService__c = :contractServiceId
            WITH SYSTEM_MODE
            ORDER BY
                InvoiceDate__c ASC NULLS LAST,
                StartDate__c ASC NULLS LAST,
                Name ASC
        ];

        InvoicePreviewDto preview = new InvoicePreviewDto();
        preview.unlockedTotal = 0;
        preview.lockedTotal = 0;
        preview.unlockedTaxTotal = 0;
        preview.lockedTaxTotal = 0;
        preview.unlockedCount = 0;
        preview.lockedCount = 0;
        preview.blocks = new List<InvoiceDateBlockDto>();

        Map<String, InvoiceDateBlockDto> blocksByKey = new Map<String, InvoiceDateBlockDto>();
        for (InvoiceProduct__c product : products) {
            Boolean locked = InvoiceProductLockUtil.isLocked(product);
            Decimal amount = product.Amount__c == null ? 0 : product.Amount__c;
            Decimal taxAmount = product.TaxAmount__c == null ? 0 : product.TaxAmount__c;
            if (locked) {
                preview.lockedTotal += amount;
                preview.lockedTaxTotal += taxAmount;
                preview.lockedCount++;
            } else {
                preview.unlockedTotal += amount;
                preview.unlockedTaxTotal += taxAmount;
                preview.unlockedCount++;
            }

            String blockKey = formatDate(product.InvoiceDate__c);
            InvoiceDateBlockDto block = blocksByKey.get(blockKey);
            if (block == null) {
                block = new InvoiceDateBlockDto();
                block.invoiceDate = blockKey;
                block.subtotal = 0;
                block.lockedSubtotal = 0;
                block.taxSubtotal = 0;
                block.taxLockedSubtotal = 0;
                block.lines = new List<InvoiceLineDto>();
                blocksByKey.put(blockKey, block);
            }

            InvoiceLineDto line = new InvoiceLineDto();
            line.id = product.Id;
            line.productName = resolveProductName(product);
            line.periodLabel = buildPeriodLabel(
                product.StartDate__c,
                product.Enddate__c
            );
            line.amount = amount;
            line.taxAmount = taxAmount;
            line.locked = locked;
            line.isAdjustment = product.ContractProduct__r.Type__c == 'Original';
            line.historyVersionLabel = formatHistoryVersionLabel(
                product.ContractHistory__r.Version__c
            );
            line.paymentScheduledDate = formatDate(product.PaymentScheduledDate__c);
            block.lines.add(line);
            if (locked) {
                block.lockedSubtotal += amount;
                block.taxLockedSubtotal += taxAmount;
            } else {
                block.subtotal += amount;
                block.taxSubtotal += taxAmount;
            }
        }

        preview.blocks = new List<InvoiceDateBlockDto>(blocksByKey.values());
        return preview;
    }

    private static String buildRevertBlockedReason(
        Id contractHistoryId,
        String historyStatus
    ) {
        if (historyStatus != HISTORY_STATUS_ORDERED) {
            return '受注済み（Ordered）状態の契約履歴のみ差し戻しできます。';
        }
        if (hasBlockedInvoiceProductsForRevert(contractHistoryId)) {
            return 'この契約履歴に請求済またはエクスポート済の請求商品があるため、差し戻しできません。';
        }
        return null;
    }

    private static Boolean hasBlockedInvoiceProductsForRevert(Id contractHistoryId) {
        if (contractHistoryId == null) {
            return false;
        }
        return [
                SELECT COUNT()
                FROM InvoiceProduct__c
                WHERE ContractHistory__c = :contractHistoryId
                AND (
                    ActualInvoiceDate__c != NULL
                    OR LatestExportDate__c != NULL
                )
                WITH SYSTEM_MODE
            ] > 0;
    }

    private static String extractDmlMessage(DmlException ex) {
        if (ex == null) {
            return '差し戻し処理中にエラーが発生しました。';
        }
        if (ex.getNumDml() > 0) {
            return ex.getDmlMessage(0);
        }
        return String.isNotBlank(ex.getMessage())
            ? ex.getMessage()
            : '差し戻し処理中にエラーが発生しました。';
    }

    private static ContractHistory__c loadOrderedHistory(Id contractHistoryId) {
        if (contractHistoryId == null) {
            throw new AuraHandledException('契約履歴IDが指定されていません。');
        }

        List<ContractHistory__c> histories = [
            SELECT Id, historystatus__c, ContractService__c
            FROM ContractHistory__c
            WHERE Id = :contractHistoryId
            WITH SYSTEM_MODE
            LIMIT 1
        ];
        if (histories.isEmpty()) {
            throw new AuraHandledException('契約履歴が見つかりません。');
        }
        ContractHistory__c history = histories[0];
        if (history.historystatus__c != HISTORY_STATUS_ORDERED) {
            throw new AuraHandledException(
                '受注済み（Ordered）状態の契約履歴のみ差し戻しできます。'
            );
        }
        return history;
    }

    private static ContractHistory__c loadEstimateHistory(Id contractHistoryId) {
        if (contractHistoryId == null) {
            throw new AuraHandledException('契約履歴IDが指定されていません。');
        }

        List<ContractHistory__c> histories = queryEstimateHistoryForEdit(
            contractHistoryId
        );
        if (histories.isEmpty()) {
            throw new AuraHandledException('契約履歴が見つかりません。');
        }
        ContractHistory__c history = histories[0];
        if (history.historystatus__c != HISTORY_STATUS_ESTIMATE) {
            throw new AuraHandledException(
                '見積（Estimate）状態の契約履歴のみ編集できます。'
            );
        }
        return history;
    }

    private static void validateReadyForOrder(ContractHistory__c history) {
        if (resolveBillingAccountId(history.ContractService__c) == null) {
            throw new AuraHandledException(
                '請求アカウントが未設定のため受注できません。'
            );
        }

        Integer productCount = [
            SELECT COUNT()
            FROM ContractProduct__c
            WHERE ContractHistory__c = :history.Id
            WITH SYSTEM_MODE
        ];
        if (productCount == 0) {
            throw new AuraHandledException('契約商品がないため受注できません。');
        }
    }

    private static Id resolveBillingAccountId(Id contractServiceId) {
        if (contractServiceId == null) {
            return null;
        }
        List<ContractService__c> services = [
            SELECT BiilingAcccount__c
            FROM ContractService__c
            WHERE Id = :contractServiceId
            WITH SYSTEM_MODE
            LIMIT 1
        ];
        return services.isEmpty() ? null : services[0].BiilingAcccount__c;
    }

    private static Id resolveContractServiceId(Id contractHistoryId) {
        List<ContractHistory__c> histories = [
            SELECT ContractService__c
            FROM ContractHistory__c
            WHERE Id = :contractHistoryId
            WITH SYSTEM_MODE
            LIMIT 1
        ];
        return histories.isEmpty() ? null : histories[0].ContractService__c;
    }

    private static List<ProductLineDto> loadProductLines(Id contractHistoryId) {
        List<ProductLineDto> lines = new List<ProductLineDto>();
        for (ContractProduct__c product : [
            SELECT
                Product__r.Name,
                Quantity__c,
                UnitPrice__c,
                Unit__c,
                BillingType__c,
                InvoiceSetting__c,
                StartDate__c,
                Enddate__c
            FROM ContractProduct__c
            WHERE ContractHistory__c = :contractHistoryId
            WITH SYSTEM_MODE
            ORDER BY StartDate__c ASC NULLS LAST, Product__r.Name ASC
        ]) {
            ProductLineDto line = new ProductLineDto();
            line.productName = product.Product__r == null ? '' : product.Product__r.Name;
            line.quantity = product.Quantity__c;
            line.unitPrice = product.UnitPrice__c;
            line.unit = product.Unit__c;
            line.billingType = product.BillingType__c;
            line.invoiceSetting = product.InvoiceSetting__c;
            line.startDate = formatDate(product.StartDate__c);
            line.endDate = formatDate(product.Enddate__c);
            Decimal qty = product.Quantity__c == null ? 0 : product.Quantity__c;
            Decimal price = product.UnitPrice__c == null ? 0 : product.UnitPrice__c;
            line.lineAmount = qty * price;
            lines.add(line);
        }
        return lines;
    }

    private static EstimateCreateController.BillingAccountInvoiceSettingsDto buildBillingSettings(
        BillingAccount__c billingAccount
    ) {
        if (billingAccount == null) {
            return new EstimateCreateController.BillingAccountInvoiceSettingsDto();
        }
        return EstimateCreateController.getBillingAccountInvoiceSettings(
            billingAccount.Id
        );
    }

    private static List<ContractHistory__c> queryContractHistoryForOrderContext(
        Id contractHistoryId
    ) {
        String editableFieldClause = buildOrderHistoryEditableFieldClause();
        String soql =
            'SELECT Id, Name, Type__c, historystatus__c, Version__c, ' +
            'CurrentTermStartDate__c, CurrentTermEndDate__c, EffectiveDate__c' +
            editableFieldClause +
            ', ContractService__c, ContractService__r.Name, ' +
            'ContractService__r.Account__r.Name, ContractService__r.BiilingAcccount__c, ' +
            'ContractService__r.BiilingAcccount__r.Name, ' +
            'ContractService__r.BiilingAcccount__r.PaymentTerm__c, ' +
            'ContractService__r.BiilingAcccount__r.BillingDayOfMonth__c, ' +
            'ContractService__r.BiilingAcccount__r.AdjustInvoiceDateToBusinessDay__c, ' +
            'ContractService__r.BiilingAcccount__r.BillingAddressee__c, ' +
            'ContractService__r.BiilingAcccount__r.BillingEmailTo__c, ' +
            'ContractService__r.BiilingAcccount__r.BillingEmailCc__c, ' +
            'ContractService__r.BiilingAcccount__r.BillingEmailBcc__c, ' +
            'ContractService__r.BiilingAcccount__r.Account__r.Name ' +
            'FROM ContractHistory__c WHERE Id = :contractHistoryId LIMIT 1';
        return Database.queryWithBinds(
            soql,
            new Map<String, Object>{ 'contractHistoryId' => contractHistoryId },
            AccessLevel.SYSTEM_MODE
        );
    }

    private static List<ContractHistory__c> queryEstimateHistoryForEdit(
        Id contractHistoryId
    ) {
        String editableFieldClause = buildOrderHistoryEditableFieldClause();
        String soql =
            'SELECT Id, historystatus__c, ContractService__c' +
            editableFieldClause +
            ' FROM ContractHistory__c WHERE Id = :contractHistoryId LIMIT 1';
        return Database.queryWithBinds(
            soql,
            new Map<String, Object>{ 'contractHistoryId' => contractHistoryId },
            AccessLevel.SYSTEM_MODE
        );
    }

    private static String buildOrderHistoryEditableFieldClause() {
        Map<String, Schema.SObjectField> fieldMap =
            ContractHistory__c.SObjectType.getDescribe().fields.getMap();
        List<String> validatedFields = new List<String>();
        for (String apiName : OrderWizardFieldService.getActiveOrderHistoryFieldApiNames()) {
            if (String.isNotBlank(apiName) && fieldMap.containsKey(apiName)) {
                validatedFields.add(apiName);
            }
        }
        if (validatedFields.isEmpty()) {
            return '';
        }
        return ', ' + String.join(validatedFields, ', ');
    }

    private static Map<String, Object> buildBillingCustomFields(
        BillingAccount__c billingAccount
    ) {
        Map<String, Object> values = new Map<String, Object>();
        if (billingAccount == null || billingAccount.Id == null) {
            return values;
        }

        List<BillingAccount__c> billingAccounts = [
            SELECT
                BillingAddressee__c,
                BillingEmailTo__c,
                BillingEmailCc__c,
                BillingEmailBcc__c,
                PaymentTerm__c,
                BillingDayOfMonth__c,
                AdjustInvoiceDateToBusinessDay__c
            FROM BillingAccount__c
            WHERE Id = :billingAccount.Id
            WITH SYSTEM_MODE
            LIMIT 1
        ];
        if (billingAccounts.isEmpty()) {
            return values;
        }

        BillingAccount__c loaded = billingAccounts[0];
        values.put('BillingAddressee__c', loaded.BillingAddressee__c);
        values.put('BillingEmailTo__c', loaded.BillingEmailTo__c);
        values.put('BillingEmailCc__c', loaded.BillingEmailCc__c);
        values.put('BillingEmailBcc__c', loaded.BillingEmailBcc__c);
        values.put('PaymentTerm__c', loaded.PaymentTerm__c);
        values.put('BillingDayOfMonth__c', loaded.BillingDayOfMonth__c);
        values.put(
            'AdjustInvoiceDateToBusinessDay__c',
            loaded.AdjustInvoiceDateToBusinessDay__c == true
        );
        return values;
    }

    private static void saveBillingAccountFields(
        Id contractServiceId,
        Map<String, Object> customFields
    ) {
        if (customFields == null || customFields.isEmpty()) {
            return;
        }

        Id billingAccountId = resolveBillingAccountId(contractServiceId);
        if (billingAccountId == null) {
            throw new AuraHandledException(
                '請求アカウントが設定されていません。見積作成で請求アカウントを設定してください。'
            );
        }

        Map<String, Object> normalizedFields = normalizeBillingCustomFields(customFields);
        String validationError =
            OrderWizardFieldService.validateBillingCustomFields(normalizedFields);
        if (String.isNotBlank(validationError)) {
            throw new AuraHandledException(validationError);
        }

        BillingAccount__c billingAccount = new BillingAccount__c(Id = billingAccountId);
        OrderWizardFieldService.applyBillingFields(billingAccount, normalizedFields);
        SystemContextAccess.updateRecords(new List<BillingAccount__c>{ billingAccount });
    }

    private static Map<String, Object> normalizeBillingCustomFields(
        Map<String, Object> customFields
    ) {
        Map<String, Object> normalized = new Map<String, Object>();
        if (customFields != null) {
            normalized.putAll(customFields);
        }
        if (!normalized.containsKey('AdjustInvoiceDateToBusinessDay__c')) {
            normalized.put('AdjustInvoiceDateToBusinessDay__c', false);
        }
        return normalized;
    }

    private static String resolveProductName(InvoiceProduct__c product) {
        if (product.ContractProduct__r != null &&
            product.ContractProduct__r.Product__r != null) {
            return product.ContractProduct__r.Product__r.Name;
        }
        return '';
    }

    private static String buildPeriodLabel(Date startDate, Date endDate) {
        String startLabel = formatDate(startDate);
        String endLabel = formatDate(endDate);
        if (String.isBlank(startLabel) && String.isBlank(endLabel)) {
            return '';
        }
        if (String.isBlank(endLabel)) {
            return startLabel;
        }
        return startLabel + ' 〜 ' + endLabel;
    }

    private static String formatDate(Date value) {
        return value == null ? '' : String.valueOf(value);
    }

    private static String formatHistoryVersionLabel(Decimal version) {
        if (version == null) {
            return '';
        }
        return 'V' + String.valueOf(version.intValue());
    }

    private static InvoicePreviewDto emptyPreview() {
        InvoicePreviewDto preview = new InvoicePreviewDto();
        preview.unlockedTotal = 0;
        preview.lockedTotal = 0;
        preview.unlockedTaxTotal = 0;
        preview.lockedTaxTotal = 0;
        preview.unlockedCount = 0;
        preview.lockedCount = 0;
        preview.blocks = new List<InvoiceDateBlockDto>();
        return preview;
    }

    private static Map<String, Object> parseCustomFields(String jsonText) {
        if (String.isBlank(jsonText)) {
            return new Map<String, Object>();
        }
        Object parsed = JSON.deserializeUntyped(jsonText);
        if (!(parsed instanceof Map<String, Object>)) {
            return new Map<String, Object>();
        }
        return (Map<String, Object>) parsed;
    }
}
