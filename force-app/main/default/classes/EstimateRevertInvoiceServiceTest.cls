@IsTest
private class EstimateRevertInvoiceServiceTest {
    private static final String BILLING_TYPE_RECURRING = '継続課金';
    private static final String INVOICE_SETTING_MONTHLY = '月次分割';
    private static final String CREDIT_NOTE_INVOICE_TYPE =
        INVOICE_SETTING_MONTHLY + '（赤伝）';

    @IsTest
    static void revertToEstimate_deletesUninvoicedProductsOnOwnHistory() {
        System.runAs(ContractTestDataFactory.getAdminUser()) {
            TestContext context = createSingleOrderedContext();

            insert new InvoiceProduct__c(
                ContractHistory__c = context.history.Id,
                ContractProduct__c = context.contractProduct.Id,
                StartDate__c = Date.newInstance(2026, 6, 1),
                Enddate__c = Date.newInstance(2026, 6, 30),
                InvoiceDate__c = Date.newInstance(2026, 6, 1),
                Amount__c = 8000,
                invoicetype__c = INVOICE_SETTING_MONTHLY
            );

            context.history.historystatus__c = 'Estimate';
            Test.startTest();
            update context.history;
            Test.stopTest();

            System.assertEquals(
                0,
                [
                    SELECT COUNT()
                    FROM InvoiceProduct__c
                    WHERE ContractHistory__c = :context.history.Id
                ]
            );
        }
    }

    @IsTest
    static void revertToEstimate_doesNotModifyPriorHistoryInvoiceProducts() {
        System.runAs(ContractTestDataFactory.getAdminUser()) {
            TestContext context = createTwoVersionContext(
                Date.newInstance(2026, 10, 1)
            );

            context.changeHistory.historystatus__c = 'Ordered';
            update context.changeHistory;

            insert new InvoiceProduct__c(
                ContractHistory__c = context.priorHistory.Id,
                ContractProduct__c = context.priorContractProduct.Id,
                StartDate__c = Date.newInstance(2026, 10, 1),
                Enddate__c = Date.newInstance(2026, 10, 31),
                InvoiceDate__c = Date.newInstance(2026, 10, 1),
                Amount__c = -8000,
                invoicetype__c = CREDIT_NOTE_INVOICE_TYPE
            );

            Integer priorCountBefore = [
                SELECT COUNT()
                FROM InvoiceProduct__c
                WHERE ContractHistory__c = :context.priorHistory.Id
            ];

            context.changeHistory.historystatus__c = 'Estimate';
            Test.startTest();
            update context.changeHistory;
            Test.stopTest();

            System.assertEquals(
                priorCountBefore,
                [
                    SELECT COUNT()
                    FROM InvoiceProduct__c
                    WHERE ContractHistory__c = :context.priorHistory.Id
                ]
            );
        }
    }

    @IsTest
    static void revertToEstimate_blocksWhenInvoicedProductsExistOnOwnHistory() {
        System.runAs(ContractTestDataFactory.getAdminUser()) {
            TestContext context = createSingleOrderedContext();

            insert new InvoiceProduct__c(
                ContractHistory__c = context.history.Id,
                ContractProduct__c = context.contractProduct.Id,
                StartDate__c = Date.newInstance(2026, 6, 1),
                Enddate__c = Date.newInstance(2026, 6, 30),
                InvoiceDate__c = Date.newInstance(2026, 6, 1),
                Amount__c = 8000,
                invoicetype__c = INVOICE_SETTING_MONTHLY,
                ActualInvoiceDate__c = Date.today()
            );

            Boolean thrown = false;
            try {
                context.history.historystatus__c = 'Estimate';
                update context.history;
            } catch (DmlException ex) {
                thrown = true;
                System.assert(
                    ex.getMessage().contains('請求済またはエクスポート済の請求商品があるため'),
                    ex.getMessage()
                );
            }
            System.assertEquals(true, thrown);
        }
    }

