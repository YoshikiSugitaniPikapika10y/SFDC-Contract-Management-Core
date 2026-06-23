@IsTest
private class ContractHistoryTriggerHandlerTest {
    @IsTest
    static void beforeUpdate_blocksRevertToEstimateWhenInvoicedProductsExist() {
        System.runAs(ContractTestDataFactory.getAdminUser()) {
            Account account = ContractTestDataFactory.insertAccount('Revert Block Account');
            ContractService__c service = new ContractService__c(
                Name = 'Revert Block Service',
                Account__c = account.Id
            );
            insert service;

            ContractHistory__c history = new ContractHistory__c(
                Name = 'Revert Block History',
                ContractService__c = service.Id,
                Type__c = 'Renew',
                historystatus__c = 'Ordered',
                Version__c = 1,
                CurrentTermStartDate__c = Date.newInstance(2026, 6, 1),
                CurrentTermEndDate__c = Date.newInstance(2027, 5, 31)
            );
            insert history;

            Product2 product = ContractTestDataFactory.buildProduct('Revert Block Product');
            product.BillingType__c = '継続課金';
            ContractTestDataFactory.insertProduct(product);

            ContractProduct__c contractProduct = new ContractProduct__c(
                ContractHistory__c = history.Id,
                Product__c = product.Id,
                Quantity__c = 1,
                UnitPrice__c = 8000,
                StartDate__c = Date.newInstance(2026, 6, 1),
                Enddate__c = Date.newInstance(2027, 5, 31),
                InvoiceSetting__c = '一括前払',
                BillingType__c = '継続課金',
                Type__c = 'Renew'
            );
            insert contractProduct;

            insert new InvoiceProduct__c(
                ContractHistory__c = history.Id,
                ContractProduct__c = contractProduct.Id,
                StartDate__c = Date.newInstance(2026, 6, 1),
                Enddate__c = Date.newInstance(2027, 5, 31),
                InvoiceDate__c = Date.newInstance(2026, 6, 1),
                Amount__c = 96000,
                invoicetype__c = '一括前払',
                ActualInvoiceDate__c = Date.today()
            );

            Boolean thrown = false;
            try {
                history.historystatus__c = 'Estimate';
                update history;
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

    @IsTest
    static void beforeUpdate_blocksRevertToEstimateWhenExportedProductsExist() {
        System.runAs(ContractTestDataFactory.getAdminUser()) {
            Account account = ContractTestDataFactory.insertAccount('Revert Export Block Account');
            ContractService__c service = new ContractService__c(
                Name = 'Revert Export Block Service',
                Account__c = account.Id
            );
            insert service;

            ContractHistory__c history = new ContractHistory__c(
                Name = 'Revert Export Block History',
                ContractService__c = service.Id,
                Type__c = 'Renew',
                historystatus__c = 'Ordered',
                Version__c = 1,
                CurrentTermStartDate__c = Date.newInstance(2026, 6, 1),
                CurrentTermEndDate__c = Date.newInstance(2027, 5, 31)
            );
            insert history;

            Product2 product = ContractTestDataFactory.buildProduct('Revert Export Block Product');
            product.BillingType__c = '継続課金';
            ContractTestDataFactory.insertProduct(product);

            ContractProduct__c contractProduct = new ContractProduct__c(
                ContractHistory__c = history.Id,
                Product__c = product.Id,
                Quantity__c = 1,
                UnitPrice__c = 8000,
                StartDate__c = Date.newInstance(2026, 6, 1),
                Enddate__c = Date.newInstance(2027, 5, 31),
                InvoiceSetting__c = '一括前払',
                BillingType__c = '継続課金',
                Type__c = 'Renew'
            );
            insert contractProduct;

            insert new InvoiceProduct__c(
                ContractHistory__c = history.Id,
                ContractProduct__c = contractProduct.Id,
                StartDate__c = Date.newInstance(2026, 6, 1),
                Enddate__c = Date.newInstance(2027, 5, 31),
                InvoiceDate__c = Date.newInstance(2026, 6, 1),
                Amount__c = 96000,
                invoicetype__c = '一括前払',
                ActualInvoiceDate__c = null,
                LatestExportDate__c = Date.newInstance(2026, 6, 1)
            );

            Boolean thrown = false;
            try {
                history.historystatus__c = 'Estimate';
                update history;
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

    @IsTest
    static void beforeUpdate_allowsRevertToEstimateWhenNoInvoicedProducts() {
        System.runAs(ContractTestDataFactory.getAdminUser()) {
            Account account = ContractTestDataFactory.insertAccount('Revert Allow Account');
            ContractService__c service = new ContractService__c(
                Name = 'Revert Allow Service',
                Account__c = account.Id
            );
            insert service;

            ContractHistory__c history = new ContractHistory__c(
                Name = 'Revert Allow History',
                ContractService__c = service.Id,
                Type__c = 'Renew',
                historystatus__c = 'Ordered',
                Version__c = 1,
                CurrentTermStartDate__c = Date.newInstance(2026, 6, 1),
                CurrentTermEndDate__c = Date.newInstance(2027, 5, 31)
            );
            insert history;

            Product2 product = ContractTestDataFactory.buildProduct('Revert Allow Product');
            product.BillingType__c = '継続課金';
            ContractTestDataFactory.insertProduct(product);

            ContractProduct__c contractProduct = new ContractProduct__c(
                ContractHistory__c = history.Id,
                Product__c = product.Id,
                Quantity__c = 1,
                UnitPrice__c = 8000,
                StartDate__c = Date.newInstance(2026, 6, 1),
                Enddate__c = Date.newInstance(2027, 5, 31),
                InvoiceSetting__c = '一括前払',
                BillingType__c = '継続課金',
                Type__c = 'Renew'
            );
            insert contractProduct;

            insert new InvoiceProduct__c(
                ContractHistory__c = history.Id,
                ContractProduct__c = contractProduct.Id,
                StartDate__c = Date.newInstance(2026, 6, 1),
                Enddate__c = Date.newInstance(2027, 5, 31),
                InvoiceDate__c = Date.newInstance(2026, 6, 1),
                Amount__c = 96000,
                invoicetype__c = '一括前払'
            );

            history.historystatus__c = 'Estimate';
            update history;

            ContractHistory__c updated = [
                SELECT historystatus__c
                FROM ContractHistory__c
                WHERE Id = :history.Id
            ];
            System.assertEquals('Estimate', updated.historystatus__c);
        }
    }

    @IsTest
    static void beforeDelete_cascadesUninvoicedInvoiceProductsOnEstimateDelete() {
        System.runAs(ContractTestDataFactory.getAdminUser()) {
            Account account = ContractTestDataFactory.insertAccount('Estimate Delete Account');
            ContractService__c service = new ContractService__c(
                Name = 'Estimate Delete Service',
                Account__c = account.Id
            );
            insert service;

            ContractHistory__c history = new ContractHistory__c(
                Name = 'Estimate Delete History',
                ContractService__c = service.Id,
                Type__c = 'New',
                historystatus__c = 'Estimate',
                Version__c = 1,
                CurrentTermStartDate__c = Date.newInstance(2026, 6, 1),
                CurrentTermEndDate__c = Date.newInstance(2027, 5, 31)
            );
            insert history;

            Product2 product = ContractTestDataFactory.buildProduct('Estimate Delete Product');
            product.BillingType__c = '継続課金';
            ContractTestDataFactory.insertProduct(product);

            ContractProduct__c contractProduct = new ContractProduct__c(
                ContractHistory__c = history.Id,
                Product__c = product.Id,
                Quantity__c = 1,
                UnitPrice__c = 8000,
                StartDate__c = Date.newInstance(2026, 6, 1),
                Enddate__c = Date.newInstance(2027, 5, 31),
                InvoiceSetting__c = '月次分割',
                BillingType__c = '継続課金',
                Type__c = 'New'
            );
            insert contractProduct;

            insert new InvoiceProduct__c(
                ContractHistory__c = history.Id,
                ContractProduct__c = contractProduct.Id,
                StartDate__c = Date.newInstance(2026, 6, 1),
                Enddate__c = Date.newInstance(2026, 6, 30),
                InvoiceDate__c = Date.newInstance(2026, 6, 1),
                Amount__c = 8000,
                invoicetype__c = '月次分割'
            );

            delete history;

            System.assertEquals(
                0,
                [
                    SELECT COUNT()
                    FROM InvoiceProduct__c
                    WHERE ContractHistory__c = :history.Id
                ]
            );
        }
    }
}
