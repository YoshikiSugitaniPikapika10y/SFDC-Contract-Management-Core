@IsTest
private class EstimateCreateControllerTest {
    @TestSetup
    static void setupAccess() {
        ContractTestDataFactory.initTestContext();
    }

    @IsTest
    static void getProductDefaults_returnsValues() {
        System.runAs(ContractTestDataFactory.getAdminUser()) {
            Product2 product = ContractTestDataFactory.buildProduct('Test Product');
            product.UnitName__c = '式';
            product.UnitPrice__c = 12000;
            product.invoicetype__c = '一括前払';
            product.BillingType__c = '継続課金';
            ContractTestDataFactory.insertProduct(product);

            EstimateCreateController.ProductDefaultDto result =
                EstimateCreateController.getProductDefaults(product.Id);

            System.assertNotEquals(null, result);
            System.assertEquals('式', result.unitName);
            System.assertEquals(12000, result.unitPrice);
            System.assertEquals('一括前払', result.invoiceType);
            System.assertEquals('式・月', result.displayUnit);
        }
    }

    @IsTest
    static void getProductDefaults_nullId_returnsNull() {
        System.runAs(ContractTestDataFactory.getAdminUser()) {
            System.assertEquals(null, EstimateCreateController.getProductDefaults(null));
        }
    }

    @IsTest
    static void getEstimateRemarkMasterText_returnsRemarkText() {
        System.runAs(ContractTestDataFactory.getAdminUser()) {
            EstimateNoteMaster__c master = new EstimateNoteMaster__c(
                Name = 'Standard Remark',
                NoteText__c = '見積備考のサンプル文'
            );
            insert master;

            System.assertEquals(
                '見積備考のサンプル文',
                EstimateCreateController.getEstimateRemarkMasterText(master.Id)
            );
        }
    }

    @IsTest
    static void getEstimateRemarkMasterText_nullId_returnsEmpty() {
        System.runAs(ContractTestDataFactory.getAdminUser()) {
            System.assertEquals('', EstimateCreateController.getEstimateRemarkMasterText(null));
        }
    }

    @IsTest
    static void saveEstimate_createsRecordsForNewType() {
        System.runAs(ContractTestDataFactory.getAdminUser()) {
        Account testAccount = ContractTestDataFactory.insertAccount('Test Account');
        Opportunity opportunity = ContractTestDataFactory.insertOpportunity(
            testAccount.Id,
            'Test Opportunity'
        );

        Product2 product = ContractTestDataFactory.buildProduct('Save Test Product');
        product.UnitName__c = '式';
        product.UnitPrice__c = 10000;
        product.invoicetype__c = '一括前払';
        product.BillingType__c = '継続課金';
        ContractTestDataFactory.insertProduct(product);

        EstimateCreateController.ProductLineItem lineItem = new EstimateCreateController.ProductLineItem();
        lineItem.productId = product.Id;
        lineItem.quantity = 2;
        lineItem.unitPrice = 10000;
        lineItem.amount = 20000;
        lineItem.startDate = String.valueOf(Date.today());
        lineItem.endDate = String.valueOf(Date.today().addMonths(12).addDays(-1));
        lineItem.invoiceType = '一括前払';
        lineItem.unit = '式';
        lineItem.billingType = '継続課金';
        lineItem.billingCycle = '月';
        lineItem.recordType = 'New';

        String productsJson = JSON.serialize(
            new List<EstimateCreateController.ProductLineItem>{ lineItem }
        );

        Test.startTest();
        EstimateCreateController.EstimateSaveResult result = EstimateCreateController.saveEstimate(
            opportunity.Id,
            'New',
            'Test Service',
            'Test History',
            null,
            null,
            String.valueOf(Date.today()),
            String.valueOf(Date.today().addMonths(12).addDays(-1)),
            String.valueOf(Date.today()),
            String.valueOf(Date.today()),
            productsJson,
            null,
            null,
            null,
            null
        );
        Test.stopTest();

        System.assertNotEquals(null, result.contractServiceId);
        System.assertNotEquals(null, result.contractHistoryId);
        System.assertEquals(1, result.contractProductIds.size());

        ContractService__c service = [
            SELECT Name, Account__c, FirstOrderedHistory__c, LatestOrderedHistory__c
            FROM ContractService__c
            WHERE Id = :result.contractServiceId
        ];
        System.assertEquals('Test Service', service.Name);
        System.assertEquals(opportunity.AccountId, service.Account__c);
        System.assertEquals(null, service.FirstOrderedHistory__c);
        System.assertEquals(null, service.LatestOrderedHistory__c);

        ContractHistory__c history = [
            SELECT
                Name,
                Type__c,
                historystatus__c,
                Version__c,
                Opportunity__c,
                ContractService__c,
                PreviousHistory__c,
                EstimateNoteMaster__c,
                Note__c
            FROM ContractHistory__c
            WHERE Id = :result.contractHistoryId
        ];
        System.assertEquals('Test History', history.Name);
        System.assertEquals('New', history.Type__c);
        System.assertEquals('Estimate', history.historystatus__c);
        System.assertEquals(1, history.Version__c);
        System.assertEquals(opportunity.Id, history.Opportunity__c);
        System.assertEquals(result.contractServiceId, history.ContractService__c);
        System.assertEquals(null, history.PreviousHistory__c);

        ContractProduct__c contractProduct = [
            SELECT
                Product__c,
                Quantity__c,
                UnitPrice__c,
                InvoiceSetting__c,
                ContractHistory__c,
                Type__c,
                Unit__c,
                BillingType__c,
                Amount__c,
                StartDate__c,
                Enddate__c
            FROM ContractProduct__c
            WHERE Id = :result.contractProductIds[0]
        ];
        System.assertEquals(product.Id, contractProduct.Product__c);
        System.assertEquals(2, contractProduct.Quantity__c);
        System.assertEquals(10000, contractProduct.UnitPrice__c);
        System.assertEquals(result.contractHistoryId, contractProduct.ContractHistory__c);
        System.assertEquals('New', contractProduct.Type__c);
        System.assertEquals('式・月', contractProduct.Unit__c);
        System.assertEquals('継続課金', contractProduct.BillingType__c);
        System.assertEquals(
            ContractProductAmountUtil.calculateSignedAmount(contractProduct, '継続課金'),
            contractProduct.Amount__c
        );
        }
    }

    @IsTest
    static void saveEstimate_newType_savesOptionalBillingAccount() {
        System.runAs(ContractTestDataFactory.getAdminUser()) {
        Account testAccount = ContractTestDataFactory.insertAccount('Test Account');
        Opportunity opportunity = ContractTestDataFactory.insertOpportunity(
            testAccount.Id,
            'Test Opportunity'
        );

        BillingAccount__c billingAccount = new BillingAccount__c(
            Account__c = opportunity.AccountId,
            BillingDayOfMonth__c = '25'
        );
        insert billingAccount;

        Product2 product = ContractTestDataFactory.buildProduct('Billing Account Product');
        product.UnitName__c = '式';
        product.UnitPrice__c = 1000;
        product.BillingType__c = '一回課金';
        ContractTestDataFactory.insertProduct(product);

        EstimateCreateController.ProductLineItem lineItem =
            new EstimateCreateController.ProductLineItem();
        lineItem.productId = product.Id;
        lineItem.quantity = 1;
        lineItem.unitPrice = 1000;
        lineItem.amount = 1000;
        lineItem.startDate = String.valueOf(Date.today());
        lineItem.endDate = String.valueOf(Date.today());
        lineItem.invoiceType = '一回課金_開始日請求';
        lineItem.unit = '式';
        lineItem.recordType = 'New';

        String productsJson = JSON.serialize(
            new List<EstimateCreateController.ProductLineItem>{ lineItem }
        );

        Test.startTest();
        EstimateCreateController.EstimateSaveResult result =
            EstimateCreateController.saveEstimate(
                opportunity.Id,
                'New',
                'Billing Service',
                'Billing History',
                null,
                null,
                String.valueOf(Date.today()),
                String.valueOf(Date.today()),
                String.valueOf(Date.today()),
                String.valueOf(Date.today()),
                productsJson,
                null,
                null,
                billingAccount.Id,
                null
            );
        Test.stopTest();

        ContractService__c service = [
            SELECT BiilingAcccount__c
            FROM ContractService__c
            WHERE Id = :result.contractServiceId
        ];
        System.assertEquals(billingAccount.Id, service.BiilingAcccount__c);
        }
    }

    @IsTest
    static void getBillingAccountInvoiceSettings_returnsConfiguredValues() {
        System.runAs(ContractTestDataFactory.getAdminUser()) {
            Account testAccount = ContractTestDataFactory.insertAccount('Billing Settings Account');
            BillingAccount__c billingAccount = new BillingAccount__c(
                Account__c = testAccount.Id,
                PaymentTerm__c = '翌月15日',
                BillingDayOfMonth__c = '25',
                AdjustInvoiceDateToBusinessDay__c = true
            );
            insert billingAccount;

            EstimateCreateController.BillingAccountInvoiceSettingsDto result =
                EstimateCreateController.getBillingAccountInvoiceSettings(
                    billingAccount.Id
                );

            System.assertEquals(25, result.billingDayOfMonth);
            System.assertEquals('25', result.billingDayOfMonthPicklistValue);
            System.assertEquals('25日', result.billingDayOfMonthLabel);
            System.assertEquals('翌月15日', result.paymentTerm);
            System.assertEquals(true, result.adjustInvoiceDateToBusinessDay);
        }
    }

    @IsTest
    static void saveEstimate_unsupportedType_throwsException() {
        System.runAs(ContractTestDataFactory.getAdminUser()) {
        Boolean thrown = false;
        try {
            EstimateCreateController.saveEstimate(
                null,
                'Invalid',
                null,
                null,
                null,
                null,
                null,
                null,
                null,
                null,
                null,
                null,
                null,
                null,
                null
            );
        } catch (Exception ex) {
            thrown = true;
        }
        System.assertEquals(true, thrown, '未対応タイプは例外になること');
        }
    }

    @IsTest
    static void getLatestContractHistory_returnsHighestNonEstimateVersion() {
        System.runAs(ContractTestDataFactory.getAdminUser()) {
        Account account = new Account(Name = 'Test Account');
        insert account;

        ContractService__c service = new ContractService__c(
            Name = 'Service A',
            Account__c = account.Id
        );
        insert service;

        ContractHistory__c older = new ContractHistory__c(
            Name = 'History v1',
            ContractService__c = service.Id,
            historystatus__c = 'Ordered',
            Version__c = 1
        );
        ContractHistory__c latest = new ContractHistory__c(
            Name = 'History v2',
            ContractService__c = service.Id,
            historystatus__c = 'Ordered',
            Version__c = 2
        );
        ContractHistory__c estimate = new ContractHistory__c(
            Name = 'Estimate v3',
            ContractService__c = service.Id,
            historystatus__c = 'Estimate',
            Version__c = 3
        );
        insert new List<ContractHistory__c>{ older, latest, estimate };

        EstimateCreateController.ContractHistoryDto result =
            EstimateCreateController.getLatestContractHistory(service.Id);

        System.assertNotEquals(null, result);
        System.assertEquals(latest.Id, result.historyId);
        System.assertEquals('History v2', result.historyName);
        System.assertEquals(2, result.version);
        System.assertEquals(4, result.nextVersion);
        }
    }

    @IsTest
    static void getLatestContractHistory_nullId_returnsNull() {
        System.runAs(ContractTestDataFactory.getAdminUser()) {
        System.assertEquals(null, EstimateCreateController.getLatestContractHistory(null));
        }
    }

    @IsTest
    static void getLatestContractHistory_skipsOrderedCancelChurn() {
        System.runAs(ContractTestDataFactory.getAdminUser()) {
            Account account = new Account(Name = 'Churn Skip Account');
            insert account;

            ContractService__c service = new ContractService__c(
                Name = 'Churn Skip Service',
                Account__c = account.Id
            );
            insert service;

            ContractHistory__c activeHistory = new ContractHistory__c(
                Name = 'Renew v1',
                ContractService__c = service.Id,
                Type__c = 'Renew',
                historystatus__c = 'Ordered',
                Version__c = 1
            );
            ContractHistory__c churnHistory = new ContractHistory__c(
                Name = 'Churn v2',
                ContractService__c = service.Id,
                Type__c = 'Cancel',
                historystatus__c = 'Ordered',
                Version__c = 2
            );
            insert new List<ContractHistory__c>{ activeHistory, churnHistory };

            EstimateCreateController.ContractHistoryDto result =
                EstimateCreateController.getLatestContractHistory(service.Id);

            System.assertNotEquals(null, result);
            System.assertEquals(activeHistory.Id, result.historyId);
            System.assertEquals('Renew v1', result.historyName);
            System.assertEquals(1, result.version);
        }
    }

    @IsTest
    static void getRecurringContractProducts_returnsRecurringOnly() {
        System.runAs(ContractTestDataFactory.getAdminUser()) {
        Account account = new Account(Name = 'Test Account');
        insert account;

        ContractService__c service = new ContractService__c(
            Name = 'Service A',
            Account__c = account.Id
        );
        insert service;

        ContractHistory__c history = new ContractHistory__c(
            Name = 'History',
            ContractService__c = service.Id,
            historystatus__c = 'Ordered',
            Version__c = 1
        );
        insert history;

        Product2 recurringProduct = ContractTestDataFactory.buildProduct('Recurring Product');
        recurringProduct.BillingType__c = '継続課金';
        recurringProduct.UnitName__c = '式';
        recurringProduct.UnitPrice__c = 5000;
        recurringProduct.invoicetype__c = '一括前払';
        Product2 oneTimeProduct = ContractTestDataFactory.buildProduct('One Time Product');
        oneTimeProduct.BillingType__c = '一回課金';
        oneTimeProduct.UnitName__c = '式';
        oneTimeProduct.UnitPrice__c = 10000;
        ContractTestDataFactory.insertProducts(new List<Product2>{ recurringProduct, oneTimeProduct });

        insert new List<ContractProduct__c>{
            new ContractProduct__c(
                ContractHistory__c = history.Id,
                Product__c = recurringProduct.Id,
                Quantity__c = 2,
                UnitPrice__c = 5000,
                StartDate__c = Date.today(),
                Enddate__c = Date.today().addMonths(12),
                InvoiceSetting__c = '一括前払'
            ),
            new ContractProduct__c(
                ContractHistory__c = history.Id,
                Product__c = oneTimeProduct.Id,
                Quantity__c = 1,
                UnitPrice__c = 10000,
                StartDate__c = Date.today(),
                Enddate__c = Date.today().addMonths(12),
                InvoiceSetting__c = ContractMetadataService.INVOICE_SETTING_PREPAID_START
            )
        };

        List<EstimateCreateController.ContractProductLineDto> results =
            EstimateCreateController.getRecurringContractProducts(history.Id);

        System.assertEquals(1, results.size());
        System.assertEquals(recurringProduct.Id, results[0].productId);
        System.assertEquals('Recurring Product', results[0].productName);
        System.assertEquals('式', results[0].unitName);
        System.assertEquals(2, results[0].quantity);
        System.assertEquals(5000, results[0].unitPrice);
        System.assertEquals('一括前払', results[0].invoiceType);
        }
    }

    @IsTest
    static void getRecurringContractProducts_nullId_returnsEmpty() {
        System.runAs(ContractTestDataFactory.getAdminUser()) {
        System.assertEquals(
            0,
            EstimateCreateController.getRecurringContractProducts(null).size()
        );
        }
    }

