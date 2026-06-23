@IsTest

private class InvoiceProductGenerationServiceTest {

    @IsTest

    static void estimateToOrdered_createsMonthlyInvoiceProducts() {

        System.runAs(ContractTestDataFactory.getAdminUser()) {

            TestData data = createHistoryWithProducts(false);



            Test.startTest();

            data.history.historystatus__c = 'Ordered';

            update data.history;

            Test.stopTest();



            List<InvoiceProduct__c> invoiceProducts = [

                SELECT StartDate__c, Enddate__c, InvoiceDate__c, Amount__c, TaxPercent__c, TaxAmount__c, invoicetype__c

                FROM InvoiceProduct__c

                WHERE ContractHistory__c = :data.history.Id

                ORDER BY StartDate__c ASC

            ];

            System.assertEquals(12, invoiceProducts.size());

            System.assertEquals(

                Date.newInstance(2026, 6, 1),

                invoiceProducts[0].StartDate__c

            );

            System.assertEquals(

                Date.newInstance(2026, 6, 30),

                invoiceProducts[0].Enddate__c

            );

            System.assertEquals(

                Date.newInstance(2026, 6, 1),

                invoiceProducts[0].InvoiceDate__c

            );

            System.assertEquals(8000, invoiceProducts[0].Amount__c);

            System.assertEquals(
                10,
                TaxCalculationUtil.resolveTaxPercent(invoiceProducts[0].TaxPercent__c)
            );

            System.assertEquals(800, invoiceProducts[0].TaxAmount__c);

            System.assertEquals('一括前払', invoiceProducts[0].invoicetype__c);

            for (InvoiceProduct__c invoiceProduct : invoiceProducts) {
                System.assertEquals(
                    Date.newInstance(2026, 6, 1),
                    invoiceProduct.InvoiceDate__c,
                    '前請求は月次分割しても請求日は期間開始日で統一'
                );
            }

            System.assertEquals(

                96000,

                [

                    SELECT SUM(Amount__c) totalAmount

                    FROM InvoiceProduct__c

                    WHERE ContractHistory__c = :data.history.Id

                ][0]

                .get('totalAmount')

            );

        }

    }



    @IsTest

    static void estimateToOrdered_usesContractServiceTaxPercent() {

        System.runAs(ContractTestDataFactory.getAdminUser()) {

            TestData data = createHistoryWithProducts(false);

            update new ContractService__c(

                Id = data.history.ContractService__c,

                TaxPercent__c = 0.08

            );



            Test.startTest();

            data.history.historystatus__c = 'Ordered';

            update data.history;

            Test.stopTest();



            InvoiceProduct__c invoiceProduct = [

                SELECT Amount__c, TaxPercent__c, TaxAmount__c

                FROM InvoiceProduct__c

                WHERE ContractHistory__c = :data.history.Id

                ORDER BY StartDate__c ASC

                LIMIT 1

            ];

            System.assertEquals(8000, invoiceProduct.Amount__c);

            System.assertEquals(
                8,
                TaxCalculationUtil.resolveTaxPercent(invoiceProduct.TaxPercent__c)
            );

            System.assertEquals(640, invoiceProduct.TaxAmount__c);

        }

    }



    @IsTest

    static void estimateToOrdered_createsPositiveInvoiceProductsOnly() {

        System.runAs(ContractTestDataFactory.getAdminUser()) {

            TestData data = createHistoryWithProducts(true);



            Test.startTest();

            data.history.historystatus__c = 'Ordered';

            update data.history;

            Test.stopTest();



            List<InvoiceProduct__c> invoiceProducts = [

                SELECT Amount__c, invoicetype__c

                FROM InvoiceProduct__c

                WHERE ContractHistory__c = :data.history.Id

                ORDER BY Amount__c ASC

            ];

            System.assertEquals(12, invoiceProducts.size());

            System.assertEquals(8000, invoiceProducts[0].Amount__c);

            System.assertEquals('一括前払', invoiceProducts[0].invoicetype__c);

            for (InvoiceProduct__c invoiceProduct : invoiceProducts) {
                System.assert(invoiceProduct.Amount__c > 0);
            }

        }

    }

    @IsTest
    static void estimateToOrdered_copiesQuantityUnitPriceAndUnit() {
        System.runAs(ContractTestDataFactory.getAdminUser()) {
            TestData data = createHistoryWithProducts(false);
            data.recurringProduct.Unit__c = 'ID/月';
            update data.recurringProduct;

            Test.startTest();
            data.history.historystatus__c = 'Ordered';
            update data.history;
            Test.stopTest();

            InvoiceProduct__c invoiceProduct = [
                SELECT
                    Unit__c,
                    Amount__c,
                    ContractProduct__r.Quantity__c,
                    ContractProduct__r.UnitPrice__c
                FROM InvoiceProduct__c
                WHERE ContractHistory__c = :data.history.Id
                ORDER BY StartDate__c ASC
                LIMIT 1
            ];
            System.assertEquals(1, invoiceProduct.ContractProduct__r.Quantity__c);
            System.assertEquals(8000, invoiceProduct.ContractProduct__r.UnitPrice__c);
            System.assertEquals('ID/月', invoiceProduct.Unit__c);
            System.assertEquals(8000, invoiceProduct.Amount__c);
        }
    }

    @IsTest
    static void estimateToOrdered_createsSeparateLinesForDifferentUnit() {
        System.runAs(ContractTestDataFactory.getAdminUser()) {
            TestData data = createHistoryWithProducts(false);
            data.recurringProduct.Unit__c = 'ID/月';
            update data.recurringProduct;

            insert new ContractProduct__c(
                ContractHistory__c = data.history.Id,
                Product__c = data.recurringProduct.Product__c,
                Quantity__c = 1,
                UnitPrice__c = 8000,
                Unit__c = '式/月',
                StartDate__c = data.recurringProduct.StartDate__c,
                Enddate__c = data.recurringProduct.Enddate__c,
                InvoiceSetting__c = '一括前払',
                BillingType__c = '継続課金',
                Type__c = 'Renew'
            );

            Test.startTest();
            data.history.historystatus__c = 'Ordered';
            update data.history;
            Test.stopTest();

            List<InvoiceProduct__c> juneLines = [
                SELECT Unit__c, Amount__c
                FROM InvoiceProduct__c
                WHERE ContractHistory__c = :data.history.Id
                AND StartDate__c = :Date.newInstance(2026, 6, 1)
                ORDER BY Unit__c ASC
            ];
            System.assertEquals(2, juneLines.size());
            System.assertEquals('ID/月', juneLines[0].Unit__c);
            System.assertEquals(8000, juneLines[0].Amount__c);
            System.assertEquals('式/月', juneLines[1].Unit__c);
            System.assertEquals(8000, juneLines[1].Amount__c);
        }
    }

