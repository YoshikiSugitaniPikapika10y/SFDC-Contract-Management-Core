@IsTest
private class ContractProductTriggerHandlerTest {
    @IsTest
    static void populateAccountFromContractHistory_setsAccountFromService() {
        System.runAs(ContractTestDataFactory.getAdminUser()) {
            Account account = ContractTestDataFactory.insertAccount('Trigger Test Account');
            ContractService__c service = new ContractService__c(
                Name = 'Trigger Test Service',
                Account__c = account.Id
            );
            insert service;

            ContractHistory__c history = new ContractHistory__c(
                Name = 'Trigger Test History',
                ContractService__c = service.Id,
                Type__c = 'New',
                historystatus__c = 'Estimate',
                Version__c = 1,
                CurrentTermStartDate__c = Date.newInstance(2026, 6, 1),
                CurrentTermEndDate__c = Date.newInstance(2027, 5, 31)
            );
            insert history;

            Product2 product = ContractTestDataFactory.buildProduct('Trigger Test Product');
            product.BillingType__c = '継続課金';
            ContractTestDataFactory.insertProduct(product);

            ContractProduct__c contractProduct = new ContractProduct__c(
                ContractHistory__c = history.Id,
                Product__c = product.Id,
                Quantity__c = 1,
                UnitPrice__c = 1000,
                StartDate__c = Date.newInstance(2026, 6, 1),
                Enddate__c = Date.newInstance(2027, 5, 31),
                InvoiceSetting__c = '一括前払',
                BillingType__c = '継続課金',
                Type__c = 'New'
            );
            insert contractProduct;

            contractProduct = [
                SELECT Account__c
                FROM ContractProduct__c
                WHERE Id = :contractProduct.Id
            ];
            System.assertEquals(account.Id, contractProduct.Account__c);
        }
    }

    @IsTest
    static void populateAmount_setsRecurringMonthlyTotal() {
        System.runAs(ContractTestDataFactory.getAdminUser()) {
            Account account = ContractTestDataFactory.insertAccount('Amount Trigger Account');
            ContractService__c service = new ContractService__c(
                Name = 'Amount Trigger Service',
                Account__c = account.Id
            );
            insert service;

            ContractHistory__c history = new ContractHistory__c(
                Name = 'Amount Trigger History',
                ContractService__c = service.Id,
                Type__c = 'New',
                historystatus__c = 'Estimate',
                Version__c = 1,
                CurrentTermStartDate__c = Date.newInstance(2026, 4, 1),
                CurrentTermEndDate__c = Date.newInstance(2027, 3, 31)
            );
            insert history;

            Product2 product = ContractTestDataFactory.buildProduct('Amount Trigger Product');
            product.BillingType__c = '継続課金';
            ContractTestDataFactory.insertProduct(product);

            ContractProduct__c contractProduct = new ContractProduct__c(
                ContractHistory__c = history.Id,
                Product__c = product.Id,
                Quantity__c = 1,
                UnitPrice__c = 12000,
                StartDate__c = Date.newInstance(2026, 4, 1),
                Enddate__c = Date.newInstance(2027, 3, 31),
                InvoiceSetting__c = '一括前払',
                BillingType__c = '継続課金',
                Type__c = 'New'
            );
            insert contractProduct;

            contractProduct = [
                SELECT Amount__c
                FROM ContractProduct__c
                WHERE Id = :contractProduct.Id
            ];
            System.assertEquals(144000, contractProduct.Amount__c);

            history = [
                SELECT DeltaAmountSum__c
                FROM ContractHistory__c
                WHERE Id = :history.Id
            ];
            System.assertEquals(144000, history.DeltaAmountSum__c);
        }
    }

    @IsTest
    static void populateAmount_originalIsNegative() {
        System.runAs(ContractTestDataFactory.getAdminUser()) {
            Account account = ContractTestDataFactory.insertAccount('Original Amount Account');
            ContractService__c service = new ContractService__c(
                Name = 'Original Amount Service',
                Account__c = account.Id
            );
            insert service;

            ContractHistory__c history = new ContractHistory__c(
                Name = 'Original Amount History',
                ContractService__c = service.Id,
                Type__c = 'Change',
                historystatus__c = 'Estimate',
                Version__c = 2,
                CurrentTermStartDate__c = Date.newInstance(2026, 4, 1),
                CurrentTermEndDate__c = Date.newInstance(2027, 3, 31)
            );
            insert history;

            Product2 product = ContractTestDataFactory.buildProduct('Original Amount Product');
            product.BillingType__c = '継続課金';
            ContractTestDataFactory.insertProduct(product);

            insert new ContractProduct__c(
                ContractHistory__c = history.Id,
                Product__c = product.Id,
                Quantity__c = 1,
                UnitPrice__c = 12000,
                StartDate__c = Date.newInstance(2026, 4, 1),
                Enddate__c = Date.newInstance(2027, 3, 31),
                InvoiceSetting__c = '一括前払',
                BillingType__c = '継続課金',
                Type__c = 'Original'
            );

            ContractProduct__c originalProduct = [
                SELECT Amount__c
                FROM ContractProduct__c
                WHERE ContractHistory__c = :history.Id
                LIMIT 1
            ];
            System.assertEquals(-144000, originalProduct.Amount__c);
        }
    }
}