    @IsTest
    static void getRecurringContractProducts_excludesOriginalAndZeroQuantity() {
        System.runAs(ContractTestDataFactory.getAdminUser()) {
        Account account = new Account(Name = 'Test Account');
        insert account;

        ContractService__c service = new ContractService__c(
            Name = 'Service A',
            Account__c = account.Id
        );
        insert service;

        ContractHistory__c sourceHistory = new ContractHistory__c(
            Name = 'Source History',
            ContractService__c = service.Id,
            historystatus__c = 'Ordered',
            Version__c = 1
        );
        ContractHistory__c changeHistory = new ContractHistory__c(
            Name = 'Change History',
            ContractService__c = service.Id,
            historystatus__c = 'Ordered',
            Version__c = 2,
            Type__c = 'Change',
            PreviousHistory__c = sourceHistory.Id
        );
        insert new List<ContractHistory__c>{ sourceHistory, changeHistory };

        Product2 product = ContractTestDataFactory.buildProduct('Recurring Product');
        product.BillingType__c = '継続課金';
        product.UnitName__c = '式';
        product.UnitPrice__c = 5000;
        product.invoicetype__c = '一括前払';
        Product2 removedProduct = ContractTestDataFactory.buildProduct('Removed Product');
        removedProduct.BillingType__c = '継続課金';
        removedProduct.UnitName__c = '式';
        removedProduct.UnitPrice__c = 3000;
        removedProduct.invoicetype__c = '一括前払';
        ContractTestDataFactory.insertProducts(new List<Product2>{ product, removedProduct });

        ContractProduct__c sourceProduct = new ContractProduct__c(
            ContractHistory__c = sourceHistory.Id,
            Product__c = product.Id,
            Quantity__c = 2,
            UnitPrice__c = 5000,
            StartDate__c = Date.today(),
            Enddate__c = Date.today().addMonths(12),
            InvoiceSetting__c = '一括前払',
            Type__c = 'New'
        );
        insert sourceProduct;

        insert new List<ContractProduct__c>{
            new ContractProduct__c(
                ContractHistory__c = changeHistory.Id,
                Product__c = product.Id,
                Quantity__c = 2,
                UnitPrice__c = 5000,
                StartDate__c = Date.today(),
                Enddate__c = Date.today().addMonths(12),
                InvoiceSetting__c = '一括前払',
                Type__c = 'Original',
                PreviousContractProduct__c = sourceProduct.Id
            ),
            new ContractProduct__c(
                ContractHistory__c = changeHistory.Id,
                Product__c = product.Id,
                Quantity__c = 3,
                UnitPrice__c = 5000,
                StartDate__c = Date.today(),
                Enddate__c = Date.today().addMonths(12),
                InvoiceSetting__c = '一括前払',
                Type__c = 'Remake',
                PreviousContractProduct__c = sourceProduct.Id
            ),
            new ContractProduct__c(
                ContractHistory__c = changeHistory.Id,
                Product__c = removedProduct.Id,
                Quantity__c = 0,
                UnitPrice__c = 3000,
                StartDate__c = Date.today(),
                Enddate__c = Date.today().addMonths(12),
                InvoiceSetting__c = '一括前払',
                Type__c = 'Remake',
                PreviousContractProduct__c = sourceProduct.Id
            )
        };

        List<EstimateCreateController.ContractProductLineDto> results =
            EstimateCreateController.getRecurringContractProducts(changeHistory.Id);

        System.assertEquals(1, results.size());
        System.assertEquals(product.Id, results[0].productId);
        System.assertEquals(3, results[0].quantity);
        }
    }

    @IsTest
    static void getRenewContractProducts_matchesHistoryEndDateOnly() {
        System.runAs(ContractTestDataFactory.getAdminUser()) {
        Account account = new Account(Name = 'Test Account');
        insert account;

        ContractService__c service = new ContractService__c(
            Name = 'Service A',
            Account__c = account.Id
        );
        insert service;

        Date termEnd = Date.newInstance(2026, 5, 31);
        ContractHistory__c history = new ContractHistory__c(
            Name = 'History',
            ContractService__c = service.Id,
            historystatus__c = 'Ordered',
            Version__c = 1,
            CurrentTermEndDate__c = termEnd
        );
        insert history;

        Product2 productA = ContractTestDataFactory.buildProduct('Product A');
        productA.BillingType__c = '継続課金';
        productA.UnitName__c = '式';
        productA.UnitPrice__c = 5000;
        productA.invoicetype__c = '一括前払';
        Product2 productB = ContractTestDataFactory.buildProduct('Product B');
        productB.BillingType__c = '継続課金';
        productB.UnitName__c = '式';
        productB.UnitPrice__c = 3000;
        productB.invoicetype__c = '一括前払';
        ContractTestDataFactory.insertProducts(new List<Product2>{ productA, productB });

        insert new List<ContractProduct__c>{
            new ContractProduct__c(
                ContractHistory__c = history.Id,
                Product__c = productA.Id,
                Quantity__c = 1,
                UnitPrice__c = 5000,
                StartDate__c = Date.newInstance(2025, 6, 1),
                Enddate__c = termEnd,
                InvoiceSetting__c = '一括前払'
            ),
            new ContractProduct__c(
                ContractHistory__c = history.Id,
                Product__c = productB.Id,
                Quantity__c = 1,
                UnitPrice__c = 3000,
                StartDate__c = Date.newInstance(2025, 6, 1),
                Enddate__c = Date.newInstance(2026, 3, 31),
                InvoiceSetting__c = '一括前払'
            )
        };

        List<EstimateCreateController.ContractProductLineDto> results =
            EstimateCreateController.getRenewContractProducts(service.Id);

        System.assertEquals(1, results.size());
        System.assertEquals(productA.Id, results[0].productId);
        System.assertEquals(String.valueOf(termEnd), results[0].endDate);
        }
    }

    @IsTest
    static void getRenewContractProducts_excludesOriginalTypeEvenWhenEndDateMatches() {
        System.runAs(ContractTestDataFactory.getAdminUser()) {
            Account account = ContractTestDataFactory.insertAccount('Test Account');
            ContractService__c service = new ContractService__c(
                Name = 'Service A',
                Account__c = account.Id
            );
            insert service;

            Date termEnd = Date.newInstance(2026, 5, 31);
            ContractHistory__c history = new ContractHistory__c(
                Name = 'Change History',
                ContractService__c = service.Id,
                historystatus__c = 'Ordered',
                Version__c = 1,
                CurrentTermEndDate__c = termEnd
            );
            insert history;

            Product2 product = ContractTestDataFactory.buildProduct('Product A');
            product.BillingType__c = '継続課金';
            product.UnitName__c = '式';
            product.UnitPrice__c = 5000;
            product.invoicetype__c = '一括前払';
            ContractTestDataFactory.insertProduct(product);

            insert new ContractProduct__c(
                ContractHistory__c = history.Id,
                Product__c = product.Id,
                Quantity__c = 1,
                UnitPrice__c = 5000,
                StartDate__c = Date.newInstance(2025, 6, 1),
                Enddate__c = termEnd,
                InvoiceSetting__c = '一括前払',
                Type__c = 'Original'
            );

            System.assertEquals(
                0,
                EstimateCreateController.getRenewContractProducts(service.Id).size()
            );
        }
    }

    @IsTest
    static void getRenewContractProducts_nullId_returnsEmpty() {
        System.runAs(ContractTestDataFactory.getAdminUser()) {
        System.assertEquals(
            0,
            EstimateCreateController.getRenewContractProducts(null).size()
        );
        }
    }

    @IsTest
    static void getRenewContractProducts_usesLatestNonEstimateHistory() {
        System.runAs(ContractTestDataFactory.getAdminUser()) {
        Account account = new Account(Name = 'Test Account');
        insert account;

        ContractService__c service = new ContractService__c(
            Name = 'Service A',
            Account__c = account.Id
        );
        insert service;

        Date priorTermEnd = Date.newInstance(2026, 5, 31);
        ContractHistory__c orderedHistory = new ContractHistory__c(
            Name = 'Ordered History',
            ContractService__c = service.Id,
            historystatus__c = 'Ordered',
            Version__c = 1,
            CurrentTermEndDate__c = priorTermEnd
        );
        ContractHistory__c estimateHistory = new ContractHistory__c(
            Name = 'Renew Estimate',
            ContractService__c = service.Id,
            historystatus__c = 'Estimate',
            Version__c = 2,
            CurrentTermEndDate__c = Date.newInstance(2027, 5, 31)
        );
        insert new List<ContractHistory__c>{ orderedHistory, estimateHistory };

        Product2 product = ContractTestDataFactory.buildProduct('Product A');
        product.BillingType__c = '継続課金';
        product.UnitName__c = '式';
        product.UnitPrice__c = 5000;
        product.invoicetype__c = '一括前払';
        ContractTestDataFactory.insertProduct(product);

        insert new ContractProduct__c(
            ContractHistory__c = orderedHistory.Id,
            Product__c = product.Id,
            Quantity__c = 1,
            UnitPrice__c = 5000,
            StartDate__c = Date.newInstance(2025, 6, 1),
            Enddate__c = priorTermEnd,
            InvoiceSetting__c = '一括前払'
        );

        List<EstimateCreateController.ContractProductLineDto> results =
            EstimateCreateController.getRenewContractProducts(service.Id);

        System.assertEquals(1, results.size());
        System.assertEquals(product.Id, results[0].productId);
        }
    }

    @IsTest
    static void getContractHistoryInfo_returnsTermDates() {
        System.runAs(ContractTestDataFactory.getAdminUser()) {
        Account account = new Account(Name = 'Test Account');
        insert account;

        ContractService__c service = new ContractService__c(
            Name = 'Service A',
            Account__c = account.Id
        );
        insert service;

        Date startDate = Date.today();
        Date endDate = Date.today().addMonths(12);
        ContractHistory__c history = new ContractHistory__c(
            Name = 'History',
            ContractService__c = service.Id,
            historystatus__c = 'Ordered',
            Version__c = 1,
            CurrentTermStartDate__c = startDate,
            CurrentTermEndDate__c = endDate
        );
        insert history;

        EstimateCreateController.ContractHistoryDto result =
            EstimateCreateController.getContractHistoryInfo(history.Id);

        System.assertNotEquals(null, result);
        System.assertEquals(String.valueOf(startDate), result.termStartDate);
        System.assertEquals(String.valueOf(endDate), result.termEndDate);
        }
    }

    @IsTest
    static void getContractHistoryInfo_nullId_returnsNull() {
        System.runAs(ContractTestDataFactory.getAdminUser()) {
        System.assertEquals(null, EstimateCreateController.getContractHistoryInfo(null));
        }
    }

    @IsTest
    static void saveEstimate_invalidBillingPeriod_throwsException() {
        System.runAs(ContractTestDataFactory.getAdminUser()) {
        Account testAccount = ContractTestDataFactory.insertAccount('Test Account');
        Opportunity opportunity = ContractTestDataFactory.insertOpportunity(
            testAccount.Id,
            'Test Opportunity'
        );

        Product2 product = ContractTestDataFactory.buildProduct('Recurring Product');
        product.UnitName__c = '式';
        product.UnitPrice__c = 1000;
        product.invoicetype__c = '一括前払';
        product.BillingType__c = '継続課金';
        ContractTestDataFactory.insertProduct(product);

        EstimateCreateController.ProductLineItem lineItem = new EstimateCreateController.ProductLineItem();
        lineItem.productId = product.Id;
        lineItem.quantity = 1;
        lineItem.unitPrice = 1000;
        lineItem.amount = 1000;
        lineItem.startDate = String.valueOf(Date.today());
        lineItem.endDate = String.valueOf(Date.today().addDays(10));
        lineItem.invoiceType = '一括前払';
        lineItem.unit = '式/月';
        lineItem.billingType = '継続課金';
        lineItem.billingCycle = '月';
        lineItem.recordType = 'New';

        String productsJson = JSON.serialize(
            new List<EstimateCreateController.ProductLineItem>{ lineItem }
        );

        Boolean thrown = false;
        try {
            EstimateCreateController.saveEstimate(
                opportunity.Id,
                'New',
                'Test Service',
                'Test History',
                null,
                null,
                String.valueOf(Date.today()),
                String.valueOf(Date.today().addMonths(12)),
                String.valueOf(Date.today()),
                String.valueOf(Date.today()),
                productsJson,
                null,
                null,
                null,
                null
            );
        } catch (Exception ex) {
            thrown = true;
        }
        System.assertEquals(true, thrown);
        }
    }

    @IsTest
    static void saveEstimate_newTypeMissingEndpointMatch_throwsException() {
        System.runAs(ContractTestDataFactory.getAdminUser()) {
        Account testAccount = ContractTestDataFactory.insertAccount('Test Account');
        Opportunity opportunity = ContractTestDataFactory.insertOpportunity(
            testAccount.Id,
            'Test Opportunity'
        );

        Product2 product = ContractTestDataFactory.buildProduct('Endpoint Product');
        product.UnitName__c = '式';
        product.UnitPrice__c = 1000;
        product.invoicetype__c = '一括前払';
        product.BillingType__c = '継続課金';
        ContractTestDataFactory.insertProduct(product);

        Date headerStart = Date.today();
        Date headerEnd = Date.today().addMonths(12).addDays(-1);

        EstimateCreateController.ProductLineItem lineItem = new EstimateCreateController.ProductLineItem();
        lineItem.productId = product.Id;
        lineItem.quantity = 1;
        lineItem.unitPrice = 1000;
        lineItem.amount = 12000;
        lineItem.startDate = String.valueOf(headerStart);
        lineItem.endDate = String.valueOf(headerStart.addMonths(6).addDays(-1));
        lineItem.invoiceType = '一括前払';
        lineItem.unit = '式/月';
        lineItem.billingType = '継続課金';
        lineItem.billingCycle = '月';
        lineItem.recordType = 'New';

        String productsJson = JSON.serialize(
            new List<EstimateCreateController.ProductLineItem>{ lineItem }
        );

        Boolean thrown = false;
        try {
            EstimateCreateController.saveEstimate(
                opportunity.Id,
                'New',
                'Test Service',
                'Test History',
                null,
                null,
                String.valueOf(headerStart),
                String.valueOf(headerEnd),
                String.valueOf(headerStart),
                String.valueOf(Date.today()),
                productsJson,
                null,
                null,
                null,
                null
            );
        } catch (Exception ex) {
            thrown = true;
        }
        System.assertEquals(true, thrown);
        }
    }

    @IsTest
    static void saveEstimate_newType_recurringPartialAddon_succeeds() {
        System.runAs(ContractTestDataFactory.getAdminUser()) {
            Account testAccount = ContractTestDataFactory.insertAccount('Partial Addon Account');
            Opportunity opportunity = ContractTestDataFactory.insertOpportunity(
                testAccount.Id,
                'Partial Addon Opportunity'
            );

            Product2 coreProduct = ContractTestDataFactory.buildProduct('Core Product');
            coreProduct.UnitName__c = 'ID';
            coreProduct.UnitPrice__c = 8000;
            coreProduct.invoicetype__c = '一括前払';
            coreProduct.BillingType__c = '継続課金';
            Product2 addonProduct = ContractTestDataFactory.buildProduct('Trial Addon');
            addonProduct.UnitName__c = 'ID';
            addonProduct.UnitPrice__c = 2000;
            addonProduct.invoicetype__c = '月次分割';
            addonProduct.BillingType__c = '継続課金';
            ContractTestDataFactory.insertProducts(
                new List<Product2>{ coreProduct, addonProduct }
            );

            Date headerStart = Date.newInstance(2026, 6, 1);
            Date headerEnd = Date.newInstance(2027, 5, 31);
            Date addonEnd = Date.newInstance(2026, 8, 31);

            EstimateCreateController.ProductLineItem coreLine =
                new EstimateCreateController.ProductLineItem();
            coreLine.productId = coreProduct.Id;
            coreLine.quantity = 1;
            coreLine.unitPrice = 8000;
            coreLine.startDate = String.valueOf(headerStart);
            coreLine.endDate = String.valueOf(headerEnd);
            coreLine.invoiceType = '一括前払';
            coreLine.billingType = '継続課金';
            coreLine.billingCycle = '月';
            coreLine.recordType = 'New';

            EstimateCreateController.ProductLineItem addonLine =
                new EstimateCreateController.ProductLineItem();
            addonLine.productId = addonProduct.Id;
            addonLine.quantity = 1;
            addonLine.unitPrice = 2000;
            addonLine.startDate = String.valueOf(headerStart);
            addonLine.endDate = String.valueOf(addonEnd);
            addonLine.invoiceType = '月次分割';
            addonLine.billingType = '継続課金';
            addonLine.billingCycle = '月';
            addonLine.recordType = 'New';

            String productsJson = JSON.serialize(
                new List<EstimateCreateController.ProductLineItem>{ coreLine, addonLine }
            );

            EstimateCreateController.EstimateSaveResult result =
                EstimateCreateController.saveEstimate(
                    opportunity.Id,
                    'New',
                    'Partial Addon Service',
                    'Partial Addon History',
                    null,
                    null,
                    String.valueOf(headerStart),
                    String.valueOf(headerEnd),
                    String.valueOf(headerStart),
                    null,
                    productsJson,
                    null,
                    null,
                    null,
                    null
                );

            System.assertEquals(2, result.contractProductIds.size());
        }
    }