    @IsTest
    static void estimateToOrdered_copiesQuantityAndUnitPrice() {
        System.runAs(ContractTestDataFactory.getAdminUser()) {
            TestData data = createHistoryWithProducts(false);

            Test.startTest();
            data.history.historystatus__c = 'Ordered';
            update data.history;
            Test.stopTest();

            InvoiceProduct__c invoiceProduct = [
                SELECT Amount__c, ContractProduct__r.Quantity__c, ContractProduct__r.UnitPrice__c
                FROM InvoiceProduct__c
                WHERE ContractHistory__c = :data.history.Id
                ORDER BY StartDate__c ASC
                LIMIT 1
            ];
            System.assertEquals(1, invoiceProduct.ContractProduct__r.Quantity__c);
            System.assertEquals(8000, invoiceProduct.ContractProduct__r.UnitPrice__c);
            System.assertEquals(8000, invoiceProduct.Amount__c);
        }
    }

    @IsTest
    static void estimateToOrdered_createsSeparateLinesForDifferentQuantityUnitPrice() {
        System.runAs(ContractTestDataFactory.getAdminUser()) {
            TestData data = createHistoryWithProducts(false);

            insert new ContractProduct__c(
                ContractHistory__c = data.history.Id,
                Product__c = data.recurringProduct.Product__c,
                Quantity__c = 2,
                UnitPrice__c = 8000,
                StartDate__c = data.recurringProduct.StartDate__c,
                Enddate__c = data.recurringProduct.Enddate__c,
                InvoiceSetting__c = '一括前払',
                BillingType__c = '継続課金',
                Type__c = 'Renew'
            );

            Test.startTest();
            data.history.historystatus__c = 'Ordered';
            update data.history;
            Test.stopTest();

            List<InvoiceProduct__c> juneLines = [
                SELECT Amount__c, ContractProduct__r.Quantity__c, ContractProduct__r.UnitPrice__c
                FROM InvoiceProduct__c
                WHERE ContractHistory__c = :data.history.Id
                AND StartDate__c = :Date.newInstance(2026, 6, 1)
                ORDER BY ContractProduct__r.Quantity__c ASC
            ];
            System.assertEquals(2, juneLines.size());
            System.assertEquals(1, juneLines[0].ContractProduct__r.Quantity__c);
            System.assertEquals(8000, juneLines[0].ContractProduct__r.UnitPrice__c);
            System.assertEquals(8000, juneLines[0].Amount__c);
            System.assertEquals(2, juneLines[1].ContractProduct__r.Quantity__c);
            System.assertEquals(8000, juneLines[1].ContractProduct__r.UnitPrice__c);
            System.assertEquals(16000, juneLines[1].Amount__c);
        }
    }



    @IsTest

    static void estimateToOrdered_createsMonthlyInvoiceSettingProducts() {

        System.runAs(ContractTestDataFactory.getAdminUser()) {

            TestData data = createHistoryWithProducts(false);

            Product2 monthlyInvoiceProduct = ContractTestDataFactory.buildProduct(

                'Monthly Invoice Product'

            );

            monthlyInvoiceProduct.UnitName__c = '式';

            monthlyInvoiceProduct.UnitPrice__c = 3000;

            monthlyInvoiceProduct.invoicetype__c = '月次分割';

            monthlyInvoiceProduct.BillingType__c = '継続課金';


            ContractTestDataFactory.insertProduct(monthlyInvoiceProduct);



            insert new ContractProduct__c(

                ContractHistory__c = data.history.Id,

                Product__c = monthlyInvoiceProduct.Id,

                Quantity__c = 1,

                UnitPrice__c = 3000,


                StartDate__c = Date.newInstance(2026, 6, 1),

                Enddate__c = Date.newInstance(2027, 5, 31),

                InvoiceSetting__c = '月次分割',

                BillingType__c = '継続課金',

                Type__c = 'New'

            );



            Test.startTest();

            data.history.historystatus__c = 'Ordered';

            update data.history;

            Test.stopTest();



            List<InvoiceProduct__c> monthlyInvoices = [

                SELECT StartDate__c, Enddate__c, InvoiceDate__c, Amount__c, invoicetype__c

                FROM InvoiceProduct__c

                WHERE ContractHistory__c = :data.history.Id

                AND invoicetype__c = '月次分割'

                ORDER BY StartDate__c ASC

            ];

            System.assertEquals(12, monthlyInvoices.size());

            System.assertEquals(

                Date.newInstance(2026, 6, 1),

                monthlyInvoices[0].InvoiceDate__c

            );

            System.assertEquals(3000, monthlyInvoices[0].Amount__c);

            System.assertEquals(
                Date.newInstance(2026, 7, 1),
                monthlyInvoices[1].InvoiceDate__c,
                '月次請求は各月の開始日が請求日'
            );

            System.assertEquals(

                24,

                [

                    SELECT COUNT()

                    FROM InvoiceProduct__c

                    WHERE ContractHistory__c = :data.history.Id

                ]

            );

        }

    }



    @IsTest

    static void estimateToOrdered_usesMonthlyBillingDayAsInvoiceDate() {

        System.runAs(ContractTestDataFactory.getAdminUser()) {

            Account account = ContractTestDataFactory.insertAccount('Calendar Month Account');

            ContractService__c service = new ContractService__c(

                Name = 'Calendar Month Service',

                Account__c = account.Id

            );

            insert service;

            ContractHistory__c history = new ContractHistory__c(

                Name = 'Calendar Month History',

                ContractService__c = service.Id,

                Type__c = 'New',

                historystatus__c = 'Estimate',

                Version__c = 1,

                CurrentTermStartDate__c = Date.newInstance(2026, 6, 5),

                CurrentTermEndDate__c = Date.newInstance(2027, 6, 4)

            );

            insert history;

            Product2 monthlyProduct = ContractTestDataFactory.buildProduct('Calendar Monthly Product');

            monthlyProduct.UnitName__c = 'ID';

            monthlyProduct.UnitPrice__c = 5000;

            monthlyProduct.invoicetype__c = '月次分割';

            monthlyProduct.BillingType__c = '継続課金';


            ContractTestDataFactory.insertProduct(monthlyProduct);

            insert new ContractProduct__c(

                ContractHistory__c = history.Id,

                Product__c = monthlyProduct.Id,

                Quantity__c = 1,

                UnitPrice__c = 5000,


                StartDate__c = Date.newInstance(2026, 6, 5),

                Enddate__c = Date.newInstance(2027, 6, 4),

                InvoiceSetting__c = '月次分割',

                BillingType__c = '継続課金',

                Type__c = 'New'

            );

            Test.startTest();

            history.historystatus__c = 'Ordered';

            update history;

            Test.stopTest();

            InvoiceProduct__c firstInvoice = [

                SELECT StartDate__c, Enddate__c, InvoiceDate__c

                FROM InvoiceProduct__c

                WHERE ContractHistory__c = :history.Id

                ORDER BY StartDate__c ASC

                LIMIT 1

            ];

            System.assertEquals(Date.newInstance(2026, 6, 5), firstInvoice.StartDate__c);

            System.assertEquals(Date.newInstance(2026, 7, 4), firstInvoice.Enddate__c);

            System.assertEquals(Date.newInstance(2026, 6, 5), firstInvoice.InvoiceDate__c);

        }

    }