    private class TestContext {
        public ContractHistory__c history;
        public ContractProduct__c contractProduct;
        public ContractHistory__c priorHistory;
        public ContractHistory__c changeHistory;
        public ContractProduct__c priorContractProduct;
    }

    private static TestContext createSingleOrderedContext() {
        Account account = ContractTestDataFactory.insertAccount('Revert Own Account');
        ContractService__c service = new ContractService__c(
            Name = 'Revert Own Service',
            Account__c = account.Id
        );
        insert service;

        Product2 product = ContractTestDataFactory.buildProduct('Revert Own Product');
        product.BillingType__c = BILLING_TYPE_RECURRING;
        ContractTestDataFactory.insertProduct(product);

        ContractHistory__c history = new ContractHistory__c(
            Name = 'Revert Own History',
            ContractService__c = service.Id,
            Type__c = 'Renew',
            historystatus__c = 'Ordered',
            Version__c = 1,
            CurrentTermStartDate__c = Date.newInstance(2026, 6, 1),
            CurrentTermEndDate__c = Date.newInstance(2027, 5, 31)
        );
        insert history;

        ContractProduct__c contractProduct = new ContractProduct__c(
            ContractHistory__c = history.Id,
            Product__c = product.Id,
            Quantity__c = 1,
            UnitPrice__c = 8000,
            StartDate__c = Date.newInstance(2026, 6, 1),
            Enddate__c = Date.newInstance(2027, 5, 31),
            InvoiceSetting__c = INVOICE_SETTING_MONTHLY,
            BillingType__c = BILLING_TYPE_RECURRING,
            Type__c = 'Renew'
        );
        insert contractProduct;

        TestContext context = new TestContext();
        context.history = history;
        context.contractProduct = contractProduct;
        return context;
    }

    private static TestContext createTwoVersionContext(Date effectiveDate) {
        Account account = ContractTestDataFactory.insertAccount('Revert Prior Account');
        ContractService__c service = new ContractService__c(
            Name = 'Revert Prior Service',
            Account__c = account.Id
        );
        insert service;

        Product2 product = ContractTestDataFactory.buildProduct('Revert Prior Product');
        product.BillingType__c = BILLING_TYPE_RECURRING;
        ContractTestDataFactory.insertProduct(product);

        ContractHistory__c priorHistory = new ContractHistory__c(
            Name = 'Revert Prior History v1',
            ContractService__c = service.Id,
            Type__c = 'New',
            historystatus__c = 'Ordered',
            Version__c = 1,
            CurrentTermStartDate__c = Date.newInstance(2026, 6, 1),
            CurrentTermEndDate__c = Date.newInstance(2027, 5, 31),
            EffectiveDate__c = Date.newInstance(2026, 6, 1)
        );
        insert priorHistory;

        ContractProduct__c priorContractProduct = new ContractProduct__c(
            ContractHistory__c = priorHistory.Id,
            Product__c = product.Id,
            Quantity__c = 1,
            UnitPrice__c = 8000,
            StartDate__c = Date.newInstance(2026, 6, 1),
            Enddate__c = Date.newInstance(2027, 5, 31),
            InvoiceSetting__c = INVOICE_SETTING_MONTHLY,
            BillingType__c = BILLING_TYPE_RECURRING,
            Type__c = 'New'
        );
        insert priorContractProduct;

        ContractHistory__c changeHistory = new ContractHistory__c(
            Name = 'Revert Change History v2',
            ContractService__c = service.Id,
            Type__c = 'Change',
            historystatus__c = 'Estimate',
            Version__c = 2,
            CurrentTermStartDate__c = Date.newInstance(2026, 6, 1),
            CurrentTermEndDate__c = Date.newInstance(2027, 5, 31),
            EffectiveDate__c = effectiveDate,
            PreviousHistory__c = priorHistory.Id
        );
        insert changeHistory;

        TestContext context = new TestContext();
        context.priorHistory = priorHistory;
        context.changeHistory = changeHistory;
        context.priorContractProduct = priorContractProduct;
        return context;
    }
}