    @IsTest
    static void saveEstimate_newType_overlappingProducts_throwsException() {
        System.runAs(ContractTestDataFactory.getAdminUser()) {
            Account testAccount = ContractTestDataFactory.insertAccount('Overlap Account');
            Opportunity opportunity = ContractTestDataFactory.insertOpportunity(
                testAccount.Id,
                'Overlap Opportunity'
            );

            Product2 product = ContractTestDataFactory.buildProduct('Overlap Product');
            product.UnitName__c = 'ID';
            product.UnitPrice__c = 8000;
            product.invoicetype__c = '一括前払';
            product.BillingType__c = '継続課金';
            ContractTestDataFactory.insertProduct(product);

            Date headerStart = Date.newInstance(2026, 6, 1);
            Date headerEnd = Date.newInstance(2027, 5, 31);

            EstimateCreateController.ProductLineItem firstLine =
                new EstimateCreateController.ProductLineItem();
            firstLine.productId = product.Id;
            firstLine.quantity = 1;
            firstLine.unitPrice = 8000;
            firstLine.startDate = String.valueOf(headerStart);
            firstLine.endDate = String.valueOf(headerEnd);
            firstLine.invoiceType = '一括前払';
            firstLine.billingType = '継続課金';
            firstLine.billingCycle = '月';
            firstLine.recordType = 'New';

            EstimateCreateController.ProductLineItem secondLine =
                new EstimateCreateController.ProductLineItem();
            secondLine.productId = product.Id;
            secondLine.quantity = 2;
            secondLine.unitPrice = 8000;
            secondLine.startDate = String.valueOf(Date.newInstance(2026, 10, 1));
            secondLine.endDate = String.valueOf(headerEnd);
            secondLine.invoiceType = '一括前払';
            secondLine.billingType = '継続課金';
            secondLine.billingCycle = '月';
            secondLine.recordType = 'New';

            String productsJson = JSON.serialize(
                new List<EstimateCreateController.ProductLineItem>{ firstLine, secondLine }
            );

            Boolean thrown = false;
            try {
                EstimateCreateController.saveEstimate(
                    opportunity.Id,
                    'New',
                    'Overlap Service',
                    'Overlap History',
                    null,
                    null,
                    String.valueOf(headerStart),
                    String.valueOf(headerEnd),
                    String.valueOf(headerStart),
                    null,
                    productsJson,
                    null,
                    null,
                    null,
                    null
                );
            } catch (Exception ex) {
                thrown = true;
            }
            System.assertEquals(true, thrown);
        }
    }

    @IsTest
    static void saveEstimate_createsRecordsForChangeType() {
        System.runAs(ContractTestDataFactory.getAdminUser()) {
        Account testAccount = ContractTestDataFactory.insertAccount('Test Account');
        Opportunity opportunity = ContractTestDataFactory.insertOpportunity(
            testAccount.Id,
            'Test Opportunity'
        );

        ContractService__c service = new ContractService__c(
            Name = 'Change Test Service',
            Account__c = opportunity.AccountId
        );
        insert service;

        Date termStart = Date.newInstance(2025, 6, 1);
        Date termEnd = Date.newInstance(2026, 5, 31);
        Date effectiveDate = Date.newInstance(2025, 10, 1);

        ContractHistory__c sourceHistory = new ContractHistory__c(
            Name = 'Source History',
            ContractService__c = service.Id,
            Type__c = 'New',
            historystatus__c = 'Ordered',
            Version__c = 1,
            CurrentTermStartDate__c = termStart,
            CurrentTermEndDate__c = termEnd,
            Opportunity__c = opportunity.Id
        );
        insert sourceHistory;

        Product2 product = ContractTestDataFactory.buildProduct('Change Product');
        product.UnitName__c = '式';
        product.UnitPrice__c = 5000;
        product.invoicetype__c = '一括前払';
        product.BillingType__c = '継続課金';
        ContractTestDataFactory.insertProduct(product);

        ContractProduct__c sourceProduct = new ContractProduct__c(
            ContractHistory__c = sourceHistory.Id,
            Product__c = product.Id,
            Quantity__c = 2,
            UnitPrice__c = 5000,
            Unit__c = '式/月',
            StartDate__c = termStart,
            Enddate__c = termEnd,
            InvoiceSetting__c = '一括前払',
            Type__c = 'New'
        );
        insert sourceProduct;

        EstimateCreateController.ProductLineItem beforeLine =
            new EstimateCreateController.ProductLineItem();
        beforeLine.productId = product.Id;
        beforeLine.quantity = 2;
        beforeLine.unitPrice = 5000;
        beforeLine.amount = -120000;
        beforeLine.startDate = String.valueOf(termStart);
        beforeLine.endDate = String.valueOf(termEnd);
        beforeLine.invoiceType = '一括前払';
        beforeLine.unit = '式/月';
        beforeLine.billingType = '継続課金';
        beforeLine.billingCycle = '月';
        beforeLine.recordType = 'Original';
        beforeLine.sourceContractProductId = sourceProduct.Id;

        EstimateCreateController.ProductLineItem afterLine =
            new EstimateCreateController.ProductLineItem();
        afterLine.productId = product.Id;
        afterLine.quantity = 3;
        afterLine.unitPrice = 5000;
        afterLine.amount = 180000;
        afterLine.startDate = String.valueOf(effectiveDate);
        afterLine.endDate = String.valueOf(termEnd);
        afterLine.invoiceType = '一括前払';
        afterLine.unit = '式/月';
        afterLine.billingType = '継続課金';
        afterLine.billingCycle = '月';
        afterLine.recordType = 'Remake';
        afterLine.sourceContractProductId = sourceProduct.Id;

        String productsJson = JSON.serialize(
            new List<EstimateCreateController.ProductLineItem>{ beforeLine, afterLine }
        );

        Test.startTest();
        EstimateCreateController.EstimateSaveResult result = EstimateCreateController.saveEstimate(
            opportunity.Id,
            'Change',
            null,
            'Change Estimate',
            service.Id,
            sourceHistory.Id,
            String.valueOf(termStart),
            String.valueOf(termEnd),
            String.valueOf(effectiveDate),
            String.valueOf(Date.today()),
            productsJson,
            null,
            null,
            null,
            null
        );
        Test.stopTest();

        System.assertEquals(service.Id, result.contractServiceId);
        System.assertNotEquals(null, result.contractHistoryId);
        System.assertEquals(2, result.contractProductIds.size());

        ContractHistory__c estimateHistory = [
            SELECT Type__c, historystatus__c, Version__c, ContractService__c, PreviousHistory__c
            FROM ContractHistory__c
            WHERE Id = :result.contractHistoryId
        ];
        System.assertEquals('Change', estimateHistory.Type__c);
        System.assertEquals('Estimate', estimateHistory.historystatus__c);
        System.assertEquals(2, estimateHistory.Version__c);
        System.assertEquals(service.Id, estimateHistory.ContractService__c);
        System.assertEquals(sourceHistory.Id, estimateHistory.PreviousHistory__c);

        List<ContractProduct__c> savedProducts = [
            SELECT
                Type__c,
                PreviousContractProduct__c,
                Quantity__c,
                UnitPrice__c,
                BillingType__c,
                Amount__c,
                StartDate__c,
                Enddate__c
            FROM ContractProduct__c
            WHERE ContractHistory__c = :result.contractHistoryId
            ORDER BY Type__c DESC
        ];
        System.assertEquals(2, savedProducts.size());
        System.assertEquals('Remake', savedProducts[0].Type__c);
        System.assertEquals('継続課金', savedProducts[0].BillingType__c);
        System.assertEquals(sourceProduct.Id, savedProducts[0].PreviousContractProduct__c);
        System.assertEquals(3, savedProducts[0].Quantity__c);
        System.assertEquals(
            120000,
            savedProducts[0].Amount__c,
            'Remake: 単価×数量×月数'
        );
        System.assertEquals('Original', savedProducts[1].Type__c);
        System.assertEquals(sourceProduct.Id, savedProducts[1].PreviousContractProduct__c);
        System.assertEquals(
            -120000,
            savedProducts[1].Amount__c,
            'Original: マイナス符号'
        );
        }
    }

    @IsTest
    static void saveEstimate_change_allowsNewAddonWithMislabeledDerivativeRecordType() {
        System.runAs(ContractTestDataFactory.getAdminUser()) {
            Account testAccount = ContractTestDataFactory.insertAccount('Change Addon Account');
            Opportunity opportunity = ContractTestDataFactory.insertOpportunity(
                testAccount.Id,
                'Change Addon Opportunity'
            );

            ContractService__c service = new ContractService__c(
                Name = 'Change Addon Service',
                Account__c = opportunity.AccountId
            );
            insert service;

            Date termStart = Date.newInstance(2025, 6, 1);
            Date termEnd = Date.newInstance(2026, 5, 31);
            Date effectiveDate = Date.newInstance(2025, 10, 1);

            ContractHistory__c sourceHistory = new ContractHistory__c(
                Name = 'Change Addon Source',
                ContractService__c = service.Id,
                Type__c = 'New',
                historystatus__c = 'Ordered',
                Version__c = 1,
                CurrentTermStartDate__c = termStart,
                CurrentTermEndDate__c = termEnd,
                Opportunity__c = opportunity.Id
            );
            insert sourceHistory;

            Product2 product = ContractTestDataFactory.buildProduct('Change Addon Product');
            product.UnitName__c = '式';
            product.UnitPrice__c = 5000;
            product.invoicetype__c = '一括前払';
            product.BillingType__c = '継続課金';
            ContractTestDataFactory.insertProduct(product);

            Product2 addonProduct = ContractTestDataFactory.buildProduct('Change Addon Extra Product');
            addonProduct.UnitName__c = '式';
            addonProduct.UnitPrice__c = 3000;
            addonProduct.invoicetype__c = '一括前払';
            addonProduct.BillingType__c = '継続課金';
            ContractTestDataFactory.insertProduct(addonProduct);

            ContractProduct__c sourceProduct = new ContractProduct__c(
                ContractHistory__c = sourceHistory.Id,
                Product__c = product.Id,
                Quantity__c = 2,
                UnitPrice__c = 5000,
                Unit__c = '式/月',
                StartDate__c = termStart,
                Enddate__c = termEnd,
                InvoiceSetting__c = '一括前払',
                Type__c = 'New'
            );
            insert sourceProduct;

            EstimateCreateController.ProductLineItem beforeLine =
                new EstimateCreateController.ProductLineItem();
            beforeLine.productId = product.Id;
            beforeLine.quantity = 2;
            beforeLine.unitPrice = 5000;
            beforeLine.amount = -120000;
            beforeLine.startDate = String.valueOf(termStart);
            beforeLine.endDate = String.valueOf(termEnd);
            beforeLine.invoiceType = '一括前払';
            beforeLine.unit = '式/月';
            beforeLine.billingType = '継続課金';
            beforeLine.billingCycle = '月';
            beforeLine.recordType = 'Original';
            beforeLine.sourceContractProductId = sourceProduct.Id;

            EstimateCreateController.ProductLineItem afterLine =
                new EstimateCreateController.ProductLineItem();
            afterLine.productId = product.Id;
            afterLine.quantity = 3;
            afterLine.unitPrice = 5000;
            afterLine.amount = 180000;
            afterLine.startDate = String.valueOf(effectiveDate);
            afterLine.endDate = String.valueOf(termEnd);
            afterLine.invoiceType = '一括前払';
            afterLine.unit = '式/月';
            afterLine.billingType = '継続課金';
            afterLine.billingCycle = '月';
            afterLine.recordType = 'Remake';
            afterLine.sourceContractProductId = sourceProduct.Id;

            EstimateCreateController.ProductLineItem addonLine =
                new EstimateCreateController.ProductLineItem();
            addonLine.productId = addonProduct.Id;
            addonLine.quantity = 1;
            addonLine.unitPrice = 3000;
            addonLine.amount = 36000;
            addonLine.startDate = String.valueOf(effectiveDate);
            addonLine.endDate = String.valueOf(termEnd);
            addonLine.invoiceType = '一括前払';
            addonLine.unit = '式/月';
            addonLine.billingType = '継続課金';
            addonLine.billingCycle = '月';
            addonLine.recordType = 'derivative';
            addonLine.typeLabel = 'New';
            addonLine.isDuplicate = true;
            addonLine.sourceContractProductId = null;

            String productsJson = JSON.serialize(
                new List<EstimateCreateController.ProductLineItem>{
                    beforeLine,
                    afterLine,
                    addonLine
                }
            );

            Test.startTest();
            EstimateCreateController.EstimateSaveResult result = EstimateCreateController.saveEstimate(
                opportunity.Id,
                'Change',
                null,
                'Change Addon Estimate',
                service.Id,
                sourceHistory.Id,
                String.valueOf(termStart),
                String.valueOf(termEnd),
                String.valueOf(effectiveDate),
                String.valueOf(Date.today()),
                productsJson,
                null,
                null,
                null,
                null
            );
            Test.stopTest();

            System.assertEquals(3, result.contractProductIds.size());
        }
    }

    @IsTest
    static void saveEstimate_changeType_rejectsMisalignedEffectiveDate() {
        System.runAs(ContractTestDataFactory.getAdminUser()) {
            Account testAccount = ContractTestDataFactory.insertAccount('Change Align Account');
            Opportunity opportunity = ContractTestDataFactory.insertOpportunity(
                testAccount.Id,
                'Change Align Opportunity'
            );

            ContractService__c service = new ContractService__c(
                Name = 'Change Align Service',
                Account__c = opportunity.AccountId
            );
            insert service;

            Date termStart = Date.newInstance(2026, 4, 15);
            Date termEnd = Date.newInstance(2027, 4, 14);

            ContractHistory__c sourceHistory = new ContractHistory__c(
                Name = 'Change Align Source',
                ContractService__c = service.Id,
                Type__c = 'New',
                historystatus__c = 'Ordered',
                Version__c = 1,
                CurrentTermStartDate__c = termStart,
                CurrentTermEndDate__c = termEnd,
                Opportunity__c = opportunity.Id
            );
            insert sourceHistory;

            Product2 product = ContractTestDataFactory.buildProduct('Change Align Product');
            product.BillingType__c = '継続課金';
            product.invoicetype__c = '一括前払';
            ContractTestDataFactory.insertProduct(product);

            ContractProduct__c sourceProduct = new ContractProduct__c(
                ContractHistory__c = sourceHistory.Id,
                Product__c = product.Id,
                Quantity__c = 1,
                UnitPrice__c = 5000,
                StartDate__c = termStart,
                Enddate__c = termEnd,
                InvoiceSetting__c = '一括前払',
                Type__c = 'New'
            );
            insert sourceProduct;

            EstimateCreateController.ProductLineItem beforeLine =
                new EstimateCreateController.ProductLineItem();
            beforeLine.productId = product.Id;
            beforeLine.quantity = 1;
            beforeLine.unitPrice = 5000;
            beforeLine.amount = -60000;
            beforeLine.startDate = String.valueOf(termStart);
            beforeLine.endDate = String.valueOf(termEnd);
            beforeLine.invoiceType = '一括前払';
            beforeLine.billingType = '継続課金';
            beforeLine.billingCycle = '月';
            beforeLine.recordType = 'Original';
            beforeLine.sourceContractProductId = sourceProduct.Id;

            EstimateCreateController.ProductLineItem afterLine =
                new EstimateCreateController.ProductLineItem();
            afterLine.productId = product.Id;
            afterLine.quantity = 1;
            afterLine.unitPrice = 5000;
            afterLine.amount = 60000;
            afterLine.startDate = String.valueOf(Date.newInstance(2026, 10, 1));
            afterLine.endDate = String.valueOf(termEnd);
            afterLine.invoiceType = '一括前払';
            afterLine.billingType = '継続課金';
            afterLine.billingCycle = '月';
            afterLine.recordType = 'Remake';
            afterLine.sourceContractProductId = sourceProduct.Id;

            String productsJson = JSON.serialize(
                new List<EstimateCreateController.ProductLineItem>{ beforeLine, afterLine }
            );

            Boolean thrown = false;
            try {
                EstimateCreateController.saveEstimate(
                    opportunity.Id,
                    'Change',
                    null,
                    'Change Align Estimate',
                    service.Id,
                    sourceHistory.Id,
                    String.valueOf(termStart),
                    String.valueOf(termEnd),
                    String.valueOf(Date.newInstance(2026, 10, 20)),
                    String.valueOf(Date.today()),
                    productsJson,
                    null,
                    null,
                    null,
                    null
                );
            } catch (Exception ex) {
                thrown = true;
            }
            System.assertEquals(true, thrown);
        }
    }