    @IsTest

    static void estimateToOrdered_usesAfterBillingInvoiceDate() {

        System.runAs(ContractTestDataFactory.getAdminUser()) {

            TestData data = createHistoryWithProducts(false);

            data.recurringProduct.InvoiceSetting__c = '一括後払';

            update data.recurringProduct;



            Test.startTest();

            data.history.historystatus__c = 'Ordered';

            update data.history;

            Test.stopTest();



            InvoiceProduct__c firstInvoice = [

                SELECT InvoiceDate__c, Enddate__c

                FROM InvoiceProduct__c

                WHERE ContractHistory__c = :data.history.Id

                ORDER BY StartDate__c ASC

                LIMIT 1

            ];

            System.assertEquals(
                Date.newInstance(2027, 6, 1),
                firstInvoice.InvoiceDate__c
            );

            System.assertEquals(

                Date.newInstance(2026, 6, 30),

                firstInvoice.Enddate__c

            );

        }

    }



    @IsTest

    static void estimateToOrdered_createsOneTimeInvoiceProduct() {

        System.runAs(ContractTestDataFactory.getAdminUser()) {

            TestData data = createHistoryWithProducts(false);

            Product2 oneTimeProduct = ContractTestDataFactory.buildProduct('One Time Product');

            oneTimeProduct.UnitName__c = '式';

            oneTimeProduct.UnitPrice__c = 100000;

            oneTimeProduct.BillingType__c = '一回課金';

            ContractTestDataFactory.insertProduct(oneTimeProduct);



            Date startDate = Date.newInstance(2026, 6, 1);

            Date endDate = Date.newInstance(2026, 6, 30);

            insert new ContractProduct__c(

                ContractHistory__c = data.history.Id,

                Product__c = oneTimeProduct.Id,

                Quantity__c = 1,

                UnitPrice__c = 100000,


                StartDate__c = startDate,

                Enddate__c = endDate,

                InvoiceSetting__c = ContractMetadataService.INVOICE_SETTING_POSTPAID_NEXT_DAY,

                BillingType__c = '一回課金',

                Type__c = 'New'

            );



            Test.startTest();

            data.history.historystatus__c = 'Ordered';

            update data.history;

            Test.stopTest();



            InvoiceProduct__c oneTimeInvoice = [

                SELECT StartDate__c, Enddate__c, InvoiceDate__c, Amount__c

                FROM InvoiceProduct__c

                WHERE ContractHistory__c = :data.history.Id

                AND Amount__c = 100000

                LIMIT 1

            ];

            System.assertEquals(startDate, oneTimeInvoice.StartDate__c);

            System.assertEquals(endDate, oneTimeInvoice.Enddate__c);

            System.assertEquals(endDate.addDays(1), oneTimeInvoice.InvoiceDate__c);

        }

    }



    @IsTest

    static void estimateToOrdered_mergesSameProductSamePeriodAmounts() {

        System.runAs(ContractTestDataFactory.getAdminUser()) {

            TestData data = createHistoryWithProducts(false);

            insert new ContractProduct__c(

                ContractHistory__c = data.history.Id,

                Product__c = data.recurringProduct.Product__c,

                Quantity__c = 1,

                UnitPrice__c = 2000,


                StartDate__c = data.recurringProduct.StartDate__c,

                Enddate__c = data.recurringProduct.Enddate__c,

                InvoiceSetting__c = '一括前払',

                BillingType__c = '継続課金',

                Type__c = 'Original'

            );



            Test.startTest();

            data.history.historystatus__c = 'Ordered';

            update data.history;

            Test.stopTest();



            List<InvoiceProduct__c> invoiceProducts = [

                SELECT StartDate__c, Enddate__c, Amount__c

                FROM InvoiceProduct__c

                WHERE ContractHistory__c = :data.history.Id

                ORDER BY StartDate__c ASC

            ];

            System.assertEquals(12, invoiceProducts.size());

            System.assertEquals(8000, invoiceProducts[0].Amount__c);

            System.assertEquals(

                Date.newInstance(2026, 6, 1),

                invoiceProducts[0].StartDate__c

            );

            System.assertEquals(

                Date.newInstance(2026, 6, 30),

                invoiceProducts[0].Enddate__c

            );

            System.assertEquals(

                96000,

                [

                    SELECT SUM(Amount__c) totalAmount

                    FROM InvoiceProduct__c

                    WHERE ContractHistory__c = :data.history.Id

                ][0]

                .get('totalAmount')

            );

        }

    }



    @IsTest

    static void estimateToOrdered_excludesZeroAmountAfterMerge() {

        System.runAs(ContractTestDataFactory.getAdminUser()) {

            TestData data = createHistoryWithProducts(false);

            insert new ContractProduct__c(

                ContractHistory__c = data.history.Id,

                Product__c = data.recurringProduct.Product__c,

                Quantity__c = 1,

                UnitPrice__c = 8000,


                StartDate__c = data.recurringProduct.StartDate__c,

                Enddate__c = data.recurringProduct.Enddate__c,

                InvoiceSetting__c = '一括前払',

                BillingType__c = '継続課金',

                Type__c = 'Original'

            );



            Test.startTest();

            data.history.historystatus__c = 'Ordered';

            update data.history;

            Test.stopTest();



            System.assertEquals(

                12,

                [

                    SELECT COUNT()

                    FROM InvoiceProduct__c

                    WHERE ContractHistory__c = :data.history.Id

                ]

            );

        }

    }



    @IsTest

    static void estimateToOrdered_regeneratesInvoiceProducts() {

        System.runAs(ContractTestDataFactory.getAdminUser()) {

            TestData data = createHistoryWithProducts(false);

            data.history.historystatus__c = 'Ordered';

            update data.history;



            Integer firstCount = [

                SELECT COUNT()

                FROM InvoiceProduct__c

                WHERE ContractHistory__c = :data.history.Id

            ];

            System.assertEquals(12, firstCount);



            data.recurringProduct.UnitPrice__c = 9000;

            update data.recurringProduct;



            Test.startTest();

            data.history.historystatus__c = 'Estimate';

            update data.history;

            data.history.historystatus__c = 'Ordered';

            update data.history;

            Test.stopTest();



            List<InvoiceProduct__c> regeneratedProducts = [

                SELECT Amount__c

                FROM InvoiceProduct__c

                WHERE ContractHistory__c = :data.history.Id

            ];

            System.assertEquals(12, regeneratedProducts.size());

            System.assertEquals(9000, regeneratedProducts[0].Amount__c);

            System.assertEquals(

                108000,

                [

                    SELECT SUM(Amount__c) totalAmount

                    FROM InvoiceProduct__c

                    WHERE ContractHistory__c = :data.history.Id

                ][0]

                .get('totalAmount')

            );

        }

    }

