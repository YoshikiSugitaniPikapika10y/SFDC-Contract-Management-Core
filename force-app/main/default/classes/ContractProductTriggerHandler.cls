public without sharing class ContractProductTriggerHandler {
    public static void handleBeforeInsertOrUpdate(List<ContractProduct__c> newProducts) {
        populateAccountFromContractHistory(newProducts);
        populateAmount(newProducts);
    }

    public static void populateAccountFromContractHistory(
        List<ContractProduct__c> products
    ) {
        if (products == null || products.isEmpty()) {
            return;
        }

        Set<Id> historyIdsNeedingAccount = new Set<Id>();
        for (ContractProduct__c product : products) {
            if (product.Account__c == null && product.ContractHistory__c != null) {
                historyIdsNeedingAccount.add(product.ContractHistory__c);
            }
        }
        if (historyIdsNeedingAccount.isEmpty()) {
            return;
        }

        Map<Id, Id> accountIdByHistoryId = loadAccountIdByHistoryId(historyIdsNeedingAccount);

        for (ContractProduct__c product : products) {
            if (product.Account__c != null || product.ContractHistory__c == null) {
                continue;
            }
            product.Account__c = accountIdByHistoryId.get(product.ContractHistory__c);
        }
    }

    private static void populateAmount(List<ContractProduct__c> products) {
        if (products == null || products.isEmpty()) {
            return;
        }

        Set<Id> productIds = new Set<Id>();
        for (ContractProduct__c product : products) {
            if (product.Product__c != null) {
                productIds.add(product.Product__c);
            }
        }

        Map<Id, Product2> productById = productIds.isEmpty()
            ? new Map<Id, Product2>()
            : new Map<Id, Product2>(
                  [
                      SELECT Id, BillingType__c
                      FROM Product2
                      WHERE Id IN :productIds
                      WITH SYSTEM_MODE
                  ]
              );

        for (ContractProduct__c product : products) {
            Product2 productMaster = productById.get(product.Product__c);
            product.Amount__c = ContractProductAmountUtil.calculateSignedAmount(
                product,
                productMaster == null ? null : productMaster.BillingType__c
            );
        }
    }

    private static Map<Id, Id> loadAccountIdByHistoryId(Set<Id> historyIds) {
        Map<Id, Id> accountIdByHistoryId = new Map<Id, Id>();
        for (ContractHistory__c history : [
            SELECT Id, ContractService__r.Account__c
            FROM ContractHistory__c
            WHERE Id IN :historyIds
            WITH SYSTEM_MODE
        ]) {
            if (
                history.ContractService__r != null &&
                history.ContractService__r.Account__c != null
            ) {
                accountIdByHistoryId.put(
                    history.Id,
                    history.ContractService__r.Account__c
                );
            }
        }
        return accountIdByHistoryId;
    }

    public static void handleAfterChange(
        List<ContractProduct__c> newProducts,
        Map<Id, ContractProduct__c> oldMap
    ) {
        Set<Id> historyIds = collectHistoryIds(newProducts, oldMap);
        ContractArrCalculationService.recalculateForHistories(historyIds);
    }

    public static void handleAfterDelete(List<ContractProduct__c> oldProducts) {
        Set<Id> historyIds = new Set<Id>();
        for (ContractProduct__c product : oldProducts) {
            if (product.ContractHistory__c != null) {
                historyIds.add(product.ContractHistory__c);
            }
        }
        ContractArrCalculationService.recalculateForHistories(historyIds);
    }

    private static Set<Id> collectHistoryIds(
        List<ContractProduct__c> newProducts,
        Map<Id, ContractProduct__c> oldMap
    ) {
        Set<Id> historyIds = new Set<Id>();
        for (ContractProduct__c product : newProducts) {
            if (product.ContractHistory__c != null) {
                historyIds.add(product.ContractHistory__c);
            }
            if (oldMap == null) {
                continue;
            }
            ContractProduct__c oldProduct = oldMap.get(product.Id);
            if (
                oldProduct != null &&
                oldProduct.ContractHistory__c != null &&
                oldProduct.ContractHistory__c != product.ContractHistory__c
            ) {
                historyIds.add(oldProduct.ContractHistory__c);
            }
        }
        return historyIds;
    }
}