    @IsTest
    static void saveEstimate_createsRecordsForRenewType() {
        System.runAs(ContractTestDataFactory.getAdminUser()) {
        Account testAccount = ContractTestDataFactory.insertAccount('Test Account');
        Opportunity opportunity = ContractTestDataFactory.insertOpportunity(
            testAccount.Id,
            'Test Opportunity'
        );

        ContractService__c service = new ContractService__c(
            Name = 'Renew Test Service',
            Account__c = opportunity.AccountId
        );
        insert service;

        Date termStart = Date.newInstance(2025, 6, 1);
        Date termEnd = Date.newInstance(2026, 5, 31);
        Date renewStart = Date.newInstance(2026, 6, 1);
        Date renewEnd = Date.newInstance(2027, 5, 31);

        ContractHistory__c sourceHistory = new ContractHistory__c(
            Name = 'Source History',
            ContractService__c = service.Id,
            Type__c = 'New',
            historystatus__c = 'Ordered',
            Version__c = 1,
            CurrentTermStartDate__c = termStart,
            CurrentTermEndDate__c = termEnd,
            Opportunity__c = opportunity.Id
        );
        insert sourceHistory;

        Product2 product = ContractTestDataFactory.buildProduct('Renew Product');
        product.UnitName__c = 'ID';
        product.UnitPrice__c = 8000;
        product.invoicetype__c = '一括前払';
        product.BillingType__c = '継続課金';
        ContractTestDataFactory.insertProduct(product);

        Product2 addonProduct = ContractTestDataFactory.buildProduct('Renew Addon Product');
        addonProduct.UnitName__c = 'ID';
        addonProduct.UnitPrice__c = 8000;
        addonProduct.invoicetype__c = '一括前払';
        addonProduct.BillingType__c = '継続課金';
        ContractTestDataFactory.insertProduct(addonProduct);

        insert new ContractProduct__c(
            ContractHistory__c = sourceHistory.Id,
            Product__c = product.Id,
            Quantity__c = 1,
            UnitPrice__c = 8000,
            Unit__c = 'ID/月',
            StartDate__c = termStart,
            Enddate__c = termEnd,
            InvoiceSetting__c = '一括前払',
            Type__c = 'New'
        );
        insert new ContractProduct__c(
            ContractHistory__c = sourceHistory.Id,
            Product__c = addonProduct.Id,
            Quantity__c = 1,
            UnitPrice__c = 8000,
            Unit__c = 'ID/月',
            StartDate__c = termStart,
            Enddate__c = termEnd,
            InvoiceSetting__c = '一括前払',
            Type__c = 'New'
        );

        EstimateCreateController.ProductLineItem renewLine =
            new EstimateCreateController.ProductLineItem();
        renewLine.productId = product.Id;
        renewLine.quantity = 1;
        renewLine.unitPrice = 8000;
        renewLine.amount = 96000;
        renewLine.startDate = String.valueOf(renewStart);
        renewLine.endDate = String.valueOf(renewEnd);
        renewLine.invoiceType = '一括前払';
        renewLine.unit = 'ID/月';
        renewLine.billingType = '継続課金';
        renewLine.billingCycle = '月';
        renewLine.recordType = 'Renew';

        EstimateCreateController.ProductLineItem newLine =
            new EstimateCreateController.ProductLineItem();
        newLine.productId = addonProduct.Id;
        newLine.quantity = 2;
        newLine.unitPrice = 8000;
        newLine.amount = 192000;
        newLine.startDate = String.valueOf(renewStart);
        newLine.endDate = String.valueOf(renewEnd);
        newLine.invoiceType = '一括前払';
        newLine.unit = 'ID/月';
        newLine.billingType = '継続課金';
        newLine.billingCycle = '月';
        newLine.recordType = 'New';

        String productsJson = JSON.serialize(
            new List<EstimateCreateController.ProductLineItem>{ renewLine, newLine }
        );

        Test.startTest();
        EstimateCreateController.EstimateSaveResult result = EstimateCreateController.saveEstimate(
            opportunity.Id,
            'Renew',
            null,
            'Renew Estimate',
            service.Id,
            sourceHistory.Id,
            String.valueOf(renewStart),
            String.valueOf(renewEnd),
            String.valueOf(termEnd.addDays(1)),
            String.valueOf(Date.today()),
            productsJson,
            null,
            null,
            null,
            null
        );
        Test.stopTest();

        System.assertEquals(service.Id, result.contractServiceId);
        System.assertNotEquals(null, result.contractHistoryId);
        System.assertEquals(2, result.contractProductIds.size());

        ContractHistory__c estimateHistory = [
            SELECT Type__c, historystatus__c, Version__c, PreviousHistory__c
            FROM ContractHistory__c
            WHERE Id = :result.contractHistoryId
        ];
        System.assertEquals('Renew', estimateHistory.Type__c);
        System.assertEquals('Estimate', estimateHistory.historystatus__c);
        System.assertEquals(2, estimateHistory.Version__c);
        System.assertEquals(sourceHistory.Id, estimateHistory.PreviousHistory__c);

        List<ContractProduct__c> savedProducts = [
            SELECT Type__c, Quantity__c, BillingType__c
            FROM ContractProduct__c
            WHERE ContractHistory__c = :result.contractHistoryId
            ORDER BY Type__c DESC
        ];
        System.assertEquals(2, savedProducts.size());
        System.assertEquals('Renew', savedProducts[0].Type__c);
        System.assertEquals('継続課金', savedProducts[0].BillingType__c);
        System.assertEquals(1, savedProducts[0].Quantity__c);
        System.assertEquals('New', savedProducts[1].Type__c);
        System.assertEquals(2, savedProducts[1].Quantity__c);
        }
    }

    @IsTest
    static void saveEstimate_renew_allowsOneTimeAddonWithRecurring() {
        System.runAs(ContractTestDataFactory.getAdminUser()) {
            Account account = ContractTestDataFactory.insertAccount('Renew Addon Account');
            Opportunity opportunity = ContractTestDataFactory.insertOpportunity(
                account.Id,
                'Renew Addon Opportunity'
            );
            ContractService__c service = new ContractService__c(
                Name = 'Renew Addon Service',
                Account__c = account.Id
            );
            insert service;

            Date termStart = Date.newInstance(2025, 6, 1);
            Date termEnd = Date.newInstance(2026, 5, 31);
            Date renewStart = Date.newInstance(2026, 6, 1);
            Date renewEnd = Date.newInstance(2027, 5, 31);

            ContractHistory__c sourceHistory = new ContractHistory__c(
                Name = 'Renew Addon Source',
                ContractService__c = service.Id,
                Type__c = 'New',
                historystatus__c = 'Ordered',
                Version__c = 1,
                CurrentTermStartDate__c = termStart,
                CurrentTermEndDate__c = termEnd,
                Opportunity__c = opportunity.Id
            );
            insert sourceHistory;

            Product2 recurringProduct = ContractTestDataFactory.buildProduct('Renew Addon Recurring');
            recurringProduct.BillingType__c = '継続課金';
            recurringProduct.invoicetype__c = '一括前払';
            ContractTestDataFactory.insertProduct(recurringProduct);

            Product2 oneTimeProduct = ContractTestDataFactory.buildProduct('Renew Addon One Time');
            oneTimeProduct.BillingType__c = '一回課金';
            ContractTestDataFactory.insertProduct(oneTimeProduct);

            insert new ContractProduct__c(
                ContractHistory__c = sourceHistory.Id,
                Product__c = recurringProduct.Id,
                Quantity__c = 1,
                UnitPrice__c = 8000,
                StartDate__c = termStart,
                Enddate__c = termEnd,
                InvoiceSetting__c = '一括前払',
                Type__c = 'New'
            );

            EstimateCreateController.ProductLineItem renewLine =
                new EstimateCreateController.ProductLineItem();
            renewLine.productId = recurringProduct.Id;
            renewLine.quantity = 1;
            renewLine.unitPrice = 8000;
            renewLine.amount = 96000;
            renewLine.startDate = String.valueOf(renewStart);
            renewLine.endDate = String.valueOf(renewEnd);
            renewLine.invoiceType = '一括前払';
            renewLine.billingType = '継続課金';
            renewLine.billingCycle = '月';
            renewLine.recordType = 'Renew';

            EstimateCreateController.ProductLineItem addonLine =
                new EstimateCreateController.ProductLineItem();
            addonLine.productId = oneTimeProduct.Id;
            addonLine.quantity = 1;
            addonLine.unitPrice = 50000;
            addonLine.amount = 50000;
            addonLine.startDate = String.valueOf(renewStart);
            addonLine.endDate = String.valueOf(renewEnd);
            addonLine.invoiceType = '一回課金_開始日請求';
            addonLine.billingType = '一回課金';
            addonLine.recordType = 'New';

            EstimateCreateController.EstimateSaveResult result =
                EstimateCreateController.saveEstimate(
                    opportunity.Id,
                    'Renew',
                    null,
                    'Renew Addon Estimate',
                    service.Id,
                    sourceHistory.Id,
                    String.valueOf(renewStart),
                    String.valueOf(renewEnd),
                    String.valueOf(termEnd.addDays(1)),
                    String.valueOf(Date.today()),
                    JSON.serialize(
                        new List<EstimateCreateController.ProductLineItem>{
                            renewLine,
                            addonLine
                        }
                    ),
                    null,
                    null,
                    null,
                    null
                );

            System.assertEquals(2, result.contractProductIds.size());
        }
    }

    @IsTest
    static void saveEstimate_renew_rejectsOneTimeOnlyLines() {
        System.runAs(ContractTestDataFactory.getAdminUser()) {
            Account account = ContractTestDataFactory.insertAccount('Renew One Time Only Account');
            Opportunity opportunity = ContractTestDataFactory.insertOpportunity(
                account.Id,
                'Renew One Time Only Opportunity'
            );
            ContractService__c service = new ContractService__c(
                Name = 'Renew One Time Only Service',
                Account__c = account.Id
            );
            insert service;

            Date termStart = Date.newInstance(2025, 6, 1);
            Date termEnd = Date.newInstance(2026, 5, 31);
            Date renewStart = Date.newInstance(2026, 6, 1);
            Date renewEnd = Date.newInstance(2027, 5, 31);

            ContractHistory__c sourceHistory = new ContractHistory__c(
                Name = 'Renew One Time Only Source',
                ContractService__c = service.Id,
                Type__c = 'New',
                historystatus__c = 'Ordered',
                Version__c = 1,
                CurrentTermStartDate__c = termStart,
                CurrentTermEndDate__c = termEnd,
                Opportunity__c = opportunity.Id
            );
            insert sourceHistory;

            Product2 recurringProduct = ContractTestDataFactory.buildProduct('Renew One Time Only Recurring');
            recurringProduct.BillingType__c = '継続課金';
            recurringProduct.invoicetype__c = '一括前払';
            ContractTestDataFactory.insertProduct(recurringProduct);

            Product2 oneTimeProduct = ContractTestDataFactory.buildProduct('Renew One Time Only Fee');
            oneTimeProduct.BillingType__c = '一回課金';
            ContractTestDataFactory.insertProduct(oneTimeProduct);

            insert new ContractProduct__c(
                ContractHistory__c = sourceHistory.Id,
                Product__c = recurringProduct.Id,
                Quantity__c = 1,
                UnitPrice__c = 8000,
                StartDate__c = termStart,
                Enddate__c = termEnd,
                InvoiceSetting__c = '一括前払',
                Type__c = 'New'
            );

            EstimateCreateController.ProductLineItem oneTimeLine =
                new EstimateCreateController.ProductLineItem();
            oneTimeLine.productId = oneTimeProduct.Id;
            oneTimeLine.quantity = 1;
            oneTimeLine.unitPrice = 50000;
            oneTimeLine.amount = 50000;
            oneTimeLine.startDate = String.valueOf(renewStart);
            oneTimeLine.endDate = String.valueOf(renewEnd);
            oneTimeLine.invoiceType = '一回課金_開始日請求';
            oneTimeLine.billingType = '一回課金';
            oneTimeLine.recordType = 'New';

            Boolean thrown = false;
            try {
                EstimateCreateController.saveEstimate(
                    opportunity.Id,
                    'Renew',
                    null,
                    'Renew One Time Only Estimate',
                    service.Id,
                    sourceHistory.Id,
                    String.valueOf(renewStart),
                    String.valueOf(renewEnd),
                    String.valueOf(termEnd.addDays(1)),
                    String.valueOf(Date.today()),
                    JSON.serialize(
                        new List<EstimateCreateController.ProductLineItem>{ oneTimeLine }
                    ),
                    null,
                    null,
                    null,
                    null
                );
            } catch (Exception ex) {
                thrown = true;
            }
            System.assertEquals(true, thrown);
        }
    }

    @IsTest
    static void saveEstimate_createsRecordsForCancelType() {
        System.runAs(ContractTestDataFactory.getAdminUser()) {
        Account testAccount = ContractTestDataFactory.insertAccount('Test Account');
        Opportunity opportunity = ContractTestDataFactory.insertOpportunity(
            testAccount.Id,
            'Test Opportunity'
        );

        ContractService__c service = new ContractService__c(
            Name = 'Cancel Test Service',
            Account__c = opportunity.AccountId
        );
        insert service;

        Date termStart = Date.newInstance(2025, 6, 1);
        Date termEnd = Date.newInstance(2026, 5, 31);
        Date cancelDate = Date.newInstance(2026, 6, 1);

        ContractHistory__c sourceHistory = new ContractHistory__c(
            Name = 'Source History',
            ContractService__c = service.Id,
            Type__c = 'New',
            historystatus__c = 'Ordered',
            Version__c = 1,
            CurrentTermStartDate__c = termStart,
            CurrentTermEndDate__c = termEnd,
            Opportunity__c = opportunity.Id
        );
        insert sourceHistory;

        Product2 recurringProduct = ContractTestDataFactory.buildProduct('Cancel Source Recurring');
        recurringProduct.BillingType__c = '継続課金';
        recurringProduct.invoicetype__c = '一括前払';
        ContractTestDataFactory.insertProduct(recurringProduct);

        insert new ContractProduct__c(
            ContractHistory__c = sourceHistory.Id,
            Product__c = recurringProduct.Id,
            Quantity__c = 1,
            UnitPrice__c = 8000,
            StartDate__c = termStart,
            Enddate__c = termEnd,
            InvoiceSetting__c = '一括前払',
            Type__c = 'New'
        );

        Test.startTest();
        EstimateCreateController.EstimateSaveResult result = EstimateCreateController.saveEstimate(
            opportunity.Id,
            'Cancel',
            null,
            'Cancel Churn',
            service.Id,
            sourceHistory.Id,
            String.valueOf(cancelDate),
            String.valueOf(cancelDate),
            String.valueOf(termEnd.addDays(1)),
            String.valueOf(Date.today()),
            '[]',
            null,
            null,
            null,
            null
        );
        Test.stopTest();

        System.assertEquals(service.Id, result.contractServiceId);
        System.assertNotEquals(null, result.contractHistoryId);
        System.assertEquals(0, result.contractProductIds.size());

        ContractHistory__c cancelHistory = [
            SELECT Type__c, historystatus__c, Version__c,
                CurrentTermStartDate__c, CurrentTermEndDate__c, PreviousHistory__c
            FROM ContractHistory__c
            WHERE Id = :result.contractHistoryId
        ];
        System.assertEquals('Cancel', cancelHistory.Type__c);
        System.assertEquals('Ordered', cancelHistory.historystatus__c);
        System.assertEquals(2, cancelHistory.Version__c);
        System.assertEquals(sourceHistory.Id, cancelHistory.PreviousHistory__c);
        System.assertEquals(cancelDate, cancelHistory.CurrentTermStartDate__c);
        System.assertEquals(cancelDate, cancelHistory.CurrentTermEndDate__c);

        ContractService__c updatedService = [
            SELECT FirstOrderedHistory__c, LatestOrderedHistory__c
            FROM ContractService__c
            WHERE Id = :service.Id
        ];
        System.assertEquals(sourceHistory.Id, updatedService.FirstOrderedHistory__c);
        System.assertEquals(result.contractHistoryId, updatedService.LatestOrderedHistory__c);
        }
    }