    @IsTest
    static void generateForHistories_preservesExportedInvoiceProducts() {
        System.runAs(ContractTestDataFactory.getAdminUser()) {
            TestData data = createHistoryWithProducts(false);

            data.history.historystatus__c = 'Ordered';
            update data.history;

            InvoiceProduct__c exportedProduct = [
                SELECT Id, Amount__c
                FROM InvoiceProduct__c
                WHERE ContractHistory__c = :data.history.Id
                ORDER BY StartDate__c ASC
                LIMIT 1
            ];
            exportedProduct.LatestExportDate__c = Date.today();
            update exportedProduct;

            data.recurringProduct.UnitPrice__c = 9000;
            update data.recurringProduct;

            Test.startTest();
            InvoiceProductGenerationService.generateForHistories(
                new Set<Id>{ data.history.Id }
            );
            Test.stopTest();

            InvoiceProduct__c preservedProduct = [
                SELECT Amount__c, LatestExportDate__c
                FROM InvoiceProduct__c
                WHERE Id = :exportedProduct.Id
            ];
            System.assertEquals(8000, preservedProduct.Amount__c);
            System.assertNotEquals(null, preservedProduct.LatestExportDate__c);
            System.assertEquals(
                12,
                [
                    SELECT COUNT()
                    FROM InvoiceProduct__c
                    WHERE ContractHistory__c = :data.history.Id
                ]
            );
            System.assertEquals(
                107000,
                [
                    SELECT SUM(Amount__c) totalAmount
                    FROM InvoiceProduct__c
                    WHERE ContractHistory__c = :data.history.Id
                ][0]
                .get('totalAmount')
            );
        }
    }

    @IsTest
    static void estimateToOrdered_setsPaymentScheduledDateFromPaymentTerm() {
        System.runAs(ContractTestDataFactory.getAdminUser()) {
            TestData data = createHistoryWithProducts(false);
            ContractService__c service = [
                SELECT Id, Account__c
                FROM ContractService__c
                WHERE Id = :data.history.ContractService__c
            ];
            BillingAccount__c billingAccount = new BillingAccount__c(
                Account__c = service.Account__c,
                PaymentTerm__c = '翌月15日',
                BillingDayOfMonth__c = '25'
            );
            insert billingAccount;

            service.BiilingAcccount__c = billingAccount.Id;
            update service;

            Test.startTest();
            data.history.historystatus__c = 'Ordered';
            update data.history;
            Test.stopTest();

            InvoiceProduct__c firstInvoice = [
                SELECT InvoiceDate__c, PaymentScheduledDate__c
                FROM InvoiceProduct__c
                WHERE ContractHistory__c = :data.history.Id
                ORDER BY StartDate__c ASC
                LIMIT 1
            ];
            System.assertEquals(
                Date.newInstance(2026, 6, 25),
                firstInvoice.InvoiceDate__c
            );
            System.assertEquals(
                Date.newInstance(2026, 7, 15),
                firstInvoice.PaymentScheduledDate__c
            );
        }
    }

    @IsTest
    static void estimateToOrdered_usesBillingAccountDayForMonthlyInvoiceDate() {
        System.runAs(ContractTestDataFactory.getAdminUser()) {
            Account account = ContractTestDataFactory.insertAccount('Billing Day Account');
            BillingAccount__c billingAccount = new BillingAccount__c(
                Account__c = account.Id,
                BillingDayOfMonth__c = '25'
            );
            insert billingAccount;

            ContractService__c service = new ContractService__c(
                Name = 'Billing Day Service',
                Account__c = account.Id,
                BiilingAcccount__c = billingAccount.Id
            );
            insert service;

            ContractHistory__c history = new ContractHistory__c(
                Name = 'Billing Day History',
                ContractService__c = service.Id,
                Type__c = 'New',
                historystatus__c = 'Estimate',
                Version__c = 1,
                CurrentTermStartDate__c = Date.newInstance(2026, 6, 5),
                CurrentTermEndDate__c = Date.newInstance(2027, 6, 4)
            );
            insert history;

            Product2 monthlyProduct = ContractTestDataFactory.buildProduct(
                'Billing Day Product'
            );
            monthlyProduct.UnitName__c = 'ID';
            monthlyProduct.UnitPrice__c = 5000;
            monthlyProduct.invoicetype__c = '月次分割';
            monthlyProduct.BillingType__c = '継続課金';
            ContractTestDataFactory.insertProduct(monthlyProduct);

            insert new ContractProduct__c(
                ContractHistory__c = history.Id,
                Product__c = monthlyProduct.Id,
                Quantity__c = 1,
                UnitPrice__c = 5000,
                StartDate__c = Date.newInstance(2026, 6, 5),
                Enddate__c = Date.newInstance(2027, 6, 4),
                InvoiceSetting__c = '月次分割',
                BillingType__c = '継続課金',
                Type__c = 'New'
            );

            Test.startTest();
            history.historystatus__c = 'Ordered';
            update history;
            Test.stopTest();

            InvoiceProduct__c firstInvoice = [
                SELECT InvoiceDate__c
                FROM InvoiceProduct__c
                WHERE ContractHistory__c = :history.Id
                ORDER BY StartDate__c ASC
                LIMIT 1
            ];
            System.assertEquals(
                Date.newInstance(2026, 6, 25),
                firstInvoice.InvoiceDate__c
            );
        }
    }

