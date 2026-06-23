@IsTest
private class ContractArrCalculationServiceTest {
    @TestSetup
    static void setupAccess() {
        ContractTestDataFactory.initTestContext();
    }

    @IsTest

    static void recalculateForHistories_setsArrAndDeltaArr() {

        System.runAs(ContractTestDataFactory.getAdminUser()) {

            Account account = ContractTestDataFactory.insertAccount('ARR Test Account');

            Opportunity opportunity = ContractTestDataFactory.insertOpportunity(

                account.Id,

                'ARR Test Opportunity'

            );



            Product2 product = ContractTestDataFactory.buildProduct('ARR Test Product');

            product.UnitName__c = '式';

            product.UnitPrice__c = 10000;

            product.invoicetype__c = '一括前払';

            product.BillingType__c = '継続課金';


            ContractTestDataFactory.insertProduct(product);



            Date termEnd = Date.today().addMonths(12).addDays(-1);



            ContractService__c service = new ContractService__c(

                Name = 'ARR Test Service',

                Account__c = account.Id

            );

            insert service;



            ContractHistory__c previousHistory = new ContractHistory__c(

                Name = 'ARR Previous History',

                ContractService__c = service.Id,

                Type__c = 'New',

                historystatus__c = 'Estimate',

                Version__c = 1,

                CurrentTermStartDate__c = Date.today(),

                CurrentTermEndDate__c = termEnd,

                Opportunity__c = opportunity.Id

            );

            insert previousHistory;



            insert new ContractProduct__c(

                ContractHistory__c = previousHistory.Id,

                Product__c = product.Id,

                Quantity__c = 1,

                UnitPrice__c = 10000,


                StartDate__c = Date.today(),

                Enddate__c = termEnd,

                InvoiceSetting__c = '一括前払',

                BillingType__c = '継続課金',

                Type__c = 'New'

            );



            previousHistory = [

                SELECT ARR__c, DeltaARR__c

                FROM ContractHistory__c

                WHERE Id = :previousHistory.Id

            ];

            System.assertEquals(120000, previousHistory.ARR__c);

            System.assertEquals(120000, previousHistory.DeltaARR__c);



            ContractHistory__c changeHistory = new ContractHistory__c(

                Name = 'ARR Change History',

                ContractService__c = service.Id,

                Type__c = 'Change',

                historystatus__c = 'Estimate',

                Version__c = 2,

                CurrentTermStartDate__c = Date.today(),

                CurrentTermEndDate__c = termEnd,

                Opportunity__c = opportunity.Id,

                PreviousHistory__c = previousHistory.Id

            );

            insert changeHistory;



            insert new ContractProduct__c(

                ContractHistory__c = changeHistory.Id,

                Product__c = product.Id,

                Quantity__c = 2,

                UnitPrice__c = 10000,


                StartDate__c = Date.today(),

                Enddate__c = termEnd,

                InvoiceSetting__c = '一括前払',

                BillingType__c = '継続課金',

                Type__c = 'New'

            );



            changeHistory = [

                SELECT ARR__c, DeltaARR__c

                FROM ContractHistory__c

                WHERE Id = :changeHistory.Id

            ];

            System.assertEquals(240000, changeHistory.ARR__c);

            System.assertEquals(120000, changeHistory.DeltaARR__c);

        }

    }



    @IsTest

    static void recalculateForHistories_excludesOriginalAndShortTermProducts() {

        System.runAs(ContractTestDataFactory.getAdminUser()) {

            Account account = ContractTestDataFactory.insertAccount('ARR Filter Account');

            Opportunity opportunity = ContractTestDataFactory.insertOpportunity(

                account.Id,

                'ARR Filter Opportunity'

            );



            Product2 product = ContractTestDataFactory.buildProduct('ARR Filter Product');

            product.UnitName__c = '式';

            product.UnitPrice__c = 5000;

            product.invoicetype__c = '一括前払';

            product.BillingType__c = '継続課金';


            ContractTestDataFactory.insertProduct(product);



            Date termEnd = Date.today().addMonths(12).addDays(-1);



            ContractService__c service = new ContractService__c(

                Name = 'ARR Filter Service',

                Account__c = account.Id

            );

            insert service;



            ContractHistory__c history = new ContractHistory__c(

                Name = 'ARR Filter History',

                ContractService__c = service.Id,

                Type__c = 'Change',

                historystatus__c = 'Estimate',

                Version__c = 1,

                CurrentTermStartDate__c = Date.today(),

                CurrentTermEndDate__c = termEnd,

                Opportunity__c = opportunity.Id

            );

            insert history;



            insert new List<ContractProduct__c>{

                new ContractProduct__c(

                    ContractHistory__c = history.Id,

                    Product__c = product.Id,

                    Quantity__c = 1,

                    UnitPrice__c = 5000,

                    StartDate__c = Date.today(),

                    Enddate__c = termEnd,

                    InvoiceSetting__c = '一括前払',

                    BillingType__c = '継続課金',

                    Type__c = 'New'

                ),

                new ContractProduct__c(

                    ContractHistory__c = history.Id,

                    Product__c = product.Id,

                    Quantity__c = 1,

                    UnitPrice__c = 5000,

                    StartDate__c = Date.today(),

                    Enddate__c = Date.today().addMonths(6).addDays(-1),

                    InvoiceSetting__c = '一括前払',

                    BillingType__c = '継続課金',

                    Type__c = 'Original'

                )

            };



            history = [

                SELECT ARR__c

                FROM ContractHistory__c

                WHERE Id = :history.Id

            ];

            System.assertEquals(60000, history.ARR__c);

        }

    }

}


