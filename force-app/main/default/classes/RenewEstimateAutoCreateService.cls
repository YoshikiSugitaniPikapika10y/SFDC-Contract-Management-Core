public without sharing class RenewEstimateAutoCreateService {
    private static final String HISTORY_STATUS_ESTIMATE = 'Estimate';
    private static final String HISTORY_STATUS_ARCHIVE = 'Archive';
    private static final String HISTORY_TYPE_RENEW = 'Renew';
    private static final String PRODUCT_TYPE_RENEW = 'Renew';
    private static final String BILLING_TYPE_RECURRING = '継続課金';

    public static void validateBeforeSave(
        List<Opportunity> opportunities,
        Map<Id, Opportunity> oldMap
    ) {
        Set<Id> previousOppIds = new Set<Id>();
        for (Opportunity opportunity : opportunities) {
            if (!shouldProcess(opportunity, getOldOpportunity(opportunity, oldMap))) {
                continue;
            }
            if (opportunity.PreviousOpportunity__c == null) {
                opportunity.addError('更新見積自動作成には前商談を設定してください。');
                continue;
            }
            previousOppIds.add(opportunity.PreviousOpportunity__c);
        }
        if (previousOppIds.isEmpty()) {
            return;
        }

        Map<Id, ContractHistory__c> sourceByPreviousOpp = loadSourceHistories(previousOppIds);
        for (Opportunity opportunity : opportunities) {
            if (!shouldProcess(opportunity, getOldOpportunity(opportunity, oldMap))) {
                continue;
            }
            if (opportunity.PreviousOpportunity__c == null) {
                continue;
            }
            if (!sourceByPreviousOpp.containsKey(opportunity.PreviousOpportunity__c)) {
                opportunity.addError(
                    '前商談に Estimate 以外の契約履歴がありません。'
                );
            }
        }
    }

    public static void createRenewEstimates(
        List<Opportunity> opportunities,
        Map<Id, Opportunity> oldMap
    ) {
        List<Opportunity> targets = new List<Opportunity>();
        for (Opportunity opportunity : opportunities) {
            if (shouldProcess(opportunity, getOldOpportunity(opportunity, oldMap))) {
                targets.add(opportunity);
            }
        }
        if (targets.isEmpty()) {
            return;
        }

        Set<Id> previousOppIds = new Set<Id>();
        Set<Id> targetOppIds = new Set<Id>();
        for (Opportunity opportunity : targets) {
            targetOppIds.add(opportunity.Id);
            if (opportunity.PreviousOpportunity__c != null) {
                previousOppIds.add(opportunity.PreviousOpportunity__c);
            }
        }

        Map<Id, ContractHistory__c> sourceByPreviousOpp = loadSourceHistories(previousOppIds);
        Set<Id> oppsWithExistingEstimate = loadOpportunityIdsWithRenewEstimate(targetOppIds);
        Set<Id> sourceHistoryIds = new Set<Id>();
        for (ContractHistory__c sourceHistory : sourceByPreviousOpp.values()) {
            sourceHistoryIds.add(sourceHistory.Id);
        }
        Map<Id, List<ContractProduct__c>> productsByHistoryId = loadRenewSourceProducts(
            sourceHistoryIds
        );

        Set<Id> contractServiceIds = new Set<Id>();
        for (ContractHistory__c sourceHistory : sourceByPreviousOpp.values()) {
            if (sourceHistory.ContractService__c != null) {
                contractServiceIds.add(sourceHistory.ContractService__c);
            }
        }
        Map<Id, Decimal> versionAllocator =
            ContractHistoryVersionUtil.buildVersionAllocator(contractServiceIds);

        List<ContractHistory__c> historiesToInsert = new List<ContractHistory__c>();
        List<RenewEstimateContext> contexts = new List<RenewEstimateContext>();

        for (Opportunity opportunity : targets) {
            if (opportunity.PreviousOpportunity__c == null) {
                continue;
            }
            if (oppsWithExistingEstimate.contains(opportunity.Id)) {
                continue;
            }

            ContractHistory__c sourceHistory = sourceByPreviousOpp.get(
                opportunity.PreviousOpportunity__c
            );
            if (sourceHistory == null || sourceHistory.CurrentTermEndDate__c == null) {
                continue;
            }

            Date renewStartDate = sourceHistory.CurrentTermEndDate__c.addDays(1);
            Date renewEndDate = renewStartDate.addYears(1).addDays(-1);
            ContractHistory__c renewHistory = new ContractHistory__c(
                Name = opportunity.Name,
                ContractService__c = sourceHistory.ContractService__c,
                Type__c = HISTORY_TYPE_RENEW,
                historystatus__c = HISTORY_STATUS_ESTIMATE,
                Version__c = ContractHistoryVersionUtil.allocateNextVersion(
                    versionAllocator,
                    sourceHistory.ContractService__c
                ),
                CurrentTermStartDate__c = renewStartDate,
                CurrentTermEndDate__c = renewEndDate,
                EffectiveDate__c = renewStartDate,
                Opportunity__c = opportunity.Id,
                PreviousHistory__c = sourceHistory.Id
            );
            historiesToInsert.add(renewHistory);
            contexts.add(
                new RenewEstimateContext(
                    opportunity,
                    sourceHistory,
                    renewHistory,
                    renewStartDate,
                    renewEndDate,
                    productsByHistoryId.get(sourceHistory.Id)
                )
            );
        }

        if (historiesToInsert.isEmpty()) {
            return;
        }

        SystemContextAccess.insertRecords(historiesToInsert);

        List<ContractProduct__c> productsToInsert = new List<ContractProduct__c>();
        for (RenewEstimateContext context : contexts) {
            productsToInsert.addAll(
                buildRenewProducts(
                    context.renewHistory.Id,
                    context.renewStartDate,
                    context.renewEndDate,
                    context.sourceProducts
                )
            );
        }
        if (!productsToInsert.isEmpty()) {
            SystemContextAccess.insertRecords(productsToInsert);
        }
    }

    private class RenewEstimateContext {
        public Opportunity opportunity;
        public ContractHistory__c sourceHistory;
        public ContractHistory__c renewHistory;
        public Date renewStartDate;
        public Date renewEndDate;
        public List<ContractProduct__c> sourceProducts;

        public RenewEstimateContext(
            Opportunity opportunity,
            ContractHistory__c sourceHistory,
            ContractHistory__c renewHistory,
            Date renewStartDate,
            Date renewEndDate,
            List<ContractProduct__c> sourceProducts
        ) {
            this.opportunity = opportunity;
            this.sourceHistory = sourceHistory;
            this.renewHistory = renewHistory;
            this.renewStartDate = renewStartDate;
            this.renewEndDate = renewEndDate;
            this.sourceProducts = sourceProducts == null
                ? new List<ContractProduct__c>()
                : sourceProducts;
        }
    }

    private static Boolean shouldProcess(
        Opportunity opportunity,
        Opportunity oldOpportunity
    ) {
        if (opportunity.RenewEstimateAutoCreateCheck__c != true) {
            return false;
        }
        if (oldOpportunity == null) {
            return true;
        }
        return oldOpportunity.RenewEstimateAutoCreateCheck__c != true;
    }

    private static Opportunity getOldOpportunity(
        Opportunity opportunity,
        Map<Id, Opportunity> oldMap
    ) {
        if (oldMap == null) {
            return null;
        }
        return oldMap.get(opportunity.Id);
    }

    private static Map<Id, ContractHistory__c> loadSourceHistories(Set<Id> previousOppIds) {
        Map<Id, ContractHistory__c> sourceByPreviousOpp = new Map<Id, ContractHistory__c>();
        if (previousOppIds.isEmpty()) {
            return sourceByPreviousOpp;
        }

        for (ContractHistory__c history : [
            SELECT
                Id,
                Opportunity__c,
                ContractService__c,
                CurrentTermStartDate__c,
                CurrentTermEndDate__c,
                Version__c
            FROM ContractHistory__c
            WHERE Opportunity__c IN :previousOppIds
            AND historystatus__c NOT IN (
                :HISTORY_STATUS_ESTIMATE,
                :HISTORY_STATUS_ARCHIVE
            )
            WITH SYSTEM_MODE
            ORDER BY Version__c DESC NULLS LAST
        ]) {
            if (!sourceByPreviousOpp.containsKey(history.Opportunity__c)) {
                sourceByPreviousOpp.put(history.Opportunity__c, history);
            }
        }
        return sourceByPreviousOpp;
    }

    private static Set<Id> loadOpportunityIdsWithRenewEstimate(Set<Id> opportunityIds) {
        Set<Id> result = new Set<Id>();
        if (opportunityIds.isEmpty()) {
            return result;
        }
        for (ContractHistory__c history : [
            SELECT Opportunity__c
            FROM ContractHistory__c
            WHERE Opportunity__c IN :opportunityIds
            AND Type__c = :HISTORY_TYPE_RENEW
            AND historystatus__c = :HISTORY_STATUS_ESTIMATE
            WITH SYSTEM_MODE
        ]) {
            result.add(history.Opportunity__c);
        }
        return result;
    }

    private static Map<Id, List<ContractProduct__c>> loadRenewSourceProducts(
        Set<Id> sourceHistoryIds
    ) {
        Map<Id, List<ContractProduct__c>> productsByHistoryId =
            new Map<Id, List<ContractProduct__c>>();
        if (sourceHistoryIds.isEmpty()) {
            return productsByHistoryId;
        }

        for (ContractProduct__c product : [
            SELECT
                Id,
                ContractHistory__c,
                ContractHistory__r.CurrentTermEndDate__c,
                Account__c,
                Product__c,
                Product__r.BillingType__c,
                BillingType__c,
                Unit__c,
                UnitPrice__c,
                Quantity__c,
                InvoiceSetting__c,
                Enddate__c
            FROM ContractProduct__c
            WHERE ContractHistory__c IN :sourceHistoryIds
            AND Product__r.BillingType__c = :BILLING_TYPE_RECURRING
            WITH SYSTEM_MODE
        ]) {
            if (
                product.Enddate__c !=
                product.ContractHistory__r.CurrentTermEndDate__c
            ) {
                continue;
            }
            if (!productsByHistoryId.containsKey(product.ContractHistory__c)) {
                productsByHistoryId.put(
                    product.ContractHistory__c,
                    new List<ContractProduct__c>()
                );
            }
            productsByHistoryId.get(product.ContractHistory__c).add(product);
        }
        return productsByHistoryId;
    }

    private static List<ContractProduct__c> buildRenewProducts(
        Id renewHistoryId,
        Date renewStartDate,
        Date renewEndDate,
        List<ContractProduct__c> sourceProducts
    ) {
        List<ContractProduct__c> products = new List<ContractProduct__c>();
        for (ContractProduct__c sourceProduct : sourceProducts) {
            String billingType = String.isNotBlank(sourceProduct.BillingType__c)
                ? sourceProduct.BillingType__c
                : sourceProduct.Product__r.BillingType__c;
            products.add(
                new ContractProduct__c(
                    ContractHistory__c = renewHistoryId,
                    Account__c = sourceProduct.Account__c,
                    Product__c = sourceProduct.Product__c,
                    Quantity__c = sourceProduct.Quantity__c,
                    UnitPrice__c = sourceProduct.UnitPrice__c,
                    Unit__c = sourceProduct.Unit__c,
                    StartDate__c = renewStartDate,
                    Enddate__c = renewEndDate,
                    InvoiceSetting__c = sourceProduct.InvoiceSetting__c,
                    BillingType__c = billingType,
                    Type__c = PRODUCT_TYPE_RENEW,
                    PreviousContractProduct__c = sourceProduct.Id
                )
            );
        }
        return products;
    }
}