    @IsTest
    static void estimateToOrdered_prepaidUsesBillingAccountDayForBulkInvoiceDate() {
        System.runAs(ContractTestDataFactory.getAdminUser()) {
            Account account = ContractTestDataFactory.insertAccount('Prepaid Billing Day Account');
            BillingAccount__c billingAccount = new BillingAccount__c(
                Account__c = account.Id,
                BillingDayOfMonth__c = '5'
            );
            insert billingAccount;

            ContractService__c service = new ContractService__c(
                Name = 'Prepaid Billing Day Service',
                Account__c = account.Id,
                BiilingAcccount__c = billingAccount.Id
            );
            insert service;

            ContractHistory__c history = new ContractHistory__c(
                Name = 'Prepaid Billing Day History',
                ContractService__c = service.Id,
                Type__c = 'New',
                historystatus__c = 'Estimate',
                Version__c = 1,
                CurrentTermStartDate__c = Date.newInstance(2026, 6, 1),
                CurrentTermEndDate__c = Date.newInstance(2027, 5, 31)
            );
            insert history;

            Product2 product = ContractTestDataFactory.buildProduct('Prepaid Billing Day Product');
            product.UnitName__c = 'ID';
            product.UnitPrice__c = 8000;
            product.invoicetype__c = '一括前払';
            product.BillingType__c = '継続課金';
            ContractTestDataFactory.insertProduct(product);

            insert new ContractProduct__c(
                ContractHistory__c = history.Id,
                Product__c = product.Id,
                Quantity__c = 1,
                UnitPrice__c = 8000,
                StartDate__c = Date.newInstance(2026, 6, 1),
                Enddate__c = Date.newInstance(2027, 5, 31),
                InvoiceSetting__c = '一括前払',
                BillingType__c = '継続課金',
                Type__c = 'New'
            );

            Test.startTest();
            history.historystatus__c = 'Ordered';
            update history;
            Test.stopTest();

            List<InvoiceProduct__c> invoiceProducts = [
                SELECT InvoiceDate__c
                FROM InvoiceProduct__c
                WHERE ContractHistory__c = :history.Id
                ORDER BY StartDate__c ASC
            ];
            System.assertEquals(12, invoiceProducts.size());
            for (InvoiceProduct__c invoiceProduct : invoiceProducts) {
                System.assertEquals(
                    Date.newInstance(2026, 6, 5),
                    invoiceProduct.InvoiceDate__c,
                    '一括前払も請求アカウントの請求基準日を請求日に反映する'
                );
            }
        }
    }

    @IsTest
    static void estimateToOrdered_copiesBillingAccountSnapShots() {
        System.runAs(ContractTestDataFactory.getAdminUser()) {
            Account account = ContractTestDataFactory.insertAccount('Snapshot Account');
            BillingAccount__c billingAccount = new BillingAccount__c(
                Account__c = account.Id,
                PaymentTerm__c = '翌月15日',
                BillingDayOfMonth__c = '25',
                BillingAddressee__c = '株式会社スナップショット 御中',
                BillingEmailTo__c = 'billing-to@example.com',
                BillingEmailCc__c = 'billing-cc@example.com',
                BillingEmailBcc__c = 'billing-bcc@example.com'
            );
            insert billingAccount;

            ContractService__c service = new ContractService__c(
                Name = 'Snapshot Service',
                Account__c = account.Id,
                BiilingAcccount__c = billingAccount.Id
            );
            insert service;

            Product2 product = ContractTestDataFactory.buildProduct('Snapshot Product');
            product.BillingType__c = '継続課金';
            product.invoicetype__c = '一括前払';
            ContractTestDataFactory.insertProduct(product);

            ContractHistory__c history = new ContractHistory__c(
                Name = 'Snapshot History',
                ContractService__c = service.Id,
                Type__c = 'New',
                historystatus__c = 'Estimate',
                Version__c = 1,
                CurrentTermStartDate__c = Date.newInstance(2026, 6, 1),
                CurrentTermEndDate__c = Date.newInstance(2027, 5, 31)
            );
            insert history;

            insert new ContractProduct__c(
                ContractHistory__c = history.Id,
                Product__c = product.Id,
                Quantity__c = 1,
                UnitPrice__c = 8000,
                StartDate__c = Date.newInstance(2026, 6, 1),
                Enddate__c = Date.newInstance(2027, 5, 31),
                InvoiceSetting__c = '一括前払',
                BillingType__c = '継続課金',
                Type__c = 'New'
            );

            Test.startTest();
            history.historystatus__c = 'Ordered';
            update history;
            Test.stopTest();

            InvoiceProduct__c invoiceProduct = [
                SELECT
                    BillingAccountSnapShot__c,
                    PaymentTermSnapShot__c,
                    BillingDayOfMonthSnapShot__c,
                    BillingAddresseeSnapShot__c,
                    BillingEmailToSnapShot__c,
                    BillingEmailCcSnapShot__c,
                    BillingEmailBccSnapShot__c
                FROM InvoiceProduct__c
                WHERE ContractHistory__c = :history.Id
                ORDER BY StartDate__c ASC
                LIMIT 1
            ];
            System.assertEquals(billingAccount.Id, invoiceProduct.BillingAccountSnapShot__c);
            System.assertEquals('翌月15日', invoiceProduct.PaymentTermSnapShot__c);
            System.assertEquals('25', invoiceProduct.BillingDayOfMonthSnapShot__c);
            System.assertEquals(
                '株式会社スナップショット 御中',
                invoiceProduct.BillingAddresseeSnapShot__c
            );
            System.assertEquals(
                'billing-to@example.com',
                invoiceProduct.BillingEmailToSnapShot__c
            );
            System.assertEquals(
                'billing-cc@example.com',
                invoiceProduct.BillingEmailCcSnapShot__c
            );
            System.assertEquals(
                'billing-bcc@example.com',
                invoiceProduct.BillingEmailBccSnapShot__c
            );
        }
    }

    @IsTest
    static void estimateToOrdered_copiesImmediateBillingDaySnapShotAsIs() {
        System.runAs(ContractTestDataFactory.getAdminUser()) {
            Account account = ContractTestDataFactory.insertAccount('Immediate Snapshot Account');
            BillingAccount__c billingAccount = new BillingAccount__c(
                Account__c = account.Id,
                PaymentTerm__c = '当月末',
                BillingDayOfMonth__c = '即日'
            );
            insert billingAccount;

            ContractService__c service = new ContractService__c(
                Name = 'Immediate Snapshot Service',
                Account__c = account.Id,
                BiilingAcccount__c = billingAccount.Id
            );
            insert service;

            Product2 product = ContractTestDataFactory.buildProduct('Immediate Snapshot Product');
            product.BillingType__c = '継続課金';
            product.invoicetype__c = '一括前払';
            ContractTestDataFactory.insertProduct(product);

            ContractHistory__c history = new ContractHistory__c(
                Name = 'Immediate Snapshot History',
                ContractService__c = service.Id,
                Type__c = 'New',
                historystatus__c = 'Estimate',
                Version__c = 1,
                CurrentTermStartDate__c = Date.newInstance(2026, 6, 1),
                CurrentTermEndDate__c = Date.newInstance(2027, 5, 31)
            );
            insert history;

            insert new ContractProduct__c(
                ContractHistory__c = history.Id,
                Product__c = product.Id,
                Quantity__c = 1,
                UnitPrice__c = 8000,
                StartDate__c = Date.newInstance(2026, 6, 1),
                Enddate__c = Date.newInstance(2027, 5, 31),
                InvoiceSetting__c = '一括前払',
                BillingType__c = '継続課金',
                Type__c = 'New'
            );

            Test.startTest();
            history.historystatus__c = 'Ordered';
            update history;
            Test.stopTest();

            InvoiceProduct__c invoiceProduct = [
                SELECT BillingDayOfMonthSnapShot__c
                FROM InvoiceProduct__c
                WHERE ContractHistory__c = :history.Id
                LIMIT 1
            ];
            System.assertEquals(
                '即日',
                invoiceProduct.BillingDayOfMonthSnapShot__c
            );
        }
    }

