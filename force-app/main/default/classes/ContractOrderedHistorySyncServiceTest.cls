@IsTest
private class ContractOrderedHistorySyncServiceTest {
    @TestSetup
    static void setupAccess() {
        ContractTestDataFactory.initTestContext();
    }

    @IsTest

    static void syncForServices_setsFirstAndLatestOrderedHistories() {

        System.runAs(ContractTestDataFactory.getAdminUser()) {

            Account account = ContractTestDataFactory.insertAccount('Ordered Sync Account');

            Opportunity opportunity = ContractTestDataFactory.insertOpportunity(

                account.Id,

                'Ordered Sync Opportunity'

            );



            ContractService__c service = new ContractService__c(

                Name = 'Ordered History Sync Service',

                Account__c = account.Id

            );

            insert service;



            Date termStart = Date.today();

            Date termEnd = Date.today().addMonths(12).addDays(-1);



            ContractHistory__c firstHistory = new ContractHistory__c(

                Name = 'First Ordered History',

                ContractService__c = service.Id,

                Type__c = 'New',

                historystatus__c = 'Ordered',

                Version__c = 1,

                CurrentTermStartDate__c = termStart,

                CurrentTermEndDate__c = termEnd,

                Opportunity__c = opportunity.Id

            );

            insert firstHistory;



            ContractService__c afterFirstInsert = [

                SELECT FirstOrderedHistory__c, LatestOrderedHistory__c

                FROM ContractService__c

                WHERE Id = :service.Id

            ];

            System.assertEquals(firstHistory.Id, afterFirstInsert.FirstOrderedHistory__c);

            System.assertEquals(firstHistory.Id, afterFirstInsert.LatestOrderedHistory__c);



            ContractHistory__c secondHistory = new ContractHistory__c(

                Name = 'Second Ordered History',

                ContractService__c = service.Id,

                Type__c = 'Change',

                historystatus__c = 'Estimate',

                Version__c = 2,

                CurrentTermStartDate__c = termStart,

                CurrentTermEndDate__c = termEnd,

                Opportunity__c = opportunity.Id,

                PreviousHistory__c = firstHistory.Id

            );

            insert secondHistory;



            Test.startTest();

            secondHistory.historystatus__c = 'Ordered';

            update secondHistory;

            Test.stopTest();



            ContractService__c afterSecondOrdered = [

                SELECT FirstOrderedHistory__c, LatestOrderedHistory__c

                FROM ContractService__c

                WHERE Id = :service.Id

            ];

            System.assertEquals(firstHistory.Id, afterSecondOrdered.FirstOrderedHistory__c);

            System.assertEquals(secondHistory.Id, afterSecondOrdered.LatestOrderedHistory__c);

        }

    }



    @IsTest

    static void syncForServices_ignoresEstimateHistories() {

        System.runAs(ContractTestDataFactory.getAdminUser()) {

            Account account = ContractTestDataFactory.insertAccount('Estimate Only Account');

            Opportunity opportunity = ContractTestDataFactory.insertOpportunity(

                account.Id,

                'Estimate Only Opportunity'

            );



            ContractService__c service = new ContractService__c(

                Name = 'Estimate Only Service',

                Account__c = account.Id

            );

            insert service;



            insert new ContractHistory__c(

                Name = 'Estimate History',

                ContractService__c = service.Id,

                Type__c = 'New',

                historystatus__c = 'Estimate',

                Version__c = 1,

                CurrentTermStartDate__c = Date.today(),

                CurrentTermEndDate__c = Date.today().addMonths(12).addDays(-1),

                Opportunity__c = opportunity.Id

            );



            ContractService__c updatedService = [

                SELECT FirstOrderedHistory__c, LatestOrderedHistory__c

                FROM ContractService__c

                WHERE Id = :service.Id

            ];

            System.assertEquals(null, updatedService.FirstOrderedHistory__c);

            System.assertEquals(null, updatedService.LatestOrderedHistory__c);

        }

    }

}

