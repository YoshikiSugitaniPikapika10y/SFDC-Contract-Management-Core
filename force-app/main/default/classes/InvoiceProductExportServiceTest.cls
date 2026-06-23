@IsTest
private class InvoiceProductExportServiceTest {
    @IsTest
    static void getExportCandidates_returnsOnlyUnexportedLines() {
        System.runAs(ContractTestDataFactory.getAdminUser()) {
            TestContext context = createHistoryWithInvoiceProducts();

            Test.startTest();
            List<InvoiceProductExportService.ExportLine> candidates =
                InvoiceProductExportService.getExportCandidates(
                    context.history.Id,
                    Date.newInstance(2026, 6, 1),
                    Date.newInstance(2026, 8, 31)
                );
            Test.stopTest();

            System.assertEquals(3, candidates.size());
            System.assertEquals(
                Date.newInstance(2026, 6, 1),
                candidates[0].invoiceDate
            );
        }
    }

    @IsTest
    static void markAsExportedByInvoiceDateRange_setsLatestExportDate() {
        System.runAs(ContractTestDataFactory.getAdminUser()) {
            TestContext context = createHistoryWithInvoiceProducts();
            Date exportDate = Date.newInstance(2026, 6, 18);

            Test.startTest();
            InvoiceProductExportService.MarkExportedResult result =
                InvoiceProductExportService.markAsExportedByInvoiceDateRange(
                    context.history.Id,
                    Date.newInstance(2026, 7, 1),
                    Date.newInstance(2026, 8, 31),
                    exportDate
                );
            Test.stopTest();

            System.assertEquals(2, result.updatedCount);
            System.assertEquals(exportDate, result.exportDate);

            List<InvoiceProduct__c> exportedProducts = [
                SELECT LatestExportDate__c, InvoiceDate__c
                FROM InvoiceProduct__c
                WHERE ContractHistory__c = :context.history.Id
                AND LatestExportDate__c != NULL
                AND InvoiceDate__c >= :Date.newInstance(2026, 7, 1)
                AND InvoiceDate__c <= :Date.newInstance(2026, 8, 31)
                ORDER BY InvoiceDate__c ASC
            ];
            System.assertEquals(2, exportedProducts.size());
            System.assertEquals(exportDate, exportedProducts[0].LatestExportDate__c);
        }
    }

    @IsTest
    static void clearExportDate_rejectsInvoicedProducts() {
        System.runAs(ContractTestDataFactory.getAdminUser()) {
            TestContext context = createHistoryWithInvoiceProducts();
            InvoiceProduct__c exportedProduct = [
                SELECT Id
                FROM InvoiceProduct__c
                WHERE ContractHistory__c = :context.history.Id
                AND InvoiceDate__c = :Date.newInstance(2026, 7, 1)
                LIMIT 1
            ];
            exportedProduct.LatestExportDate__c = Date.today();
            exportedProduct.ActualInvoiceDate__c = Date.today();
            update exportedProduct;

            Boolean thrown = false;
            Test.startTest();
            try {
                InvoiceProductExportService.clearExportDate(
                    context.history.Id,
                    new List<Id>{ exportedProduct.Id }
                );
            } catch (InvoiceProductExportService.ExportServiceException ex) {
                thrown = true;
            }
            Test.stopTest();

            System.assertEquals(true, thrown);
        }
    }

    @IsTest
    static void buildExportGroups_groupsByBillingAccountAndInvoiceDate() {
        System.runAs(ContractTestDataFactory.getAdminUser()) {
            TestContext context = createHistoryWithInvoiceProducts();

            Test.startTest();
            List<InvoiceProductExportService.ExportGroup> groups =
                InvoiceProductExportService.buildExportGroups(
                    context.history.Id,
                    null,
                    null
                );
            Test.stopTest();

            System.assertEquals(3, groups.size());
            System.assertEquals(1, groups[0].lineCount);
        }
    }

    private class TestContext {
        public ContractHistory__c history;
    }

    private static TestContext createHistoryWithInvoiceProducts() {
        Account account = ContractTestDataFactory.insertAccount('Export Service Account');
        BillingAccount__c billingAccount = new BillingAccount__c(
            Account__c = account.Id,
            BillingDayOfMonth__c = '25'
        );
        insert billingAccount;

        ContractService__c service = new ContractService__c(
            Name = 'Export Service',
            Account__c = account.Id,
            BiilingAcccount__c = billingAccount.Id
        );
        insert service;

        ContractHistory__c history = new ContractHistory__c(
            Name = 'Export History',
            ContractService__c = service.Id,
            Type__c = 'New',
            historystatus__c = 'Ordered',
            Version__c = 1,
            CurrentTermStartDate__c = Date.newInstance(2026, 6, 1),
            CurrentTermEndDate__c = Date.newInstance(2027, 5, 31)
        );
        insert history;

        Product2 product = ContractTestDataFactory.buildProduct('Export Product');
        product.BillingType__c = '継続課金';
        ContractTestDataFactory.insertProduct(product);

        ContractProduct__c contractProduct = new ContractProduct__c(
            ContractHistory__c = history.Id,
            Product__c = product.Id,
            Quantity__c = 1,
            UnitPrice__c = 10000,
            StartDate__c = Date.newInstance(2026, 6, 1),
            Enddate__c = Date.newInstance(2027, 5, 31),
            InvoiceSetting__c = '月次分割',
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
                invoicetype__c = '月次分割'
            ),
            new InvoiceProduct__c(
                ContractHistory__c = history.Id,
                ContractProduct__c = contractProduct.Id,
                StartDate__c = Date.newInstance(2026, 7, 1),
                Enddate__c = Date.newInstance(2026, 7, 31),
                InvoiceDate__c = Date.newInstance(2026, 7, 1),
                Amount__c = 10000,
                invoicetype__c = '月次分割'
            ),
            new InvoiceProduct__c(
                ContractHistory__c = history.Id,
                ContractProduct__c = contractProduct.Id,
                StartDate__c = Date.newInstance(2026, 8, 1),
                Enddate__c = Date.newInstance(2026, 8, 31),
                InvoiceDate__c = Date.newInstance(2026, 8, 1),
                Amount__c = 10000,
                invoicetype__c = '月次分割'
            ),
            new InvoiceProduct__c(
                ContractHistory__c = history.Id,
                ContractProduct__c = contractProduct.Id,
                StartDate__c = Date.newInstance(2026, 9, 1),
                Enddate__c = Date.newInstance(2026, 9, 30),
                InvoiceDate__c = Date.newInstance(2026, 9, 1),
                Amount__c = 10000,
                invoicetype__c = '月次分割',
                LatestExportDate__c = Date.today()
            )
        };

        TestContext context = new TestContext();
        context.history = history;
        return context;
    }
}
