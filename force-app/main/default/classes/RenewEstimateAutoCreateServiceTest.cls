@IsTest
private class RenewEstimateAutoCreateServiceTest {
    @TestSetup
    static void setupAccess() {
        ContractTestDataFactory.initTestContext();
    }

    @IsTest
    static void insertWithCheckbox_createsRenewEstimateHistoryAndProducts() {
        System.runAs(ContractTestDataFactory.getAdminUser()) {
            TestData data = createSourceData();

            Test.startTest();
            Opportunity renewOpportunity = ContractTestDataFactory.insertOpportunity(
                data.account.Id,
                'Renew Opportunity',
                data.previousOpportunity.Id,
                true
            );
            Test.stopTest();

            List<ContractHistory__c> createdHistories = [
                SELECT
                    Name,
                    Type__c,
                    historystatus__c,
                    ContractService__c,
                    Opportunity__c,
                    PreviousHistory__c,
                    CurrentTermStartDate__c,
                    CurrentTermEndDate__c,
                    EffectiveDate__c,
                    Version__c
                FROM ContractHistory__c
                WHERE Opportunity__c = :renewOpportunity.Id
            ];
            System.assertEquals(1, createdHistories.size());
            ContractHistory__c createdHistory = createdHistories[0];
            System.assertEquals('Renew Opportunity', createdHistory.Name);
            System.assertEquals('Renew', createdHistory.Type__c);
            System.assertEquals('Estimate', createdHistory.historystatus__c);
            System.assertEquals(data.service.Id, createdHistory.ContractService__c);
            System.assertEquals(data.sourceHistory.Id, createdHistory.PreviousHistory__c);
            System.assertEquals(
                Date.newInstance(2026, 6, 1),
                createdHistory.CurrentTermStartDate__c
            );
            System.assertEquals(
                Date.newInstance(2027, 5, 31),
                createdHistory.CurrentTermEndDate__c
            );
            System.assertEquals(
                Date.newInstance(2026, 6, 1),
                createdHistory.EffectiveDate__c
            );
            System.assertEquals(2, createdHistory.Version__c);

            List<ContractProduct__c> createdProducts = [
                SELECT
                    Product__c,
                    Type__c,
                    BillingType__c,
                    Quantity__c,
                    UnitPrice__c,
                    PreviousContractProduct__c,
                    StartDate__c,
                    Enddate__c
                FROM ContractProduct__c
                WHERE ContractHistory__c = :createdHistory.Id
            ];
            System.assertEquals(1, createdProducts.size());
            System.assertEquals(
                data.sourceProduct.Id,
                createdProducts[0].PreviousContractProduct__c
            );
            System.assertEquals('Renew', createdProducts[0].Type__c);
            System.assertEquals('継続課金', createdProducts[0].BillingType__c);
            System.assertEquals(1, createdProducts[0].Quantity__c);
            System.assertEquals(8000, createdProducts[0].UnitPrice__c);
            System.assertEquals(
                Date.newInstance(2026, 6, 1),
                createdProducts[0].StartDate__c
            );
            System.assertEquals(
                Date.newInstance(2027, 5, 31),
                createdProducts[0].Enddate__c
            );
        }
    }

    @IsTest
    static void insertWithoutPreviousOpportunity_blocksSave() {
        System.runAs(ContractTestDataFactory.getAdminUser()) {
            Account account = ContractTestDataFactory.insertAccount('Test Account');

            Boolean thrown = false;
            try {
                ContractTestDataFactory.insertOpportunity(
                    account.Id,
                    'Renew Opportunity',
                    null,
                    true
                );
            } catch (DmlException ex) {
                thrown = true;
            }
            System.assertEquals(true, thrown, '前商談未設定時は保存できないこと');
        }
    }

    @IsTest
    static void updateCheckboxToTrue_createsRenewEstimate() {
        System.runAs(ContractTestDataFactory.getAdminUser()) {
            TestData data = createSourceData();
            Opportunity renewOpportunity = ContractTestDataFactory.insertOpportunity(
                data.account.Id,
                'Renew Opportunity',
                data.previousOpportunity.Id,
                false
            );

            Test.startTest();
            renewOpportunity.RenewEstimateAutoCreateCheck__c = true;
            update renewOpportunity;
            Test.stopTest();

            System.assertEquals(
                1,
                [
                    SELECT COUNT()
                    FROM ContractHistory__c
                    WHERE Opportunity__c = :renewOpportunity.Id
                    AND Type__c = 'Renew'
                ]
            );
        }
    }

    @IsTest
    static void updateCheckboxAlreadyTrue_doesNotDuplicate() {
        System.runAs(ContractTestDataFactory.getAdminUser()) {
            TestData data = createSourceData();
            Opportunity renewOpportunity = ContractTestDataFactory.insertOpportunity(
                data.account.Id,
                'Renew Opportunity',
                data.previousOpportunity.Id,
                true
            );

            Test.startTest();
            renewOpportunity.Name = 'Renew Opportunity Updated';
            update renewOpportunity;
            Test.stopTest();

            System.assertEquals(
                1,
                [
                    SELECT COUNT()
                    FROM ContractHistory__c
                    WHERE Opportunity__c = :renewOpportunity.Id
                    AND Type__c = 'Renew'
                ]
            );
        }
    }

    private class TestData {
        public Account account;
        public Opportunity previousOpportunity;
        public ContractService__c service;
        public ContractHistory__c sourceHistory;
        public ContractProduct__c sourceProduct;
    }

    private static TestData createSourceData() {
        TestData data = new TestData();
        data.account = ContractTestDataFactory.insertAccount('Test Account');
        data.previousOpportunity = ContractTestDataFactory.insertOpportunity(
            data.account.Id,
            'Previous Opportunity'
        );

        data.service = new ContractService__c(
            Name = 'Renew Source Service',
            Account__c = data.account.Id
        );
        insert data.service;

        Date termStart = Date.newInstance(2025, 6, 1);
        Date termEnd = Date.newInstance(2026, 5, 31);
        data.sourceHistory = new ContractHistory__c(
            Name = 'Source History',
            ContractService__c = data.service.Id,
            Type__c = 'New',
            historystatus__c = 'Ordered',
            Version__c = 1,
            CurrentTermStartDate__c = termStart,
            CurrentTermEndDate__c = termEnd,
            Opportunity__c = data.previousOpportunity.Id
        );
        insert data.sourceHistory;

        Product2 product = ContractTestDataFactory.buildProduct('Renew Product');
        product.UnitName__c = 'ID';
        product.UnitPrice__c = 8000;
        product.invoicetype__c = '一括前払';
        product.BillingType__c = '継続課金';
        ContractTestDataFactory.insertProduct(product);

        data.sourceProduct = new ContractProduct__c(
            ContractHistory__c = data.sourceHistory.Id,
            Product__c = product.Id,
            Quantity__c = 1,
            UnitPrice__c = 8000,
            Unit__c = 'ID/月',
            StartDate__c = termStart,
            Enddate__c = termEnd,
            InvoiceSetting__c = '一括前払',
            BillingType__c = '継続課金',
            Type__c = 'New'
        );
        insert data.sourceProduct;
        return data;
    }
}