    @IsTest
    static void getLatestContractHistory_returnsRenewEligibleFlag() {
        System.runAs(ContractTestDataFactory.getAdminUser()) {
            Account account = ContractTestDataFactory.insertAccount('Renew Eligible Account');
            ContractService__c service = new ContractService__c(
                Name = 'Renew Eligible Service',
                Account__c = account.Id
            );
            insert service;

            Date termStart = Date.newInstance(2025, 6, 1);
            Date termEnd = Date.newInstance(2026, 5, 31);

            ContractHistory__c recurringHistory = new ContractHistory__c(
                Name = 'Renew Source',
                ContractService__c = service.Id,
                Type__c = 'New',
                historystatus__c = 'Ordered',
                Version__c = 1,
                CurrentTermStartDate__c = termStart,
                CurrentTermEndDate__c = termEnd
            );
            insert recurringHistory;

            Product2 recurringProduct = ContractTestDataFactory.buildProduct('Renew Eligible Product');
            recurringProduct.BillingType__c = '継続課金';
            recurringProduct.invoicetype__c = '一括前払';
            ContractTestDataFactory.insertProduct(recurringProduct);

            insert new ContractProduct__c(
                ContractHistory__c = recurringHistory.Id,
                Product__c = recurringProduct.Id,
                Quantity__c = 1,
                UnitPrice__c = 8000,
                StartDate__c = termStart,
                Enddate__c = termEnd,
                InvoiceSetting__c = '一括前払',
                Type__c = 'New'
            );

            EstimateCreateController.ContractHistoryDto result =
                EstimateCreateController.getLatestContractHistory(service.Id);

            System.assertEquals(true, result.renewEligible);
        }
    }

    @IsTest
    static void saveEstimate_renew_rejectsWhenNoRecurringSource() {
        System.runAs(ContractTestDataFactory.getAdminUser()) {
            Account account = ContractTestDataFactory.insertAccount('Renew Reject Account');
            Opportunity opportunity = ContractTestDataFactory.insertOpportunity(
                account.Id,
                'Renew Reject Opportunity'
            );
            ContractService__c service = new ContractService__c(
                Name = 'Renew Reject Service',
                Account__c = account.Id
            );
            insert service;

            Date termStart = Date.newInstance(2025, 6, 1);
            Date termEnd = Date.newInstance(2026, 5, 31);
            Date renewStart = Date.newInstance(2026, 6, 1);
            Date renewEnd = Date.newInstance(2027, 5, 31);

            ContractHistory__c sourceHistory = new ContractHistory__c(
                Name = 'One Time Source',
                ContractService__c = service.Id,
                Type__c = 'New',
                historystatus__c = 'Ordered',
                Version__c = 1,
                CurrentTermStartDate__c = termStart,
                CurrentTermEndDate__c = termEnd,
                Opportunity__c = opportunity.Id
            );
            insert sourceHistory;

            Product2 oneTimeProduct = ContractTestDataFactory.buildProduct('One Time Product');
            oneTimeProduct.BillingType__c = '一回課金';
            ContractTestDataFactory.insertProduct(oneTimeProduct);

            insert new ContractProduct__c(
                ContractHistory__c = sourceHistory.Id,
                Product__c = oneTimeProduct.Id,
                Quantity__c = 1,
                UnitPrice__c = 100000,
                StartDate__c = termStart,
                Enddate__c = termEnd,
                InvoiceSetting__c = ContractMetadataService.INVOICE_SETTING_PREPAID_START,
                Type__c = 'New'
            );

            EstimateCreateController.ProductLineItem renewLine =
                new EstimateCreateController.ProductLineItem();
            renewLine.productId = oneTimeProduct.Id;
            renewLine.quantity = 1;
            renewLine.unitPrice = 100000;
            renewLine.amount = 100000;
            renewLine.startDate = String.valueOf(renewStart);
            renewLine.endDate = String.valueOf(renewEnd);
            renewLine.invoiceType = '一回課金_開始日請求';
            renewLine.billingType = '一回課金';
            renewLine.recordType = 'Renew';

            Boolean thrown = false;
            try {
                EstimateCreateController.saveEstimate(
                    opportunity.Id,
                    'Renew',
                    null,
                    'Renew Reject',
                    service.Id,
                    sourceHistory.Id,
                    String.valueOf(renewStart),
                    String.valueOf(renewEnd),
                    String.valueOf(renewStart),
                    String.valueOf(Date.today()),
                    JSON.serialize(new List<EstimateCreateController.ProductLineItem>{ renewLine }),
                    null,
                    null,
                    null,
                    null
                );
            } catch (Exception ex) {
                thrown = true;
            }
            System.assertEquals(true, thrown);
        }
    }

    @IsTest
    static void saveEstimate_renew_rejectsWrongPeriodStart() {
        System.runAs(ContractTestDataFactory.getAdminUser()) {
            Account account = ContractTestDataFactory.insertAccount('Renew Start Account');
            Opportunity opportunity = ContractTestDataFactory.insertOpportunity(
                account.Id,
                'Renew Start Opportunity'
            );
            ContractService__c service = new ContractService__c(
                Name = 'Renew Start Service',
                Account__c = account.Id
            );
            insert service;

            Date termStart = Date.newInstance(2025, 6, 1);
            Date termEnd = Date.newInstance(2026, 5, 31);
            Date wrongStart = Date.newInstance(2026, 7, 1);
            Date renewEnd = Date.newInstance(2027, 6, 30);

            ContractHistory__c sourceHistory = new ContractHistory__c(
                Name = 'Renew Source',
                ContractService__c = service.Id,
                Type__c = 'New',
                historystatus__c = 'Ordered',
                Version__c = 1,
                CurrentTermStartDate__c = termStart,
                CurrentTermEndDate__c = termEnd,
                Opportunity__c = opportunity.Id
            );
            insert sourceHistory;

            Product2 product = ContractTestDataFactory.buildProduct('Renew Product');
            product.BillingType__c = '継続課金';
            product.invoicetype__c = '一括前払';
            ContractTestDataFactory.insertProduct(product);

            insert new ContractProduct__c(
                ContractHistory__c = sourceHistory.Id,
                Product__c = product.Id,
                Quantity__c = 1,
                UnitPrice__c = 8000,
                StartDate__c = termStart,
                Enddate__c = termEnd,
                InvoiceSetting__c = '一括前払',
                Type__c = 'New'
            );

            EstimateCreateController.ProductLineItem renewLine =
                new EstimateCreateController.ProductLineItem();
            renewLine.productId = product.Id;
            renewLine.quantity = 1;
            renewLine.unitPrice = 8000;
            renewLine.amount = 96000;
            renewLine.startDate = String.valueOf(wrongStart);
            renewLine.endDate = String.valueOf(renewEnd);
            renewLine.invoiceType = '一括前払';
            renewLine.billingType = '継続課金';
            renewLine.billingCycle = '月';
            renewLine.recordType = 'Renew';

            Boolean thrown = false;
            try {
                EstimateCreateController.saveEstimate(
                    opportunity.Id,
                    'Renew',
                    null,
                    'Renew Wrong Start',
                    service.Id,
                    sourceHistory.Id,
                    String.valueOf(wrongStart),
                    String.valueOf(renewEnd),
                    String.valueOf(wrongStart),
                    String.valueOf(Date.today()),
                    JSON.serialize(new List<EstimateCreateController.ProductLineItem>{ renewLine }),
                    null,
                    null,
                    null,
                    null
                );
            } catch (Exception ex) {
                thrown = true;
            }
            System.assertEquals(true, thrown);
        }
    }

    @IsTest
    static void saveEstimate_renew_rejectsOverlappingSameProduct() {
        System.runAs(ContractTestDataFactory.getAdminUser()) {
            Account account = ContractTestDataFactory.insertAccount('Renew Overlap Account');
            Opportunity opportunity = ContractTestDataFactory.insertOpportunity(
                account.Id,
                'Renew Overlap Opportunity'
            );
            ContractService__c service = new ContractService__c(
                Name = 'Renew Overlap Service',
                Account__c = account.Id
            );
            insert service;

            Date termStart = Date.newInstance(2025, 6, 1);
            Date termEnd = Date.newInstance(2026, 5, 31);
            Date renewStart = Date.newInstance(2026, 6, 1);
            Date renewEnd = Date.newInstance(2027, 5, 31);

            ContractHistory__c sourceHistory = new ContractHistory__c(
                Name = 'Renew Overlap Source',
                ContractService__c = service.Id,
                Type__c = 'New',
                historystatus__c = 'Ordered',
                Version__c = 1,
                CurrentTermStartDate__c = termStart,
                CurrentTermEndDate__c = termEnd,
                Opportunity__c = opportunity.Id
            );
            insert sourceHistory;

            Product2 product = ContractTestDataFactory.buildProduct('Renew Overlap Product');
            product.BillingType__c = '継続課金';
            product.invoicetype__c = '一括前払';
            ContractTestDataFactory.insertProduct(product);

            insert new ContractProduct__c(
                ContractHistory__c = sourceHistory.Id,
                Product__c = product.Id,
                Quantity__c = 1,
                UnitPrice__c = 8000,
                StartDate__c = termStart,
                Enddate__c = termEnd,
                InvoiceSetting__c = '一括前払',
                Type__c = 'New'
            );

            EstimateCreateController.ProductLineItem renewLine =
                new EstimateCreateController.ProductLineItem();
            renewLine.productId = product.Id;
            renewLine.quantity = 1;
            renewLine.unitPrice = 8000;
            renewLine.amount = 96000;
            renewLine.startDate = String.valueOf(renewStart);
            renewLine.endDate = String.valueOf(renewEnd);
            renewLine.invoiceType = '一括前払';
            renewLine.billingType = '継続課金';
            renewLine.billingCycle = '月';
            renewLine.recordType = 'Renew';

            EstimateCreateController.ProductLineItem newLine =
                new EstimateCreateController.ProductLineItem();
            newLine.productId = product.Id;
            newLine.quantity = 2;
            newLine.unitPrice = 8000;
            newLine.amount = 192000;
            newLine.startDate = String.valueOf(renewStart);
            newLine.endDate = String.valueOf(renewEnd);
            newLine.invoiceType = '一括前払';
            newLine.billingType = '継続課金';
            newLine.billingCycle = '月';
            newLine.recordType = 'New';

            Boolean thrown = false;
            try {
                EstimateCreateController.saveEstimate(
                    opportunity.Id,
                    'Renew',
                    null,
                    'Renew Overlap',
                    service.Id,
                    sourceHistory.Id,
                    String.valueOf(renewStart),
                    String.valueOf(renewEnd),
                    String.valueOf(renewStart),
                    String.valueOf(Date.today()),
                    JSON.serialize(
                        new List<EstimateCreateController.ProductLineItem>{ renewLine, newLine }
                    ),
                    null,
                    null,
                    null,
                    null
                );
            } catch (Exception ex) {
                thrown = true;
            }
            System.assertEquals(true, thrown);
        }
    }

    @IsTest
    static void saveEstimate_cancel_rejectsWhenNoRecurringSource() {
        System.runAs(ContractTestDataFactory.getAdminUser()) {
            Account account = ContractTestDataFactory.insertAccount('Cancel Reject Account');
            Opportunity opportunity = ContractTestDataFactory.insertOpportunity(
                account.Id,
                'Cancel Reject Opportunity'
            );
            ContractService__c service = new ContractService__c(
                Name = 'Cancel Reject Service',
                Account__c = account.Id
            );
            insert service;

            Date termStart = Date.newInstance(2025, 6, 1);
            Date termEnd = Date.newInstance(2026, 5, 31);
            Date cancelDate = Date.newInstance(2026, 6, 1);

            ContractHistory__c sourceHistory = new ContractHistory__c(
                Name = 'Cancel One Time Source',
                ContractService__c = service.Id,
                Type__c = 'New',
                historystatus__c = 'Ordered',
                Version__c = 1,
                CurrentTermStartDate__c = termStart,
                CurrentTermEndDate__c = termEnd,
                Opportunity__c = opportunity.Id
            );
            insert sourceHistory;

            Boolean thrown = false;
            try {
                EstimateCreateController.saveEstimate(
                    opportunity.Id,
                    'Cancel',
                    null,
                    'Cancel Reject',
                    service.Id,
                    sourceHistory.Id,
                    String.valueOf(cancelDate),
                    String.valueOf(cancelDate),
                    String.valueOf(cancelDate),
                    String.valueOf(Date.today()),
                    '[]',
                    null,
                    null,
                    null,
                    null
                );
            } catch (Exception ex) {
                thrown = true;
            }
            System.assertEquals(true, thrown);
        }
    }

    @IsTest
    static void saveEstimate_cancel_rejectsFromChurnHistory() {
        System.runAs(ContractTestDataFactory.getAdminUser()) {
            Account account = ContractTestDataFactory.insertAccount('Cancel Churn Account');
            Opportunity opportunity = ContractTestDataFactory.insertOpportunity(
                account.Id,
                'Cancel Churn Opportunity'
            );
            ContractService__c service = new ContractService__c(
                Name = 'Cancel Churn Service',
                Account__c = account.Id
            );
            insert service;

            Date termStart = Date.newInstance(2025, 6, 1);
            Date termEnd = Date.newInstance(2026, 5, 31);
            Date cancelDate = Date.newInstance(2026, 6, 1);

            ContractHistory__c churnHistory = new ContractHistory__c(
                Name = 'Already Churned',
                ContractService__c = service.Id,
                Type__c = 'Cancel',
                historystatus__c = 'Ordered',
                Version__c = 1,
                CurrentTermStartDate__c = cancelDate,
                CurrentTermEndDate__c = cancelDate,
                Opportunity__c = opportunity.Id
            );
            insert churnHistory;

            Boolean thrown = false;
            try {
                EstimateCreateController.saveEstimate(
                    opportunity.Id,
                    'Cancel',
                    null,
                    'Cancel From Churn',
                    service.Id,
                    churnHistory.Id,
                    String.valueOf(cancelDate),
                    String.valueOf(cancelDate),
                    String.valueOf(cancelDate),
                    String.valueOf(Date.today()),
                    '[]',
                    null,
                    null,
                    null,
                    null
                );
            } catch (Exception ex) {
                thrown = true;
            }
            System.assertEquals(true, thrown);
        }
    }

