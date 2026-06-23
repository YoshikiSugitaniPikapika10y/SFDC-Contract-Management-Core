@IsTest
private class ContractHistoryVersionUtilTest {
    @TestSetup
    static void setupAccess() {
        ContractTestDataFactory.initTestContext();
    }

    @IsTest

    static void getNextHistoryVersion_returnsOneForNewService() {

        System.runAs(ContractTestDataFactory.getAdminUser()) {

            Account account = ContractTestDataFactory.insertAccount('Version Account');



            ContractService__c service = new ContractService__c(

                Name = 'Version Service',

                Account__c = account.Id

            );

            insert service;



            System.assertEquals(

                1,

                ContractHistoryVersionUtil.getNextHistoryVersion(service.Id)

            );

        }

    }



    @IsTest

    static void allocateNextVersion_incrementsWithinBatch() {

        System.runAs(ContractTestDataFactory.getAdminUser()) {

            Account account = ContractTestDataFactory.insertAccount('Batch Version Account');



            ContractService__c service = new ContractService__c(

                Name = 'Batch Version Service',

                Account__c = account.Id

            );

            insert service;



            insert new ContractHistory__c(

                Name = 'History v1',

                ContractService__c = service.Id,

                Type__c = 'New',

                historystatus__c = 'Estimate',

                Version__c = 1

            );



            Map<Id, Decimal> allocator = ContractHistoryVersionUtil.buildVersionAllocator(

                new Set<Id>{ service.Id }

            );



            System.assertEquals(

                2,

                ContractHistoryVersionUtil.allocateNextVersion(allocator, service.Id)

            );

            System.assertEquals(

                3,

                ContractHistoryVersionUtil.allocateNextVersion(allocator, service.Id)

            );

        }

    }

}

