public without sharing class InvoiceProductGenerationService {
    private static final String BILLING_TYPE_RECURRING = '継続課金';
    private static final String PRODUCT_TYPE_ORIGINAL = 'Original';
    private static final String PRODUCT_TYPE_REMAKE = 'Remake';
    private static final String LEGACY_PRODUCT_TYPE_DERIVATIVE = 'derivative';
    private static final String HISTORY_TYPE_CHANGE = 'Change';
    private static final String HISTORY_TYPE_CANCEL = 'Cancel';
    private static final String HISTORY_STATUS_ORDERED = 'Ordered';

    private class InvoiceGenerationContext {
        public String historyType;
        public Date effectiveDate;
    }

    private class HistoryBillingContext {
        public String paymentTermLabel;
        public Decimal taxPercent;
        public ContractMetadataService.InvoiceDateContext invoiceDateContext;
        public BillingAccountSnapshot billingAccountSnapshot;
    }

    private class BillingAccountSnapshot {
        public Id billingAccountId;
        public String paymentTerm;
        public String billingDayOfMonth;
        public String billingAddressee;
        public String billingEmailTo;
        public String billingEmailCc;
        public String billingEmailBcc;
    }

    private class HistoryGenerationContext {
        public Id historyId;
        public Id contractServiceId;
        public Decimal version;
        public String historyType;
        public Date effectiveDate;
    }

    private class MergeKeyDraft {
        public String mergeKey;
        public Decimal amount = 0;
        public InvoiceProduct__c template;
    }

    private class DraftInvoiceLine {
        public Id productId;
        public ContractProduct__c contractProduct;
        public InvoiceProduct__c invoiceProduct;

        public DraftInvoiceLine(
            Id productId,
            ContractProduct__c contractProduct,
            InvoiceProduct__c invoiceProduct
        ) {
            this.productId = productId;
            this.contractProduct = contractProduct;
            this.invoiceProduct = invoiceProduct;
        }
    }

    public static void generateForHistories(Set<Id> contractHistoryIds) {
        if (contractHistoryIds == null || contractHistoryIds.isEmpty()) {
            return;
        }

        deleteUninvoicedInvoiceProducts(contractHistoryIds);

        Map<Id, HistoryGenerationContext> historyContextById =
            loadHistoryGenerationContextById(contractHistoryIds);
        Map<Id, HistoryBillingContext> billingContextByHistoryId =
            loadHistoryBillingContextByHistoryId(contractHistoryIds);

        List<ContractProduct__c> contractProducts = [
            SELECT
                Id,
                Product__c,
                ContractHistory__c,
                Type__c,
                BillingType__c,
                InvoiceSetting__c,
                Quantity__c,
                UnitPrice__c,
                Amount__c,
                Unit__c,
                StartDate__c,
                Enddate__c,
                Product__r.BillingType__c
            FROM ContractProduct__c
            WHERE ContractHistory__c IN :contractHistoryIds
            WITH SYSTEM_MODE
        ];

        Map<Id, List<ContractProduct__c>> contractProductsByHistoryId =
            new Map<Id, List<ContractProduct__c>>();
        for (ContractProduct__c contractProduct : contractProducts) {
            if (!contractProductsByHistoryId.containsKey(contractProduct.ContractHistory__c)) {
                contractProductsByHistoryId.put(
                    contractProduct.ContractHistory__c,
                    new List<ContractProduct__c>()
                );
            }
            contractProductsByHistoryId.get(contractProduct.ContractHistory__c)
                .add(contractProduct);
        }

        List<InvoiceProduct__c> invoiceProductsToInsert = new List<InvoiceProduct__c>();
        for (Id historyId : contractHistoryIds) {
            HistoryGenerationContext historyContext = historyContextById.get(historyId);
            if (historyContext == null || historyContext.historyType == HISTORY_TYPE_CANCEL) {
                continue;
            }

            List<ContractProduct__c> historyProducts =
                contractProductsByHistoryId.get(historyId);
            if (historyProducts == null) {
                historyProducts = new List<ContractProduct__c>();
            }

            Map<String, MergeKeyDraft> shouldHaveByMergeKey = aggregateShouldHaveByMergeKey(
                historyContext,
                historyProducts,
                billingContextByHistoryId.get(historyId)
            );
            Map<String, Decimal> pastCumulativeByMergeKey = loadPastCumulativeByMergeKey(
                historyContext.contractServiceId,
                historyContext.version
            );
            Map<String, InvoiceProduct__c> pastSampleByMergeKey =
                loadPastInvoiceProductSampleByMergeKey(
                    historyContext.contractServiceId,
                    historyContext.version
                );
            Set<String> lockedMergeKeys = loadLockedMergeKeys(historyId);
            Set<String> lockedPeriodKeys = loadLockedPeriodKeys(historyId);

            Set<String> shouldHavePeriodKeys = new Set<String>();
            for (String mergeKey : shouldHaveByMergeKey.keySet()) {
                String periodKey = InvoiceProductMergeKeyUtil.extractPeriodKey(mergeKey);
                if (String.isNotBlank(periodKey)) {
                    shouldHavePeriodKeys.add(periodKey);
                }
            }

            Map<String, Decimal> pastCumulativeByPeriodKey =
                loadPastCumulativeByPeriodKey(
                    historyContext.contractServiceId,
                    historyContext.version
                );

            if (historyContext.historyType == HISTORY_TYPE_CHANGE) {
                Map<String, InvoiceProduct__c> pastSampleByPeriodKey =
                    loadPastInvoiceProductSampleByPeriodKey(
                        historyContext.contractServiceId,
                        historyContext.version
                    );
                invoiceProductsToInsert.addAll(
                    buildChangeInvoiceProducts(
                        historyId,
                        historyProducts,
                        shouldHaveByMergeKey,
                        pastCumulativeByPeriodKey,
                        pastSampleByPeriodKey,
                        lockedPeriodKeys,
                        billingContextByHistoryId.get(historyId)
                    )
                );
            } else {
                Set<String> allMergeKeys = new Set<String>();
                allMergeKeys.addAll(shouldHaveByMergeKey.keySet());
                allMergeKeys.addAll(pastCumulativeByMergeKey.keySet());

                for (String mergeKey : allMergeKeys) {
                    if (lockedMergeKeys.contains(mergeKey)) {
                        continue;
                    }

                    String periodKey = InvoiceProductMergeKeyUtil.extractPeriodKey(mergeKey);
                    if (
                        String.isNotBlank(periodKey) &&
                        lockedPeriodKeys.contains(periodKey)
                    ) {
                        continue;
                    }

                    if (
                        !shouldHaveByMergeKey.containsKey(mergeKey) &&
                        String.isNotBlank(periodKey) &&
                        shouldHavePeriodKeys.contains(periodKey)
                    ) {
                        continue;
                    }

                    Decimal shouldHaveAmount = shouldHaveByMergeKey.containsKey(mergeKey)
                        ? shouldHaveByMergeKey.get(mergeKey).amount
                        : 0;
                    Decimal pastAmount = pastCumulativeByMergeKey.containsKey(mergeKey)
                        ? pastCumulativeByMergeKey.get(mergeKey)
                        : 0;
                    Decimal diffAmount = shouldHaveAmount - pastAmount;
                    if (diffAmount == 0) {
                        continue;
                    }

                    InvoiceProduct__c template = resolveDiffTemplate(
                        mergeKey,
                        diffAmount,
                        shouldHaveByMergeKey,
                        pastSampleByMergeKey
                    );
                    if (template == null) {
                        continue;
                    }

                    Id productId = extractProductIdFromMergeKey(mergeKey);
                    Id contractProductId = resolveContractProductId(
                        historyProducts,
                        productId,
                        template.ContractProduct__c
                    );
                    if (contractProductId == null) {
                        continue;
                    }

                    invoiceProductsToInsert.add(
                        buildDiffInvoiceProduct(
                            template,
                            historyId,
                            contractProductId,
                            diffAmount,
                            billingContextByHistoryId.get(historyId)
                        )
                    );
                }
            }
        }

        if (!invoiceProductsToInsert.isEmpty()) {
            SystemContextAccess.insertRecords(invoiceProductsToInsert);
        }
    }

    private static Map<Id, HistoryGenerationContext> loadHistoryGenerationContextById(
        Set<Id> contractHistoryIds
    ) {
        Map<Id, HistoryGenerationContext> contextByHistoryId =
            new Map<Id, HistoryGenerationContext>();
        for (ContractHistory__c history : [
            SELECT Id, Type__c, EffectiveDate__c, ContractService__c, Version__c
            FROM ContractHistory__c
            WHERE Id IN :contractHistoryIds
            WITH SYSTEM_MODE
        ]) {
            HistoryGenerationContext context = new HistoryGenerationContext();
            context.historyId = history.Id;
            context.contractServiceId = history.ContractService__c;
            context.version = history.Version__c;
            context.historyType = history.Type__c;
            context.effectiveDate = history.EffectiveDate__c;
            contextByHistoryId.put(history.Id, context);
        }
        return contextByHistoryId;
    }

    private static Map<String, MergeKeyDraft> aggregateShouldHaveByMergeKey(
        HistoryGenerationContext historyContext,
        List<ContractProduct__c> contractProducts,
        HistoryBillingContext billingContext
    ) {
        List<DraftInvoiceLine> draftLines = new List<DraftInvoiceLine>();
        if (historyContext.historyType == HISTORY_TYPE_CHANGE) {
            draftLines.addAll(
                buildChangeShouldHaveDraftLines(
                    historyContext,
                    contractProducts,
                    billingContext
                )
            );
            InvoiceGenerationContext generationContext = new InvoiceGenerationContext();
            generationContext.historyType = historyContext.historyType;
            generationContext.effectiveDate = historyContext.effectiveDate;
            for (ContractProduct__c contractProduct : contractProducts) {
                if (!isChangeStandaloneContractProduct(contractProduct)) {
                    continue;
                }
                draftLines.addAll(
                    buildInvoiceProductDrafts(
                        contractProduct,
                        billingContext,
                        generationContext
                    )
                );
            }
        } else {
            InvoiceGenerationContext generationContext = new InvoiceGenerationContext();
            generationContext.historyType = historyContext.historyType;
            generationContext.effectiveDate = historyContext.effectiveDate;
            for (ContractProduct__c contractProduct : contractProducts) {
                if (isOriginalProductType(contractProduct)) {
                    continue;
                }
                draftLines.addAll(
                    buildInvoiceProductDrafts(
                        contractProduct,
                        billingContext,
                        generationContext
                    )
                );
            }
        }

        Map<String, MergeKeyDraft> shouldHaveByMergeKey = new Map<String, MergeKeyDraft>();
        for (DraftInvoiceLine draftLine : draftLines) {
            if (
                draftLine.productId == null ||
                draftLine.invoiceProduct == null ||
                draftLine.contractProduct == null
            ) {
                continue;
            }

            String mergeKey = InvoiceProductMergeKeyUtil.buildMergeKey(
                historyContext.contractServiceId,
                draftLine.productId,
                draftLine.invoiceProduct.StartDate__c,
                draftLine.invoiceProduct.Enddate__c,
                draftLine.contractProduct.Quantity__c,
                draftLine.contractProduct.UnitPrice__c,
                draftLine.contractProduct.Unit__c
            );
            if (String.isBlank(mergeKey)) {
                continue;
            }

            Decimal draftAmount = draftLine.invoiceProduct.Amount__c == null
                ? 0
                : draftLine.invoiceProduct.Amount__c;
            MergeKeyDraft aggregate = shouldHaveByMergeKey.get(mergeKey);
            if (aggregate == null) {
                aggregate = new MergeKeyDraft();
                aggregate.mergeKey = mergeKey;
                aggregate.template = cloneInvoiceProduct(draftLine.invoiceProduct);
                shouldHaveByMergeKey.put(mergeKey, aggregate);
            }
            aggregate.amount += draftAmount;
            aggregate.template.Amount__c = aggregate.amount;
            applyTaxFields(
                aggregate.template,
                billingContext == null ? null : billingContext.taxPercent
            );
        }
        return shouldHaveByMergeKey;
    }

    private static List<DraftInvoiceLine> buildChangeShouldHaveDraftLines(
        HistoryGenerationContext historyContext,
        List<ContractProduct__c> contractProducts,
        HistoryBillingContext billingContext
    ) {
        Map<Id, List<ContractProduct__c>> contractProductsByProductId =
            groupContractProductsByProductId(contractProducts);
        List<DraftInvoiceLine> draftLines = new List<DraftInvoiceLine>();

        for (Id productId : contractProductsByProductId.keySet()) {
            List<ContractProduct__c> rows = contractProductsByProductId.get(productId);
            ContractProduct__c originalRow = null;
            List<ContractProduct__c> remakeRows = new List<ContractProduct__c>();
            for (ContractProduct__c row : rows) {
                if (isOriginalProductType(row)) {
                    originalRow = row;
                } else if (isRemakeAfterProductType(row.Type__c)) {
                    remakeRows.add(row);
                }
            }
            remakeRows.sort(new ContractProductStartDateComparator());

            if (remakeRows.size() > 1) {
                draftLines.addAll(
                    buildExplicitChangeRemakeDraftLines(
                        remakeRows,
                        historyContext,
                        billingContext
                    )
                );
                continue;
            }

            ContractProduct__c remakeRow = remakeRows.isEmpty()
                ? null
                : remakeRows[0];

            if (remakeRow == null && originalRow != null) {
                InvoiceGenerationContext unchangedContext = new InvoiceGenerationContext();
                unchangedContext.historyType = null;
                unchangedContext.effectiveDate = null;
                draftLines.addAll(
                    buildInvoiceProductDrafts(
                        originalRow,
                        billingContext,
                        unchangedContext
                    )
                );
                continue;
            }

            if (remakeRow != null) {
                if (originalRow != null && historyContext.effectiveDate != null) {
                    Date preEffectiveEndDate = historyContext.effectiveDate.addDays(-1);
                    if (
                        originalRow.StartDate__c != null &&
                        preEffectiveEndDate >= originalRow.StartDate__c
                    ) {
                        ContractProduct__c preEffectiveProduct = cloneContractProductForPeriod(
                            originalRow,
                            originalRow.StartDate__c,
                            preEffectiveEndDate < originalRow.Enddate__c
                                ? preEffectiveEndDate
                                : originalRow.Enddate__c
                        );
                        InvoiceGenerationContext preContext = new InvoiceGenerationContext();
                        preContext.historyType = null;
                        preContext.effectiveDate = null;
                        draftLines.addAll(
                            buildInvoiceProductDrafts(
                                preEffectiveProduct,
                                billingContext,
                                preContext
                            )
                        );
                    }
                }

                InvoiceGenerationContext postContext = new InvoiceGenerationContext();
                postContext.historyType = HISTORY_TYPE_CHANGE;
                postContext.effectiveDate = historyContext.effectiveDate;
                draftLines.addAll(
                    buildInvoiceProductDrafts(
                        remakeRow,
                        billingContext,
                        postContext
                    )
                );
            }
        }
        return draftLines;
    }

    private static List<DraftInvoiceLine> buildExplicitChangeRemakeDraftLines(
        List<ContractProduct__c> remakeRows,
        HistoryGenerationContext historyContext,
        HistoryBillingContext billingContext
    ) {
        List<DraftInvoiceLine> draftLines = new List<DraftInvoiceLine>();
        Date effectiveDate = historyContext.effectiveDate;

        for (ContractProduct__c remakeRow : remakeRows) {
            InvoiceGenerationContext context = resolveChangeRemakeGenerationContext(
                remakeRow,
                effectiveDate
            );
            draftLines.addAll(
                buildInvoiceProductDrafts(
                    remakeRow,
                    billingContext,
                    context
                )
            );
        }
        return draftLines;
    }

    private static InvoiceGenerationContext resolveChangeRemakeGenerationContext(
        ContractProduct__c remakeRow,
        Date effectiveDate
    ) {
        InvoiceGenerationContext context = new InvoiceGenerationContext();
        if (effectiveDate == null) {
            context.historyType = null;
            context.effectiveDate = null;
            return context;
        }
        if (
            remakeRow.Enddate__c != null &&
            remakeRow.Enddate__c < effectiveDate
        ) {
            context.historyType = null;
            context.effectiveDate = null;
            return context;
        }
        context.historyType = HISTORY_TYPE_CHANGE;
        context.effectiveDate = effectiveDate;
        return context;
    }

    private class ContractProductStartDateComparator implements Comparator<ContractProduct__c> {
        public Integer compare(ContractProduct__c left, ContractProduct__c right) {
            String leftStart = left == null || left.StartDate__c == null
                ? ''
                : String.valueOf(left.StartDate__c);
            String rightStart = right == null || right.StartDate__c == null
                ? ''
                : String.valueOf(right.StartDate__c);
            return leftStart.compareTo(rightStart);
        }
    }

    private static Map<Id, List<ContractProduct__c>> groupContractProductsByProductId(
        List<ContractProduct__c> contractProducts
    ) {
        Map<Id, List<ContractProduct__c>> contractProductsByProductId =
            new Map<Id, List<ContractProduct__c>>();
        for (ContractProduct__c contractProduct : contractProducts) {
            if (contractProduct.Product__c == null) {
                continue;
            }
            if (!contractProductsByProductId.containsKey(contractProduct.Product__c)) {
                contractProductsByProductId.put(
                    contractProduct.Product__c,
                    new List<ContractProduct__c>()
                );
            }
            contractProductsByProductId.get(contractProduct.Product__c).add(contractProduct);
        }
        return contractProductsByProductId;
    }

    private static ContractProduct__c cloneContractProductForPeriod(
        ContractProduct__c source,
        Date startDate,
        Date endDate
    ) {
        ContractProduct__c clone = source.clone(false, true, false, false);
        clone.StartDate__c = startDate;
        clone.Enddate__c = endDate;
        return clone;
    }

    private static Map<String, Decimal> loadPastCumulativeByMergeKey(
        Id contractServiceId,
        Decimal currentVersion
    ) {
        Map<String, Decimal> pastCumulativeByMergeKey = new Map<String, Decimal>();
        if (contractServiceId == null || currentVersion == null) {
            return pastCumulativeByMergeKey;
        }

        for (InvoiceProduct__c invoiceProduct : [
            SELECT
                Amount__c,
                StartDate__c,
                Enddate__c,
                ContractProduct__r.Product__c,
                ContractProduct__r.Quantity__c,
                ContractProduct__r.UnitPrice__c,
                ContractProduct__r.Unit__c,
                ContractHistory__r.ContractService__c
            FROM InvoiceProduct__c
            WHERE ContractHistory__r.ContractService__c = :contractServiceId
            AND ContractHistory__r.historystatus__c = :HISTORY_STATUS_ORDERED
            AND ContractHistory__r.Version__c < :currentVersion
            WITH SYSTEM_MODE
        ]) {
            String mergeKey =
                InvoiceProductMergeKeyUtil.buildMergeKeyFromContractProductReference(
                    invoiceProduct
                );
            if (String.isBlank(mergeKey)) {
                continue;
            }
            Decimal amount = invoiceProduct.Amount__c == null ? 0 : invoiceProduct.Amount__c;
            Decimal existing = pastCumulativeByMergeKey.containsKey(mergeKey)
                ? pastCumulativeByMergeKey.get(mergeKey)
                : 0;
            pastCumulativeByMergeKey.put(mergeKey, existing + amount);
        }
        return pastCumulativeByMergeKey;
    }

    private static Map<String, Decimal> loadPastCumulativeByPeriodKey(
        Id contractServiceId,
        Decimal currentVersion
    ) {
        Map<String, Decimal> pastCumulativeByPeriodKey = new Map<String, Decimal>();
        if (contractServiceId == null || currentVersion == null) {
            return pastCumulativeByPeriodKey;
        }

        for (InvoiceProduct__c invoiceProduct : [
            SELECT
                Amount__c,
                StartDate__c,
                Enddate__c,
                ContractProduct__r.Product__c,
                ContractHistory__r.ContractService__c
            FROM InvoiceProduct__c
            WHERE ContractHistory__r.ContractService__c = :contractServiceId
            AND ContractHistory__r.historystatus__c = :HISTORY_STATUS_ORDERED
            AND ContractHistory__r.Version__c < :currentVersion
            WITH SYSTEM_MODE
        ]) {
            String periodKey = InvoiceProductMergeKeyUtil.buildPeriodKey(
                invoiceProduct.ContractHistory__r.ContractService__c,
                invoiceProduct.ContractProduct__r.Product__c,
                invoiceProduct.StartDate__c,
                invoiceProduct.Enddate__c
            );
            if (String.isBlank(periodKey)) {
                continue;
            }
            Decimal amount = invoiceProduct.Amount__c == null ? 0 : invoiceProduct.Amount__c;
            Decimal existing = pastCumulativeByPeriodKey.containsKey(periodKey)
                ? pastCumulativeByPeriodKey.get(periodKey)
                : 0;
            pastCumulativeByPeriodKey.put(periodKey, existing + amount);
        }
        return pastCumulativeByPeriodKey;
    }

    private static Map<String, InvoiceProduct__c> loadPastInvoiceProductSampleByMergeKey(
        Id contractServiceId,
        Decimal currentVersion
    ) {
        Map<String, InvoiceProduct__c> pastSampleByMergeKey = new Map<String, InvoiceProduct__c>();
        if (contractServiceId == null || currentVersion == null) {
            return pastSampleByMergeKey;
        }

        for (InvoiceProduct__c invoiceProduct : [
            SELECT
                ContractHistory__c,
                ContractProduct__c,
                StartDate__c,
                Enddate__c,
                InvoiceDate__c,
                PaymentScheduledDate__c,
                invoicetype__c,
                Amount__c,
                Quantity__c,
                UnitPrice__c,
                TaxPercent__c,
                TaxAmount__c,
                Unit__c,
                BillingAccountSnapShot__c,
                PaymentTermSnapShot__c,
                BillingDayOfMonthSnapShot__c,
                BillingAddresseeSnapShot__c,
                BillingEmailToSnapShot__c,
                BillingEmailCcSnapShot__c,
                BillingEmailBccSnapShot__c,
                ContractProduct__r.Product__c,
                ContractProduct__r.Quantity__c,
                ContractProduct__r.UnitPrice__c,
                ContractProduct__r.Unit__c,
                ContractHistory__r.ContractService__c
            FROM InvoiceProduct__c
            WHERE ContractHistory__r.ContractService__c = :contractServiceId
            AND ContractHistory__r.historystatus__c = :HISTORY_STATUS_ORDERED
            AND ContractHistory__r.Version__c < :currentVersion
            WITH SYSTEM_MODE
            ORDER BY ContractHistory__r.Version__c DESC, CreatedDate DESC
        ]) {
            String mergeKey =
                InvoiceProductMergeKeyUtil.buildMergeKeyFromContractProductReference(
                    invoiceProduct
                );
            if (String.isBlank(mergeKey) || pastSampleByMergeKey.containsKey(mergeKey)) {
                continue;
            }
            pastSampleByMergeKey.put(mergeKey, invoiceProduct);
        }
        return pastSampleByMergeKey;
    }

    private static Map<String, InvoiceProduct__c> loadPastInvoiceProductSampleByPeriodKey(
        Id contractServiceId,
        Decimal currentVersion
    ) {
        Map<String, InvoiceProduct__c> pastSampleByPeriodKey =
            new Map<String, InvoiceProduct__c>();
        if (contractServiceId == null || currentVersion == null) {
            return pastSampleByPeriodKey;
        }

        for (InvoiceProduct__c invoiceProduct : [
            SELECT
                ContractHistory__c,
                ContractProduct__c,
                StartDate__c,
                Enddate__c,
                InvoiceDate__c,
                PaymentScheduledDate__c,
                invoicetype__c,
                Amount__c,
                Quantity__c,
                UnitPrice__c,
                TaxPercent__c,
                TaxAmount__c,
                Unit__c,
                BillingAccountSnapShot__c,
                PaymentTermSnapShot__c,
                BillingDayOfMonthSnapShot__c,
                BillingAddresseeSnapShot__c,
                BillingEmailToSnapShot__c,
                BillingEmailCcSnapShot__c,
                BillingEmailBccSnapShot__c,
                ContractProduct__r.Product__c,
                ContractProduct__r.Quantity__c,
                ContractProduct__r.UnitPrice__c,
                ContractProduct__r.Unit__c,
                ContractHistory__r.ContractService__c
            FROM InvoiceProduct__c
            WHERE ContractHistory__r.ContractService__c = :contractServiceId
            AND ContractHistory__r.historystatus__c = :HISTORY_STATUS_ORDERED
            AND ContractHistory__r.Version__c < :currentVersion
            WITH SYSTEM_MODE
            ORDER BY ContractHistory__r.Version__c DESC, CreatedDate DESC
        ]) {
            String periodKey = InvoiceProductMergeKeyUtil.buildPeriodKey(
                invoiceProduct.ContractHistory__r.ContractService__c,
                invoiceProduct.ContractProduct__r.Product__c,
                invoiceProduct.StartDate__c,
                invoiceProduct.Enddate__c
            );
            if (String.isBlank(periodKey) || pastSampleByPeriodKey.containsKey(periodKey)) {
                continue;
            }
            pastSampleByPeriodKey.put(periodKey, invoiceProduct);
        }
        return pastSampleByPeriodKey;
    }

    private static List<InvoiceProduct__c> buildChangeInvoiceProducts(
        Id historyId,
        List<ContractProduct__c> historyProducts,
        Map<String, MergeKeyDraft> shouldHaveByMergeKey,
        Map<String, Decimal> pastCumulativeByPeriodKey,
        Map<String, InvoiceProduct__c> pastSampleByPeriodKey,
        Set<String> lockedPeriodKeys,
        HistoryBillingContext billingContext
    ) {
        List<InvoiceProduct__c> invoiceProducts = new List<InvoiceProduct__c>();
        Map<String, Decimal> shouldHaveAmountByPeriodKey = new Map<String, Decimal>();
        Map<String, MergeKeyDraft> chargeDraftByPeriodKey = new Map<String, MergeKeyDraft>();

        for (String mergeKey : shouldHaveByMergeKey.keySet()) {
            String periodKey = InvoiceProductMergeKeyUtil.extractPeriodKey(mergeKey);
            if (String.isBlank(periodKey)) {
                continue;
            }
            MergeKeyDraft draft = shouldHaveByMergeKey.get(mergeKey);
            Decimal existingAmount = shouldHaveAmountByPeriodKey.containsKey(periodKey)
                ? shouldHaveAmountByPeriodKey.get(periodKey)
                : 0;
            shouldHaveAmountByPeriodKey.put(periodKey, existingAmount + draft.amount);
            MergeKeyDraft existingDraft = chargeDraftByPeriodKey.get(periodKey);
            if (
                existingDraft == null ||
                draft.amount > existingDraft.amount
            ) {
                chargeDraftByPeriodKey.put(periodKey, draft);
            }
        }

        Set<String> allPeriodKeys = new Set<String>();
        allPeriodKeys.addAll(shouldHaveAmountByPeriodKey.keySet());
        allPeriodKeys.addAll(pastCumulativeByPeriodKey.keySet());

        for (String periodKey : allPeriodKeys) {
            if (lockedPeriodKeys.contains(periodKey)) {
                continue;
            }

            Decimal shouldHaveAmount = shouldHaveAmountByPeriodKey.containsKey(periodKey)
                ? shouldHaveAmountByPeriodKey.get(periodKey)
                : 0;
            Decimal pastAmount = pastCumulativeByPeriodKey.containsKey(periodKey)
                ? pastCumulativeByPeriodKey.get(periodKey)
                : 0;
            if (shouldHaveAmount == pastAmount) {
                continue;
            }

            Id productId = extractProductIdFromPeriodKey(periodKey);
            InvoiceProduct__c pastSample = pastSampleByPeriodKey.get(periodKey);
            InvoiceProduct__c chargeLine = null;

            if (shouldHaveAmount != 0) {
                MergeKeyDraft chargeDraft = chargeDraftByPeriodKey.get(periodKey);
                if (chargeDraft != null && chargeDraft.template != null) {
                    Id chargeContractProductId = resolveContractProductId(
                        historyProducts,
                        productId,
                        chargeDraft.template.ContractProduct__c
                    );
                    ContractProduct__c chargeContractProduct = findContractProductById(
                        historyProducts,
                        chargeContractProductId
                    );
                    if (chargeContractProduct != null) {
                        chargeLine = buildExplicitInvoiceProduct(
                            chargeDraft.template,
                            historyId,
                            chargeContractProductId,
                            chargeContractProduct.Quantity__c,
                            chargeContractProduct.UnitPrice__c,
                            shouldHaveAmount,
                            billingContext
                        );
                    }
                }
            }

            if (pastAmount != 0 && pastSample != null) {
                Id reversalContractProductId = resolveReversalContractProductId(
                    historyProducts,
                    productId,
                    pastSample
                );
                if (reversalContractProductId != null) {
                    InvoiceProduct__c reversalLine = buildExplicitInvoiceProduct(
                        pastSample,
                        historyId,
                        reversalContractProductId,
                        resolvePastQuantity(pastSample),
                        resolvePastUnitPrice(pastSample),
                        -pastAmount,
                        billingContext
                    );
                    if (chargeLine != null) {
                        reversalLine.InvoiceDate__c = chargeLine.InvoiceDate__c;
                        reversalLine.PaymentScheduledDate__c =
                            chargeLine.PaymentScheduledDate__c;
                    }
                    invoiceProducts.add(reversalLine);
                }
            }

            if (chargeLine != null) {
                invoiceProducts.add(chargeLine);
            }
        }
        return invoiceProducts;
    }

    private static ContractProduct__c findContractProductById(
        List<ContractProduct__c> historyProducts,
        Id contractProductId
    ) {
        if (historyProducts == null || contractProductId == null) {
            return null;
        }
        for (ContractProduct__c contractProduct : historyProducts) {
            if (contractProduct.Id == contractProductId) {
                return contractProduct;
            }
        }
        return null;
    }

    private static Decimal resolvePastQuantity(InvoiceProduct__c pastSample) {
        if (pastSample == null) {
            return 0;
        }
        if (pastSample.Quantity__c != null) {
            return pastSample.Quantity__c;
        }
        return pastSample.ContractProduct__r == null
            ? 0
            : pastSample.ContractProduct__r.Quantity__c;
    }

    private static Decimal resolvePastUnitPrice(InvoiceProduct__c pastSample) {
        if (pastSample == null) {
            return 0;
        }
        if (pastSample.UnitPrice__c != null) {
            return pastSample.UnitPrice__c;
        }
        return pastSample.ContractProduct__r == null
            ? 0
            : pastSample.ContractProduct__r.UnitPrice__c;
    }

    private static Id resolveReversalContractProductId(
        List<ContractProduct__c> historyProducts,
        Id productId,
        InvoiceProduct__c pastSample
    ) {
        if (historyProducts == null || productId == null || pastSample == null) {
            return null;
        }

        Decimal pastQuantity = resolvePastQuantity(pastSample);
        Decimal pastUnitPrice = resolvePastUnitPrice(pastSample);
        Id originalMatchId = null;
        Id remakeMatchId = null;

        for (ContractProduct__c contractProduct : historyProducts) {
            if (contractProduct.Product__c != productId) {
                continue;
            }
            if (
                contractProduct.Quantity__c == pastQuantity &&
                contractProduct.UnitPrice__c == pastUnitPrice
            ) {
                if (isOriginalProductType(contractProduct)) {
                    originalMatchId = contractProduct.Id;
                } else if (isRemakeAfterProductType(contractProduct.Type__c)) {
                    remakeMatchId = contractProduct.Id;
                }
            }
        }

        if (originalMatchId != null) {
            return originalMatchId;
        }
        if (remakeMatchId != null) {
            return remakeMatchId;
        }
        return resolveContractProductId(historyProducts, productId, null);
    }

    private static Id extractProductIdFromPeriodKey(String periodKey) {
        if (String.isBlank(periodKey)) {
            return null;
        }
        List<String> parts = periodKey.split('_');
        if (parts.size() < 2) {
            return null;
        }
        return (Id) parts[1];
    }

    private static InvoiceProduct__c buildExplicitInvoiceProduct(
        InvoiceProduct__c template,
        Id contractHistoryId,
        Id contractProductId,
        Decimal quantity,
        Decimal unitPrice,
        Decimal amount,
        HistoryBillingContext billingContext
    ) {
        InvoiceProduct__c invoiceProduct = cloneInvoiceProduct(template);
        invoiceProduct.ContractHistory__c = contractHistoryId;
        invoiceProduct.ContractProduct__c = contractProductId;
        invoiceProduct.Quantity__c = quantity;
        invoiceProduct.UnitPrice__c = unitPrice;
        invoiceProduct.Amount__c = amount;
        applyBillingAccountSnapshot(invoiceProduct, billingContext);
        applyTaxFields(
            invoiceProduct,
            billingContext == null ? null : billingContext.taxPercent
        );
        return invoiceProduct;
    }

    private static Set<String> loadLockedMergeKeys(Id contractHistoryId) {
        Set<String> lockedMergeKeys = new Set<String>();
        for (InvoiceProduct__c invoiceProduct : [
            SELECT
                StartDate__c,
                Enddate__c,
                ContractProduct__r.Product__c,
                ContractProduct__r.Quantity__c,
                ContractProduct__r.UnitPrice__c,
                ContractProduct__r.Unit__c,
                ContractHistory__r.ContractService__c
            FROM InvoiceProduct__c
            WHERE ContractHistory__c = :contractHistoryId
            AND (
                ActualInvoiceDate__c != NULL
                OR LatestExportDate__c != NULL
            )
            WITH SYSTEM_MODE
        ]) {
            lockedMergeKeys.add(
                InvoiceProductMergeKeyUtil.buildMergeKeyFromContractProductReference(
                    invoiceProduct
                )
            );
        }
        return lockedMergeKeys;
    }

    private static Set<String> loadLockedPeriodKeys(Id contractHistoryId) {
        Set<String> lockedPeriodKeys = new Set<String>();
        for (InvoiceProduct__c invoiceProduct : [
            SELECT
                StartDate__c,
                Enddate__c,
                ContractProduct__r.Product__c,
                ContractHistory__r.ContractService__c
            FROM InvoiceProduct__c
            WHERE ContractHistory__c = :contractHistoryId
            AND (
                ActualInvoiceDate__c != NULL
                OR LatestExportDate__c != NULL
            )
            WITH SYSTEM_MODE
        ]) {
            lockedPeriodKeys.add(
                InvoiceProductMergeKeyUtil.buildPeriodKey(
                    invoiceProduct.ContractHistory__r.ContractService__c,
                    invoiceProduct.ContractProduct__r.Product__c,
                    invoiceProduct.StartDate__c,
                    invoiceProduct.Enddate__c
                )
            );
        }
        return lockedPeriodKeys;
    }

    private static InvoiceProduct__c resolveDiffTemplate(
        String mergeKey,
        Decimal diffAmount,
        Map<String, MergeKeyDraft> shouldHaveByMergeKey,
        Map<String, InvoiceProduct__c> pastSampleByMergeKey
    ) {
        if (shouldHaveByMergeKey.containsKey(mergeKey)) {
            return shouldHaveByMergeKey.get(mergeKey).template;
        }
        if (pastSampleByMergeKey.containsKey(mergeKey)) {
            return pastSampleByMergeKey.get(mergeKey);
        }
        if (diffAmount < 0) {
            for (InvoiceProduct__c pastSample : pastSampleByMergeKey.values()) {
                return pastSample;
            }
        }
        return null;
    }

    private static Id resolveContractProductId(
        List<ContractProduct__c> contractProducts,
        Id productId,
        Id templateContractProductId
    ) {
        if (templateContractProductId != null) {
            return templateContractProductId;
        }
        if (contractProducts == null || productId == null) {
            return null;
        }
        Map<Id, Id> contractProductIdByProductId =
            buildContractProductIdByProductId(contractProducts);
        return contractProductIdByProductId.get(productId);
    }

    private static Map<Id, Id> buildContractProductIdByProductId(
        List<ContractProduct__c> contractProducts
    ) {
        Map<Id, Id> remakeIdByProductId = new Map<Id, Id>();
        Map<Id, Id> originalIdByProductId = new Map<Id, Id>();
        Map<Id, Id> fallbackIdByProductId = new Map<Id, Id>();

        for (ContractProduct__c contractProduct : contractProducts) {
            if (contractProduct.Product__c == null) {
                continue;
            }
            fallbackIdByProductId.put(contractProduct.Product__c, contractProduct.Id);
            if (
                isRemakeAfterProductType(contractProduct.Type__c) &&
                !isLegacyBeforeRemake(contractProduct)
            ) {
                remakeIdByProductId.put(contractProduct.Product__c, contractProduct.Id);
            } else if (isOriginalProductType(contractProduct)) {
                originalIdByProductId.put(contractProduct.Product__c, contractProduct.Id);
            }
        }

        Map<Id, Id> contractProductIdByProductId = new Map<Id, Id>();
        for (Id productId : fallbackIdByProductId.keySet()) {
            if (remakeIdByProductId.containsKey(productId)) {
                contractProductIdByProductId.put(
                    productId,
                    remakeIdByProductId.get(productId)
                );
            } else if (originalIdByProductId.containsKey(productId)) {
                contractProductIdByProductId.put(
                    productId,
                    originalIdByProductId.get(productId)
                );
            } else {
                contractProductIdByProductId.put(
                    productId,
                    fallbackIdByProductId.get(productId)
                );
            }
        }
        return contractProductIdByProductId;
    }

    private static Id extractProductIdFromMergeKey(String mergeKey) {
        if (String.isBlank(mergeKey)) {
            return null;
        }
        List<String> parts = mergeKey.split('_');
        if (parts.size() < 2) {
            return null;
        }
        return (Id) parts[1];
    }

    private static InvoiceProduct__c buildDiffInvoiceProduct(
        InvoiceProduct__c template,
        Id contractHistoryId,
        Id contractProductId,
        Decimal diffAmount,
        HistoryBillingContext billingContext
    ) {
        InvoiceProduct__c invoiceProduct = cloneInvoiceProduct(template);
        invoiceProduct.ContractHistory__c = contractHistoryId;
        invoiceProduct.ContractProduct__c = contractProductId;
        invoiceProduct.Amount__c = diffAmount;
        if (invoiceProduct.Quantity__c == null || invoiceProduct.UnitPrice__c == null) {
            populateQuantityAndUnitPriceFromAmount(invoiceProduct, diffAmount);
        }
        applyBillingAccountSnapshot(invoiceProduct, billingContext);
        applyTaxFields(
            invoiceProduct,
            billingContext == null ? null : billingContext.taxPercent
        );
        return invoiceProduct;
    }

    private static void populateQuantityAndUnitPriceFromAmount(
        InvoiceProduct__c invoiceProduct,
        Decimal amount
    ) {
        if (invoiceProduct == null || amount == null || amount == 0) {
            return;
        }
        if (invoiceProduct.Quantity__c != null && invoiceProduct.UnitPrice__c != null) {
            return;
        }
        Decimal absAmount = Math.abs(amount);
        if (invoiceProduct.UnitPrice__c != null && invoiceProduct.UnitPrice__c != 0) {
            invoiceProduct.Quantity__c = absAmount / invoiceProduct.UnitPrice__c;
            return;
        }
        if (invoiceProduct.Quantity__c != null && invoiceProduct.Quantity__c != 0) {
            invoiceProduct.UnitPrice__c = absAmount / invoiceProduct.Quantity__c;
            return;
        }
        invoiceProduct.Quantity__c = 1;
        invoiceProduct.UnitPrice__c = absAmount;
    }

    private static void applyTaxFields(
        InvoiceProduct__c invoiceProduct,
        Decimal taxPercent
    ) {
        if (invoiceProduct == null) {
            return;
        }
        Decimal resolvedPercent = TaxCalculationUtil.resolveTaxPercent(taxPercent);
        invoiceProduct.TaxPercent__c = TaxCalculationUtil.toPercentFieldStorage(
            resolvedPercent
        );
        invoiceProduct.TaxAmount__c = TaxCalculationUtil.calculateTaxAmount(
            invoiceProduct.Amount__c,
            resolvedPercent
        );
    }

    private static void applyBillingAccountSnapshot(
        InvoiceProduct__c invoiceProduct,
        HistoryBillingContext billingContext
    ) {
        if (invoiceProduct == null || billingContext == null) {
            return;
        }
        BillingAccountSnapshot snapshot = billingContext.billingAccountSnapshot;
        if (snapshot == null) {
            return;
        }
        invoiceProduct.BillingAccountSnapShot__c = snapshot.billingAccountId;
        invoiceProduct.PaymentTermSnapShot__c = snapshot.paymentTerm;
        invoiceProduct.BillingDayOfMonthSnapShot__c = snapshot.billingDayOfMonth;
        invoiceProduct.BillingAddresseeSnapShot__c = snapshot.billingAddressee;
        invoiceProduct.BillingEmailToSnapShot__c = snapshot.billingEmailTo;
        invoiceProduct.BillingEmailCcSnapShot__c = snapshot.billingEmailCc;
        invoiceProduct.BillingEmailBccSnapShot__c = snapshot.billingEmailBcc;
    }

    private static Map<Id, HistoryBillingContext> loadHistoryBillingContextByHistoryId(
        Set<Id> contractHistoryIds
    ) {
        Map<Id, HistoryBillingContext> billingContextByHistoryId =
            new Map<Id, HistoryBillingContext>();
        for (ContractHistory__c history : [
            SELECT
                Id,
                ContractService__r.TaxPercent__c,
                ContractService__r.BiilingAcccount__c,
                ContractService__r.BiilingAcccount__r.PaymentTerm__c,
                ContractService__r.BiilingAcccount__r.BillingDayOfMonth__c,
                ContractService__r.BiilingAcccount__r.AdjustInvoiceDateToBusinessDay__c,
                ContractService__r.BiilingAcccount__r.BillingAddressee__c,
                ContractService__r.BiilingAcccount__r.BillingEmailTo__c,
                ContractService__r.BiilingAcccount__r.BillingEmailCc__c,
                ContractService__r.BiilingAcccount__r.BillingEmailBcc__c
            FROM ContractHistory__c
            WHERE Id IN :contractHistoryIds
            WITH SYSTEM_MODE
        ]) {
            HistoryBillingContext billingContext = new HistoryBillingContext();
            if (history.ContractService__r != null) {
                billingContext.taxPercent = history.ContractService__r.TaxPercent__c;
            }
            if (
                history.ContractService__r != null &&
                history.ContractService__r.BiilingAcccount__r != null
            ) {
                BillingAccount__c billingAccount =
                    history.ContractService__r.BiilingAcccount__r;
                billingContext.paymentTermLabel = billingAccount.PaymentTerm__c;
                billingContext.invoiceDateContext =
                    ContractMetadataService.buildInvoiceDateContext(
                        billingAccount.BillingDayOfMonth__c,
                        billingAccount.AdjustInvoiceDateToBusinessDay__c == true
                    );
                BillingAccountSnapshot snapshot = new BillingAccountSnapshot();
                snapshot.billingAccountId = history.ContractService__r.BiilingAcccount__c;
                snapshot.paymentTerm = billingAccount.PaymentTerm__c;
                snapshot.billingDayOfMonth = billingAccount.BillingDayOfMonth__c;
                snapshot.billingAddressee = billingAccount.BillingAddressee__c;
                snapshot.billingEmailTo = billingAccount.BillingEmailTo__c;
                snapshot.billingEmailCc = billingAccount.BillingEmailCc__c;
                snapshot.billingEmailBcc = billingAccount.BillingEmailBcc__c;
                billingContext.billingAccountSnapshot = snapshot;
            }
            billingContextByHistoryId.put(history.Id, billingContext);
        }
        return billingContextByHistoryId;
    }

    private static void deleteUninvoicedInvoiceProducts(Set<Id> contractHistoryIds) {
        List<InvoiceProduct__c> existingProducts = [
            SELECT Id
            FROM InvoiceProduct__c
            WHERE ContractHistory__c IN :contractHistoryIds
            AND LatestExportDate__c = NULL
            AND ActualInvoiceDate__c = NULL
            WITH SYSTEM_MODE
        ];
        if (!existingProducts.isEmpty()) {
            SystemContextAccess.deleteRecords(existingProducts);
        }
    }

    private static List<DraftInvoiceLine> buildInvoiceProductDrafts(
        ContractProduct__c contractProduct,
        HistoryBillingContext billingContext,
        InvoiceGenerationContext context
    ) {
        List<DraftInvoiceLine> draftLines = new List<DraftInvoiceLine>();
        String invoiceSetting = contractProduct.InvoiceSetting__c;
        if (ContractMetadataService.shouldSkipInvoiceGeneration(invoiceSetting)) {
            return draftLines;
        }

        Date generationStartDate = resolveGenerationStartDate(contractProduct, context);
        Date generationEndDate = contractProduct.Enddate__c;
        if (
            generationStartDate == null ||
            generationEndDate == null ||
            generationEndDate < generationStartDate
        ) {
            return draftLines;
        }

        String billingType = resolveBillingType(contractProduct);
        ContractMetadataService.InvoiceDateContext invoiceDateContext =
            billingContext == null ? null : billingContext.invoiceDateContext;
        Boolean usesBulkInvoiceDate =
            ContractMetadataService.usesBulkContractProductInvoiceDate(invoiceSetting);
        Date contractProductInvoiceDate;
        if (usesBulkInvoiceDate) {
            contractProductInvoiceDate = ContractMetadataService.resolveInvoiceDate(
                invoiceSetting,
                null,
                null,
                generationStartDate,
                generationEndDate,
                invoiceDateContext
            );
        }
        if (
            billingType == BILLING_TYPE_RECURRING &&
            ContractMetadataService.isRecurringBillingType(billingType)
        ) {
            List<MonthlyBillingPeriodUtil.BillingPeriod> periods =
                ContractMetadataService.useCalendarMonthPeriodSplit(invoiceSetting)
                    ? MonthlyBillingPeriodUtil.buildCalendarMonthPeriods(
                          generationStartDate,
                          generationEndDate
                      )
                    : MonthlyBillingPeriodUtil.buildMonthlyPeriods(
                          generationStartDate,
                          generationEndDate
                      );
            for (MonthlyBillingPeriodUtil.BillingPeriod period : periods) {
                Date invoiceDate = usesBulkInvoiceDate
                    ? contractProductInvoiceDate
                    : ContractMetadataService.resolveInvoiceDate(
                          invoiceSetting,
                          period.startDate,
                          period.endDate,
                          generationStartDate,
                          generationEndDate,
                          invoiceDateContext
                      );
                draftLines.add(
                    new DraftInvoiceLine(
                        contractProduct.Product__c,
                        contractProduct,
                        createInvoiceProduct(
                            contractProduct,
                            period.startDate,
                            period.endDate,
                            invoiceDate,
                            billingContext
                        )
                    )
                );
            }
            return draftLines;
        }

        Date invoiceDate = usesBulkInvoiceDate
            ? contractProductInvoiceDate
            : ContractMetadataService.resolveInvoiceDate(
                  invoiceSetting,
                  generationStartDate,
                  generationEndDate,
                  generationStartDate,
                  generationEndDate,
                  invoiceDateContext
              );
        draftLines.add(
            new DraftInvoiceLine(
                contractProduct.Product__c,
                contractProduct,
                createInvoiceProduct(
                    contractProduct,
                    generationStartDate,
                    generationEndDate,
                    invoiceDate,
                    billingContext
                )
            )
        );
        return draftLines;
    }

    private static Date resolveGenerationStartDate(
        ContractProduct__c contractProduct,
        InvoiceGenerationContext context
    ) {
        Date startDate = contractProduct.StartDate__c;
        if (
            context == null ||
            context.historyType != HISTORY_TYPE_CHANGE ||
            context.effectiveDate == null ||
            isOriginalProductType(contractProduct)
        ) {
            return startDate;
        }
        if (startDate == null || context.effectiveDate > startDate) {
            return context.effectiveDate;
        }
        return startDate;
    }

    private static InvoiceProduct__c cloneInvoiceProduct(InvoiceProduct__c source) {
        return new InvoiceProduct__c(
            ContractHistory__c = source.ContractHistory__c,
            ContractProduct__c = source.ContractProduct__c,
            StartDate__c = source.StartDate__c,
            Enddate__c = source.Enddate__c,
            InvoiceDate__c = source.InvoiceDate__c,
            PaymentScheduledDate__c = source.PaymentScheduledDate__c,
            invoicetype__c = source.invoicetype__c,
            Amount__c = source.Amount__c,
            Quantity__c = source.Quantity__c,
            UnitPrice__c = source.UnitPrice__c,
            TaxPercent__c = source.TaxPercent__c,
            TaxAmount__c = source.TaxAmount__c,
            Unit__c = source.Unit__c,
            BillingAccountSnapShot__c = source.BillingAccountSnapShot__c,
            PaymentTermSnapShot__c = source.PaymentTermSnapShot__c,
            BillingDayOfMonthSnapShot__c = source.BillingDayOfMonthSnapShot__c,
            BillingAddresseeSnapShot__c = source.BillingAddresseeSnapShot__c,
            BillingEmailToSnapShot__c = source.BillingEmailToSnapShot__c,
            BillingEmailCcSnapShot__c = source.BillingEmailCcSnapShot__c,
            BillingEmailBccSnapShot__c = source.BillingEmailBccSnapShot__c
        );
    }

    private static InvoiceProduct__c createInvoiceProduct(
        ContractProduct__c contractProduct,
        Date startDate,
        Date endDate,
        Date invoiceDate,
        HistoryBillingContext billingContext
    ) {
        String paymentTermLabel =
            billingContext == null ? null : billingContext.paymentTermLabel;
        InvoiceProduct__c invoiceProduct = new InvoiceProduct__c(
            ContractHistory__c = contractProduct.ContractHistory__c,
            ContractProduct__c = contractProduct.Id,
            StartDate__c = startDate,
            Enddate__c = endDate,
            InvoiceDate__c = invoiceDate,
            PaymentScheduledDate__c = ContractMetadataService.resolvePaymentScheduledDate(
                paymentTermLabel,
                invoiceDate
            ),
            invoicetype__c = contractProduct.InvoiceSetting__c,
            Unit__c = contractProduct.Unit__c,
            Quantity__c = contractProduct.Quantity__c,
            UnitPrice__c = contractProduct.UnitPrice__c,
            Amount__c = calculatePositiveAmount(contractProduct)
        );
        applyBillingAccountSnapshot(invoiceProduct, billingContext);
        applyTaxFields(
            invoiceProduct,
            billingContext == null ? null : billingContext.taxPercent
        );
        return invoiceProduct;
    }

    private static Decimal calculatePositiveAmount(ContractProduct__c contractProduct) {
        Decimal quantity = contractProduct.Quantity__c == null
            ? 0
            : contractProduct.Quantity__c;
        Decimal unitPrice = contractProduct.UnitPrice__c == null
            ? 0
            : contractProduct.UnitPrice__c;
        return quantity * unitPrice;
    }

    private static String resolveBillingType(ContractProduct__c contractProduct) {
        if (String.isNotBlank(contractProduct.BillingType__c)) {
            return contractProduct.BillingType__c;
        }
        return contractProduct.Product__r.BillingType__c;
    }

    private static Boolean isLegacyBeforeRemake(ContractProduct__c product) {
        return product != null &&
            product.Type__c == PRODUCT_TYPE_REMAKE &&
            product.Amount__c != null &&
            product.Amount__c < 0;
    }

    private static Boolean isOriginalProductType(ContractProduct__c product) {
        return product != null &&
            (product.Type__c == PRODUCT_TYPE_ORIGINAL ||
            isLegacyBeforeRemake(product));
    }

    private static Boolean isRemakeAfterProductType(String productType) {
        return productType == PRODUCT_TYPE_REMAKE ||
            productType == LEGACY_PRODUCT_TYPE_DERIVATIVE;
    }

    private static Boolean isChangeStandaloneContractProduct(
        ContractProduct__c product
    ) {
        if (product == null || isOriginalProductType(product)) {
            return false;
        }
        return !isRemakeAfterProductType(product.Type__c);
    }
}
