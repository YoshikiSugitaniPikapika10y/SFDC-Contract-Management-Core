public without sharing class ContractHistoryArchiveService {
    private static final String HISTORY_STATUS_ESTIMATE = 'Estimate';
    private static final String HISTORY_STATUS_ARCHIVE = 'Archive';

    public static void archiveSupersededEstimates(
        List<ContractHistory__c> newlyOrderedHistories
    ) {
        if (newlyOrderedHistories == null || newlyOrderedHistories.isEmpty()) {
            return;
        }

        List<ContractHistory__c> historiesToArchive = new List<ContractHistory__c>();
        for (ContractHistory__c orderedHistory : newlyOrderedHistories) {
            if (
                orderedHistory == null ||
                orderedHistory.Id == null ||
                orderedHistory.ContractService__c == null ||
                orderedHistory.Version__c == null
            ) {
                continue;
            }

            for (ContractHistory__c estimateHistory : [
                SELECT Id
                FROM ContractHistory__c
                WHERE ContractService__c = :orderedHistory.ContractService__c
                AND historystatus__c = :HISTORY_STATUS_ESTIMATE
                AND Version__c <= :orderedHistory.Version__c
                AND Id != :orderedHistory.Id
                WITH SYSTEM_MODE
            ]) {
                historiesToArchive.add(
                    new ContractHistory__c(
                        Id = estimateHistory.Id,
                        historystatus__c = HISTORY_STATUS_ARCHIVE
                    )
                );
            }
        }

        if (!historiesToArchive.isEmpty()) {
            SystemContextAccess.updateRecords(historiesToArchive);
        }
    }
}