    private class TestData {

        public ContractHistory__c history;

        public ContractProduct__c recurringProduct;

    }



    private static TestData createHistoryWithProducts(Boolean includeOriginal) {

        Account account = ContractTestDataFactory.insertAccount('Test Account');



        ContractService__c service = new ContractService__c(

            Name = 'Invoice Test Service',

            Account__c = account.Id

        );

        insert service;



        TestData data = new TestData();

        data.history = new ContractHistory__c(

            Name = 'Invoice Test History',

            ContractService__c = service.Id,

            Type__c = 'Renew',

            historystatus__c = 'Estimate',

            Version__c = 1,

            CurrentTermStartDate__c = Date.newInstance(2026, 6, 1),

            CurrentTermEndDate__c = Date.newInstance(2027, 5, 31)

        );

        insert data.history;



        Product2 recurringProduct = ContractTestDataFactory.buildProduct('Recurring Product');

        recurringProduct.UnitName__c = 'ID';

        recurringProduct.UnitPrice__c = 8000;

        recurringProduct.invoicetype__c = '一括前払';

        recurringProduct.BillingType__c = '継続課金';


        ContractTestDataFactory.insertProduct(recurringProduct);



        Date termStart = Date.newInstance(2026, 6, 1);

        Date termEnd = Date.newInstance(2027, 5, 31);

        data.recurringProduct = new ContractProduct__c(

            ContractHistory__c = data.history.Id,

            Product__c = recurringProduct.Id,

            Quantity__c = 1,

            UnitPrice__c = 8000,


            StartDate__c = termStart,

            Enddate__c = termEnd,

            InvoiceSetting__c = '一括前払',

            BillingType__c = '継続課金',

            Type__c = 'Renew'

        );

        insert data.recurringProduct;



        if (includeOriginal) {

            Product2 originalProduct = ContractTestDataFactory.buildProduct('Original Product');

            originalProduct.UnitName__c = '式';

            originalProduct.UnitPrice__c = 5000;

            originalProduct.invoicetype__c = '一括前払';

            originalProduct.BillingType__c = '継続課金';


            ContractTestDataFactory.insertProduct(originalProduct);



            insert new ContractProduct__c(

                ContractHistory__c = data.history.Id,

                Product__c = originalProduct.Id,

                Quantity__c = 1,

                UnitPrice__c = 5000,


                StartDate__c = termStart,

                Enddate__c = termEnd,

                InvoiceSetting__c = '一括前払',

                BillingType__c = '継続課金',

                Type__c = 'Original'

            );

        }



        return data;

    }

    @IsTest
    static void changeToOrdered_skipsOriginalInvoiceProductsAndUsesEffectiveDate() {
        System.runAs(ContractTestDataFactory.getAdminUser()) {
            Account account = ContractTestDataFactory.insertAccount('Change Invoice Account');
            ContractService__c service = new ContractService__c(
                Name = 'Change Invoice Service',
                Account__c = account.Id
            );
            insert service;

            Date termStart = Date.newInstance(2026, 6, 1);
            Date termEnd = Date.newInstance(2027, 5, 31);
            Date effectiveDate = Date.newInstance(2026, 10, 1);

            ContractHistory__c priorHistory = new ContractHistory__c(
                Name = 'Change Invoice Prior',
                ContractService__c = service.Id,
                Type__c = 'New',
                historystatus__c = 'Ordered',
                Version__c = 1,
                CurrentTermStartDate__c = termStart,
                CurrentTermEndDate__c = termEnd,
                EffectiveDate__c = termStart
            );
            insert priorHistory;

            Product2 product = ContractTestDataFactory.buildProduct('Change Invoice Product');
            product.BillingType__c = '継続課金';
            ContractTestDataFactory.insertProduct(product);

            ContractProduct__c priorContractProduct = new ContractProduct__c(
                ContractHistory__c = priorHistory.Id,
                Product__c = product.Id,
                Quantity__c = 1,
                UnitPrice__c = 8000,
                StartDate__c = termStart,
                Enddate__c = termEnd,
                InvoiceSetting__c = '一括前払',
                BillingType__c = '継続課金',
                Type__c = 'New'
            );
            insert priorContractProduct;

            InvoiceProductGenerationService.generateForHistories(
                new Set<Id>{ priorHistory.Id }
            );
            for (InvoiceProduct__c priorInvoice : [
                SELECT Id
                FROM InvoiceProduct__c
                WHERE ContractHistory__c = :priorHistory.Id
            ]) {
                priorInvoice.ActualInvoiceDate__c = Date.today();
            }
            update [
                SELECT Id, ActualInvoiceDate__c
                FROM InvoiceProduct__c
                WHERE ContractHistory__c = :priorHistory.Id
            ];

            ContractHistory__c changeHistory = new ContractHistory__c(
                Name = 'Change Invoice History',
                ContractService__c = service.Id,
                Type__c = 'Change',
                historystatus__c = 'Estimate',
                Version__c = 2,
                CurrentTermStartDate__c = termStart,
                CurrentTermEndDate__c = termEnd,
                EffectiveDate__c = effectiveDate,
                PreviousHistory__c = priorHistory.Id
            );
            insert changeHistory;

            insert new ContractProduct__c(
                ContractHistory__c = changeHistory.Id,
                Product__c = product.Id,
                Quantity__c = 1,
                UnitPrice__c = 8000,
                StartDate__c = termStart,
                Enddate__c = termEnd,
                InvoiceSetting__c = '一括前払',
                BillingType__c = '継続課金',
                Type__c = 'Original',
                PreviousContractProduct__c = priorContractProduct.Id
            );

            insert new ContractProduct__c(
                ContractHistory__c = changeHistory.Id,
                Product__c = product.Id,
                Quantity__c = 2,
                UnitPrice__c = 8000,
                StartDate__c = termStart,
                Enddate__c = termEnd,
                InvoiceSetting__c = '一括前払',
                BillingType__c = '継続課金',
                Type__c = 'Remake',
                PreviousContractProduct__c = priorContractProduct.Id
            );

            Test.startTest();
            changeHistory.historystatus__c = 'Ordered';
            update changeHistory;
            Test.stopTest();

            System.assertEquals(
                12,
                [
                    SELECT COUNT()
                    FROM InvoiceProduct__c
                    WHERE ContractHistory__c = :priorHistory.Id
                ]
            );
            System.assertEquals(
                0,
                [
                    SELECT COUNT()
                    FROM InvoiceProduct__c
                    WHERE ContractHistory__c = :priorHistory.Id
                    AND Amount__c < 0
                ]
            );

            List<InvoiceProduct__c> changeInvoices = [
                SELECT Amount__c, Quantity__c, UnitPrice__c, StartDate__c, Enddate__c, InvoiceDate__c, invoicetype__c
                FROM InvoiceProduct__c
                WHERE ContractHistory__c = :changeHistory.Id
                ORDER BY StartDate__c ASC, Amount__c ASC
            ];
            System.assertEquals(16, changeInvoices.size(), '±2行×8ヶ月');
            System.assertEquals(-8000, changeInvoices[0].Amount__c);
            System.assertEquals(1, changeInvoices[0].Quantity__c);
            System.assertEquals(8000, changeInvoices[0].UnitPrice__c);
            System.assertEquals('一括前払', changeInvoices[0].invoicetype__c);
            System.assertEquals(16000, changeInvoices[1].Amount__c);
            System.assertEquals(2, changeInvoices[1].Quantity__c);
            System.assertEquals(8000, changeInvoices[1].UnitPrice__c);
            System.assertEquals(effectiveDate, changeInvoices[0].StartDate__c);
            System.assertEquals(
                Date.newInstance(2026, 10, 31),
                changeInvoices[0].Enddate__c
            );
            System.assertEquals(
                effectiveDate,
                changeInvoices[0].InvoiceDate__c,
                '反転行も新規行と同じ請求日'
            );
            System.assertEquals(
                effectiveDate,
                changeInvoices[1].InvoiceDate__c,
                'Change初回請求期間は有効日を請求日にする'
            );
            System.assertEquals(
                64000,
                [
                    SELECT SUM(Amount__c) totalAmount
                    FROM InvoiceProduct__c
                    WHERE ContractHistory__c = :changeHistory.Id
                ][0]
                .get('totalAmount')
            );
        }
    }