    @IsTest
    static void saveEstimate_cancel_rejectsProductsInPayload() {
        System.runAs(ContractTestDataFactory.getAdminUser()) {
            Account account = ContractTestDataFactory.insertAccount('Cancel Product Account');
            Opportunity opportunity = ContractTestDataFactory.insertOpportunity(
                account.Id,
                'Cancel Product Opportunity'
            );
            ContractService__c service = new ContractService__c(
                Name = 'Cancel Product Service',
                Account__c = account.Id
            );
            insert service;

            Date termStart = Date.newInstance(2025, 6, 1);
            Date termEnd = Date.newInstance(2026, 5, 31);
            Date cancelDate = Date.newInstance(2026, 6, 1);

            ContractHistory__c sourceHistory = new ContractHistory__c(
                Name = 'Cancel Product Source',
                ContractService__c = service.Id,
                Type__c = 'New',
                historystatus__c = 'Ordered',
                Version__c = 1,
                CurrentTermStartDate__c = termStart,
                CurrentTermEndDate__c = termEnd,
                Opportunity__c = opportunity.Id
            );
            insert sourceHistory;

            Product2 recurringProduct = ContractTestDataFactory.buildProduct('Cancel Product Recurring');
            recurringProduct.BillingType__c = '継続課金';
            recurringProduct.invoicetype__c = '一括前払';
            ContractTestDataFactory.insertProduct(recurringProduct);

            insert new ContractProduct__c(
                ContractHistory__c = sourceHistory.Id,
                Product__c = recurringProduct.Id,
                Quantity__c = 1,
                UnitPrice__c = 8000,
                StartDate__c = termStart,
                Enddate__c = termEnd,
                InvoiceSetting__c = '一括前払',
                Type__c = 'New'
            );

            EstimateCreateController.ProductLineItem line =
                new EstimateCreateController.ProductLineItem();
            line.productId = recurringProduct.Id;
            line.quantity = 1;
            line.unitPrice = 8000;
            line.amount = 8000;
            line.startDate = String.valueOf(cancelDate);
            line.endDate = String.valueOf(cancelDate);
            line.invoiceType = '一括前払';
            line.billingType = '継続課金';

            Boolean thrown = false;
            try {
                EstimateCreateController.saveEstimate(
                    opportunity.Id,
                    'Cancel',
                    null,
                    'Cancel With Products',
                    service.Id,
                    sourceHistory.Id,
                    String.valueOf(cancelDate),
                    String.valueOf(cancelDate),
                    String.valueOf(cancelDate),
                    String.valueOf(Date.today()),
                    JSON.serialize(new List<EstimateCreateController.ProductLineItem>{ line }),
                    null,
                    null,
                    null,
                    null
                );
            } catch (Exception ex) {
                thrown = true;
            }
            System.assertEquals(true, thrown);
        }
    }

    @IsTest
    static void saveEstimate_cancel_rejectsWrongCancelDate() {
        System.runAs(ContractTestDataFactory.getAdminUser()) {
            Account account = ContractTestDataFactory.insertAccount('Cancel Date Account');
            Opportunity opportunity = ContractTestDataFactory.insertOpportunity(
                account.Id,
                'Cancel Date Opportunity'
            );
            ContractService__c service = new ContractService__c(
                Name = 'Cancel Date Service',
                Account__c = account.Id
            );
            insert service;

            Date termStart = Date.newInstance(2025, 6, 1);
            Date termEnd = Date.newInstance(2026, 5, 31);
            Date wrongCancelDate = Date.newInstance(2026, 6, 15);

            ContractHistory__c sourceHistory = new ContractHistory__c(
                Name = 'Cancel Date Source',
                ContractService__c = service.Id,
                Type__c = 'New',
                historystatus__c = 'Ordered',
                Version__c = 1,
                CurrentTermStartDate__c = termStart,
                CurrentTermEndDate__c = termEnd,
                Opportunity__c = opportunity.Id
            );
            insert sourceHistory;

            Product2 recurringProduct = ContractTestDataFactory.buildProduct('Cancel Date Recurring');
            recurringProduct.BillingType__c = '継続課金';
            recurringProduct.invoicetype__c = '一括前払';
            ContractTestDataFactory.insertProduct(recurringProduct);

            insert new ContractProduct__c(
                ContractHistory__c = sourceHistory.Id,
                Product__c = recurringProduct.Id,
                Quantity__c = 1,
                UnitPrice__c = 8000,
                StartDate__c = termStart,
                Enddate__c = termEnd,
                InvoiceSetting__c = '一括前払',
                Type__c = 'New'
            );

            Boolean thrown = false;
            try {
                EstimateCreateController.saveEstimate(
                    opportunity.Id,
                    'Cancel',
                    null,
                    'Cancel Wrong Date',
                    service.Id,
                    sourceHistory.Id,
                    String.valueOf(wrongCancelDate),
                    String.valueOf(wrongCancelDate),
                    String.valueOf(wrongCancelDate),
                    String.valueOf(Date.today()),
                    '[]',
                    null,
                    null,
                    null,
                    null
                );
            } catch (Exception ex) {
                thrown = true;
            }
            System.assertEquals(true, thrown);
        }
    }

    @IsTest
    static void saveEstimate_change_allowsUnchangedRemakeFullTerm() {
        System.runAs(ContractTestDataFactory.getAdminUser()) {
            Account account = ContractTestDataFactory.insertAccount('Change Unchanged Account');
            Opportunity opportunity = ContractTestDataFactory.insertOpportunity(
                account.Id,
                'Change Unchanged Opportunity'
            );
            ContractService__c service = new ContractService__c(
                Name = 'Change Unchanged Service',
                Account__c = account.Id
            );
            insert service;

            Date termStart = Date.newInstance(2025, 6, 1);
            Date termEnd = Date.newInstance(2026, 5, 31);
            Date effectiveDate = Date.newInstance(2025, 10, 1);

            ContractHistory__c sourceHistory = new ContractHistory__c(
                Name = 'Change Unchanged Source',
                ContractService__c = service.Id,
                Type__c = 'New',
                historystatus__c = 'Ordered',
                Version__c = 1,
                CurrentTermStartDate__c = termStart,
                CurrentTermEndDate__c = termEnd,
                Opportunity__c = opportunity.Id
            );
            insert sourceHistory;

            Product2 product = ContractTestDataFactory.buildProduct('Change Unchanged Product');
            product.BillingType__c = '継続課金';
            product.invoicetype__c = '一括前払';
            ContractTestDataFactory.insertProduct(product);

            ContractProduct__c sourceProduct = new ContractProduct__c(
                ContractHistory__c = sourceHistory.Id,
                Product__c = product.Id,
                Quantity__c = 2,
                UnitPrice__c = 5000,
                StartDate__c = termStart,
                Enddate__c = termEnd,
                InvoiceSetting__c = '一括前払',
                Type__c = 'New'
            );
            insert sourceProduct;

            EstimateCreateController.ProductLineItem beforeLine =
                new EstimateCreateController.ProductLineItem();
            beforeLine.productId = product.Id;
            beforeLine.quantity = 2;
            beforeLine.unitPrice = 5000;
            beforeLine.amount = -120000;
            beforeLine.startDate = String.valueOf(termStart);
            beforeLine.endDate = String.valueOf(termEnd);
            beforeLine.invoiceType = '一括前払';
            beforeLine.billingType = '継続課金';
            beforeLine.billingCycle = '月';
            beforeLine.recordType = 'Original';
            beforeLine.sourceContractProductId = sourceProduct.Id;

            EstimateCreateController.ProductLineItem afterLine =
                new EstimateCreateController.ProductLineItem();
            afterLine.productId = product.Id;
            afterLine.quantity = 2;
            afterLine.unitPrice = 5000;
            afterLine.amount = 120000;
            afterLine.startDate = String.valueOf(termStart);
            afterLine.endDate = String.valueOf(termEnd);
            afterLine.invoiceType = '一括前払';
            afterLine.billingType = '継続課金';
            afterLine.billingCycle = '月';
            afterLine.recordType = 'Remake';
            afterLine.sourceContractProductId = sourceProduct.Id;

            EstimateCreateController.EstimateSaveResult result =
                EstimateCreateController.saveEstimate(
                    opportunity.Id,
                    'Change',
                    null,
                    'Change Unchanged Estimate',
                    service.Id,
                    sourceHistory.Id,
                    String.valueOf(termStart),
                    String.valueOf(termEnd),
                    String.valueOf(effectiveDate),
                    String.valueOf(Date.today()),
                    JSON.serialize(
                        new List<EstimateCreateController.ProductLineItem>{ beforeLine, afterLine }
                    ),
                    null,
                    null,
                    null,
                    null
                );

            System.assertNotEquals(null, result.contractHistoryId);
        }
    }

    @IsTest
    static void saveEstimate_change_allowsChangeBeforeEffectiveWithFullTermRemake() {
        System.runAs(ContractTestDataFactory.getAdminUser()) {
            Account account = ContractTestDataFactory.insertAccount('Change Before Effective Account');
            Opportunity opportunity = ContractTestDataFactory.insertOpportunity(
                account.Id,
                'Change Before Effective Opportunity'
            );
            ContractService__c service = new ContractService__c(
                Name = 'Change Before Effective Service',
                Account__c = account.Id
            );
            insert service;

            Date termStart = Date.newInstance(2025, 6, 1);
            Date termEnd = Date.newInstance(2026, 5, 31);
            Date effectiveDate = Date.newInstance(2025, 10, 1);

            ContractHistory__c sourceHistory = new ContractHistory__c(
                Name = 'Change Before Effective Source',
                ContractService__c = service.Id,
                Type__c = 'New',
                historystatus__c = 'Ordered',
                Version__c = 1,
                CurrentTermStartDate__c = termStart,
                CurrentTermEndDate__c = termEnd,
                Opportunity__c = opportunity.Id
            );
            insert sourceHistory;

            Product2 product = ContractTestDataFactory.buildProduct('Change Before Effective Product');
            product.BillingType__c = '継続課金';
            product.invoicetype__c = '一括前払';
            ContractTestDataFactory.insertProduct(product);

            ContractProduct__c sourceProduct = new ContractProduct__c(
                ContractHistory__c = sourceHistory.Id,
                Product__c = product.Id,
                Quantity__c = 2,
                UnitPrice__c = 5000,
                StartDate__c = termStart,
                Enddate__c = termEnd,
                InvoiceSetting__c = '一括前払',
                Type__c = 'New'
            );
            insert sourceProduct;

            EstimateCreateController.ProductLineItem beforeLine =
                new EstimateCreateController.ProductLineItem();
            beforeLine.productId = product.Id;
            beforeLine.quantity = 2;
            beforeLine.unitPrice = 5000;
            beforeLine.amount = -120000;
            beforeLine.startDate = String.valueOf(termStart);
            beforeLine.endDate = String.valueOf(termEnd);
            beforeLine.invoiceType = '一括前払';
            beforeLine.billingType = '継続課金';
            beforeLine.billingCycle = '月';
            beforeLine.recordType = 'Original';
            beforeLine.sourceContractProductId = sourceProduct.Id;

            EstimateCreateController.ProductLineItem afterLine =
                new EstimateCreateController.ProductLineItem();
            afterLine.productId = product.Id;
            afterLine.quantity = 3;
            afterLine.unitPrice = 5000;
            afterLine.amount = 180000;
            afterLine.startDate = String.valueOf(termStart);
            afterLine.endDate = String.valueOf(termEnd);
            afterLine.invoiceType = '一括前払';
            afterLine.billingType = '継続課金';
            afterLine.billingCycle = '月';
            afterLine.recordType = 'Remake';
            afterLine.sourceContractProductId = sourceProduct.Id;

            EstimateCreateController.EstimateSaveResult result =
                EstimateCreateController.saveEstimate(
                    opportunity.Id,
                    'Change',
                    null,
                    'Change Before Effective',
                    service.Id,
                    sourceHistory.Id,
                    String.valueOf(termStart),
                    String.valueOf(termEnd),
                    String.valueOf(effectiveDate),
                    String.valueOf(Date.today()),
                    JSON.serialize(
                        new List<EstimateCreateController.ProductLineItem>{ beforeLine, afterLine }
                    ),
                    null,
                    null,
                    null,
                    null
                );

            System.assertNotEquals(null, result.contractHistoryId);

            List<ContractProduct__c> savedProducts = [
                SELECT Type__c, StartDate__c, Enddate__c, Quantity__c, UnitPrice__c
                FROM ContractProduct__c
                WHERE ContractHistory__c = :result.contractHistoryId
                ORDER BY Type__c DESC
            ];
            System.assertEquals(2, savedProducts.size());
            System.assertEquals('Remake', savedProducts[0].Type__c);
            System.assertEquals(effectiveDate, savedProducts[0].StartDate__c);
            System.assertEquals(termEnd, savedProducts[0].Enddate__c);
            System.assertEquals(3, savedProducts[0].Quantity__c);
        }
    }

    @IsTest
    static void saveEstimate_change_allowsSplitReconstitutionWithNewLine() {
        System.runAs(ContractTestDataFactory.getAdminUser()) {
            Account account = ContractTestDataFactory.insertAccount('Change Split Account');
            Opportunity opportunity = ContractTestDataFactory.insertOpportunity(
                account.Id,
                'Change Split Opportunity'
            );
            ContractService__c service = new ContractService__c(
                Name = 'Change Split Service',
                Account__c = account.Id
            );
            insert service;

            Date termStart = Date.newInstance(2026, 4, 1);
            Date termEnd = Date.newInstance(2027, 3, 31);
            Date effectiveDate = Date.newInstance(2026, 5, 1);
            Date preEffectiveEnd = Date.newInstance(2026, 4, 30);

            ContractHistory__c sourceHistory = new ContractHistory__c(
                Name = 'Change Split Source',
                ContractService__c = service.Id,
                Type__c = 'New',
                historystatus__c = 'Ordered',
                Version__c = 1,
                CurrentTermStartDate__c = termStart,
                CurrentTermEndDate__c = termEnd,
                Opportunity__c = opportunity.Id
            );
            insert sourceHistory;

            Product2 product = ContractTestDataFactory.buildProduct('Change Split Product');
            product.BillingType__c = '継続課金';
            product.invoicetype__c = '一括前払';
            ContractTestDataFactory.insertProduct(product);

            ContractProduct__c sourceProduct = new ContractProduct__c(
                ContractHistory__c = sourceHistory.Id,
                Product__c = product.Id,
                Quantity__c = 1,
                UnitPrice__c = 30000,
                StartDate__c = termStart,
                Enddate__c = termEnd,
                InvoiceSetting__c = '一括前払',
                Type__c = 'New'
            );
            insert sourceProduct;

            EstimateCreateController.ProductLineItem beforeLine =
                new EstimateCreateController.ProductLineItem();
            beforeLine.productId = product.Id;
            beforeLine.quantity = 1;
            beforeLine.unitPrice = 30000;
            beforeLine.amount = -360000;
            beforeLine.startDate = String.valueOf(termStart);
            beforeLine.endDate = String.valueOf(termEnd);
            beforeLine.invoiceType = '一括前払';
            beforeLine.billingType = '継続課金';
            beforeLine.billingCycle = '月';
            beforeLine.recordType = 'Original';
            beforeLine.sourceContractProductId = sourceProduct.Id;

            EstimateCreateController.ProductLineItem derivativeLine =
                new EstimateCreateController.ProductLineItem();
            derivativeLine.productId = product.Id;
            derivativeLine.quantity = 1;
            derivativeLine.unitPrice = 30000;
            derivativeLine.amount = 30000;
            derivativeLine.startDate = String.valueOf(termStart);
            derivativeLine.endDate = String.valueOf(preEffectiveEnd);
            derivativeLine.invoiceType = '一括前払';
            derivativeLine.billingType = '継続課金';
            derivativeLine.billingCycle = '月';
            derivativeLine.recordType = 'Remake';
            derivativeLine.sourceContractProductId = sourceProduct.Id;

            EstimateCreateController.ProductLineItem newLine =
                new EstimateCreateController.ProductLineItem();
            newLine.productId = product.Id;
            newLine.quantity = 1;
            newLine.unitPrice = 50000;
            newLine.amount = 550000;
            newLine.startDate = String.valueOf(effectiveDate);
            newLine.endDate = String.valueOf(termEnd);
            newLine.invoiceType = '一括前払';
            newLine.billingType = '継続課金';
            newLine.billingCycle = '月';
            newLine.recordType = 'New';
            newLine.typeLabel = 'New';

            EstimateCreateController.EstimateSaveResult result =
                EstimateCreateController.saveEstimate(
                    opportunity.Id,
                    'Change',
                    null,
                    'Change Split Estimate',
                    service.Id,
                    sourceHistory.Id,
                    String.valueOf(termStart),
                    String.valueOf(termEnd),
                    String.valueOf(effectiveDate),
                    String.valueOf(Date.today()),
                    JSON.serialize(
                        new List<EstimateCreateController.ProductLineItem>{
                            beforeLine,
                            derivativeLine,
                            newLine
                        }
                    ),
                    null,
                    null,
                    null,
                    null
                );

            System.assertNotEquals(null, result.contractHistoryId);

            List<ContractProduct__c> savedProducts = [
                SELECT Type__c, StartDate__c, Enddate__c, UnitPrice__c
                FROM ContractProduct__c
                WHERE ContractHistory__c = :result.contractHistoryId
                ORDER BY Type__c DESC
            ];
            System.assertEquals(2, savedProducts.size());
            System.assertEquals('Remake', savedProducts[0].Type__c);
            System.assertEquals(effectiveDate, savedProducts[0].StartDate__c);
            System.assertEquals(termEnd, savedProducts[0].Enddate__c);
            System.assertEquals(50000, savedProducts[0].UnitPrice__c);
        }
    }

