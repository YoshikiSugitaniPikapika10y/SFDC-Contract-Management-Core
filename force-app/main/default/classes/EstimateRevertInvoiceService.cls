public without sharing class EstimateRevertInvoiceService {
    public static void adjustForRevertedToEstimateHistories(
        List<ContractHistory__c> revertedHistories
    ) {
        if (revertedHistories == null || revertedHistories.isEmpty()) {
            return;
        }

        Set<Id> revertedHistoryIds = new Set<Id>();
        for (ContractHistory__c revertedHistory : revertedHistories) {
            if (revertedHistory.Id != null) {
                revertedHistoryIds.add(revertedHistory.Id);
            }
        }
        if (revertedHistoryIds.isEmpty()) {
            return;
        }

        List<InvoiceProduct__c> uninvoicedProducts = [
            SELECT Id
            FROM InvoiceProduct__c
            WHERE ContractHistory__c IN :revertedHistoryIds
            AND LatestExportDate__c = NULL
            AND ActualInvoiceDate__c = NULL
            WITH SYSTEM_MODE
        ];
        if (!uninvoicedProducts.isEmpty()) {
            SystemContextAccess.deleteRecords(uninvoicedProducts);
        }
    }
}