    @IsTest
    static void changeToOrdered_createsOneTimeAddonInvoiceProduct() {
        System.runAs(ContractTestDataFactory.getAdminUser()) {
            Account account = ContractTestDataFactory.insertAccount('Change One Time Account');
            ContractService__c service = new ContractService__c(
                Name = 'Change One Time Service',
                Account__c = account.Id
            );
            insert service;

            Date termStart = Date.newInstance(2026, 6, 1);
            Date termEnd = Date.newInstance(2027, 5, 31);
            Date effectiveDate = Date.newInstance(2026, 10, 1);

            ContractHistory__c priorHistory = new ContractHistory__c(
                Name = 'Change One Time Prior',
                ContractService__c = service.Id,
                Type__c = 'New',
                historystatus__c = 'Ordered',
                Version__c = 1,
                CurrentTermStartDate__c = termStart,
                CurrentTermEndDate__c = termEnd,
                EffectiveDate__c = termStart
            );
            insert priorHistory;

            Product2 recurringProduct = ContractTestDataFactory.buildProduct(
                'Change One Time Recurring'
            );
            recurringProduct.BillingType__c = '継続課金';
            ContractTestDataFactory.insertProduct(recurringProduct);

            ContractProduct__c priorContractProduct = new ContractProduct__c(
                ContractHistory__c = priorHistory.Id,
                Product__c = recurringProduct.Id,
                Quantity__c = 1,
                UnitPrice__c = 8000,
                StartDate__c = termStart,
                Enddate__c = termEnd,
                InvoiceSetting__c = '一括前払',
                BillingType__c = '継続課金',
                Type__c = 'New'
            );
            insert priorContractProduct;

            InvoiceProductGenerationService.generateForHistories(
                new Set<Id>{ priorHistory.Id }
            );

            Product2 oneTimeProduct = ContractTestDataFactory.buildProduct(
                'Change One Time Addon'
            );
            oneTimeProduct.BillingType__c = '一回課金';
            ContractTestDataFactory.insertProduct(oneTimeProduct);

            ContractHistory__c changeHistory = new ContractHistory__c(
                Name = 'Change One Time History',
                ContractService__c = service.Id,
                Type__c = 'Change',
                historystatus__c = 'Estimate',
                Version__c = 2,
                CurrentTermStartDate__c = termStart,
                CurrentTermEndDate__c = termEnd,
                EffectiveDate__c = effectiveDate,
                PreviousHistory__c = priorHistory.Id
            );
            insert changeHistory;

            insert new ContractProduct__c(
                ContractHistory__c = changeHistory.Id,
                Product__c = recurringProduct.Id,
                Quantity__c = 1,
                UnitPrice__c = 8000,
                StartDate__c = termStart,
                Enddate__c = termEnd,
                InvoiceSetting__c = '一括前払',
                BillingType__c = '継続課金',
                Type__c = 'Original',
                PreviousContractProduct__c = priorContractProduct.Id
            );

            insert new ContractProduct__c(
                ContractHistory__c = changeHistory.Id,
                Product__c = recurringProduct.Id,
                Quantity__c = 1,
                UnitPrice__c = 8000,
                StartDate__c = effectiveDate,
                Enddate__c = termEnd,
                InvoiceSetting__c = '一括前払',
                BillingType__c = '継続課金',
                Type__c = 'Remake',
                PreviousContractProduct__c = priorContractProduct.Id
            );

            Date addonStart = Date.newInstance(2026, 10, 15);
            Date addonEnd = Date.newInstance(2026, 10, 31);
            insert new ContractProduct__c(
                ContractHistory__c = changeHistory.Id,
                Product__c = oneTimeProduct.Id,
                Quantity__c = 1,
                UnitPrice__c = 50000,
                StartDate__c = addonStart,
                Enddate__c = addonEnd,
                InvoiceSetting__c = ContractMetadataService.INVOICE_SETTING_POSTPAID_NEXT_DAY,
                BillingType__c = '一回課金',
                Type__c = 'New'
            );

            Test.startTest();
            changeHistory.historystatus__c = 'Ordered';
            update changeHistory;
            Test.stopTest();

            List<InvoiceProduct__c> addonInvoices = [
                SELECT Amount__c, StartDate__c, Enddate__c
                FROM InvoiceProduct__c
                WHERE ContractHistory__c = :changeHistory.Id
                AND ContractProduct__r.Product__c = :oneTimeProduct.Id
            ];
            System.assertEquals(1, addonInvoices.size(), 'Changeの一回課金追加商品に請求商品が1件生成される');
            System.assertEquals(50000, addonInvoices[0].Amount__c);
            System.assertEquals(addonStart, addonInvoices[0].StartDate__c);
            System.assertEquals(addonEnd, addonInvoices[0].Enddate__c);
        }
    }