    @IsTest
    static void saveEstimate_change_rejectsReconstitutionGap() {
        System.runAs(ContractTestDataFactory.getAdminUser()) {
            Account account = ContractTestDataFactory.insertAccount('Change Gap Account');
            Opportunity opportunity = ContractTestDataFactory.insertOpportunity(
                account.Id,
                'Change Gap Opportunity'
            );
            ContractService__c service = new ContractService__c(
                Name = 'Change Gap Service',
                Account__c = account.Id
            );
            insert service;

            Date termStart = Date.newInstance(2026, 4, 1);
            Date termEnd = Date.newInstance(2027, 3, 31);
            Date effectiveDate = Date.newInstance(2026, 5, 1);

            ContractHistory__c sourceHistory = new ContractHistory__c(
                Name = 'Change Gap Source',
                ContractService__c = service.Id,
                Type__c = 'New',
                historystatus__c = 'Ordered',
                Version__c = 1,
                CurrentTermStartDate__c = termStart,
                CurrentTermEndDate__c = termEnd,
                Opportunity__c = opportunity.Id
            );
            insert sourceHistory;

            Product2 product = ContractTestDataFactory.buildProduct('Change Gap Product');
            product.BillingType__c = '継続課金';
            product.invoicetype__c = '一括前払';
            ContractTestDataFactory.insertProduct(product);

            ContractProduct__c sourceProduct = new ContractProduct__c(
                ContractHistory__c = sourceHistory.Id,
                Product__c = product.Id,
                Quantity__c = 1,
                UnitPrice__c = 30000,
                StartDate__c = termStart,
                Enddate__c = termEnd,
                InvoiceSetting__c = '一括前払',
                Type__c = 'New'
            );
            insert sourceProduct;

            EstimateCreateController.ProductLineItem beforeLine =
                new EstimateCreateController.ProductLineItem();
            beforeLine.productId = product.Id;
            beforeLine.quantity = 1;
            beforeLine.unitPrice = 30000;
            beforeLine.amount = -360000;
            beforeLine.startDate = String.valueOf(termStart);
            beforeLine.endDate = String.valueOf(termEnd);
            beforeLine.invoiceType = '一括前払';
            beforeLine.billingType = '継続課金';
            beforeLine.billingCycle = '月';
            beforeLine.recordType = 'Original';
            beforeLine.sourceContractProductId = sourceProduct.Id;

            EstimateCreateController.ProductLineItem derivativeLine =
                new EstimateCreateController.ProductLineItem();
            derivativeLine.productId = product.Id;
            derivativeLine.quantity = 1;
            derivativeLine.unitPrice = 50000;
            derivativeLine.amount = 550000;
            derivativeLine.startDate = String.valueOf(Date.newInstance(2026, 6, 1));
            derivativeLine.endDate = String.valueOf(termEnd);
            derivativeLine.invoiceType = '一括前払';
            derivativeLine.billingType = '継続課金';
            derivativeLine.billingCycle = '月';
            derivativeLine.recordType = 'Remake';
            derivativeLine.sourceContractProductId = sourceProduct.Id;

            Boolean thrown = false;
            try {
                EstimateCreateController.saveEstimate(
                    opportunity.Id,
                    'Change',
                    null,
                    'Change Gap Estimate',
                    service.Id,
                    sourceHistory.Id,
                    String.valueOf(termStart),
                    String.valueOf(termEnd),
                    String.valueOf(effectiveDate),
                    String.valueOf(Date.today()),
                    JSON.serialize(
                        new List<EstimateCreateController.ProductLineItem>{
                            beforeLine,
                            derivativeLine
                        }
                    ),
                    null,
                    null,
                    null,
                    null
                );
            } catch (Exception ex) {
                thrown = true;
            }
            System.assertEquals(true, thrown);
        }
    }

    @IsTest
    static void saveEstimate_change_rejectsTamperedOriginal() {
        System.runAs(ContractTestDataFactory.getAdminUser()) {
            Account account = ContractTestDataFactory.insertAccount('Change Tamper Account');
            Opportunity opportunity = ContractTestDataFactory.insertOpportunity(
                account.Id,
                'Change Tamper Opportunity'
            );
            ContractService__c service = new ContractService__c(
                Name = 'Change Tamper Service',
                Account__c = account.Id
            );
            insert service;

            Date termStart = Date.newInstance(2025, 6, 1);
            Date termEnd = Date.newInstance(2026, 5, 31);

            ContractHistory__c sourceHistory = new ContractHistory__c(
                Name = 'Change Tamper Source',
                ContractService__c = service.Id,
                Type__c = 'New',
                historystatus__c = 'Ordered',
                Version__c = 1,
                CurrentTermStartDate__c = termStart,
                CurrentTermEndDate__c = termEnd,
                Opportunity__c = opportunity.Id
            );
            insert sourceHistory;

            Product2 product = ContractTestDataFactory.buildProduct('Change Tamper Product');
            product.BillingType__c = '継続課金';
            product.invoicetype__c = '一括前払';
            ContractTestDataFactory.insertProduct(product);

            ContractProduct__c sourceProduct = new ContractProduct__c(
                ContractHistory__c = sourceHistory.Id,
                Product__c = product.Id,
                Quantity__c = 2,
                UnitPrice__c = 5000,
                StartDate__c = termStart,
                Enddate__c = termEnd,
                InvoiceSetting__c = '一括前払',
                Type__c = 'New'
            );
            insert sourceProduct;

            EstimateCreateController.ProductLineItem beforeLine =
                new EstimateCreateController.ProductLineItem();
            beforeLine.productId = product.Id;
            beforeLine.quantity = 3;
            beforeLine.unitPrice = 5000;
            beforeLine.amount = -180000;
            beforeLine.startDate = String.valueOf(termStart);
            beforeLine.endDate = String.valueOf(termEnd);
            beforeLine.invoiceType = '一括前払';
            beforeLine.billingType = '継続課金';
            beforeLine.billingCycle = '月';
            beforeLine.recordType = 'Original';
            beforeLine.sourceContractProductId = sourceProduct.Id;

            EstimateCreateController.ProductLineItem afterLine =
                new EstimateCreateController.ProductLineItem();
            afterLine.productId = product.Id;
            afterLine.quantity = 2;
            afterLine.unitPrice = 5000;
            afterLine.amount = 120000;
            afterLine.startDate = String.valueOf(termStart);
            afterLine.endDate = String.valueOf(termEnd);
            afterLine.invoiceType = '一括前払';
            afterLine.billingType = '継続課金';
            afterLine.billingCycle = '月';
            afterLine.recordType = 'Remake';
            afterLine.sourceContractProductId = sourceProduct.Id;

            Boolean thrown = false;
            try {
                EstimateCreateController.saveEstimate(
                    opportunity.Id,
                    'Change',
                    null,
                    'Change Tamper',
                    service.Id,
                    sourceHistory.Id,
                    String.valueOf(termStart),
                    String.valueOf(termEnd),
                    String.valueOf(termStart),
                    String.valueOf(Date.today()),
                    JSON.serialize(
                        new List<EstimateCreateController.ProductLineItem>{ beforeLine, afterLine }
                    ),
                    null,
                    null,
                    null,
                    null
                );
            } catch (Exception ex) {
                thrown = true;
            }
            System.assertEquals(true, thrown);
        }
    }

    @IsTest
    static void saveEstimate_change_rejectsRemakeEndBeforeHeaderEnd() {
        System.runAs(ContractTestDataFactory.getAdminUser()) {
            Account account = ContractTestDataFactory.insertAccount(
                'Change End Endpoint Account'
            );
            Opportunity opportunity = ContractTestDataFactory.insertOpportunity(
                account.Id,
                'Change End Endpoint Opportunity'
            );
            ContractService__c service = new ContractService__c(
                Name = 'Change End Endpoint Service',
                Account__c = account.Id
            );
            insert service;

            Date termStart = Date.newInstance(2025, 6, 1);
            Date termEnd = Date.newInstance(2026, 5, 31);
            Date extendedTermEnd = Date.newInstance(2027, 5, 31);
            Date effectiveDate = Date.newInstance(2025, 10, 1);

            ContractHistory__c sourceHistory = new ContractHistory__c(
                Name = 'Change End Endpoint Source',
                ContractService__c = service.Id,
                Type__c = 'New',
                historystatus__c = 'Ordered',
                Version__c = 1,
                CurrentTermStartDate__c = termStart,
                CurrentTermEndDate__c = termEnd,
                Opportunity__c = opportunity.Id
            );
            insert sourceHistory;

            Product2 product = ContractTestDataFactory.buildProduct(
                'Change End Endpoint Product'
            );
            product.BillingType__c = '継続課金';
            product.invoicetype__c = '一括前払';
            ContractTestDataFactory.insertProduct(product);

            ContractProduct__c sourceProduct = new ContractProduct__c(
                ContractHistory__c = sourceHistory.Id,
                Product__c = product.Id,
                Quantity__c = 2,
                UnitPrice__c = 5000,
                StartDate__c = termStart,
                Enddate__c = termEnd,
                InvoiceSetting__c = '一括前払',
                Type__c = 'New'
            );
            insert sourceProduct;

            EstimateCreateController.ProductLineItem beforeLine =
                new EstimateCreateController.ProductLineItem();
            beforeLine.productId = product.Id;
            beforeLine.quantity = 2;
            beforeLine.unitPrice = 5000;
            beforeLine.amount = -120000;
            beforeLine.startDate = String.valueOf(termStart);
            beforeLine.endDate = String.valueOf(termEnd);
            beforeLine.invoiceType = '一括前払';
            beforeLine.billingType = '継続課金';
            beforeLine.billingCycle = '月';
            beforeLine.recordType = 'Original';
            beforeLine.sourceContractProductId = sourceProduct.Id;

            EstimateCreateController.ProductLineItem afterLine =
                new EstimateCreateController.ProductLineItem();
            afterLine.productId = product.Id;
            afterLine.quantity = 2;
            afterLine.unitPrice = 5000;
            afterLine.amount = 60000;
            afterLine.startDate = String.valueOf(effectiveDate);
            afterLine.endDate = String.valueOf(termEnd);
            afterLine.invoiceType = '一括前払';
            afterLine.billingType = '継続課金';
            afterLine.billingCycle = '月';
            afterLine.recordType = 'Remake';
            afterLine.sourceContractProductId = sourceProduct.Id;

            Boolean thrown = false;
            try {
                EstimateCreateController.saveEstimate(
                    opportunity.Id,
                    'Change',
                    null,
                    'Change End Endpoint',
                    service.Id,
                    sourceHistory.Id,
                    String.valueOf(termStart),
                    String.valueOf(extendedTermEnd),
                    String.valueOf(effectiveDate),
                    String.valueOf(Date.today()),
                    JSON.serialize(
                        new List<EstimateCreateController.ProductLineItem>{
                            beforeLine,
                            afterLine
                        }
                    ),
                    null,
                    null,
                    null,
                    null
                );
            } catch (Exception ex) {
                thrown = true;
            }
            System.assertEquals(true, thrown);
        }
    }

    @IsTest
    static void saveEstimate_change_defaultsMissingRecordTypeToNew() {
        System.runAs(ContractTestDataFactory.getAdminUser()) {
            Account account = ContractTestDataFactory.insertAccount(
                'Change Missing RecordType Account'
            );
            Opportunity opportunity = ContractTestDataFactory.insertOpportunity(
                account.Id,
                'Change Missing RecordType Opportunity'
            );
            ContractService__c service = new ContractService__c(
                Name = 'Change Missing RecordType Service',
                Account__c = account.Id
            );
            insert service;

            Date termStart = Date.newInstance(2025, 6, 1);
            Date termEnd = Date.newInstance(2026, 5, 31);
            Date effectiveDate = Date.newInstance(2025, 10, 1);

            ContractHistory__c sourceHistory = new ContractHistory__c(
                Name = 'Change Missing RecordType Source',
                ContractService__c = service.Id,
                Type__c = 'New',
                historystatus__c = 'Ordered',
                Version__c = 1,
                CurrentTermStartDate__c = termStart,
                CurrentTermEndDate__c = termEnd,
                Opportunity__c = opportunity.Id
            );
            insert sourceHistory;

            Product2 product = ContractTestDataFactory.buildProduct(
                'Change Missing RecordType Product'
            );
            product.BillingType__c = '継続課金';
            product.invoicetype__c = '一括前払';
            ContractTestDataFactory.insertProduct(product);

            Product2 addonProduct = ContractTestDataFactory.buildProduct(
                'Change Missing RecordType Addon'
            );
            addonProduct.BillingType__c = '継続課金';
            addonProduct.invoicetype__c = '一括前払';
            ContractTestDataFactory.insertProduct(addonProduct);

            ContractProduct__c sourceProduct = new ContractProduct__c(
                ContractHistory__c = sourceHistory.Id,
                Product__c = product.Id,
                Quantity__c = 2,
                UnitPrice__c = 5000,
                StartDate__c = termStart,
                Enddate__c = termEnd,
                InvoiceSetting__c = '一括前払',
                Type__c = 'New'
            );
            insert sourceProduct;

            EstimateCreateController.ProductLineItem beforeLine =
                new EstimateCreateController.ProductLineItem();
            beforeLine.productId = product.Id;
            beforeLine.quantity = 2;
            beforeLine.unitPrice = 5000;
            beforeLine.amount = -120000;
            beforeLine.startDate = String.valueOf(termStart);
            beforeLine.endDate = String.valueOf(termEnd);
            beforeLine.invoiceType = '一括前払';
            beforeLine.billingType = '継続課金';
            beforeLine.billingCycle = '月';
            beforeLine.recordType = 'Original';
            beforeLine.sourceContractProductId = sourceProduct.Id;

            EstimateCreateController.ProductLineItem afterLine =
                new EstimateCreateController.ProductLineItem();
            afterLine.productId = product.Id;
            afterLine.quantity = 2;
            afterLine.unitPrice = 5000;
            afterLine.amount = 120000;
            afterLine.startDate = String.valueOf(termStart);
            afterLine.endDate = String.valueOf(termEnd);
            afterLine.invoiceType = '一括前払';
            afterLine.billingType = '継続課金';
            afterLine.billingCycle = '月';
            afterLine.recordType = 'Remake';
            afterLine.sourceContractProductId = sourceProduct.Id;

            EstimateCreateController.ProductLineItem addonLine =
                new EstimateCreateController.ProductLineItem();
            addonLine.productId = addonProduct.Id;
            addonLine.quantity = 1;
            addonLine.unitPrice = 3000;
            addonLine.amount = 60000;
            addonLine.startDate = String.valueOf(effectiveDate);
            addonLine.endDate = String.valueOf(termEnd);
            addonLine.invoiceType = '一括前払';
            addonLine.billingType = '継続課金';
            addonLine.billingCycle = '月';

            EstimateCreateController.EstimateSaveResult result =
                EstimateCreateController.saveEstimate(
                    opportunity.Id,
                    'Change',
                    null,
                    'Change Missing RecordType Estimate',
                    service.Id,
                    sourceHistory.Id,
                    String.valueOf(termStart),
                    String.valueOf(termEnd),
                    String.valueOf(effectiveDate),
                    String.valueOf(Date.today()),
                    JSON.serialize(
                        new List<EstimateCreateController.ProductLineItem>{
                            beforeLine,
                            afterLine,
                            addonLine
                        }
                    ),
                    null,
                    null,
                    null,
                    null
                );

            System.assertNotEquals(null, result.contractHistoryId);

            List<ContractProduct__c> savedProducts = [
                SELECT Type__c
                FROM ContractProduct__c
                WHERE ContractHistory__c = :result.contractHistoryId
                ORDER BY Type__c ASC
            ];
            System.assertEquals(3, savedProducts.size());
            System.assertEquals('New', savedProducts[0].Type__c);
        }
    }

