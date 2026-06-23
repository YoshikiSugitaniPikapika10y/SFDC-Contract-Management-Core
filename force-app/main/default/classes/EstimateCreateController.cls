public without sharing class EstimateCreateController {
    private static final String HISTORY_STATUS_ESTIMATE = 'Estimate';
    private static final String HISTORY_STATUS_ARCHIVE = 'Archive';
    private static final String HISTORY_STATUS_ORDERED = 'Ordered';
    private static final String HISTORY_TYPE_CANCEL = 'Cancel';
    private static final Integer NOTE_MAX_LENGTH = 255;

    public class ProductDefaultDto {
        @AuraEnabled
        public String unitName;

        @AuraEnabled
        public Decimal unitPrice;

        @AuraEnabled
        public String invoiceType;

        @AuraEnabled
        public String billingType;

        @AuraEnabled
        public String billingCycle;

        @AuraEnabled
        public String displayUnit;

        @AuraEnabled
        public String productName;
    }

    public class ProductLineItem {
        @AuraEnabled
        public Id productId;

        @AuraEnabled
        public String productName;

        @AuraEnabled
        public Decimal quantity;

        @AuraEnabled
        public Decimal unitPrice;

        @AuraEnabled
        public Decimal amount;

        @AuraEnabled
        public String startDate;

        @AuraEnabled
        public String endDate;

        @AuraEnabled
        public String invoiceType;

        @AuraEnabled
        public String unit;

        @AuraEnabled
        public String billingType;

        @AuraEnabled
        public String billingCycle;

        @AuraEnabled
        public String recordType;

        @AuraEnabled
        public String typeLabel;

        @AuraEnabled
        public Boolean isDuplicate;

        @AuraEnabled
        public Id sourceContractProductId;

        @AuraEnabled
        public Boolean isReadonly;

        @AuraEnabled
        public String pairId;
    }

    public class EstimateCopyPresetDto {
        @AuraEnabled
        public Id opportunityId;

        @AuraEnabled
        public String opportunityName;

        @AuraEnabled
        public String accountName;

        @AuraEnabled
        public String selectedType;

        @AuraEnabled
        public String contractServiceName;

        @AuraEnabled
        public String contractHistoryName;

        @AuraEnabled
        public Id contractServiceId;

        @AuraEnabled
        public Id contractHistoryId;

        @AuraEnabled
        public String contractStartDate;

        @AuraEnabled
        public String endDate;

        @AuraEnabled
        public String contractEffectiveDate;

        @AuraEnabled
        public String autoHistoryName;

        @AuraEnabled
        public Decimal baseHistoryVersion;

        @AuraEnabled
        public Decimal nextHistoryVersion;

        @AuraEnabled
        public String previousTermStartDate;

        @AuraEnabled
        public String previousTermEndDate;

        @AuraEnabled
        public Boolean renewEligible;

        @AuraEnabled
        public List<ProductLineItem> selectedProducts;

        @AuraEnabled
        public Id estimateRemarkMasterId;

        @AuraEnabled
        public String estimateRemarks;

        @AuraEnabled
        public Id billingAccountId;
    }

    public class BillingAccountInvoiceSettingsDto {
        @AuraEnabled
        public Integer billingDayOfMonth;

        @AuraEnabled
        public String billingDayOfMonthPicklistValue;

        @AuraEnabled
        public String billingDayOfMonthLabel;

        @AuraEnabled
        public String paymentTerm;

        @AuraEnabled
        public Boolean adjustInvoiceDateToBusinessDay;
    }

    public class EstimateSaveRequest {
        @AuraEnabled
        public Id opportunityId;

        @AuraEnabled
        public String selectedType;

        @AuraEnabled
        public String contractServiceName;

        @AuraEnabled
        public Id contractServiceId;

        @AuraEnabled
        public Id previousHistoryId;

        @AuraEnabled
        public String contractStartDate;

        @AuraEnabled
        public String contractEndDate;

        @AuraEnabled
        public String effectiveDate;

        @AuraEnabled
        public String applicationDate;

        @AuraEnabled
        public List<ProductLineItem> products;

        @AuraEnabled
        public Id estimateRemarkMasterId;

        @AuraEnabled
        public String remarksText;

        @AuraEnabled
        public Id billingAccountId;

        @AuraEnabled
        public Id copyFromHistoryId;
    }

    public class EstimateSaveResult {
        @AuraEnabled
        public Id contractServiceId;

        @AuraEnabled
        public Id contractHistoryId;

        @AuraEnabled
        public List<Id> contractProductIds;
    }

    public class ContractHistoryDto {
        @AuraEnabled
        public Id historyId;

        @AuraEnabled
        public String historyName;

        @AuraEnabled
        public Decimal version;

        @AuraEnabled
        public Decimal nextVersion;

        @AuraEnabled
        public String termStartDate;

        @AuraEnabled
        public String termEndDate;

        @AuraEnabled
        public String historyType;

        @AuraEnabled
        public Boolean renewEligible;
    }

    public class ContractProductLineDto {
        @AuraEnabled
        public Id contractProductId;

        @AuraEnabled
        public Id productId;

        @AuraEnabled
        public String productName;

        @AuraEnabled
        public String unitName;

        @AuraEnabled
        public String unit;

        @AuraEnabled
        public Decimal unitPrice;

        @AuraEnabled
        public Decimal quantity;

        @AuraEnabled
        public String startDate;

        @AuraEnabled
        public String endDate;

        @AuraEnabled
        public String invoiceType;

        @AuraEnabled
        public String billingType;

        @AuraEnabled
        public String billingCycle;
    }

    private static final String BILLING_TYPE_RECURRING = '継続課金';
    private static final String BILLING_TYPE_ONE_TIME = '一回課金';
    private static final String MONTHLY_BILLING_CYCLE = '月';
    private static final String PRODUCT_TYPE_ORIGINAL = 'Original';
    private static final String PRODUCT_TYPE_REMAKE = 'Remake';
    private static final String LEGACY_PRODUCT_TYPE_DERIVATIVE = 'derivative';
    private static final String PRODUCT_TYPE_NEW = 'New';
    private static final String PRODUCT_TYPE_RENEW = 'Renew';

    @AuraEnabled
    public static List<ContractProductLineDto> getRecurringContractProducts(
        Id contractHistoryId
    ) {
        if (contractHistoryId == null) {
            return new List<ContractProductLineDto>();
        }

        List<ContractProduct__c> products = [
            SELECT
                Id,
                Product__c,
                Product__r.Name,
                Product__r.UnitName__c,
                Product__r.BillingType__c,
                Unit__c,
                UnitPrice__c,
                Quantity__c,
                StartDate__c,
                Enddate__c,
                InvoiceSetting__c
            FROM ContractProduct__c
            WHERE ContractHistory__c = :contractHistoryId
            AND Product__r.BillingType__c = :BILLING_TYPE_RECURRING
            AND Quantity__c > 0
            AND (
                Type__c = NULL
                OR Type__c IN (
                    :PRODUCT_TYPE_REMAKE,
                    :PRODUCT_TYPE_NEW,
                    :PRODUCT_TYPE_RENEW
                )
            )
            WITH SYSTEM_MODE
            ORDER BY Name ASC
        ];

        return toContractProductLineDtos(products);
    }

    @AuraEnabled
    public static List<ContractProductLineDto> getRenewContractProducts(
        Id contractServiceId
    ) {
        if (contractServiceId == null) {
            return new List<ContractProductLineDto>();
        }

        ContractHistory__c sourceHistory = queryLatestNonEstimateHistory(
            contractServiceId
        );
        if (
            sourceHistory == null ||
            sourceHistory.CurrentTermEndDate__c == null ||
            sourceHistory.Type__c == HISTORY_TYPE_CANCEL
        ) {
            return new List<ContractProductLineDto>();
        }

        Date termEndDate = sourceHistory.CurrentTermEndDate__c;

        List<ContractProduct__c> products = [
            SELECT
                Id,
                Product__c,
                Product__r.Name,
                Product__r.UnitName__c,
                Product__r.BillingType__c,
                Unit__c,
                UnitPrice__c,
                Quantity__c,
                StartDate__c,
                Enddate__c,
                InvoiceSetting__c
            FROM ContractProduct__c
            WHERE ContractHistory__c = :sourceHistory.Id
            AND Product__r.BillingType__c = :BILLING_TYPE_RECURRING
            AND Quantity__c > 0
            AND Enddate__c = :termEndDate
            AND (
                Type__c = NULL
                OR Type__c IN (
                    :PRODUCT_TYPE_REMAKE,
                    :PRODUCT_TYPE_NEW,
                    :PRODUCT_TYPE_RENEW
                )
            )
            WITH SYSTEM_MODE
            ORDER BY Name ASC
        ];

        return toContractProductLineDtos(products);
    }

    private static List<ContractProductLineDto> toContractProductLineDtos(
        List<ContractProduct__c> products
    ) {
        List<ContractProductLineDto> lines = new List<ContractProductLineDto>();
        for (ContractProduct__c product : products) {
            ContractProductLineDto line = new ContractProductLineDto();
            line.contractProductId = product.Id;
            line.productId = product.Product__c;
            line.productName = product.Product__r.Name;
            line.unitName = product.Product__r.UnitName__c;
            line.billingType = product.Product__r.BillingType__c;
            line.billingCycle = resolveRecurringBillingCycleLabel(
                product.Product__r.BillingType__c
            );
            line.unit = String.isNotBlank(product.Unit__c)
                ? product.Unit__c
                : buildDisplayUnit(
                      product.Product__r.UnitName__c,
                      product.Product__r.BillingType__c
                  );
            line.unitPrice = product.UnitPrice__c;
            line.quantity = product.Quantity__c;
            line.startDate = formatDate(product.StartDate__c);
            line.endDate = formatDate(product.Enddate__c);
            line.invoiceType = ContractMetadataService.normalizeInvoiceSettingLabel(
                product.InvoiceSetting__c
            );
            lines.add(line);
        }
        return lines;
    }

    @AuraEnabled
    public static ContractHistoryDto getLatestContractHistory(Id contractServiceId) {
        if (contractServiceId == null) {
            return null;
        }

        ContractHistory__c history = queryLatestNonEstimateHistory(contractServiceId);
        if (history == null) {
            return null;
        }

        ContractHistoryDto dto = toContractHistoryDto(history);
        dto.nextVersion = ContractHistoryVersionUtil.getNextHistoryVersion(
            contractServiceId
        );
        return dto;
    }

    private static ContractHistory__c queryLatestNonEstimateHistory(
        Id contractServiceId
    ) {
        List<ContractHistory__c> histories = [
            SELECT Id, Name, Version__c, Type__c, CurrentTermStartDate__c, CurrentTermEndDate__c
            FROM ContractHistory__c
            WHERE ContractService__c = :contractServiceId
            AND historystatus__c NOT IN (
                :HISTORY_STATUS_ESTIMATE,
                :HISTORY_STATUS_ARCHIVE
            )
            AND (
                Type__c != :HISTORY_TYPE_CANCEL
                OR historystatus__c != :HISTORY_STATUS_ORDERED
            )
            WITH SYSTEM_MODE
            ORDER BY Version__c DESC NULLS LAST
            LIMIT 1
        ];

        return histories.isEmpty() ? null : histories[0];
    }

    @AuraEnabled
    public static ContractHistoryDto getContractHistoryInfo(Id contractHistoryId) {
        if (contractHistoryId == null) {
            return null;
        }

        List<ContractHistory__c> histories = [
            SELECT Id, Name, Version__c, Type__c, CurrentTermStartDate__c, CurrentTermEndDate__c
            FROM ContractHistory__c
            WHERE Id = :contractHistoryId
            WITH SYSTEM_MODE
            LIMIT 1
        ];

        if (histories.isEmpty()) {
            return null;
        }

        return toContractHistoryDto(histories[0]);
    }

    @AuraEnabled
    public static Id getEstimateCopyLaunchInfo(Id contractHistoryId) {
        if (contractHistoryId == null) {
            throw new AuraHandledException('コピー元の契約履歴が指定されていません。');
        }

        List<ContractHistory__c> histories = [
            SELECT Id, Opportunity__c, historystatus__c
            FROM ContractHistory__c
            WHERE Id = :contractHistoryId
            WITH SYSTEM_MODE
            LIMIT 1
        ];

        if (histories.isEmpty()) {
            throw new AuraHandledException('契約履歴が見つかりません。');
        }

        ContractHistory__c history = histories[0];
        if (history.historystatus__c != HISTORY_STATUS_ESTIMATE) {
            throw new AuraHandledException(
                'Estimate状態の契約履歴のみコピーできます。'
            );
        }
        if (history.Opportunity__c == null) {
            throw new AuraHandledException('商談が設定されていません。');
        }

        return history.Opportunity__c;
    }

    @AuraEnabled(cacheable=true)
    public static EstimateCopyPresetDto getEstimateCopyPreset(Id contractHistoryId) {
        if (contractHistoryId == null) {
            throw new AuraHandledException('コピー元の契約履歴が指定されていません。');
        }

        List<ContractHistory__c> histories = [
            SELECT
                Id,
                Name,
                Type__c,
                Version__c,
                historystatus__c,
                CurrentTermStartDate__c,
                CurrentTermEndDate__c,
                EffectiveDate__c,
                Opportunity__c,
                Opportunity__r.Name,
                Opportunity__r.Account.Name,
                ContractService__c,
                EstimateNoteMaster__c,
                Note__c,
                PreviousHistory__c,
                PreviousHistory__r.Name,
                PreviousHistory__r.Version__c,
                PreviousHistory__r.CurrentTermStartDate__c,
                PreviousHistory__r.CurrentTermEndDate__c
            FROM ContractHistory__c
            WHERE Id = :contractHistoryId
            WITH SYSTEM_MODE
            LIMIT 1
        ];

        if (histories.isEmpty()) {
            throw new AuraHandledException('契約履歴が見つかりません。');
        }

        ContractHistory__c history = histories[0];
        if (history.historystatus__c != HISTORY_STATUS_ESTIMATE) {
            throw new AuraHandledException('Estimate状態の契約履歴のみコピーできます。');
        }
        if (history.Opportunity__c == null) {
            throw new AuraHandledException('商談が設定されていません。');
        }

        EstimateCopyPresetDto preset = new EstimateCopyPresetDto();
        preset.opportunityId = history.Opportunity__c;
        preset.opportunityName = history.Opportunity__r.Name;
        preset.accountName = history.Opportunity__r.Account == null
            ? ''
            : history.Opportunity__r.Account.Name;
        preset.selectedType = history.Type__c;
        preset.contractHistoryName = buildCopyHistoryName(history.Name);
        preset.contractStartDate = formatDate(history.CurrentTermStartDate__c);
        preset.endDate = formatDate(history.CurrentTermEndDate__c);
        preset.contractEffectiveDate = formatDate(history.EffectiveDate__c);
        if (
            (history.Type__c == 'Renew' || history.Type__c == 'Cancel') &&
            String.isBlank(preset.contractEffectiveDate)
        ) {
            preset.contractEffectiveDate = preset.contractStartDate;
        }
        preset.estimateRemarkMasterId = history.EstimateNoteMaster__c;
        preset.estimateRemarks = history.Note__c == null ? '' : history.Note__c;
        preset.selectedProducts = loadCopyProductLines(history.Id, history.Type__c);

        ContractService__c service = loadContractServiceForCopy(history.ContractService__c);
        if (history.Type__c == 'New') {
            preset.contractServiceName = service == null
                ? ''
                : buildCopyHistoryName(service.Name);
            preset.contractServiceId = null;
            preset.contractHistoryId = null;
            preset.billingAccountId = service == null ? null : service.BiilingAcccount__c;
            return preset;
        }

        preset.contractServiceId = history.ContractService__c;
        preset.contractHistoryId = history.PreviousHistory__c;
        preset.contractServiceName = service == null ? '' : service.Name;
        preset.billingAccountId = service == null ? null : service.BiilingAcccount__c;

        if (history.PreviousHistory__c != null) {
            preset.autoHistoryName = history.PreviousHistory__r.Name;
            preset.baseHistoryVersion = history.PreviousHistory__r.Version__c;
            preset.previousTermStartDate = formatDate(
                history.PreviousHistory__r.CurrentTermStartDate__c
            );
            preset.previousTermEndDate = formatDate(
                history.PreviousHistory__r.CurrentTermEndDate__c
            );
        }

        ContractHistoryDto latestHistory = getLatestContractHistory(
            history.ContractService__c
        );
        if (latestHistory != null) {
            if (String.isBlank(preset.autoHistoryName)) {
                preset.autoHistoryName = latestHistory.historyName;
            }
            if (preset.baseHistoryVersion == null) {
                preset.baseHistoryVersion = latestHistory.version;
            }
            preset.renewEligible = latestHistory.renewEligible;
        }

        if (history.Version__c != null) {
            preset.nextHistoryVersion = history.Version__c;
        }

        return preset;
    }

    private static ContractService__c loadContractServiceForCopy(Id contractServiceId) {
        if (contractServiceId == null) {
            return null;
        }

        List<ContractService__c> services = [
            SELECT Id, Name, BiilingAcccount__c
            FROM ContractService__c
            WHERE Id = :contractServiceId
            WITH SYSTEM_MODE
            LIMIT 1
        ];
        return services.isEmpty() ? null : services[0];
    }

    private static String buildCopyHistoryName(String sourceName) {
        String baseName = String.isBlank(sourceName) ? '' : sourceName.trim();
        return baseName + 'のコピー';
    }

    private static List<ProductLineItem> loadCopyProductLines(
        Id contractHistoryId,
        String selectedType
    ) {
        List<ContractProduct__c> products = [
            SELECT
                Id,
                Product__c,
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
                Amount__c,
                PreviousContractProduct__c
            FROM ContractProduct__c
            WHERE ContractHistory__c = :contractHistoryId
            WITH SYSTEM_MODE
            ORDER BY Name ASC
        ];

        Map<Id, String> pairIdBySource = new Map<Id, String>();
        Integer pairIndex = 0;
        for (ContractProduct__c product : products) {
            Id pairKey = product.PreviousContractProduct__c != null
                ? product.PreviousContractProduct__c
                : product.Id;
            if (!pairIdBySource.containsKey(pairKey)) {
                pairIndex++;
                pairIdBySource.put(pairKey, 'pair-' + pairIndex);
            }
        }

        List<ProductLineItem> lines = new List<ProductLineItem>();
        for (ContractProduct__c product : products) {
            lines.add(toCopyProductLineItem(product, selectedType, pairIdBySource));
        }
        return lines;
    }

    private static ProductLineItem toCopyProductLineItem(
        ContractProduct__c product,
        String selectedType,
        Map<Id, String> pairIdBySource
    ) {
        String billingType = String.isNotBlank(product.BillingType__c)
            ? product.BillingType__c
            : product.Product__r.BillingType__c;
        String recordType = normalizeProductRecordType(product.Type__c);

        ProductLineItem line = new ProductLineItem();
        line.productId = product.Product__c;
        line.productName = product.Product__r.Name;
        line.quantity = product.Quantity__c;
        line.unitPrice = product.UnitPrice__c;
        line.startDate = formatDate(product.StartDate__c);
        line.endDate = formatDate(product.Enddate__c);
        line.invoiceType = ContractMetadataService.resolveInvoiceSettingForBillingType(
            billingType,
            product.InvoiceSetting__c
        );
        line.unit = String.isNotBlank(product.Unit__c)
            ? product.Unit__c
            : buildDisplayUnit(product.Product__r.UnitName__c, billingType);
        line.billingType = billingType;
        line.billingCycle = resolveRecurringBillingCycleLabel(billingType);
        line.recordType = recordType;
        line.typeLabel = resolveCopyTypeLabel(recordType);
        line.isDuplicate = false;
        line.sourceContractProductId = product.PreviousContractProduct__c;
        line.isReadonly = recordType == PRODUCT_TYPE_ORIGINAL;
        line.amount = product.Amount__c;
        if (line.amount == null) {
            line.amount = ContractProductAmountUtil.calculateSignedAmount(
                product,
                billingType
            );
        }

        Id pairKey = product.PreviousContractProduct__c != null
            ? product.PreviousContractProduct__c
            : product.Id;
        if (selectedType == 'Change' && pairIdBySource.containsKey(pairKey)) {
            line.pairId = pairIdBySource.get(pairKey);
        }

        return line;
    }

    private static String resolveCopyTypeLabel(String recordType) {
        if (recordType == PRODUCT_TYPE_ORIGINAL) {
            return 'Original';
        }
        if (recordType == PRODUCT_TYPE_REMAKE) {
            return 'Remake';
        }
        if (recordType == LEGACY_PRODUCT_TYPE_DERIVATIVE) {
            return 'Remake';
        }
        if (recordType == PRODUCT_TYPE_RENEW) {
            return 'Renew';
        }
        return 'New';
    }

    private static ContractHistoryDto toContractHistoryDto(ContractHistory__c history) {
        ContractHistoryDto dto = new ContractHistoryDto();
        dto.historyId = history.Id;
        dto.historyName = history.Name;
        dto.version = history.Version__c;
        dto.termStartDate = formatDate(history.CurrentTermStartDate__c);
        dto.termEndDate = formatDate(history.CurrentTermEndDate__c);
        dto.historyType = history.Type__c;
        dto.renewEligible = isRenewEligibleHistory(history);
        return dto;
    }

    private static Boolean isRenewEligibleHistory(ContractHistory__c history) {
        if (
            history == null ||
            history.Id == null ||
            history.Type__c == HISTORY_TYPE_CANCEL ||
            history.CurrentTermEndDate__c == null
        ) {
            return false;
        }
        return countRenewSourceRecurringProducts(
            history.Id,
            history.CurrentTermEndDate__c
        ) > 0;
    }

    private static Integer countRenewSourceRecurringProducts(
        Id contractHistoryId,
        Date termEndDate
    ) {
        if (contractHistoryId == null || termEndDate == null) {
            return 0;
        }

        return [
            SELECT COUNT()
            FROM ContractProduct__c
            WHERE ContractHistory__c = :contractHistoryId
            AND Product__r.BillingType__c = :BILLING_TYPE_RECURRING
            AND Quantity__c > 0
            AND Enddate__c = :termEndDate
            AND (
                Type__c = NULL
                OR Type__c IN (
                    :PRODUCT_TYPE_REMAKE,
                    :PRODUCT_TYPE_NEW,
                    :PRODUCT_TYPE_RENEW
                )
            )
            WITH SYSTEM_MODE
        ];
    }

    @AuraEnabled
    public static ProductDefaultDto getProductDefaults(Id productId) {
        if (productId == null) {
            return null;
        }

        List<Product2> products = [
            SELECT Name, UnitName__c, UnitPrice__c, invoicetype__c, BillingType__c
            FROM Product2
            WHERE Id = :productId
            WITH SYSTEM_MODE
            LIMIT 1
        ];

        if (products.isEmpty()) {
            return null;
        }

        Product2 product = products[0];
        ProductDefaultDto dto = new ProductDefaultDto();
        dto.productName = product.Name;
        dto.unitName = product.UnitName__c;
        dto.unitPrice = product.UnitPrice__c;
        dto.invoiceType = ContractMetadataService.resolveInvoiceSettingForBillingType(
            product.BillingType__c,
            product.invoicetype__c
        );
        dto.billingType = product.BillingType__c;
        dto.billingCycle = resolveRecurringBillingCycleLabel(product.BillingType__c);
        dto.displayUnit = buildDisplayUnit(
            product.UnitName__c,
            product.BillingType__c
        );
        return dto;
    }

    @AuraEnabled(cacheable=true)
    public static List<ContractMetadataService.InvoiceSettingOption> getInvoiceSettingOptions() {
        return ContractMetadataService.getActiveInvoiceSettingOptions();
    }

    @AuraEnabled(cacheable=true)
    public static String getDefaultInvoiceSettingLabel() {
        String label = ContractMetadataService.getDefaultInvoiceSettingLabel();
        return label == null ? '' : label;
    }

    @AuraEnabled(cacheable=true)
    public static BillingAccountInvoiceSettingsDto getBillingAccountInvoiceSettings(
        Id billingAccountId
    ) {
        BillingAccountInvoiceSettingsDto dto = new BillingAccountInvoiceSettingsDto();
        if (billingAccountId == null) {
            return dto;
        }

        List<BillingAccount__c> billingAccounts = [
            SELECT
                PaymentTerm__c,
                BillingDayOfMonth__c,
                AdjustInvoiceDateToBusinessDay__c
            FROM BillingAccount__c
            WHERE Id = :billingAccountId
            WITH SYSTEM_MODE
            LIMIT 1
        ];
        if (billingAccounts.isEmpty()) {
            return dto;
        }

        BillingAccount__c billingAccount = billingAccounts[0];
        dto.paymentTerm = billingAccount.PaymentTerm__c;
        dto.adjustInvoiceDateToBusinessDay =
            billingAccount.AdjustInvoiceDateToBusinessDay__c == true;
        dto.billingDayOfMonthPicklistValue = billingAccount.BillingDayOfMonth__c;
        dto.billingDayOfMonth = ContractMetadataService.parseBillingDayOfMonth(
            billingAccount.BillingDayOfMonth__c
        );
        dto.billingDayOfMonthLabel =
            ContractMetadataService.formatBillingDayPicklistLabel(
                billingAccount.BillingDayOfMonth__c
            );
        return dto;
    }

    @AuraEnabled(cacheable=true)
    public static String getEstimateRemarkMasterText(Id masterId) {
        if (masterId == null) {
            return '';
        }

        List<EstimateNoteMaster__c> masters = [
            SELECT NoteText__c
            FROM EstimateNoteMaster__c
            WHERE Id = :masterId
            WITH SYSTEM_MODE
            LIMIT 1
        ];
        if (masters.isEmpty()) {
            return '';
        }
        return masters[0].NoteText__c == null ? '' : masters[0].NoteText__c;
    }

    @AuraEnabled
    public static EstimateSaveResult saveEstimate(
        Id opportunityId,
        String selectedType,
        String contractServiceName,
        String contractHistoryName,
        Id contractServiceId,
        Id previousHistoryId,
        String contractStartDate,
        String contractEndDate,
        String effectiveDate,
        String applicationDate,
        String productsJson,
        Id estimateRemarkMasterId,
        String remarksText,
        Id billingAccountId,
        Id copyFromHistoryId
    ) {
        EstimateSaveRequest request = new EstimateSaveRequest();
        request.opportunityId = opportunityId;
        request.selectedType = selectedType;
        request.contractServiceName = contractServiceName;
        request.contractServiceId = contractServiceId;
        request.previousHistoryId = previousHistoryId;
        request.contractStartDate = contractStartDate;
        request.contractEndDate = contractEndDate;
        request.effectiveDate = effectiveDate;
        request.applicationDate = applicationDate;
        request.products = parseProducts(productsJson);
        request.estimateRemarkMasterId = estimateRemarkMasterId;
        request.remarksText = remarksText;
        request.billingAccountId = billingAccountId;
        request.copyFromHistoryId = copyFromHistoryId;

        if (request.opportunityId == null && request.selectedType == null && request.products == null) {
            throw new AuraHandledException('保存データがありません。');
        }

        if (String.isBlank(request.selectedType)) {
            throw new AuraHandledException('タイプが指定されていません。');
        }

        if (request.selectedType == 'New') {
            validateNewSaveRequest(request, contractHistoryName);
            return saveNewEstimate(request, contractHistoryName);
        }

        if (request.selectedType == 'Change') {
            validateChangeSaveRequest(request, contractHistoryName);
            return saveChangeEstimate(request, contractHistoryName);
        }

        if (request.selectedType == 'Renew') {
            validateRenewSaveRequest(request, contractHistoryName);
            return saveChangeEstimate(request, contractHistoryName);
        }

        if (request.selectedType == 'Cancel') {
            validateCancelSaveRequest(request, contractHistoryName);
            return saveCancelEstimate(request, contractHistoryName);
        }

        throw new AuraHandledException('New、Change、Renew、Cancelタイプのみ保存できます。');
    }

    private static EstimateSaveResult saveNewEstimate(
        EstimateSaveRequest request,
        String contractHistoryName
    ) {
        Opportunity opportunity = [
            SELECT Id, AccountId
            FROM Opportunity
            WHERE Id = :request.opportunityId
            WITH SYSTEM_MODE
            LIMIT 1
        ];

        if (opportunity.AccountId == null) {
            throw new AuraHandledException('商談に取引先が設定されていません。');
        }

        Date serviceStartDate = parseDate(request.contractStartDate);
        Date serviceEndDate = parseDate(request.contractEndDate);

        ContractService__c contractService = new ContractService__c(
            Name = request.contractServiceName,
            Account__c = opportunity.AccountId,
            BiilingAcccount__c = request.billingAccountId
        );
        SystemContextAccess.insertRecords(new List<SObject>{ contractService });

        ContractHistory__c contractHistory = new ContractHistory__c(
            Name = contractHistoryName,
            ContractService__c = contractService.Id,
            Type__c = request.selectedType,
            historystatus__c = HISTORY_STATUS_ESTIMATE,
            Version__c = 1,
            CurrentTermStartDate__c = serviceStartDate,
            CurrentTermEndDate__c = serviceEndDate,
            EffectiveDate__c = parseDate(request.effectiveDate),
            Opportunity__c = opportunity.Id,
            EstimateNoteMaster__c = request.estimateRemarkMasterId
        );
        applyRemarks(contractHistory, request.remarksText);
        SystemContextAccess.insertRecords(new List<SObject>{ contractHistory });

        SystemContextAccess.insertRecords(
            buildContractProducts(
                contractHistory.Id,
                opportunity.AccountId,
                request
            )
        );

        return buildSaveResult(contractService.Id, contractHistory.Id, contractHistory.Id);
    }

    private static EstimateSaveResult saveChangeEstimate(
        EstimateSaveRequest request,
        String contractHistoryName
    ) {
        Opportunity opportunity = [
            SELECT Id
            FROM Opportunity
            WHERE Id = :request.opportunityId
            WITH SYSTEM_MODE
            LIMIT 1
        ];

        List<ContractService__c> services = [
            SELECT Id, Account__c
            FROM ContractService__c
            WHERE Id = :request.contractServiceId
            WITH SYSTEM_MODE
            LIMIT 1
        ];
        if (services.isEmpty()) {
            throw new AuraHandledException('契約サービスが見つかりません。');
        }

        Date serviceStartDate = parseDate(request.contractStartDate);
        Date serviceEndDate = parseDate(request.contractEndDate);

        ContractHistory__c contractHistory = new ContractHistory__c(
            Name = contractHistoryName,
            ContractService__c = request.contractServiceId,
            Type__c = request.selectedType,
            historystatus__c = HISTORY_STATUS_ESTIMATE,
            Version__c = resolveEstimateHistoryVersion(
                request.contractServiceId,
                request.copyFromHistoryId
            ),
            CurrentTermStartDate__c = serviceStartDate,
            CurrentTermEndDate__c = serviceEndDate,
            EffectiveDate__c = parseDate(request.effectiveDate),
            Opportunity__c = opportunity.Id,
            PreviousHistory__c = request.previousHistoryId,
            EstimateNoteMaster__c = request.estimateRemarkMasterId
        );
        applyRemarks(contractHistory, request.remarksText);
        SystemContextAccess.insertRecords(new List<SObject>{ contractHistory });

        if (request.selectedType == 'Change') {
            request.products = normalizeChangeProductsForSave(
                request.products,
                parseDate(request.effectiveDate),
                parseDate(request.contractStartDate),
                parseDate(request.contractEndDate)
            );
        }

        SystemContextAccess.insertRecords(
            buildContractProducts(
                contractHistory.Id,
                services[0].Account__c,
                request
            )
        );

        return buildSaveResult(request.contractServiceId, contractHistory.Id, contractHistory.Id);
    }

    private static EstimateSaveResult saveCancelEstimate(
        EstimateSaveRequest request,
        String contractHistoryName
    ) {
        Opportunity opportunity = [
            SELECT Id
            FROM Opportunity
            WHERE Id = :request.opportunityId
            WITH SYSTEM_MODE
            LIMIT 1
        ];

        List<ContractService__c> services = [
            SELECT Id
            FROM ContractService__c
            WHERE Id = :request.contractServiceId
            WITH SYSTEM_MODE
            LIMIT 1
        ];
        if (services.isEmpty()) {
            throw new AuraHandledException('契約サービスが見つかりません。');
        }

        Date cancelDate = parseDate(request.contractStartDate);
        if (cancelDate == null) {
            cancelDate = parseDate(request.contractEndDate);
        }

        ContractHistory__c contractHistory = new ContractHistory__c(
            Name = contractHistoryName,
            ContractService__c = request.contractServiceId,
            Type__c = request.selectedType,
            historystatus__c = HISTORY_STATUS_ORDERED,
            Version__c = resolveEstimateHistoryVersion(
                request.contractServiceId,
                request.copyFromHistoryId
            ),
            CurrentTermStartDate__c = cancelDate,
            CurrentTermEndDate__c = cancelDate,
            EffectiveDate__c = parseDate(request.effectiveDate),
            Opportunity__c = opportunity.Id,
            PreviousHistory__c = request.previousHistoryId,
            EstimateNoteMaster__c = request.estimateRemarkMasterId
        );
        applyRemarks(contractHistory, request.remarksText);
        SystemContextAccess.insertRecords(new List<SObject>{ contractHistory });

        return buildSaveResult(request.contractServiceId, contractHistory.Id, contractHistory.Id);
    }

    @TestVisible
    private static Decimal resolveEstimateHistoryVersion(
        Id contractServiceId,
        Id copyFromHistoryId
    ) {
        if (copyFromHistoryId == null || contractServiceId == null) {
            return ContractHistoryVersionUtil.getNextHistoryVersion(contractServiceId);
        }

        List<ContractHistory__c> sources = [
            SELECT Version__c, ContractService__c, historystatus__c, Type__c
            FROM ContractHistory__c
            WHERE Id = :copyFromHistoryId
            WITH SYSTEM_MODE
            LIMIT 1
        ];
        if (sources.isEmpty()) {
            return ContractHistoryVersionUtil.getNextHistoryVersion(contractServiceId);
        }

        ContractHistory__c source = sources[0];
        if (
            source.historystatus__c != HISTORY_STATUS_ESTIMATE ||
            source.Type__c == 'New' ||
            source.ContractService__c != contractServiceId ||
            source.Version__c == null
        ) {
            return ContractHistoryVersionUtil.getNextHistoryVersion(contractServiceId);
        }

        return source.Version__c;
    }

    private static List<ContractProduct__c> buildContractProducts(
        Id contractHistoryId,
        Id accountId,
        EstimateSaveRequest request
    ) {
        Map<Id, Product2> productById = loadProductBillingTypes(request.products);
        List<ContractProduct__c> contractProducts = new List<ContractProduct__c>();
        for (ProductLineItem line : request.products) {
            Product2 product = productById.get(line.productId);
            contractProducts.add(
                buildContractProduct(
                    contractHistoryId,
                    accountId,
                    line,
                    product,
                    request.selectedType
                )
            );
        }
        return contractProducts;
    }

    private static ContractProduct__c buildContractProduct(
        Id contractHistoryId,
        Id accountId,
        ProductLineItem line,
        Product2 product,
        String selectedType
    ) {
        String billingType = product != null
            ? product.BillingType__c
            : line.billingType;
        String unitName = product != null ? product.UnitName__c : null;
        ContractProduct__c contractProduct = new ContractProduct__c(
            ContractHistory__c = contractHistoryId,
            Account__c = accountId,
            Product__c = line.productId,
            Quantity__c = line.quantity,
            UnitPrice__c = line.unitPrice,
            Unit__c = buildDisplayUnit(unitName, billingType),
            StartDate__c = parseDate(line.startDate),
            Enddate__c = parseDate(line.endDate),
            InvoiceSetting__c = ContractMetadataService.normalizeInvoiceSettingLabel(
                line.invoiceType
            ),
            BillingType__c = billingType,
            Type__c = resolveProductType(line, selectedType),
            PreviousContractProduct__c = line.sourceContractProductId
        );
        contractProduct.Amount__c = ContractProductAmountUtil.calculateSignedAmount(
            contractProduct,
            billingType
        );
        return contractProduct;
    }

    private static Map<Id, Product2> loadProductBillingTypes(
        List<ProductLineItem> products
    ) {
        Set<Id> productIds = new Set<Id>();
        for (ProductLineItem line : products) {
            if (line.productId != null) {
                productIds.add(line.productId);
            }
        }
        if (productIds.isEmpty()) {
            return new Map<Id, Product2>();
        }
        return new Map<Id, Product2>(
            [
                SELECT Id, BillingType__c, UnitName__c
                FROM Product2
                WHERE Id IN :productIds
                WITH SYSTEM_MODE
            ]
        );
    }

    private static String resolveProductType(ProductLineItem line, String selectedType) {
        if (String.isNotBlank(line.recordType)) {
            return normalizeProductRecordType(line.recordType);
        }
        if (selectedType == 'Change') {
            return PRODUCT_TYPE_NEW;
        }
        if (selectedType == 'New') {
            return PRODUCT_TYPE_NEW;
        }
        if (selectedType == 'Renew') {
            return PRODUCT_TYPE_RENEW;
        }
        return selectedType;
    }

    private static EstimateSaveResult buildSaveResult(
        Id contractServiceId,
        Id contractHistoryId,
        Id historyIdForProducts
    ) {
        List<ContractProduct__c> savedProducts = [
            SELECT Id
            FROM ContractProduct__c
            WHERE ContractHistory__c = :historyIdForProducts
            WITH SYSTEM_MODE
        ];

        List<Id> productIds = new List<Id>();
        for (ContractProduct__c contractProduct : savedProducts) {
            productIds.add(contractProduct.Id);
        }

        EstimateSaveResult result = new EstimateSaveResult();
        result.contractServiceId = contractServiceId;
        result.contractHistoryId = contractHistoryId;
        result.contractProductIds = productIds;
        return result;
    }

    private static void validateNewSaveRequest(
        EstimateSaveRequest request,
        String contractHistoryName
    ) {
        validateCommonSaveRequest(request, contractHistoryName, true);

        if (String.isBlank(request.contractServiceName)) {
            throw new AuraHandledException('契約サービス名を入力してください。');
        }

        validateBillingAccount(request);
        validateProductLines(request.products, false);
        validateNewProductLineRules(
            request.products,
            request.contractStartDate,
            request.contractEndDate,
            true
        );
    }

    private static void validateChangeSaveRequest(
        EstimateSaveRequest request,
        String contractHistoryName
    ) {
        validateCommonSaveRequest(request, contractHistoryName, true);

        if (request.contractServiceId == null) {
            throw new AuraHandledException('契約サービスを選択してください。');
        }

        validatePreviousHistory(request);
        validateChangeEligibility(request.previousHistoryId);
        validateChangePeriodDates(request);
        validateProductLines(request.products, true);
        validateChangeProductLineRules(request);
    }

    private static void validateChangeEligibility(Id previousHistoryId) {
        ContractHistory__c previousHistory = loadPreviousHistoryTerm(previousHistoryId);
        if (previousHistory.Type__c == HISTORY_TYPE_CANCEL) {
            throw new AuraHandledException(
                'Churn（解約）済みの契約履歴からChangeは作成できません。'
            );
        }
        if (loadChangeSourceProducts(previousHistoryId).isEmpty()) {
            throw new AuraHandledException('継続課金の契約商品がありません。');
        }
    }

    private static ContractHistory__c loadPreviousHistoryTerm(Id previousHistoryId) {
        List<ContractHistory__c> histories = [
            SELECT Id, Type__c, CurrentTermStartDate__c, CurrentTermEndDate__c
            FROM ContractHistory__c
            WHERE Id = :previousHistoryId
            WITH SYSTEM_MODE
            LIMIT 1
        ];
        if (histories.isEmpty()) {
            throw new AuraHandledException('前回契約履歴が見つかりません。');
        }
        return histories[0];
    }

    private static List<ContractProduct__c> loadChangeSourceProducts(Id contractHistoryId) {
        if (contractHistoryId == null) {
            return new List<ContractProduct__c>();
        }

        return [
            SELECT
                Id,
                Product__c,
                Quantity__c,
                UnitPrice__c,
                StartDate__c,
                Enddate__c,
                InvoiceSetting__c
            FROM ContractProduct__c
            WHERE ContractHistory__c = :contractHistoryId
            AND Product__r.BillingType__c = :BILLING_TYPE_RECURRING
            AND Quantity__c > 0
            AND (
                Type__c = NULL
                OR Type__c IN (
                    :PRODUCT_TYPE_REMAKE,
                    :PRODUCT_TYPE_NEW,
                    :PRODUCT_TYPE_RENEW
                )
            )
            WITH SYSTEM_MODE
            ORDER BY Name ASC
        ];
    }

    private static void validateChangePeriodDates(EstimateSaveRequest request) {
        ContractHistory__c previousHistory = loadPreviousHistoryTerm(
            request.previousHistoryId
        );
        if (
            previousHistory.CurrentTermStartDate__c == null ||
            previousHistory.CurrentTermEndDate__c == null
        ) {
            throw new AuraHandledException(
                '前回契約履歴の期間開始日または期間終了日が取得できません。'
            );
        }

        Date expectedStartDate = previousHistory.CurrentTermStartDate__c;
        Date previousEndDate = previousHistory.CurrentTermEndDate__c;
        Date headerStartDate = parseDate(request.contractStartDate);
        Date headerEndDate = parseDate(request.contractEndDate);

        if (headerStartDate != expectedStartDate) {
            throw new AuraHandledException(
                '期間開始日は前回Versionの期間開始日と一致している必要があります。'
            );
        }
        if (headerEndDate == null || headerEndDate < previousEndDate) {
            throw new AuraHandledException(
                '期間終了日は前回Versionの期間終了日以降の日付を入力してください。'
            );
        }

        validateNewHeaderMonthlyPeriod(headerStartDate, headerEndDate);
    }

    private static void validateChangeProductLineRules(EstimateSaveRequest request) {
        List<ContractProduct__c> sourceProducts = loadChangeSourceProducts(
            request.previousHistoryId
        );
        Map<Id, ContractProduct__c> sourceById = new Map<Id, ContractProduct__c>(
            sourceProducts
        );

        Map<Id, ProductLineItem> originalBySourceId = new Map<Id, ProductLineItem>();
        Map<Id, List<ProductLineItem>> remakesBySourceId = new Map<Id, List<ProductLineItem>>();
        List<ProductLineItem> continuationLines = new List<ProductLineItem>();
        List<ProductLineItem> overlapCandidates = new List<ProductLineItem>();

        Date headerStartDate = parseDate(request.contractStartDate);
        Date headerEndDate = parseDate(request.contractEndDate);

        for (Integer i = 0; i < request.products.size(); i++) {
            ProductLineItem line = request.products[i];
            Integer rowNumber = i + 1;
            line.recordType = normalizeProductRecordType(line.recordType);

            if (isChangeOriginalLine(line)) {
                if (line.sourceContractProductId == null) {
                    throw new AuraHandledException(
                        '商品明細' + rowNumber + '行目: Original行に元の契約商品が指定されていません。'
                    );
                }
                if (originalBySourceId.containsKey(line.sourceContractProductId)) {
                    throw new AuraHandledException('Original行が重複しています。');
                }
                ContractProduct__c source = sourceById.get(line.sourceContractProductId);
                if (source == null) {
                    throw new AuraHandledException(
                        'Original行は前回Versionの契約商品と一致している必要があります。'
                    );
                }
                validateOriginalMatchesSource(line, source, rowNumber);
                originalBySourceId.put(line.sourceContractProductId, line);
                continue;
            }

            if (isChangeRemakeLine(line)) {
                if (line.sourceContractProductId == null) {
                    throw new AuraHandledException(
                        '商品明細' +
                            rowNumber +
                            '行目: Remake行に元の契約商品が指定されていません。'
                    );
                }
                if (!remakesBySourceId.containsKey(line.sourceContractProductId)) {
                    remakesBySourceId.put(
                        line.sourceContractProductId,
                        new List<ProductLineItem>()
                    );
                }
                remakesBySourceId.get(line.sourceContractProductId).add(line);
                if (isActiveProductLine(line)) {
                    validateChangeEditableLine(
                        line,
                        rowNumber,
                        headerStartDate,
                        headerEndDate
                    );
                    overlapCandidates.add(line);
                }
                continue;
            }

            if (isChangeContinuationLine(line)) {
                continuationLines.add(line);
                if (isActiveProductLine(line)) {
                    validateChangeEditableLine(
                        line,
                        rowNumber,
                        headerStartDate,
                        headerEndDate
                    );
                    overlapCandidates.add(line);
                }
                continue;
            }

            if (isActiveProductLine(line)) {
                validateChangeEditableLine(
                    line,
                    rowNumber,
                    headerStartDate,
                    headerEndDate
                );
                overlapCandidates.add(line);
            }
        }

        for (ContractProduct__c source : sourceProducts) {
            if (!originalBySourceId.containsKey(source.Id)) {
                throw new AuraHandledException(
                    '前回Versionの継続課金商品すべてにOriginal行が必要です。'
                );
            }
            List<ProductLineItem> remakes = remakesBySourceId.get(source.Id);
            if (remakes == null || remakes.isEmpty()) {
                throw new AuraHandledException(
                    '前回Versionの継続課金商品すべてにRemake行を1件以上入力してください。'
                );
            }

            String reconstitutionError = validateChangeReconstitutionCoverage(
                originalBySourceId.get(source.Id),
                remakes,
                continuationLines,
                formatDate(headerStartDate),
                formatDate(headerEndDate),
                request.effectiveDate
            );
            if (reconstitutionError != null) {
                throw new AuraHandledException(reconstitutionError);
            }
        }

        validateChangeProductPeriodOverlap(overlapCandidates);
        validateChangeRecurringEndEndpointCoverage(
            request.products,
            request.contractEndDate
        );
    }

    private static void validateChangeRecurringEndEndpointCoverage(
        List<ProductLineItem> products,
        String headerEndDate
    ) {
        Boolean hasRecurringEndMatch = false;

        for (ProductLineItem line : products) {
            if (isChangeOriginalLine(line)) {
                continue;
            }
            if (!isActiveProductLine(line) || !isRecurringProductLine(line)) {
                continue;
            }
            if (line.endDate == headerEndDate) {
                hasRecurringEndMatch = true;
                break;
            }
        }

        if (!hasRecurringEndMatch) {
            throw new AuraHandledException(
                '期間終了日と一致する終了日の継続課金明細が1件以上必要です。'
            );
        }
    }

    private static void validateOriginalMatchesSource(
        ProductLineItem line,
        ContractProduct__c source,
        Integer rowNumber
    ) {
        if (line.productId != source.Product__c) {
            throw new AuraHandledException(
                '商品明細' +
                    rowNumber +
                    '行目: Original行は前回Versionの契約商品と一致している必要があります。'
            );
        }
        if (!decimalsEqual(line.quantity, source.Quantity__c)) {
            throw new AuraHandledException(
                '商品明細' +
                    rowNumber +
                    '行目: Original行は前回Versionの契約商品と一致している必要があります。'
            );
        }
        if (!decimalsEqual(line.unitPrice, source.UnitPrice__c)) {
            throw new AuraHandledException(
                '商品明細' +
                    rowNumber +
                    '行目: Original行は前回Versionの契約商品と一致している必要があります。'
            );
        }
        if (line.invoiceType != source.InvoiceSetting__c) {
            throw new AuraHandledException(
                '商品明細' +
                    rowNumber +
                    '行目: Original行は前回Versionの契約商品と一致している必要があります。'
            );
        }
        if (formatDate(source.StartDate__c) != line.startDate) {
            throw new AuraHandledException(
                '商品明細' +
                    rowNumber +
                    '行目: Original行は前回Versionの契約商品と一致している必要があります。'
            );
        }
        if (formatDate(source.Enddate__c) != line.endDate) {
            throw new AuraHandledException(
                '商品明細' +
                    rowNumber +
                    '行目: Original行は前回Versionの契約商品と一致している必要があります。'
            );
        }
    }

    private static String validateChangeReconstitutionCoverage(
        ProductLineItem original,
        List<ProductLineItem> derivatives,
        List<ProductLineItem> continuationLines,
        String contractStartDate,
        String contractEndDate,
        String effectiveDate
    ) {
        if (original == null || derivatives == null || derivatives.isEmpty()) {
            return '相殺後の商品明細を1行以上入力してください。';
        }

        List<ProductLineItem> segments = buildSameProductReconstitutionSegments(
            derivatives,
            continuationLines,
            original.productId
        );
        if (segments.isEmpty()) {
            return '相殺後の商品明細を1行以上入力してください。';
        }

        if (
            String.isNotBlank(contractStartDate) &&
            segments[0].startDate != contractStartDate &&
            !(
                segments.size() == 1 &&
                String.isNotBlank(effectiveDate) &&
                segments[0].startDate == effectiveDate
            )
        ) {
            return '変更後の商品明細は期間開始日から連続して入力してください。';
        }

        for (Integer index = 0; index < segments.size() - 1; index++) {
            String expectedNextStart = formatDate(
                parseDate(segments[index].endDate).addDays(1)
            );
            if (segments[index + 1].startDate != expectedNextStart) {
                return '変更後の商品明細の期間に空きがあります。期間開始日から連続して入力してください。';
            }
        }

        ProductLineItem lastSegment = segments[segments.size() - 1];
        if (
            String.isNotBlank(contractEndDate) &&
            lastSegment.endDate != contractEndDate &&
            !hasReplacementCoverage(
                continuationLines,
                original.productId,
                contractEndDate,
                lastSegment.endDate
            )
        ) {
            return '変更後の商品明細は期間終了日まで連続して入力してください。';
        }

        return null;
    }

    private static List<ProductLineItem> buildSameProductReconstitutionSegments(
        List<ProductLineItem> derivatives,
        List<ProductLineItem> continuationLines,
        Id productId
    ) {
        List<ProductLineItem> segments = new List<ProductLineItem>();
        if (derivatives != null) {
            for (ProductLineItem derivative : derivatives) {
                if (isReconstitutionSegment(derivative)) {
                    segments.add(derivative);
                }
            }
        }
        if (continuationLines != null) {
            for (ProductLineItem line : continuationLines) {
                if (!isReconstitutionSegment(line) || line.productId != productId) {
                    continue;
                }
                segments.add(line);
            }
        }
        segments.sort(new ProductLineItemStartDateComparator());
        return segments;
    }

    private static Boolean hasReplacementCoverage(
        List<ProductLineItem> continuationLines,
        Id originalProductId,
        String contractEndDate,
        String lastEndDate
    ) {
        if (
            String.isBlank(contractEndDate) ||
            String.isBlank(lastEndDate) ||
            lastEndDate == contractEndDate
        ) {
            return lastEndDate == contractEndDate;
        }

        Date lastEnd = parseDate(lastEndDate);
        if (lastEnd == null) {
            return false;
        }
        String expectedStart = formatDate(lastEnd.addDays(1));
        if (continuationLines == null) {
            return false;
        }

        for (ProductLineItem line : continuationLines) {
            if (!isReconstitutionSegment(line) || line.productId == originalProductId) {
                continue;
            }
            if (line.startDate == expectedStart && line.endDate == contractEndDate) {
                return true;
            }
        }
        return false;
    }

    private static Boolean isReconstitutionSegment(ProductLineItem line) {
        return line != null &&
            line.productId != null &&
            String.isNotBlank(line.startDate) &&
            String.isNotBlank(line.endDate) &&
            line.quantity != null &&
            line.quantity > 0;
    }

    private static List<ProductLineItem> normalizeChangeProductsForSave(
        List<ProductLineItem> products,
        Date effectiveDate,
        Date contractStartDate,
        Date contractEndDate
    ) {
        if (products == null || products.isEmpty() || effectiveDate == null) {
            return products == null ? new List<ProductLineItem>() : products;
        }

        List<ProductLineItem> originals = new List<ProductLineItem>();
        Map<Id, List<ProductLineItem>> remakesBySourceId = new Map<Id, List<ProductLineItem>>();
        List<ProductLineItem> continuationLines = new List<ProductLineItem>();

        for (ProductLineItem line : products) {
            line.recordType = normalizeProductRecordType(line.recordType);
            if (isChangeOriginalLine(line)) {
                originals.add(line);
            } else if (isChangeRemakeLine(line)) {
                if (!remakesBySourceId.containsKey(line.sourceContractProductId)) {
                    remakesBySourceId.put(
                        line.sourceContractProductId,
                        new List<ProductLineItem>()
                    );
                }
                remakesBySourceId.get(line.sourceContractProductId).add(line);
            } else if (isChangeContinuationLine(line)) {
                continuationLines.add(line);
            }
        }

        List<ProductLineItem> normalized = new List<ProductLineItem>();
        normalized.addAll(originals);
        Set<String> mergedContinuationKeys = new Set<String>();
        String contractEndDateString = formatDate(contractEndDate);

        for (ProductLineItem original : originals) {
            List<ProductLineItem> derivatives = remakesBySourceId.get(
                original.sourceContractProductId
            );
            if (derivatives == null || derivatives.isEmpty()) {
                continue;
            }

            derivatives.sort(new ProductLineItemStartDateComparator());

            if (derivatives.size() > 1) {
                for (ProductLineItem derivative : derivatives) {
                    ProductLineItem savedDerivative = cloneProductLineItem(derivative);
                    savedDerivative.recordType = PRODUCT_TYPE_REMAKE;
                    savedDerivative.typeLabel = 'Remake';
                    savedDerivative.sourceContractProductId = original.sourceContractProductId;
                    normalized.add(savedDerivative);
                }
                continue;
            }

            List<ProductLineItem> sameProductNews = new List<ProductLineItem>();
            for (ProductLineItem line : continuationLines) {
                if (line.productId == original.productId) {
                    sameProductNews.add(line);
                }
            }

            ProductLineItem primaryDerivative = derivatives[0];
            List<ProductLineItem> continuationSegments = new List<ProductLineItem>();
            for (Integer index = 1; index < derivatives.size(); index++) {
                continuationSegments.add(derivatives[index]);
            }
            continuationSegments.addAll(sameProductNews);

            ProductLineItem postLine = resolvePostEffectiveRemakeLine(
                primaryDerivative,
                continuationSegments,
                effectiveDate,
                contractEndDateString
            );
            if (postLine == null) {
                continue;
            }

            postLine.recordType = PRODUCT_TYPE_REMAKE;
            postLine.typeLabel = 'Remake';
            postLine.sourceContractProductId = original.sourceContractProductId;
            normalized.add(postLine);

            for (ProductLineItem newLine : sameProductNews) {
                if (shouldMergeSameProductNewLine(postLine, newLine)) {
                    mergedContinuationKeys.add(buildProductLineKey(newLine));
                }
            }
        }

        for (ProductLineItem line : continuationLines) {
            if (mergedContinuationKeys.contains(buildProductLineKey(line))) {
                continue;
            }
            line.recordType = PRODUCT_TYPE_NEW;
            line.typeLabel = 'New';
            normalized.add(line);
        }

        return normalized;
    }

    private static ProductLineItem resolvePostEffectiveRemakeLine(
        ProductLineItem derivative,
        List<ProductLineItem> continuationSegments,
        Date effectiveDate,
        String contractEndDate
    ) {
        if (derivative == null) {
            return null;
        }

        ProductLineItem postSegment = null;
        if (continuationSegments != null) {
            for (ProductLineItem line : continuationSegments) {
                if (!isReconstitutionSegment(line)) {
                    continue;
                }
                Date lineStartDate = parseDate(line.startDate);
                if (lineStartDate == null || lineStartDate < effectiveDate) {
                    continue;
                }
                if (
                    postSegment == null ||
                    line.startDate.compareTo(postSegment.startDate) < 0
                ) {
                    postSegment = line;
                }
            }
        }

        Date derivativeStartDate = parseDate(derivative.startDate);
        Date derivativeEndDate = parseDate(derivative.endDate);
        if (derivativeStartDate != null && derivativeStartDate >= effectiveDate) {
            return cloneProductLineItem(derivative);
        }
        if (postSegment != null) {
            return cloneProductLineItem(postSegment);
        }
        if (
            derivativeEndDate != null &&
            derivativeEndDate >= effectiveDate
        ) {
            ProductLineItem clipped = cloneProductLineItem(derivative);
            clipped.startDate = derivativeStartDate >= effectiveDate
                ? derivative.startDate
                : formatDate(effectiveDate);
            return clipped;
        }
        if (derivativeEndDate != null && derivativeEndDate < effectiveDate) {
            ProductLineItem discontinued = cloneProductLineItem(derivative);
            discontinued.quantity = 0;
            discontinued.amount = 0;
            discontinued.startDate = formatDate(effectiveDate);
            discontinued.endDate = contractEndDate;
            return discontinued;
        }

        return cloneProductLineItem(derivative);
    }

    private static Boolean shouldMergeSameProductNewLine(
        ProductLineItem postLine,
        ProductLineItem newLine
    ) {
        if (postLine == null || newLine == null) {
            return false;
        }
        return postLine.productId == newLine.productId &&
            postLine.startDate == newLine.startDate &&
            postLine.endDate == newLine.endDate &&
            decimalsEqual(postLine.quantity, newLine.quantity) &&
            decimalsEqual(postLine.unitPrice, newLine.unitPrice) &&
            postLine.invoiceType == newLine.invoiceType;
    }

    private static ProductLineItem cloneProductLineItem(ProductLineItem source) {
        ProductLineItem clone = new ProductLineItem();
        clone.productId = source.productId;
        clone.productName = source.productName;
        clone.quantity = source.quantity;
        clone.unitPrice = source.unitPrice;
        clone.amount = source.amount;
        clone.startDate = source.startDate;
        clone.endDate = source.endDate;
        clone.invoiceType = source.invoiceType;
        clone.billingType = source.billingType;
        clone.billingCycle = source.billingCycle;
        clone.unit = source.unit;
        clone.sourceContractProductId = source.sourceContractProductId;
        clone.recordType = source.recordType;
        clone.typeLabel = source.typeLabel;
        clone.isDuplicate = source.isDuplicate;
        return clone;
    }

    private static String buildProductLineKey(ProductLineItem line) {
        return String.join(
            new List<String>{
                String.valueOf(line.productId),
                line.startDate,
                line.endDate,
                String.valueOf(line.quantity),
                String.valueOf(line.unitPrice),
                line.invoiceType
            },
            '|'
        );
    }

    private class ProductLineItemStartDateComparator implements Comparator<ProductLineItem> {
        public Integer compare(ProductLineItem left, ProductLineItem right) {
            if (left == null && right == null) {
                return 0;
            }
            if (left == null) {
                return -1;
            }
            if (right == null) {
                return 1;
            }
            String leftStart = left.startDate == null ? '' : left.startDate;
            String rightStart = right.startDate == null ? '' : right.startDate;
            return leftStart.compareTo(rightStart);
        }
    }

    private static Boolean isChangeContinuationLine(ProductLineItem line) {
        if (line == null || isChangeOriginalLine(line) || isChangeRemakeLine(line)) {
            return false;
        }
        String recordType = normalizeProductRecordType(line.recordType);
        if (recordType == PRODUCT_TYPE_NEW && line.sourceContractProductId == null) {
            return true;
        }
        if (recordType == PRODUCT_TYPE_REMAKE && line.sourceContractProductId == null) {
            return true;
        }
        return false;
    }

    private static void validateChangeEditableLine(
        ProductLineItem line,
        Integer rowNumber,
        Date headerStartDate,
        Date headerEndDate
    ) {
        if (String.isBlank(line.startDate) || String.isBlank(line.endDate)) {
            throw new AuraHandledException(
                '商品明細' + rowNumber + '行目: 開始日と終了日を入力してください。'
            );
        }

        Date lineStartDate = parseDate(line.startDate);
        Date lineEndDate = parseDate(line.endDate);
        if (lineStartDate != null && lineEndDate != null && lineStartDate > lineEndDate) {
            throw new AuraHandledException(
                '商品明細' +
                    rowNumber +
                    '行目: 開始日は終了日以前の日付を入力してください。'
            );
        }
        if (lineStartDate != null && headerStartDate != null && lineStartDate < headerStartDate) {
            throw new AuraHandledException(
                '商品明細' +
                    rowNumber +
                    '行目: 開始日は期間開始日以降の日付を入力してください。'
            );
        }
        if (lineEndDate != null && headerEndDate != null && lineEndDate > headerEndDate) {
            throw new AuraHandledException(
                '商品明細' +
                    rowNumber +
                    '行目: 終了日は期間終了日以前の日付を入力してください。'
            );
        }
        if (String.isBlank(line.invoiceType)) {
            throw new AuraHandledException(
                '商品明細' + rowNumber + '行目: 請求設定を選択してください。'
            );
        }
        String invoiceSettingError = validateInvoiceSettingLine(line, rowNumber);
        if (invoiceSettingError != null) {
            throw new AuraHandledException(invoiceSettingError);
        }
    }

    private static void validateChangeProductPeriodOverlap(List<ProductLineItem> products) {
        validateNewProductPeriodOverlap(products);
    }

    private static Boolean decimalsEqual(Decimal left, Decimal right) {
        if (left == null && right == null) {
            return true;
        }
        if (left == null || right == null) {
            return false;
        }
        return left.stripTrailingZeros().equals(right.stripTrailingZeros());
    }

    private static void validateRenewSaveRequest(
        EstimateSaveRequest request,
        String contractHistoryName
    ) {
        validateCommonSaveRequest(request, contractHistoryName, true);

        if (request.contractServiceId == null) {
            throw new AuraHandledException('契約サービスを選択してください。');
        }

        validatePreviousHistory(request);
        validateRenewEligibility(request.previousHistoryId);
        validateRenewPeriodStartDate(request);
        validateProductLines(request.products, false);
        validateRenewProductLineRules(
            request.products,
            request.contractStartDate,
            request.contractEndDate
        );
    }

    private static void validateRenewEligibility(Id previousHistoryId) {
        validateRecurringSourceEligibility(previousHistoryId, 'Renew');
    }

    private static void validateCancelEligibility(Id previousHistoryId) {
        validateRecurringSourceEligibility(previousHistoryId, 'Cancel');
    }

    private static void validateRecurringSourceEligibility(
        Id previousHistoryId,
        String targetOperation
    ) {
        List<ContractHistory__c> histories = [
            SELECT Id, Type__c, CurrentTermEndDate__c
            FROM ContractHistory__c
            WHERE Id = :previousHistoryId
            WITH SYSTEM_MODE
            LIMIT 1
        ];
        if (histories.isEmpty()) {
            throw new AuraHandledException('前回契約履歴が見つかりません。');
        }

        ContractHistory__c history = histories[0];
        if (history.Type__c == HISTORY_TYPE_CANCEL) {
            if (targetOperation == 'Renew') {
                throw new AuraHandledException(
                    'Churn（解約）済みの契約履歴からRenewは作成できません。'
                );
            }
            throw new AuraHandledException(
                'Churn（解約）済みの契約履歴からCancelは作成できません。'
            );
        }
        if (
            history.CurrentTermEndDate__c == null ||
            countRenewSourceRecurringProducts(
                history.Id,
                history.CurrentTermEndDate__c
            ) == 0
        ) {
            if (targetOperation == 'Renew') {
                throw new AuraHandledException(
                    '前回Versionの期間終了日と一致する継続課金商品がありません。Renewできません。Newで作成してください。'
                );
            }
            throw new AuraHandledException(
                '前回Versionの期間終了日と一致する継続課金商品がありません。Cancelできません。Newで作成してください。'
            );
        }
    }

    private static void validateRenewPeriodStartDate(EstimateSaveRequest request) {
        List<ContractHistory__c> histories = [
            SELECT CurrentTermEndDate__c
            FROM ContractHistory__c
            WHERE Id = :request.previousHistoryId
            WITH SYSTEM_MODE
            LIMIT 1
        ];
        if (histories.isEmpty() || histories[0].CurrentTermEndDate__c == null) {
            throw new AuraHandledException('前回契約履歴の期間終了日が取得できません。');
        }

        Date expectedStartDate = histories[0].CurrentTermEndDate__c.addDays(1);
        Date serviceStartDate = parseDate(request.contractStartDate);
        if (serviceStartDate != expectedStartDate) {
            throw new AuraHandledException(
                '期間開始日は前回Versionの期間終了日の翌日である必要があります。'
            );
        }
    }

    private static void validateRenewProductLineRules(
        List<ProductLineItem> products,
        String headerStartDate,
        String headerEndDate
    ) {
        if (products == null || products.isEmpty()) {
            return;
        }

        Boolean hasActiveLine = false;
        Boolean hasRecurringLine = false;
        for (Integer i = 0; i < products.size(); i++) {
            ProductLineItem line = products[i];
            if (!isActiveProductLine(line)) {
                continue;
            }
            hasActiveLine = true;
            if (isRecurringProductLine(line)) {
                hasRecurringLine = true;
            }
        }

        if (!hasActiveLine) {
            throw new AuraHandledException('商品明細を1行以上入力してください。');
        }
        if (!hasRecurringLine) {
            throw new AuraHandledException(
                'Renewでは継続課金商品を1行以上指定してください。一回課金のみのRenewはできません。'
            );
        }

        validateNewProductLineRules(products, headerStartDate, headerEndDate, true);
    }

    private static void validateCancelSaveRequest(
        EstimateSaveRequest request,
        String contractHistoryName
    ) {
        validateCommonSaveRequest(request, contractHistoryName, false);

        if (request.contractServiceId == null) {
            throw new AuraHandledException('契約サービスを選択してください。');
        }

        validatePreviousHistory(request);
        validateCancelEligibility(request.previousHistoryId);
        validateCancelPeriodDates(request);
        validateCancelNoProducts(request.products);

        if (String.isBlank(request.contractStartDate) || String.isBlank(request.contractEndDate)) {
            throw new AuraHandledException('解約日が取得できません。');
        }

        if (request.contractStartDate != request.contractEndDate) {
            throw new AuraHandledException('解約日の開始日と終了日が一致しません。');
        }
    }

    private static void validateCancelPeriodDates(EstimateSaveRequest request) {
        List<ContractHistory__c> histories = [
            SELECT CurrentTermEndDate__c
            FROM ContractHistory__c
            WHERE Id = :request.previousHistoryId
            WITH SYSTEM_MODE
            LIMIT 1
        ];
        if (histories.isEmpty() || histories[0].CurrentTermEndDate__c == null) {
            throw new AuraHandledException('前回契約履歴の期間終了日が取得できません。');
        }

        Date expectedCancelDate = histories[0].CurrentTermEndDate__c.addDays(1);
        Date cancelStartDate = parseDate(request.contractStartDate);
        Date cancelEndDate = parseDate(request.contractEndDate);
        if (cancelStartDate != expectedCancelDate || cancelEndDate != expectedCancelDate) {
            throw new AuraHandledException(
                '解約日は前回Versionの期間終了日の翌日である必要があります。'
            );
        }
    }

    private static void validateCancelNoProducts(List<ProductLineItem> products) {
        if (products == null || products.isEmpty()) {
            return;
        }

        for (ProductLineItem line : products) {
            if (isActiveProductLine(line)) {
                throw new AuraHandledException('Cancelでは商品明細を入力できません。');
            }
        }
    }

    private static void validateBillingAccount(EstimateSaveRequest request) {
        if (request.billingAccountId == null) {
            return;
        }

        List<Opportunity> opportunities = [
            SELECT AccountId
            FROM Opportunity
            WHERE Id = :request.opportunityId
            WITH SYSTEM_MODE
            LIMIT 1
        ];
        if (opportunities.isEmpty() || opportunities[0].AccountId == null) {
            throw new AuraHandledException('商談に取引先が設定されていません。');
        }

        List<BillingAccount__c> billingAccounts = [
            SELECT Id, Account__c
            FROM BillingAccount__c
            WHERE Id = :request.billingAccountId
            WITH SYSTEM_MODE
            LIMIT 1
        ];
        if (billingAccounts.isEmpty()) {
            throw new AuraHandledException('請求アカウントが見つかりません。');
        }
        if (billingAccounts[0].Account__c != opportunities[0].AccountId) {
            throw new AuraHandledException(
                '請求アカウントが商談の取引先と一致しません。'
            );
        }
    }

    private static void validatePreviousHistory(EstimateSaveRequest request) {
        if (request.previousHistoryId == null) {
            throw new AuraHandledException('前回契約履歴が指定されていません。');
        }

        List<ContractHistory__c> histories = [
            SELECT Id, ContractService__c
            FROM ContractHistory__c
            WHERE Id = :request.previousHistoryId
            WITH SYSTEM_MODE
            LIMIT 1
        ];
        if (histories.isEmpty()) {
            throw new AuraHandledException('前回契約履歴が見つかりません。');
        }
        if (histories[0].ContractService__c != request.contractServiceId) {
            throw new AuraHandledException('前回契約履歴が契約サービスと一致しません。');
        }
    }

    private static void validateCommonSaveRequest(
        EstimateSaveRequest request,
        String contractHistoryName,
        Boolean requireProducts
    ) {
        if (request.opportunityId == null) {
            throw new AuraHandledException('商談IDが指定されていません。');
        }

        if (String.isBlank(contractHistoryName)) {
            throw new AuraHandledException('契約履歴名を入力してください。');
        }

        if (String.isBlank(request.contractStartDate) || String.isBlank(request.contractEndDate)) {
            throw new AuraHandledException('期間開始日と期間終了日を入力してください。');
        }

        Date serviceStartDate = parseDate(request.contractStartDate);
        Date serviceEndDate = parseDate(request.contractEndDate);
        if (serviceStartDate != null && serviceEndDate != null && serviceStartDate > serviceEndDate) {
            throw new AuraHandledException('期間開始日は期間終了日以前の日付を入力してください。');
        }

        validateHistoryMetaDates(request, serviceStartDate, serviceEndDate);

        if (requireProducts && (request.products == null || request.products.isEmpty())) {
            throw new AuraHandledException('商品明細を1行以上入力してください。');
        }
    }

    private static void validateHistoryMetaDates(
        EstimateSaveRequest request,
        Date serviceStartDate,
        Date serviceEndDate
    ) {
        if (String.isBlank(request.effectiveDate)) {
            throw new AuraHandledException('有効日を入力してください。');
        }
        Date effectiveDate = parseDate(request.effectiveDate);
        if (effectiveDate == null) {
            throw new AuraHandledException('有効日の形式が正しくありません。');
        }

        if (request.selectedType == 'Change') {
            if (request.previousHistoryId == null) {
                throw new AuraHandledException('前回契約履歴が指定されていません。');
            }
            ContractHistory__c previousHistory = loadPreviousHistoryTerm(
                request.previousHistoryId
            );
            if (
                previousHistory.CurrentTermStartDate__c == null ||
                previousHistory.CurrentTermEndDate__c == null
            ) {
                throw new AuraHandledException(
                    '前回契約履歴の期間開始日または期間終了日が取得できません。'
                );
            }
            Date previousStartDate = previousHistory.CurrentTermStartDate__c;
            Date previousEndDate = previousHistory.CurrentTermEndDate__c;
            if (effectiveDate < previousStartDate || effectiveDate > previousEndDate) {
                throw new AuraHandledException(
                    '有効日は前回Versionの期間開始日から期間終了日の間で入力してください。'
                );
            }
            if (
                !MonthlyBillingPeriodUtil.isMonthlyPeriodStartDate(
                    previousStartDate,
                    effectiveDate
                )
            ) {
                throw new AuraHandledException(
                    '有効日は期間開始日基準の請求期間開始日である必要があります（日割りはできません）。'
                );
            }
            return;
        }

        if (request.selectedType == 'New') {
            if (serviceStartDate != null && effectiveDate != serviceStartDate) {
                throw new AuraHandledException('有効日は期間開始日と一致している必要があります。');
            }
            return;
        }

        if (request.selectedType == 'Renew' || request.selectedType == 'Cancel') {
            if (request.previousHistoryId == null) {
                throw new AuraHandledException('前回契約履歴が指定されていません。');
            }
            List<ContractHistory__c> previousHistories = [
                SELECT CurrentTermEndDate__c
                FROM ContractHistory__c
                WHERE Id = :request.previousHistoryId
                WITH SYSTEM_MODE
                LIMIT 1
            ];
            if (
                previousHistories.isEmpty() ||
                previousHistories[0].CurrentTermEndDate__c == null
            ) {
                throw new AuraHandledException('前回契約履歴の期間終了日が取得できません。');
            }
            Date expectedEffective = previousHistories[0].CurrentTermEndDate__c.addDays(1);
            if (effectiveDate != expectedEffective) {
                throw new AuraHandledException(
                    '有効日は前回契約履歴の期間終了日の翌日である必要があります。'
                );
            }
        }
    }

    private static void validateProductLines(
        List<ProductLineItem> products,
        Boolean isChangeType
    ) {
        for (Integer i = 0; i < products.size(); i++) {
            ProductLineItem line = products[i];
            Integer rowNumber = i + 1;

            if (line.productId == null) {
                throw new AuraHandledException('商品明細' + rowNumber + '行目: 商品を選択してください。');
            }

            if (isChangeType && isChangeRemakeLine(line)) {
                if (line.quantity == null || line.quantity < 0) {
                    throw new AuraHandledException(
                        '商品明細' + rowNumber + '行目: 数量は0以上を入力してください。'
                    );
                }
            } else if (!isChangeType || !isChangeOriginalLine(line)) {
                if (line.quantity == null || line.quantity <= 0) {
                    throw new AuraHandledException('商品明細' + rowNumber + '行目: 数量を入力してください。');
                }
            }

            String periodError = validateBillingPeriod(line, rowNumber);
            if (periodError != null) {
                throw new AuraHandledException(periodError);
            }

            String invoiceSettingError = validateInvoiceSettingLine(line, rowNumber);
            if (invoiceSettingError != null) {
                throw new AuraHandledException(invoiceSettingError);
            }
        }
    }

    private static String validateInvoiceSettingLine(
        ProductLineItem line,
        Integer rowNumber
    ) {
        if (String.isBlank(line.invoiceType)) {
            return null;
        }
        String billingType = String.isNotBlank(line.billingType)
            ? line.billingType
            : null;
        if (billingType == null) {
            return null;
        }
        String validationError = ContractMetadataService.validateInvoiceSettingForBillingType(
            billingType,
            line.invoiceType
        );
        if (validationError == null) {
            return null;
        }
        return '商品明細' + rowNumber + '行目: ' + validationError;
    }

    private static void validateNewProductLineRules(
        List<ProductLineItem> products,
        String headerStartDate,
        String headerEndDate,
        Boolean includeProductOverlap
    ) {
        Date headerStart = parseDate(headerStartDate);
        Date headerEnd = parseDate(headerEndDate);
        Boolean hasRecurringLine = false;

        for (Integer i = 0; i < products.size(); i++) {
            ProductLineItem line = products[i];
            Integer rowNumber = i + 1;

            if (String.isBlank(line.startDate) || String.isBlank(line.endDate)) {
                throw new AuraHandledException(
                    '商品明細' + rowNumber + '行目: 開始日と終了日を入力してください。'
                );
            }

            Date lineStart = parseDate(line.startDate);
            Date lineEnd = parseDate(line.endDate);

            if (lineStart != null && lineEnd != null && lineStart > lineEnd) {
                throw new AuraHandledException(
                    '商品明細' +
                        rowNumber +
                        '行目: 開始日は終了日以前の日付を入力してください。'
                );
            }

            if (lineStart != null && headerStart != null && lineStart < headerStart) {
                throw new AuraHandledException(
                    '商品明細' +
                        rowNumber +
                        '行目: 開始日は期間開始日以降の日付を入力してください。'
                );
            }

            if (lineEnd != null && headerEnd != null && lineEnd > headerEnd) {
                throw new AuraHandledException(
                    '商品明細' +
                        rowNumber +
                        '行目: 終了日は期間終了日以前の日付を入力してください。'
                );
            }

            if (isActiveProductLine(line) && String.isBlank(line.invoiceType)) {
                throw new AuraHandledException(
                    '商品明細' + rowNumber + '行目: 請求設定を選択してください。'
                );
            }

            if (isActiveProductLine(line) && String.isNotBlank(line.invoiceType)) {
                String invoiceSettingError = validateInvoiceSettingLine(line, rowNumber);
                if (invoiceSettingError != null) {
                    throw new AuraHandledException(invoiceSettingError);
                }
            }

            if (isActiveProductLine(line) && isRecurringProductLine(line)) {
                hasRecurringLine = true;
            }
        }

        if (hasRecurringLine) {
            validateNewHeaderMonthlyPeriod(headerStart, headerEnd);
            validateNewRecurringEndpointCoverage(
                products,
                headerStartDate,
                headerEndDate
            );
        }

        if (includeProductOverlap == true) {
            validateNewProductPeriodOverlap(products);
        }
    }

    private static Boolean isActiveProductLine(ProductLineItem line) {
        return line.productId != null &&
            line.quantity != null &&
            line.quantity > 0;
    }

    private static Boolean isRecurringProductLine(ProductLineItem line) {
        if (line.billingType == BILLING_TYPE_ONE_TIME) {
            return false;
        }
        if (line.billingType == BILLING_TYPE_RECURRING) {
            return true;
        }
        return ContractMetadataService.isRecurringInvoiceSetting(line.invoiceType);
    }

    private static void validateNewHeaderMonthlyPeriod(Date headerStart, Date headerEnd) {
        if (headerStart == null || headerEnd == null) {
            return;
        }
        Integer cycles = ContractMetadataService.countMonthlyBillingCycles(
            headerStart,
            headerEnd
        );
        if (cycles == null || cycles < 1) {
            throw new AuraHandledException(
                '期間開始日と期間終了日の間が、月次単位（期間開始日基準）の倍数である必要があります。'
            );
        }
    }

    private static void validateNewRecurringEndpointCoverage(
        List<ProductLineItem> products,
        String headerStartDate,
        String headerEndDate
    ) {
        Boolean hasRecurringStartMatch = false;
        Boolean hasRecurringEndMatch = false;

        for (ProductLineItem line : products) {
            if (!isActiveProductLine(line) || !isRecurringProductLine(line)) {
                continue;
            }
            if (line.startDate == headerStartDate) {
                hasRecurringStartMatch = true;
            }
            if (line.endDate == headerEndDate) {
                hasRecurringEndMatch = true;
            }
        }

        if (!hasRecurringStartMatch) {
            throw new AuraHandledException(
                '期間開始日と一致する開始日の継続課金明細が1件以上必要です。'
            );
        }
        if (!hasRecurringEndMatch) {
            throw new AuraHandledException(
                '期間終了日と一致する終了日の継続課金明細が1件以上必要です。'
            );
        }
    }

    private static void validateNewProductPeriodOverlap(List<ProductLineItem> products) {
        List<ProductLineItem> activeLines = new List<ProductLineItem>();
        for (ProductLineItem line : products) {
            if (isActiveProductLine(line)) {
                activeLines.add(line);
            }
        }

        for (Integer i = 0; i < activeLines.size(); i++) {
            ProductLineItem left = activeLines[i];
            Date leftStart = parseDate(left.startDate);
            Date leftEnd = parseDate(left.endDate);
            if (leftStart == null || leftEnd == null) {
                continue;
            }

            for (Integer j = i + 1; j < activeLines.size(); j++) {
                ProductLineItem right = activeLines[j];
                if (left.productId != right.productId) {
                    continue;
                }

                Date rightStart = parseDate(right.startDate);
                Date rightEnd = parseDate(right.endDate);
                if (rightStart == null || rightEnd == null) {
                    continue;
                }

                if (leftStart <= rightEnd && leftEnd >= rightStart) {
                    throw new AuraHandledException(
                        '同一商品の契約期間が重複しています。商品ごとに期間が重ならないよう入力してください。'
                    );
                }
            }
        }
    }

    private static String validateBillingPeriod(ProductLineItem line, Integer rowNumber) {
        if (line.billingType != BILLING_TYPE_RECURRING) {
            return null;
        }
        if (String.isBlank(line.startDate) || String.isBlank(line.endDate)) {
            return '商品明細' + rowNumber + '行目: 開始日と終了日を入力してください。';
        }
        Integer cycles = ContractMetadataService.countMonthlyBillingCycles(
            parseDate(line.startDate),
            parseDate(line.endDate)
        );
        if (cycles == null || cycles < 1) {
            return '商品明細' +
                rowNumber +
                '行目: 開始日・終了日が月次単位（期間開始日基準）の倍数ではありません。';
        }
        return null;
    }

    private static String buildDisplayUnit(String unitName, String billingType) {
        if (billingType == BILLING_TYPE_RECURRING) {
            if (String.isBlank(unitName)) {
                return MONTHLY_BILLING_CYCLE;
            }
            return unitName + '・' + MONTHLY_BILLING_CYCLE;
        }
        return unitName;
    }

    private static String resolveRecurringBillingCycleLabel(String billingType) {
        return billingType == BILLING_TYPE_RECURRING ? MONTHLY_BILLING_CYCLE : null;
    }

    private static List<ProductLineItem> parseProducts(String productsJson) {
        List<ProductLineItem> lines = new List<ProductLineItem>();
        if (String.isBlank(productsJson)) {
            return lines;
        }

        for (Object row : (List<Object>) JSON.deserializeUntyped(productsJson)) {
            Map<String, Object> item = (Map<String, Object>) row;
            ProductLineItem line = new ProductLineItem();
            line.productId = (Id) item.get('productId');
            line.quantity = toDecimal(item.get('quantity'));
            line.unitPrice = toDecimal(item.get('unitPrice'));
            line.amount = toDecimal(item.get('amount'));
            line.startDate = (String) item.get('startDate');
            line.endDate = (String) item.get('endDate');
            line.invoiceType = (String) item.get('invoiceType');
            line.unit = (String) item.get('unit');
            line.billingType = (String) item.get('billingType');
            line.billingCycle = (String) item.get('billingCycle');
            line.recordType = normalizeProductRecordType((String) item.get('recordType'));
            line.typeLabel = (String) item.get('typeLabel');
            line.isDuplicate = toBoolean(item.get('isDuplicate'));
            line.sourceContractProductId = (Id) item.get('sourceContractProductId');
            lines.add(line);
        }
        return lines;
    }

    private static String normalizeProductRecordType(String recordType) {
        if (String.isBlank(recordType)) {
            return PRODUCT_TYPE_NEW;
        }
        String value = recordType.trim();
        if (value.equalsIgnoreCase(LEGACY_PRODUCT_TYPE_DERIVATIVE)) {
            return PRODUCT_TYPE_REMAKE;
        }
        if (value == PRODUCT_TYPE_ORIGINAL) {
            return PRODUCT_TYPE_ORIGINAL;
        }
        if (value == PRODUCT_TYPE_REMAKE) {
            return PRODUCT_TYPE_REMAKE;
        }
        if (value == PRODUCT_TYPE_RENEW) {
            return PRODUCT_TYPE_RENEW;
        }
        if (value == PRODUCT_TYPE_NEW) {
            return PRODUCT_TYPE_NEW;
        }
        return value;
    }

    private static Boolean isChangeOriginalLine(ProductLineItem line) {
        if (line == null) {
            return false;
        }
        String recordType = normalizeProductRecordType(line.recordType);
        if (recordType == PRODUCT_TYPE_ORIGINAL) {
            return true;
        }
        return recordType == PRODUCT_TYPE_REMAKE && line.isReadonly == true;
    }

    private static Boolean isChangeRemakeLine(ProductLineItem line) {
        if (line == null || line.sourceContractProductId == null) {
            return false;
        }
        if (isChangeOriginalLine(line)) {
            return false;
        }
        return normalizeProductRecordType(line.recordType) == PRODUCT_TYPE_REMAKE;
    }

    private static Boolean toBoolean(Object value) {
        if (value == null) {
            return false;
        }
        if (value instanceof Boolean) {
            return (Boolean) value;
        }
        return Boolean.valueOf(String.valueOf(value));
    }

    private static Decimal toDecimal(Object value) {
        if (value == null || String.isBlank(String.valueOf(value))) {
            return null;
        }
        return Decimal.valueOf(String.valueOf(value));
    }

    private static void applyRemarks(
        ContractHistory__c contractHistory,
        String remarksText
    ) {
        if (contractHistory == null || String.isBlank(remarksText)) {
            return;
        }
        contractHistory.Note__c = remarksText.length() > NOTE_MAX_LENGTH
            ? remarksText.substring(0, NOTE_MAX_LENGTH)
            : remarksText;
    }

    private static Date parseDate(String dateValue) {
        if (String.isBlank(dateValue)) {
            return null;
        }
        return Date.valueOf(dateValue);
    }

    private static String formatDate(Date dateValue) {
        return dateValue == null ? null : String.valueOf(dateValue);
    }
}
