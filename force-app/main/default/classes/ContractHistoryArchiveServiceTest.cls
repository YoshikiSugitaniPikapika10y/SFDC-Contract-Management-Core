@IsTest
private class ContractHistoryArchiveServiceTest {
    @IsTest
    static void archiveSupersededEstimates_archivesSameOrLowerVersionEstimates() {
        System.runAs(ContractTestDataFactory.getAdminUser()) {
            Account account = ContractTestDataFactory.insertAccount('Archive Account');
            ContractService__c service = new ContractService__c(
                Name = 'Archive Service',
                Account__c = account.Id
            );
            insert service;

            List<ContractHistory__c> histories = new List<ContractHistory__c>{
                buildEstimateHistory(service.Id, 'Estimate v1', 1),
                buildEstimateHistory(service.Id, 'Estimate v2', 2),
                buildEstimateHistory(service.Id, 'Estimate v4 A', 4),
                buildEstimateHistory(service.Id, 'Estimate v4 B', 4),
                buildEstimateHistory(service.Id, 'Estimate v5', 5)
            };
            insert histories;

            ContractHistory__c orderedHistory = histories[2];
            orderedHistory.historystatus__c = 'Ordered';
            update orderedHistory;

            Map<Id, ContractHistory__c> updatedById = new Map<Id, ContractHistory__c>([
                SELECT Id, Name, historystatus__c, Version__c
                FROM ContractHistory__c
                WHERE ContractService__c = :service.Id
                ORDER BY Version__c ASC, Name ASC
            ]);

            System.assertEquals('Archive', updatedById.get(histories[0].Id).historystatus__c);
            System.assertEquals('Archive', updatedById.get(histories[1].Id).historystatus__c);
            System.assertEquals('Ordered', updatedById.get(histories[2].Id).historystatus__c);
            System.assertEquals('Archive', updatedById.get(histories[3].Id).historystatus__c);
            System.assertEquals('Estimate', updatedById.get(histories[4].Id).historystatus__c);
        }
    }

    @IsTest
    static void archiveSupersededEstimates_runsOnInsertAsOrdered() {
        System.runAs(ContractTestDataFactory.getAdminUser()) {
            Account account = ContractTestDataFactory.insertAccount('Archive Insert Account');
            ContractService__c service = new ContractService__c(
                Name = 'Archive Insert Service',
                Account__c = account.Id
            );
            insert service;

            insert buildEstimateHistory(service.Id, 'Estimate v1', 1);

            Test.startTest();
            insert new ContractHistory__c(
                Name = 'Cancel Ordered v2',
                ContractService__c = service.Id,
                Type__c = 'Cancel',
                historystatus__c = 'Ordered',
                Version__c = 2,
                CurrentTermStartDate__c = Date.newInstance(2026, 6, 1),
                CurrentTermEndDate__c = Date.newInstance(2026, 6, 1),
                EffectiveDate__c = Date.newInstance(2026, 6, 1)
            );
            Test.stopTest();

            System.assertEquals(
                'Archive',
                [
                    SELECT historystatus__c
                    FROM ContractHistory__c
                    WHERE ContractService__c = :service.Id AND Version__c = 1
                ]
                .historystatus__c
            );
        }
    }

    private static ContractHistory__c buildEstimateHistory(
        Id serviceId,
        String name,
        Decimal version
    ) {
        return new ContractHistory__c(
            Name = name,
            ContractService__c = serviceId,
            Type__c = 'Renew',
            historystatus__c = 'Estimate',
            Version__c = version,
            CurrentTermStartDate__c = Date.newInstance(2026, 6, 1),
            CurrentTermEndDate__c = Date.newInstance(2027, 5, 31),
            EffectiveDate__c = Date.newInstance(2026, 6, 1)
        );
    }
}