    @IsTest
    static void saveEstimate_rejectsSplitMonthlyInvoiceSettingForOneTime() {
        System.runAs(ContractTestDataFactory.getAdminUser()) {
            Account account = ContractTestDataFactory.insertAccount('One Time Invoice Setting');
            Opportunity opportunity = ContractTestDataFactory.insertOpportunity(
                account.Id,
                'One Time Invoice Opportunity'
            );
            ContractService__c service = new ContractService__c(
                Name = 'One Time Invoice Service',
                Account__c = account.Id
            );
            insert service;

            Product2 oneTimeProduct = ContractTestDataFactory.buildProduct(
                'One Time Split Monthly Product'
            );
            oneTimeProduct.BillingType__c = '一回課金';
            ContractTestDataFactory.insertProduct(oneTimeProduct);

            EstimateCreateController.ProductLineItem lineItem =
                new EstimateCreateController.ProductLineItem();
            lineItem.productId = oneTimeProduct.Id;
            lineItem.quantity = 1;
            lineItem.unitPrice = 10000;
            lineItem.startDate = '2026-06-01';
            lineItem.endDate = '2027-05-31';
            lineItem.invoiceType = '月次分割';
            lineItem.billingType = '一回課金';

            Boolean thrown = false;
            try {
                EstimateCreateController.saveEstimate(
                    opportunity.Id,
                    'New',
                    null,
                    'One Time Split Monthly Estimate',
                    service.Id,
                    null,
                    '2026-06-01',
                    '2027-05-31',
                    '2026-06-01',
                    String.valueOf(Date.today()),
                    JSON.serialize(
                        new List<EstimateCreateController.ProductLineItem>{ lineItem }
                    ),
                    null,
                    null,
                    null,
                    null
                );
            } catch (Exception error) {
                thrown = true;
            }
            System.assertEquals(true, thrown);
        }
    }

    @IsTest
    static void getEstimateCopyPreset_returnsPresetForEstimateHistory() {
        System.runAs(ContractTestDataFactory.getAdminUser()) {
            Account testAccount = ContractTestDataFactory.insertAccount('Copy Test Account');
            Opportunity opportunity = ContractTestDataFactory.insertOpportunity(
                testAccount.Id,
                'Copy Test Opportunity'
            );

            Product2 product = ContractTestDataFactory.buildProduct('Copy Test Product');
            product.UnitName__c = '式';
            product.UnitPrice__c = 10000;
            product.invoicetype__c = '一括前払';
            product.BillingType__c = '継続課金';
            ContractTestDataFactory.insertProduct(product);

            EstimateNoteMaster__c remarkMaster = new EstimateNoteMaster__c(
                Name = 'Copy Remark Master',
                NoteText__c = '見積備考マスタの文面'
            );
            insert remarkMaster;

            EstimateCreateController.ProductLineItem lineItem =
                new EstimateCreateController.ProductLineItem();
            lineItem.productId = product.Id;
            lineItem.quantity = 2;
            lineItem.unitPrice = 10000;
            lineItem.amount = 20000;
            lineItem.startDate = String.valueOf(Date.today());
            lineItem.endDate = String.valueOf(
                Date.today().addMonths(12).addDays(-1)
            );
            lineItem.invoiceType = '一括前払';
            lineItem.unit = '式';
            lineItem.billingType = '継続課金';
            lineItem.billingCycle = '月';
            lineItem.recordType = 'New';

            EstimateCreateController.EstimateSaveResult saveResult =
                EstimateCreateController.saveEstimate(
                    opportunity.Id,
                    'New',
                    'Copy Test Service',
                    'Copy Source History',
                    null,
                    null,
                    String.valueOf(Date.today()),
                    String.valueOf(Date.today().addMonths(12).addDays(-1)),
                    String.valueOf(Date.today()),
                    String.valueOf(Date.today()),
                    JSON.serialize(
                        new List<EstimateCreateController.ProductLineItem>{ lineItem }
                    ),
                    remarkMaster.Id,
                    'コピー元の見積備考',
                    null,
                    null
                );

            Test.startTest();
            EstimateCreateController.EstimateCopyPresetDto preset =
                EstimateCreateController.getEstimateCopyPreset(
                    saveResult.contractHistoryId
                );
            Test.stopTest();

            System.assertEquals(opportunity.Id, preset.opportunityId);
            System.assertEquals('Copy Test Opportunity', preset.opportunityName);
            System.assertEquals('Copy Test Account', preset.accountName);
            System.assertEquals('New', preset.selectedType);
            System.assertEquals('Copy Test Serviceのコピー', preset.contractServiceName);
            System.assertEquals('Copy Source Historyのコピー', preset.contractHistoryName);
            System.assertEquals(null, preset.contractServiceId);
            System.assertEquals(null, preset.contractHistoryId);
            System.assertEquals(1, preset.selectedProducts.size());
            System.assertEquals(product.Id, preset.selectedProducts[0].productId);
            System.assertEquals(2, preset.selectedProducts[0].quantity);
            System.assertEquals(
                String.valueOf(Date.today()),
                preset.contractEffectiveDate
            );
            System.assertEquals(remarkMaster.Id, preset.estimateRemarkMasterId);
            System.assertEquals('コピー元の見積備考', preset.estimateRemarks);
        }
    }

    @IsTest
    static void getEstimateCopyPreset_rejectsNonEstimateHistory() {
        System.runAs(ContractTestDataFactory.getAdminUser()) {
            Account testAccount = ContractTestDataFactory.insertAccount('Reject Copy Account');
            Opportunity opportunity = ContractTestDataFactory.insertOpportunity(
                testAccount.Id,
                'Reject Copy Opportunity'
            );

            ContractService__c service = new ContractService__c(
                Name = 'Reject Copy Service',
                Account__c = testAccount.Id
            );
            insert service;

            ContractHistory__c history = new ContractHistory__c(
                Name = 'Ordered History',
                ContractService__c = service.Id,
                Type__c = 'New',
                historystatus__c = 'Ordered',
                Version__c = 1,
                Opportunity__c = opportunity.Id,
                CurrentTermStartDate__c = Date.today(),
                CurrentTermEndDate__c = Date.today().addYears(1).addDays(-1)
            );
            insert history;

            Boolean thrown = false;
            Test.startTest();
            try {
                EstimateCreateController.getEstimateCopyPreset(history.Id);
            } catch (Exception error) {
                thrown = true;
            }
            Test.stopTest();

            System.assertEquals(true, thrown);
        }
    }

    @IsTest
    static void getEstimateCopyPreset_presetsSameVersionForNonNewCopy() {
        System.runAs(ContractTestDataFactory.getAdminUser()) {
            Account testAccount = ContractTestDataFactory.insertAccount('NonNew Copy Account');
            Opportunity opportunity = ContractTestDataFactory.insertOpportunity(
                testAccount.Id,
                'NonNew Copy Opportunity'
            );

            ContractService__c service = new ContractService__c(
                Name = 'NonNew Copy Service',
                Account__c = testAccount.Id
            );
            insert service;

            Date termStart = Date.newInstance(2025, 6, 1);
            Date termEnd = Date.newInstance(2026, 5, 31);
            Date effectiveDate = Date.newInstance(2025, 10, 1);

            ContractHistory__c sourceHistory = new ContractHistory__c(
                Name = 'NonNew Source History',
                ContractService__c = service.Id,
                Type__c = 'New',
                historystatus__c = 'Ordered',
                Version__c = 1,
                CurrentTermStartDate__c = termStart,
                CurrentTermEndDate__c = termEnd,
                Opportunity__c = opportunity.Id
            );
            insert sourceHistory;

            Product2 product = ContractTestDataFactory.buildProduct('NonNew Copy Product');
            product.UnitName__c = '式';
            product.UnitPrice__c = 5000;
            product.invoicetype__c = '一括前払';
            product.BillingType__c = '継続課金';
            ContractTestDataFactory.insertProduct(product);

            ContractProduct__c sourceProduct = new ContractProduct__c(
                ContractHistory__c = sourceHistory.Id,
                Product__c = product.Id,
                Quantity__c = 2,
                UnitPrice__c = 5000,
                Unit__c = '式/月',
                StartDate__c = termStart,
                Enddate__c = termEnd,
                InvoiceSetting__c = '一括前払',
                Type__c = 'New'
            );
            insert sourceProduct;

            EstimateCreateController.ProductLineItem beforeLine =
                new EstimateCreateController.ProductLineItem();
            beforeLine.productId = product.Id;
            beforeLine.quantity = 2;
            beforeLine.unitPrice = 5000;
            beforeLine.amount = -120000;
            beforeLine.startDate = String.valueOf(termStart);
            beforeLine.endDate = String.valueOf(termEnd);
            beforeLine.invoiceType = '一括前払';
            beforeLine.unit = '式/月';
            beforeLine.billingType = '継続課金';
            beforeLine.billingCycle = '月';
            beforeLine.recordType = 'Original';
            beforeLine.sourceContractProductId = sourceProduct.Id;

            EstimateCreateController.ProductLineItem afterLine =
                new EstimateCreateController.ProductLineItem();
            afterLine.productId = product.Id;
            afterLine.quantity = 3;
            afterLine.unitPrice = 5000;
            afterLine.amount = 180000;
            afterLine.startDate = String.valueOf(effectiveDate);
            afterLine.endDate = String.valueOf(termEnd);
            afterLine.invoiceType = '一括前払';
            afterLine.unit = '式/月';
            afterLine.billingType = '継続課金';
            afterLine.billingCycle = '月';
            afterLine.recordType = 'Remake';
            afterLine.sourceContractProductId = sourceProduct.Id;

            EstimateCreateController.EstimateSaveResult sourceResult =
                EstimateCreateController.saveEstimate(
                    opportunity.Id,
                    'Change',
                    null,
                    'Change Source Estimate',
                    service.Id,
                    sourceHistory.Id,
                    String.valueOf(termStart),
                    String.valueOf(termEnd),
                    String.valueOf(effectiveDate),
                    String.valueOf(Date.today()),
                    JSON.serialize(
                        new List<EstimateCreateController.ProductLineItem>{
                            beforeLine,
                            afterLine
                        }
                    ),
                    null,
                    null,
                    null,
                    null
                );

            Test.startTest();
            EstimateCreateController.EstimateCopyPresetDto preset =
                EstimateCreateController.getEstimateCopyPreset(
                    sourceResult.contractHistoryId
                );
            Test.stopTest();

            System.assertEquals('Change', preset.selectedType);
            System.assertEquals(service.Id, preset.contractServiceId);
            System.assertEquals(sourceHistory.Id, preset.contractHistoryId);
            System.assertEquals(1, preset.baseHistoryVersion);
            System.assertEquals(2, preset.nextHistoryVersion);
            System.assertEquals('Change Source Estimateのコピー', preset.contractHistoryName);
            System.assertEquals(
                String.valueOf(effectiveDate),
                preset.contractEffectiveDate
            );
        }
    }

    @IsTest
    static void getEstimateCopyPreset_presetsEffectiveDateForRenewWithoutEffectiveDate() {
        System.runAs(ContractTestDataFactory.getAdminUser()) {
            Account testAccount = ContractTestDataFactory.insertAccount('Renew Copy Account');
            Opportunity opportunity = ContractTestDataFactory.insertOpportunity(
                testAccount.Id,
                'Renew Copy Opportunity'
            );

            ContractService__c service = new ContractService__c(
                Name = 'Renew Copy Service',
                Account__c = testAccount.Id
            );
            insert service;

            Date termStart = Date.newInstance(2025, 6, 1);
            Date termEnd = Date.newInstance(2026, 5, 31);
            Date renewStart = Date.newInstance(2026, 6, 1);
            Date renewEnd = Date.newInstance(2027, 5, 31);

            ContractHistory__c previousHistory = new ContractHistory__c(
                Name = 'Renew Copy Previous History',
                ContractService__c = service.Id,
                Type__c = 'New',
                historystatus__c = 'Ordered',
                Version__c = 1,
                CurrentTermStartDate__c = termStart,
                CurrentTermEndDate__c = termEnd,
                Opportunity__c = opportunity.Id
            );
            insert previousHistory;

            ContractHistory__c renewHistory = new ContractHistory__c(
                Name = 'Renew Copy Source History',
                ContractService__c = service.Id,
                Type__c = 'Renew',
                historystatus__c = 'Estimate',
                Version__c = 2,
                CurrentTermStartDate__c = renewStart,
                CurrentTermEndDate__c = renewEnd,
                Opportunity__c = opportunity.Id,
                PreviousHistory__c = previousHistory.Id
            );
            insert renewHistory;

            Test.startTest();
            EstimateCreateController.EstimateCopyPresetDto preset =
                EstimateCreateController.getEstimateCopyPreset(renewHistory.Id);
            Test.stopTest();

            System.assertEquals('Renew', preset.selectedType);
            System.assertEquals(
                String.valueOf(renewStart),
                preset.contractStartDate
            );
            System.assertEquals(
                String.valueOf(renewStart),
                preset.contractEffectiveDate
            );
        }
    }

    @IsTest
    static void resolveEstimateHistoryVersion_reusesSourceVersionForCopy() {
        System.runAs(ContractTestDataFactory.getAdminUser()) {
            Account testAccount = ContractTestDataFactory.insertAccount('Copy Version Account');
            Opportunity opportunity = ContractTestDataFactory.insertOpportunity(
                testAccount.Id,
                'Copy Version Opportunity'
            );

            ContractService__c service = new ContractService__c(
                Name = 'Copy Version Service',
                Account__c = testAccount.Id
            );
            insert service;

            Date termStart = Date.newInstance(2025, 6, 1);
            Date termEnd = Date.newInstance(2026, 5, 31);

            ContractHistory__c sourceHistory = new ContractHistory__c(
                Name = 'Copy Version Source History',
                ContractService__c = service.Id,
                Type__c = 'New',
                historystatus__c = 'Ordered',
                Version__c = 1,
                CurrentTermStartDate__c = termStart,
                CurrentTermEndDate__c = termEnd,
                Opportunity__c = opportunity.Id
            );
            insert sourceHistory;

            ContractHistory__c estimateHistory = new ContractHistory__c(
                Name = 'Copy Version Change Estimate',
                ContractService__c = service.Id,
                Type__c = 'Change',
                historystatus__c = 'Estimate',
                Version__c = 2,
                CurrentTermStartDate__c = termStart,
                CurrentTermEndDate__c = termEnd,
                EffectiveDate__c = Date.newInstance(2025, 10, 1),
                Opportunity__c = opportunity.Id,
                PreviousHistory__c = sourceHistory.Id
            );
            insert estimateHistory;

            Test.startTest();
            Decimal resolvedVersion = EstimateCreateController.resolveEstimateHistoryVersion(
                service.Id,
                estimateHistory.Id
            );
            Test.stopTest();

            System.assertEquals(2, resolvedVersion);
        }
    }
}

