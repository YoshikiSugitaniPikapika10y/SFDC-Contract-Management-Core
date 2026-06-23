public without sharing class ContractArrCalculationService {
    private static final String BILLING_TYPE_RECURRING = '継続課金';
    private static final String PRODUCT_TYPE_ORIGINAL = 'Original';

    public static void recalculateForHistories(Set<Id> contractHistoryIds) {
        if (contractHistoryIds == null || contractHistoryIds.isEmpty()) {
            return;
        }

        Map<Id, Decimal> arrByHistoryId = calculateArrByHistoryId(contractHistoryIds);
        Map<Id, ContractHistory__c> histories = new Map<Id, ContractHistory__c>([
            SELECT Id, ARR__c
            FROM ContractHistory__c
            WHERE Id IN :contractHistoryIds
            WITH SYSTEM_MODE
        ]);

        List<ContractHistory__c> historiesToUpdate = new List<ContractHistory__c>();

        for (Id historyId : contractHistoryIds) {
            ContractHistory__c history = histories.get(historyId);
            if (history == null) {
                continue;
            }

            Decimal arr = arrByHistoryId.containsKey(historyId)
                ? arrByHistoryId.get(historyId)
                : 0;

            if (history.ARR__c == arr) {
                continue;
            }

            historiesToUpdate.add(
                new ContractHistory__c(
                    Id = historyId,
                    ARR__c = arr
                )
            );
        }

        if (!historiesToUpdate.isEmpty()) {
            SystemContextAccess.updateRecords(historiesToUpdate);
        }
    }

    private static Map<Id, Decimal> calculateArrByHistoryId(Set<Id> contractHistoryIds) {
        Map<Id, Decimal> arrByHistoryId = new Map<Id, Decimal>();
        Map<Id, Date> termEndDateByHistoryId = new Map<Id, Date>();

        for (ContractHistory__c history : [
            SELECT Id, CurrentTermEndDate__c
            FROM ContractHistory__c
            WHERE Id IN :contractHistoryIds
            WITH SYSTEM_MODE
        ]) {
            arrByHistoryId.put(history.Id, 0);
            termEndDateByHistoryId.put(
                history.Id,
                history.CurrentTermEndDate__c
            );
        }

        for (ContractProduct__c product : [
            SELECT
                ContractHistory__c,
                Quantity__c,
                UnitPrice__c,
                BillingType__c,
                Type__c,
                Enddate__c,
                Product__r.BillingType__c
            FROM ContractProduct__c
            WHERE ContractHistory__c IN :contractHistoryIds
            AND Type__c != :PRODUCT_TYPE_ORIGINAL
            AND Quantity__c > 0
            WITH SYSTEM_MODE
        ]) {
            Date termEndDate = termEndDateByHistoryId.get(product.ContractHistory__c);
            Decimal lineArr = calculateProductArr(product, termEndDate);
            Decimal currentArr = arrByHistoryId.get(product.ContractHistory__c);
            arrByHistoryId.put(product.ContractHistory__c, currentArr + lineArr);
        }

        return arrByHistoryId;
    }

    @TestVisible
    private static Decimal calculateProductArr(
        ContractProduct__c product,
        Date termEndDate
    ) {
        if (product == null || product.ContractHistory__c == null) {
            return 0;
        }

        if (termEndDate == null || product.Enddate__c != termEndDate) {
            return 0;
        }

        if (product.Type__c == PRODUCT_TYPE_ORIGINAL) {
            return 0;
        }

        String billingType = String.isNotBlank(product.BillingType__c)
            ? product.BillingType__c
            : product.Product__r.BillingType__c;
        if (billingType != BILLING_TYPE_RECURRING) {
            return 0;
        }

        Decimal quantity = product.Quantity__c == null ? 0 : product.Quantity__c;
        Decimal unitPrice = product.UnitPrice__c == null ? 0 : product.UnitPrice__c;
        if (quantity <= 0 || unitPrice == 0) {
            return 0;
        }

        return ContractMetadataService.calculateMonthlyArrRunRate(
            quantity,
            unitPrice
        );
    }
}
