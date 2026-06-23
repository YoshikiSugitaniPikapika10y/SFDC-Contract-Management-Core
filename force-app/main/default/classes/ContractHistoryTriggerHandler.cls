public without sharing class ContractHistoryTriggerHandler {
    private static final String HISTORY_STATUS_ESTIMATE = 'Estimate';
    private static final String HISTORY_STATUS_ORDERED = 'Ordered';

    public static void handleBeforeDelete(List<ContractHistory__c> oldHistories) {
        Set<Id> estimateHistoryIds = new Set<Id>();
        for (ContractHistory__c history : oldHistories) {
            if (history.historystatus__c == HISTORY_STATUS_ESTIMATE && history.Id != null) {
                estimateHistoryIds.add(history.Id);
            }
        }
        if (estimateHistoryIds.isEmpty()) {
            return;
        }

        List<InvoiceProduct__c> uninvoicedProducts = [
            SELECT Id
            FROM InvoiceProduct__c
            WHERE ContractHistory__c IN :estimateHistoryIds
            AND LatestExportDate__c = NULL
            AND ActualInvoiceDate__c = NULL
            WITH SYSTEM_MODE
        ];
        if (!uninvoicedProducts.isEmpty()) {
            SystemContextAccess.deleteRecords(uninvoicedProducts);
        }
    }

    public static void handleBeforeUpdate(
        List<ContractHistory__c> newHistories,
        Map<Id, ContractHistory__c> oldMap
    ) {
        Set<Id> revertToEstimateHistoryIds = new Set<Id>();
        for (ContractHistory__c history : newHistories) {
            ContractHistory__c oldHistory = oldMap.get(history.Id);
            if (
                oldHistory != null &&
                oldHistory.historystatus__c == HISTORY_STATUS_ORDERED &&
                history.historystatus__c == HISTORY_STATUS_ESTIMATE
            ) {
                revertToEstimateHistoryIds.add(history.Id);
            }
        }
        if (revertToEstimateHistoryIds.isEmpty()) {
            return;
        }

        Set<Id> blockedHistoryIds = queryHistoryIdsBlockedForRevert(
            revertToEstimateHistoryIds
        );
        for (ContractHistory__c history : newHistories) {
            if (blockedHistoryIds.contains(history.Id)) {
                history.addError(
                    '請求済またはエクスポート済の請求商品があるため、ステータスを Estimate に戻せません。'
                );
            }
        }
    }

    private static Set<Id> queryHistoryIdsBlockedForRevert(
        Set<Id> contractHistoryIds
    ) {
        Set<Id> blockedHistoryIds = new Set<Id>();
        for (AggregateResult result : [
            SELECT ContractHistory__c historyId
            FROM InvoiceProduct__c
            WHERE ContractHistory__c IN :contractHistoryIds
            AND (
                ActualInvoiceDate__c != NULL
                OR LatestExportDate__c != NULL
            )
            WITH SYSTEM_MODE
            GROUP BY ContractHistory__c
        ]) {
            blockedHistoryIds.add((Id) result.get('historyId'));
        }
        return blockedHistoryIds;
    }

    public static void handleAfterInsert(List<ContractHistory__c> newHistories) {
        List<ContractHistory__c> insertedAsOrderedHistories = new List<ContractHistory__c>();
        Set<Id> insertedAsOrderedHistoryIds = new Set<Id>();

        for (ContractHistory__c history : newHistories) {
            if (history.historystatus__c == HISTORY_STATUS_ORDERED) {
                insertedAsOrderedHistories.add(history);
                insertedAsOrderedHistoryIds.add(history.Id);
            }
        }

        if (!insertedAsOrderedHistoryIds.isEmpty()) {
            InvoiceProductGenerationService.generateForHistories(
                insertedAsOrderedHistoryIds
            );
        }

        syncOrderedHistoriesOnInsert(newHistories);
        recalculateArr(newHistories);
    }

    public static void handleAfterUpdate(
        List<ContractHistory__c> newHistories,
        Map<Id, ContractHistory__c> oldMap
    ) {
        Set<Id> orderedHistoryIds = new Set<Id>();
        Set<Id> revertToEstimateHistoryIds = new Set<Id>();
        List<ContractHistory__c> orderedTransitionHistories = new List<ContractHistory__c>();
        List<ContractHistory__c> revertToEstimateHistories = new List<ContractHistory__c>();

        for (ContractHistory__c history : newHistories) {
            ContractHistory__c oldHistory = oldMap.get(history.Id);

            if (
                oldHistory != null &&
                oldHistory.historystatus__c == HISTORY_STATUS_ORDERED &&
                history.historystatus__c == HISTORY_STATUS_ESTIMATE
            ) {
                revertToEstimateHistoryIds.add(history.Id);
                revertToEstimateHistories.add(history);
            }

            if (
                history.historystatus__c == HISTORY_STATUS_ORDERED &&
                (oldHistory == null ||
                oldHistory.historystatus__c != HISTORY_STATUS_ORDERED)
            ) {
                orderedTransitionHistories.add(history);
            }

            if (
                oldHistory != null &&
                oldHistory.historystatus__c == HISTORY_STATUS_ESTIMATE &&
                history.historystatus__c == HISTORY_STATUS_ORDERED
            ) {
                orderedHistoryIds.add(history.Id);
            }
        }

        if (!revertToEstimateHistoryIds.isEmpty()) {
            EstimateRevertInvoiceService.adjustForRevertedToEstimateHistories(
                revertToEstimateHistories
            );
            ContractOrderedHistorySyncService.syncForHistories(
                revertToEstimateHistories
            );
        }

        if (!orderedHistoryIds.isEmpty()) {
            InvoiceProductGenerationService.generateForHistories(orderedHistoryIds);
        }

        if (!orderedTransitionHistories.isEmpty()) {
            ContractHistoryArchiveService.archiveSupersededEstimates(
                orderedTransitionHistories
            );
            ContractOrderedHistorySyncService.syncForHistories(
                orderedTransitionHistories
            );
        }
    }

    private static void syncOrderedHistoriesOnInsert(
        List<ContractHistory__c> histories
    ) {
        List<ContractHistory__c> orderedHistories = new List<ContractHistory__c>();
        for (ContractHistory__c history : histories) {
            if (history.historystatus__c == HISTORY_STATUS_ORDERED) {
                orderedHistories.add(history);
            }
        }

        if (!orderedHistories.isEmpty()) {
            ContractHistoryArchiveService.archiveSupersededEstimates(orderedHistories);
            ContractOrderedHistorySyncService.syncForHistories(orderedHistories);
        }
    }

    private static void recalculateArr(List<ContractHistory__c> histories) {
        Set<Id> historyIds = new Set<Id>();
        for (ContractHistory__c history : histories) {
            historyIds.add(history.Id);
        }
        ContractArrCalculationService.recalculateForHistories(historyIds);
    }
}
