@IsTest
private class InvoiceProductInvoicedControllerTest {
    @TestSetup
    static void setupAccess() {
        ContractTestDataFactory.initTestContext();
    }

    @IsTest
    static void getInvoiceProducts_returnsRowsOrderedByInvoiceDate() {
        System.runAs(ContractTestDataFactory.getAdminUser()) {
            TestContext context = createHistoryWithInvoiceProducts();

            Test.startTest();
            List<InvoiceProductInvoicedController.InvoiceProductRow> rows =
                InvoiceProductInvoicedController.getInvoiceProducts(context.history.Id);
            Test.stopTest();

            System.assertEquals(4, rows.size());
            System.assertEquals(1, rows[0].rowNumber);
            System.assertEquals(Date.newInstance(2026, 6, 1), rows[0].invoiceDate);
            System.assertEquals(false, rows[0].invoiced);
            System.assertEquals(null, rows[0].actualInvoiceDate);
            System.assertEquals(false, rows[0].exported);
            System.assertEquals(false, rows[0].locked);
        }
    }

    @IsTest
    static void updateInvoicedFlagByInvoiceDateRange_marksProductsInRange() {
        System.runAs(ContractTestDataFactory.getAdminUser()) {
            TestContext context = createHistoryWithInvoiceProducts();
            Date actualDate = Date.newInstance(2026, 7, 15);

            Test.startTest();
            Integer updatedCount =
                InvoiceProductInvoicedController.updateInvoicedFlagByInvoiceDateRange(
                    context.history.Id,
                    Date.newInstance(2026, 7, 1),
                    Date.newInstance(2026, 8, 31),
                    true,
                    actualDate
                );
            Test.stopTest();

            System.assertEquals(2, updatedCount);

            Map<Date, Date> actualDateByInvoiceDate = new Map<Date, Date>();
            for (InvoiceProduct__c product : [
                SELECT InvoiceDate__c, ActualInvoiceDate__c
                FROM InvoiceProduct__c
                WHERE ContractHistory__c = :context.history.Id
                ORDER BY InvoiceDate__c ASC
            ]) {
                actualDateByInvoiceDate.put(
                    product.InvoiceDate__c,
                    product.ActualInvoiceDate__c
                );
            }
            System.assertEquals(null, actualDateByInvoiceDate.get(Date.newInstance(2026, 6, 1)));
            System.assertEquals(actualDate, actualDateByInvoiceDate.get(Date.newInstance(2026, 7, 1)));
            System.assertEquals(actualDate, actualDateByInvoiceDate.get(Date.newInstance(2026, 8, 1)));
            System.assertEquals(null, actualDateByInvoiceDate.get(Date.newInstance(2026, 9, 1)));
        }
    }

    @IsTest
    static void updateInvoicedFlag_updatesSelectedRowsOnly() {
        System.runAs(ContractTestDataFactory.getAdminUser()) {
            TestContext context = createHistoryWithInvoiceProducts();
            Date actualDate = Date.newInstance(2026, 6, 10);
            Id targetId = [
                SELECT Id
                FROM InvoiceProduct__c
                WHERE ContractHistory__c = :context.history.Id
                AND InvoiceDate__c = :Date.newInstance(2026, 6, 1)
                LIMIT 1
            ]
            .Id;

            Test.startTest();
            Integer updatedCount = InvoiceProductInvoicedController.updateInvoicedFlag(
                context.history.Id,
                new List<Id>{ targetId },
                true,
                actualDate
            );
            Test.stopTest();

            System.assertEquals(1, updatedCount);
            System.assertEquals(
                actualDate,
                [
                    SELECT ActualInvoiceDate__c
                    FROM InvoiceProduct__c
                    WHERE Id = :targetId
                ]
                .ActualInvoiceDate__c
            );
        }
    }

    private class TestContext {
        public ContractHistory__c history;
    }

    private static TestContext createHistoryWithInvoiceProducts() {
        Account account = ContractTestDataFactory.insertAccount('Invoice Panel Account');
        ContractService__c service = new ContractService__c(
            Name = 'Invoice Panel Service',
            Account__c = account.Id
        );
        insert service;

        ContractHistory__c history = new ContractHistory__c(
            Name = 'Invoice Panel History',
            ContractService__c = service.Id,
            Type__c = 'New',
            historystatus__c = 'Ordered',
            Version__c = 1,
            CurrentTermStartDate__c = Date.newInstance(2026, 6, 1),
            CurrentTermEndDate__c = Date.newInstance(2027, 5, 31)
        );
        insert history;

        Product2 product = ContractTestDataFactory.buildProduct('Invoice Panel Product');
        product.BillingType__c = '継続課金';
        ContractTestDataFactory.insertProduct(product);

        ContractProduct__c contractProduct = new ContractProduct__c(
            ContractHistory__c = history.Id,
            Product__c = product.Id,
            Quantity__c = 1,
            UnitPrice__c = 10000,
            StartDate__c = Date.newInstance(2026, 6, 1),
            Enddate__c = Date.newInstance(2027, 5, 31),
            InvoiceSetting__c = '一括前払',
            BillingType__c = '継続課金',
            Type__c = 'New'
        );
        insert contractProduct;

        insert new List<InvoiceProduct__c>{
            new InvoiceProduct__c(
                ContractHistory__c = history.Id,
                ContractProduct__c = contractProduct.Id,
                StartDate__c = Date.newInstance(2026, 6, 1),
                Enddate__c = Date.newInstance(2026, 6, 30),
                InvoiceDate__c = Date.newInstance(2026, 6, 1),
                Amount__c = 10000,
                invoicetype__c = '一括前払'
            ),
            new InvoiceProduct__c(
                ContractHistory__c = history.Id,
                ContractProduct__c = contractProduct.Id,
                StartDate__c = Date.newInstance(2026, 7, 1),
                Enddate__c = Date.newInstance(2026, 7, 31),
                InvoiceDate__c = Date.newInstance(2026, 7, 1),
                Amount__c = 10000,
                invoicetype__c = '一括前払'
            ),
            new InvoiceProduct__c(
                ContractHistory__c = history.Id,
                ContractProduct__c = contractProduct.Id,
                StartDate__c = Date.newInstance(2026, 8, 1),
                Enddate__c = Date.newInstance(2026, 8, 31),
                InvoiceDate__c = Date.newInstance(2026, 8, 1),
                Amount__c = 10000,
                invoicetype__c = '一括前払'
            ),
            new InvoiceProduct__c(
                ContractHistory__c = history.Id,
                ContractProduct__c = contractProduct.Id,
                StartDate__c = Date.newInstance(2026, 9, 1),
                Enddate__c = Date.newInstance(2026, 9, 30),
                InvoiceDate__c = Date.newInstance(2026, 9, 1),
                Amount__c = 10000,
                invoicetype__c = '一括前払'
            )
        };

        TestContext context = new TestContext();
        context.history = history;
        return context;
    }
}