    @IsTest
    static void renewToOrdered_usesPastInvoiceProductSampleForDiffReversal() {
        System.runAs(ContractTestDataFactory.getAdminUser()) {
            Account account = ContractTestDataFactory.insertAccount('Renew Diff Account');
            ContractService__c service = new ContractService__c(
                Name = 'Renew Diff Service',
                Account__c = account.Id
            );
            insert service;

            Date priorStart = Date.newInstance(2025, 6, 1);
            Date priorEnd = Date.newInstance(2026, 5, 31);
            Date renewStart = Date.newInstance(2026, 6, 1);
            Date renewEnd = Date.newInstance(2027, 5, 31);

            ContractHistory__c priorHistory = new ContractHistory__c(
                Name = 'Renew Diff Prior',
                ContractService__c = service.Id,
                Type__c = 'New',
                historystatus__c = 'Ordered',
                Version__c = 1,
                CurrentTermStartDate__c = priorStart,
                CurrentTermEndDate__c = priorEnd,
                EffectiveDate__c = priorStart
            );
            insert priorHistory;

            Product2 product = ContractTestDataFactory.buildProduct('Renew Diff Product');
            product.BillingType__c = '継続課金';
            product.invoicetype__c = '一括前払';
            ContractTestDataFactory.insertProduct(product);

            ContractProduct__c priorContractProduct = new ContractProduct__c(
                ContractHistory__c = priorHistory.Id,
                Product__c = product.Id,
                Quantity__c = 1,
                UnitPrice__c = 8000,
                StartDate__c = priorStart,
                Enddate__c = priorEnd,
                InvoiceSetting__c = '一括前払',
                BillingType__c = '継続課金',
                Type__c = 'New'
            );
            insert priorContractProduct;

            InvoiceProductGenerationService.generateForHistories(
                new Set<Id>{ priorHistory.Id }
            );

            ContractHistory__c renewHistory = new ContractHistory__c(
                Name = 'Renew Diff History',
                ContractService__c = service.Id,
                Type__c = 'Renew',
                historystatus__c = 'Estimate',
                Version__c = 2,
                CurrentTermStartDate__c = renewStart,
                CurrentTermEndDate__c = renewEnd,
                EffectiveDate__c = renewStart,
                PreviousHistory__c = priorHistory.Id
            );
            insert renewHistory;

            insert new ContractProduct__c(
                ContractHistory__c = renewHistory.Id,
                Product__c = product.Id,
                Quantity__c = 1,
                UnitPrice__c = 8000,
                StartDate__c = renewStart,
                Enddate__c = renewEnd,
                InvoiceSetting__c = '一括前払',
                BillingType__c = '継続課金',
                Type__c = 'Renew',
                PreviousContractProduct__c = priorContractProduct.Id
            );

            Test.startTest();
            renewHistory.historystatus__c = 'Ordered';
            update renewHistory;
            Test.stopTest();

            List<InvoiceProduct__c> renewInvoices = [
                SELECT Quantity__c, UnitPrice__c, Amount__c
                FROM InvoiceProduct__c
                WHERE ContractHistory__c = :renewHistory.Id
            ];
            System.assert(
                !renewInvoices.isEmpty(),
                'Renew受注時に請求商品が生成されること'
            );
            for (InvoiceProduct__c invoiceProduct : renewInvoices) {
                System.assertNotEquals(null, invoiceProduct.Quantity__c);
                System.assertNotEquals(null, invoiceProduct.UnitPrice__c);
            }
        }
    }

    @IsTest
    static void changeToOrdered_usesBillingDayAfterFirstPeriod() {
        System.runAs(ContractTestDataFactory.getAdminUser()) {
            Account account = ContractTestDataFactory.insertAccount('Change Billing Day Account');
            BillingAccount__c billingAccount = new BillingAccount__c(
                Account__c = account.Id,
                BillingDayOfMonth__c = '15'
            );
            insert billingAccount;

            ContractService__c service = new ContractService__c(
                Name = 'Change Billing Day Service',
                Account__c = account.Id,
                BiilingAcccount__c = billingAccount.Id
            );
            insert service;

            Date termStart = Date.newInstance(2026, 6, 1);
            Date termEnd = Date.newInstance(2027, 5, 31);
            Date effectiveDate = Date.newInstance(2026, 10, 10);

            ContractHistory__c priorHistory = new ContractHistory__c(
                Name = 'Change Billing Day Prior',
                ContractService__c = service.Id,
                Type__c = 'New',
                historystatus__c = 'Ordered',
                Version__c = 1,
                CurrentTermStartDate__c = termStart,
                CurrentTermEndDate__c = termEnd,
                EffectiveDate__c = termStart
            );
            insert priorHistory;

            Product2 product = ContractTestDataFactory.buildProduct('Change Billing Day Product');
            product.BillingType__c = '継続課金';
            product.invoicetype__c = '月次分割';
            ContractTestDataFactory.insertProduct(product);

            ContractProduct__c priorContractProduct = new ContractProduct__c(
                ContractHistory__c = priorHistory.Id,
                Product__c = product.Id,
                Quantity__c = 1,
                UnitPrice__c = 8000,
                StartDate__c = termStart,
                Enddate__c = termEnd,
                InvoiceSetting__c = '月次分割',
                BillingType__c = '継続課金',
                Type__c = 'New'
            );
            insert priorContractProduct;

            ContractHistory__c changeHistory = new ContractHistory__c(
                Name = 'Change Billing Day History',
                ContractService__c = service.Id,
                Type__c = 'Change',
                historystatus__c = 'Estimate',
                Version__c = 2,
                CurrentTermStartDate__c = termStart,
                CurrentTermEndDate__c = termEnd,
                EffectiveDate__c = effectiveDate,
                PreviousHistory__c = priorHistory.Id
            );
            insert changeHistory;

            insert new ContractProduct__c(
                ContractHistory__c = changeHistory.Id,
                Product__c = product.Id,
                Quantity__c = 2,
                UnitPrice__c = 8000,
                StartDate__c = termStart,
                Enddate__c = termEnd,
                InvoiceSetting__c = '月次分割',
                BillingType__c = '継続課金',
                Type__c = 'Remake',
                PreviousContractProduct__c = priorContractProduct.Id
            );

            Test.startTest();
            changeHistory.historystatus__c = 'Ordered';
            update changeHistory;
            Test.stopTest();

            List<InvoiceProduct__c> changeInvoices = [
                SELECT InvoiceDate__c, StartDate__c
                FROM InvoiceProduct__c
                WHERE ContractHistory__c = :changeHistory.Id
                ORDER BY StartDate__c ASC
            ];
            System.assert(changeInvoices.size() >= 2);
            System.assertEquals(
                Date.newInstance(2026, 10, 15),
                changeInvoices[0].InvoiceDate__c,
                'Change初回も請求アカウントの毎月指定日'
            );
            System.assertEquals(
                Date.newInstance(2026, 11, 15),
                changeInvoices[1].InvoiceDate__c,
                '2ヶ月目以降も請求アカウントの毎月指定日'
            );
        }
    }

}