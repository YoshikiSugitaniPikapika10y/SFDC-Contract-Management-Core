@IsTest
private class InvoiceProductScenarioTest {
    private static final Date TERM_START = Date.newInstance(2026, 4, 1);
    private static final Date TERM_END = Date.newInstance(2027, 3, 31);
    private static final Date CHANGE_EFFECTIVE_DATE = Date.newInstance(2026, 5, 1);
    private static final Decimal V1_UNIT_PRICE = 30000;
    private static final Decimal V2_UNIT_PRICE = 50000;
    private static final Decimal V2_DIFF_AMOUNT = 20000;
    private static final Decimal V1_QUANTITY = 1;
    private static final Decimal V3_QUANTITY = 2;
    private static final Decimal V3_DIFF_AMOUNT = 70000;
    private static final String INVOICE_SETTING_PREPAID = '一括前払';
    private static final String BILLING_TYPE_RECURRING = '継続課金';
    private static final String PAYMENT_TERM_NEXT_MONTH_END = '翌月末';
    private static final String BILLING_DAY_OF_MONTH = '5';
    private static final Date PRE_EFFECTIVE_END = Date.newInstance(2026, 4, 30);
    private static final Date APRIL_INVOICED_DATE = Date.newInstance(2026, 4, 10);

    @TestSetup
    static void setupAccess() {
        ContractTestDataFactory.initTestContext();
    }

    @IsTest
    static void scenario001_changePriceIncrease_allUninvoiced() {
        System.runAs(ContractTestDataFactory.getAdminUser()) {
            ScenarioContext context = createScenarioContext('Scenario001', false);

            Test.startTest();
            context.changeHistory.historystatus__c = 'Ordered';
            update context.changeHistory;
            Test.stopTest();

            assertV1InvoiceProducts(context.priorHistory.Id, null);
            assertV2ContractProducts(context.changeHistory.Id);
            assertV2InvoiceProducts(context.changeHistory.Id);
            assertServiceInvoiceTotals(context.service.Id);
            assertArr(context.priorHistory.Id, context.changeHistory.Id);
            assertNegativeExpectations(
                context.priorHistory.Id,
                context.changeHistory.Id
            );
        }
    }

    @IsTest
    static void scenario002_changePriceIncrease_aprilInvoiced() {
        System.runAs(ContractTestDataFactory.getAdminUser()) {
            ScenarioContext context = createScenarioContext('Scenario002', true);

            Test.startTest();
            context.changeHistory.historystatus__c = 'Ordered';
            update context.changeHistory;
            Test.stopTest();

            assertV1InvoiceProducts(context.priorHistory.Id, APRIL_INVOICED_DATE);
            assertV2ContractProducts(context.changeHistory.Id);
            assertV2InvoiceProducts(context.changeHistory.Id);
            assertServiceInvoiceTotals(context.service.Id);
            assertArr(context.priorHistory.Id, context.changeHistory.Id);
            assertNegativeExpectations(
                context.priorHistory.Id,
                context.changeHistory.Id
            );
            assertScenario002LockedExpectations(context.priorHistory.Id);
        }
    }

    @IsTest
    static void scenario003_changePriceAndQuantityIncrease_allUninvoiced() {
        System.runAs(ContractTestDataFactory.getAdminUser()) {
            ScenarioContext context = createScenario003Context();

            Test.startTest();
            context.changeHistory.historystatus__c = 'Ordered';
            update context.changeHistory;
            Test.stopTest();

            assertV1InvoiceProducts(context.priorHistory.Id, null);
            assertV3V2ContractProducts(context.changeHistory.Id);
            assertV3V2InvoiceProducts(context.changeHistory.Id);
            assertV3ServiceInvoiceTotals(context.service.Id);
            assertV3Arr(context.priorHistory.Id, context.changeHistory.Id);
            assertNegativeExpectations(
                context.priorHistory.Id,
                context.changeHistory.Id
            );
        }
    }

    private class ScenarioContext {
        public ContractService__c service;
        public ContractHistory__c priorHistory;
        public ContractHistory__c changeHistory;
        public ContractProduct__c priorContractProduct;
        public BillingAccount__c billingAccount;
    }

    private static ScenarioContext createScenarioContext(
        String scenarioName,
        Boolean lockAprilInvoice
    ) {
        Account account = ContractTestDataFactory.insertAccount(scenarioName + ' Account');
        BillingAccount__c billingAccount = new BillingAccount__c(
            Account__c = account.Id,
            PaymentTerm__c = PAYMENT_TERM_NEXT_MONTH_END,
            BillingDayOfMonth__c = BILLING_DAY_OF_MONTH
        );
        insert billingAccount;

        ContractService__c service = new ContractService__c(
            Name = scenarioName + ' Service',
            Account__c = account.Id,
            BiilingAcccount__c = billingAccount.Id
        );
        insert service;

        Product2 product = ContractTestDataFactory.buildProduct(scenarioName + ' Product');
        product.BillingType__c = BILLING_TYPE_RECURRING;
        product.invoicetype__c = INVOICE_SETTING_PREPAID;
        ContractTestDataFactory.insertProduct(product);

        ContractHistory__c priorHistory = new ContractHistory__c(
            Name = scenarioName + ' V1',
            ContractService__c = service.Id,
            Type__c = 'New',
            historystatus__c = 'Ordered',
            Version__c = 1,
            CurrentTermStartDate__c = TERM_START,
            CurrentTermEndDate__c = TERM_END,
            EffectiveDate__c = TERM_START
        );
        insert priorHistory;

        ContractProduct__c priorContractProduct = new ContractProduct__c(
            ContractHistory__c = priorHistory.Id,
            Product__c = product.Id,
            Quantity__c = 1,
            UnitPrice__c = V1_UNIT_PRICE,
            StartDate__c = TERM_START,
            Enddate__c = TERM_END,
            InvoiceSetting__c = INVOICE_SETTING_PREPAID,
            BillingType__c = BILLING_TYPE_RECURRING,
            Type__c = 'New'
        );
        insert priorContractProduct;

        InvoiceProductGenerationService.generateForHistories(
            new Set<Id>{ priorHistory.Id }
        );

        if (lockAprilInvoice) {
            lockAprilV1InvoiceProduct(priorHistory.Id, APRIL_INVOICED_DATE);
        }

        ContractHistory__c changeHistory = new ContractHistory__c(
            Name = scenarioName + ' V2',
            ContractService__c = service.Id,
            Type__c = 'Change',
            historystatus__c = 'Estimate',
            Version__c = 2,
            CurrentTermStartDate__c = TERM_START,
            CurrentTermEndDate__c = TERM_END,
            EffectiveDate__c = CHANGE_EFFECTIVE_DATE,
            PreviousHistory__c = priorHistory.Id
        );
        insert changeHistory;

        insert new List<ContractProduct__c>{
            new ContractProduct__c(
                ContractHistory__c = changeHistory.Id,
                Product__c = product.Id,
                Quantity__c = 1,
                UnitPrice__c = V1_UNIT_PRICE,
                StartDate__c = TERM_START,
                Enddate__c = TERM_END,
                InvoiceSetting__c = INVOICE_SETTING_PREPAID,
                BillingType__c = BILLING_TYPE_RECURRING,
                Type__c = 'Original',
                PreviousContractProduct__c = priorContractProduct.Id
            ),
            new ContractProduct__c(
                ContractHistory__c = changeHistory.Id,
                Product__c = product.Id,
                Quantity__c = 1,
                UnitPrice__c = V1_UNIT_PRICE,
                StartDate__c = TERM_START,
                Enddate__c = PRE_EFFECTIVE_END,
                InvoiceSetting__c = INVOICE_SETTING_PREPAID,
                BillingType__c = BILLING_TYPE_RECURRING,
                Type__c = 'Remake',
                PreviousContractProduct__c = priorContractProduct.Id
            ),
            new ContractProduct__c(
                ContractHistory__c = changeHistory.Id,
                Product__c = product.Id,
                Quantity__c = 1,
                UnitPrice__c = V2_UNIT_PRICE,
                StartDate__c = CHANGE_EFFECTIVE_DATE,
                Enddate__c = TERM_END,
                InvoiceSetting__c = INVOICE_SETTING_PREPAID,
                BillingType__c = BILLING_TYPE_RECURRING,
                Type__c = 'Remake',
                PreviousContractProduct__c = priorContractProduct.Id
            )
        };

        ScenarioContext context = new ScenarioContext();
        context.service = service;
        context.priorHistory = priorHistory;
        context.changeHistory = changeHistory;
        context.priorContractProduct = priorContractProduct;
        context.billingAccount = billingAccount;
        return context;
    }

    private static ScenarioContext createScenario003Context() {
        Account account = ContractTestDataFactory.insertAccount('Scenario003 Account');
        BillingAccount__c billingAccount = new BillingAccount__c(
            Account__c = account.Id,
            PaymentTerm__c = PAYMENT_TERM_NEXT_MONTH_END,
            BillingDayOfMonth__c = BILLING_DAY_OF_MONTH
        );
        insert billingAccount;

        ContractService__c service = new ContractService__c(
            Name = 'Scenario003 Service',
            Account__c = account.Id,
            BiilingAcccount__c = billingAccount.Id
        );
        insert service;

        Product2 product = ContractTestDataFactory.buildProduct('Scenario003 Product');
        product.BillingType__c = BILLING_TYPE_RECURRING;
        product.invoicetype__c = INVOICE_SETTING_PREPAID;
        ContractTestDataFactory.insertProduct(product);

        ContractHistory__c priorHistory = new ContractHistory__c(
            Name = 'Scenario003 V1',
            ContractService__c = service.Id,
            Type__c = 'New',
            historystatus__c = 'Ordered',
            Version__c = 1,
            CurrentTermStartDate__c = TERM_START,
            CurrentTermEndDate__c = TERM_END,
            EffectiveDate__c = TERM_START
        );
        insert priorHistory;

        ContractProduct__c priorContractProduct = new ContractProduct__c(
            ContractHistory__c = priorHistory.Id,
            Product__c = product.Id,
            Quantity__c = V1_QUANTITY,
            UnitPrice__c = V1_UNIT_PRICE,
            StartDate__c = TERM_START,
            Enddate__c = TERM_END,
            InvoiceSetting__c = INVOICE_SETTING_PREPAID,
            BillingType__c = BILLING_TYPE_RECURRING,
            Type__c = 'New'
        );
        insert priorContractProduct;

        InvoiceProductGenerationService.generateForHistories(
            new Set<Id>{ priorHistory.Id }
        );

        ContractHistory__c changeHistory = new ContractHistory__c(
            Name = 'Scenario003 V2',
            ContractService__c = service.Id,
            Type__c = 'Change',
            historystatus__c = 'Estimate',
            Version__c = 2,
            CurrentTermStartDate__c = TERM_START,
            CurrentTermEndDate__c = TERM_END,
            EffectiveDate__c = CHANGE_EFFECTIVE_DATE,
            PreviousHistory__c = priorHistory.Id
        );
        insert changeHistory;

        insert new List<ContractProduct__c>{
            new ContractProduct__c(
                ContractHistory__c = changeHistory.Id,
                Product__c = product.Id,
                Quantity__c = V1_QUANTITY,
                UnitPrice__c = V1_UNIT_PRICE,
                StartDate__c = TERM_START,
                Enddate__c = TERM_END,
                InvoiceSetting__c = INVOICE_SETTING_PREPAID,
                BillingType__c = BILLING_TYPE_RECURRING,
                Type__c = 'Original',
                PreviousContractProduct__c = priorContractProduct.Id
            ),
            new ContractProduct__c(
                ContractHistory__c = changeHistory.Id,
                Product__c = product.Id,
                Quantity__c = V1_QUANTITY,
                UnitPrice__c = V1_UNIT_PRICE,
                StartDate__c = TERM_START,
                Enddate__c = PRE_EFFECTIVE_END,
                InvoiceSetting__c = INVOICE_SETTING_PREPAID,
                BillingType__c = BILLING_TYPE_RECURRING,
                Type__c = 'Remake',
                PreviousContractProduct__c = priorContractProduct.Id
            ),
            new ContractProduct__c(
                ContractHistory__c = changeHistory.Id,
                Product__c = product.Id,
                Quantity__c = V3_QUANTITY,
                UnitPrice__c = V2_UNIT_PRICE,
                StartDate__c = CHANGE_EFFECTIVE_DATE,
                Enddate__c = TERM_END,
                InvoiceSetting__c = INVOICE_SETTING_PREPAID,
                BillingType__c = BILLING_TYPE_RECURRING,
                Type__c = 'Remake',
                PreviousContractProduct__c = priorContractProduct.Id
            )
        };

        ScenarioContext context = new ScenarioContext();
        context.service = service;
        context.priorHistory = priorHistory;
        context.changeHistory = changeHistory;
        context.priorContractProduct = priorContractProduct;
        context.billingAccount = billingAccount;
        return context;
    }

    private static void lockAprilV1InvoiceProduct(
        Id priorHistoryId,
        Date actualInvoiceDate
    ) {
        InvoiceProduct__c aprilInvoice = [
            SELECT Id
            FROM InvoiceProduct__c
            WHERE ContractHistory__c = :priorHistoryId
            AND StartDate__c = :TERM_START
            LIMIT 1
        ];
        aprilInvoice.ActualInvoiceDate__c = actualInvoiceDate;
        update aprilInvoice;
    }

    private static void assertV1InvoiceProducts(
        Id priorHistoryId,
        Date lockedAprilActualInvoiceDate
    ) {
        List<InvoiceProduct__c> invoiceProducts = [
            SELECT
                Amount__c,
                ContractProduct__r.Quantity__c,
                ContractProduct__r.UnitPrice__c,
                StartDate__c,
                Enddate__c,
                InvoiceDate__c,
                PaymentScheduledDate__c,
                invoicetype__c,
                ActualInvoiceDate__c,
                LatestExportDate__c,
                PaymentTermSnapShot__c,
                BillingDayOfMonthSnapShot__c
            FROM InvoiceProduct__c
            WHERE ContractHistory__c = :priorHistoryId
            ORDER BY StartDate__c ASC
        ];

        System.assertEquals(12, invoiceProducts.size(), 'V1 請求商品件数');
        System.assertEquals(
            360000,
            sumAmounts(invoiceProducts),
            'V1 Amount 合計'
        );

        Date expectedInvoiceDate = Date.newInstance(2026, 4, 5);
        Date expectedPaymentScheduledDate = Date.newInstance(2026, 5, 31);

        for (InvoiceProduct__c invoiceProduct : invoiceProducts) {
            System.assertEquals(
                V1_UNIT_PRICE,
                invoiceProduct.Amount__c,
                'V1 Amount: ' + invoiceProduct.StartDate__c
            );
            System.assertEquals(
                V1_UNIT_PRICE,
                invoiceProduct.ContractProduct__r.UnitPrice__c,
                'V1 ContractProduct UnitPrice: ' + invoiceProduct.StartDate__c
            );
            System.assertEquals(1, invoiceProduct.ContractProduct__r.Quantity__c);
            System.assertEquals(INVOICE_SETTING_PREPAID, invoiceProduct.invoicetype__c);
            System.assertEquals(
                expectedInvoiceDate,
                invoiceProduct.InvoiceDate__c,
                'V1 InvoiceDate: ' + invoiceProduct.StartDate__c
            );
            System.assertEquals(
                expectedPaymentScheduledDate,
                invoiceProduct.PaymentScheduledDate__c,
                'V1 PaymentScheduledDate: ' + invoiceProduct.StartDate__c
            );
            Date expectedActualInvoiceDate =
                invoiceProduct.StartDate__c == TERM_START
                    ? lockedAprilActualInvoiceDate
                    : null;
            System.assertEquals(
                expectedActualInvoiceDate,
                invoiceProduct.ActualInvoiceDate__c,
                'V1 ActualInvoiceDate: ' + invoiceProduct.StartDate__c
            );
            System.assertEquals(null, invoiceProduct.LatestExportDate__c);
            System.assertEquals(
                PAYMENT_TERM_NEXT_MONTH_END,
                invoiceProduct.PaymentTermSnapShot__c
            );
            System.assertEquals(
                BILLING_DAY_OF_MONTH,
                invoiceProduct.BillingDayOfMonthSnapShot__c
            );
        }

        System.assertEquals(
            Date.newInstance(2026, 4, 1),
            invoiceProducts[0].StartDate__c
        );
        System.assertEquals(
            Date.newInstance(2027, 3, 31),
            invoiceProducts[11].Enddate__c
        );
    }

    private static void assertV2ContractProducts(Id changeHistoryId) {
        List<ContractProduct__c> contractProducts = [
            SELECT Type__c, StartDate__c, Enddate__c, UnitPrice__c, Quantity__c
            FROM ContractProduct__c
            WHERE ContractHistory__c = :changeHistoryId
        ];

        System.assertEquals(3, contractProducts.size(), 'V2 契約商品件数');

        ContractProduct__c originalRow = findContractProduct(
            contractProducts,
            'Original',
            TERM_START,
            TERM_END
        );
        ContractProduct__c preEffectiveRemake = findContractProduct(
            contractProducts,
            'Remake',
            TERM_START,
            PRE_EFFECTIVE_END
        );
        ContractProduct__c postEffectiveRemake = findContractProduct(
            contractProducts,
            'Remake',
            CHANGE_EFFECTIVE_DATE,
            TERM_END
        );

        System.assertNotEquals(null, originalRow, 'Original 行');
        System.assertEquals(V1_UNIT_PRICE, originalRow.UnitPrice__c);

        System.assertNotEquals(null, preEffectiveRemake, '有効日前 Remake 行');
        System.assertEquals(V1_UNIT_PRICE, preEffectiveRemake.UnitPrice__c);

        System.assertNotEquals(null, postEffectiveRemake, '有効日以降 Remake 行');
        System.assertEquals(V2_UNIT_PRICE, postEffectiveRemake.UnitPrice__c);
    }

    private static ContractProduct__c findContractProduct(
        List<ContractProduct__c> contractProducts,
        String typeValue,
        Date startDate,
        Date endDate
    ) {
        for (ContractProduct__c contractProduct : contractProducts) {
            if (
                contractProduct.Type__c == typeValue &&
                contractProduct.StartDate__c == startDate &&
                contractProduct.Enddate__c == endDate
            ) {
                return contractProduct;
            }
        }
        return null;
    }

    private static void assertV2InvoiceProducts(Id changeHistoryId) {
        List<InvoiceProduct__c> invoiceProducts = [
            SELECT
                Amount__c,
                Quantity__c,
                UnitPrice__c,
                ContractProduct__r.Quantity__c,
                ContractProduct__r.UnitPrice__c,
                ContractProduct__r.Type__c,
                StartDate__c,
                Enddate__c,
                InvoiceDate__c,
                PaymentScheduledDate__c,
                invoicetype__c
            FROM InvoiceProduct__c
            WHERE ContractHistory__c = :changeHistoryId
            ORDER BY StartDate__c ASC, Amount__c ASC
        ];

        System.assertEquals(22, invoiceProducts.size(), 'V2 請求商品件数（±2行×11ヶ月）');
        System.assertEquals(
            220000,
            sumAmounts(invoiceProducts),
            'V2 Amount 合計'
        );

        Date expectedInvoiceDate = Date.newInstance(2026, 5, 5);
        Date expectedPaymentScheduledDate = Date.newInstance(2026, 6, 30);
        Integer changeMonthCount = 0;

        for (Integer index = 0; index < invoiceProducts.size(); index += 2) {
            InvoiceProduct__c reversalLine = invoiceProducts[index];
            InvoiceProduct__c chargeLine = invoiceProducts[index + 1];

            System.assert(
                reversalLine.StartDate__c >= CHANGE_EFFECTIVE_DATE,
                'V2 は 5 月以降のみ'
            );
            System.assertEquals(
                reversalLine.StartDate__c,
                chargeLine.StartDate__c,
                '同一期間で ±2 行'
            );
            System.assertEquals(
                -V1_UNIT_PRICE,
                reversalLine.Amount__c,
                '反転行 Amount: ' + reversalLine.StartDate__c
            );
            System.assertEquals(
                V2_UNIT_PRICE,
                chargeLine.Amount__c,
                '新規行 Amount: ' + chargeLine.StartDate__c
            );
            System.assertEquals(
                V1_QUANTITY,
                reversalLine.Quantity__c,
                '反転行 Quantity: ' + reversalLine.StartDate__c
            );
            System.assertEquals(
                V1_UNIT_PRICE,
                reversalLine.UnitPrice__c,
                '反転行 UnitPrice: ' + reversalLine.StartDate__c
            );
            System.assertEquals(
                V1_QUANTITY,
                chargeLine.Quantity__c,
                '新規行 Quantity: ' + chargeLine.StartDate__c
            );
            System.assertEquals(
                V2_UNIT_PRICE,
                chargeLine.UnitPrice__c,
                '新規行 UnitPrice: ' + chargeLine.StartDate__c
            );
            System.assertEquals(
                'Original',
                reversalLine.ContractProduct__r.Type__c,
                '反転行 ContractProduct: ' + reversalLine.StartDate__c
            );
            System.assertEquals(
                INVOICE_SETTING_PREPAID,
                reversalLine.invoicetype__c,
                '反転行 invoicetype: ' + reversalLine.StartDate__c
            );
            System.assertEquals(
                INVOICE_SETTING_PREPAID,
                chargeLine.invoicetype__c,
                '新規行 invoicetype: ' + chargeLine.StartDate__c
            );
            System.assertEquals(
                chargeLine.InvoiceDate__c,
                reversalLine.InvoiceDate__c,
                '反転行 InvoiceDate: ' + reversalLine.StartDate__c
            );
            System.assertEquals(
                chargeLine.PaymentScheduledDate__c,
                reversalLine.PaymentScheduledDate__c,
                '反転行 PaymentScheduledDate: ' + reversalLine.StartDate__c
            );
            System.assertEquals(
                expectedInvoiceDate,
                chargeLine.InvoiceDate__c,
                'V2 InvoiceDate: ' + chargeLine.StartDate__c
            );
            System.assertEquals(
                expectedPaymentScheduledDate,
                chargeLine.PaymentScheduledDate__c,
                'V2 PaymentScheduledDate: ' + chargeLine.StartDate__c
            );
            changeMonthCount++;
        }

        System.assertEquals(11, changeMonthCount, 'V2 変更対象月数');
        System.assertEquals(
            CHANGE_EFFECTIVE_DATE,
            invoiceProducts[0].StartDate__c
        );
        System.assertEquals(
            Date.newInstance(2027, 3, 31),
            invoiceProducts[invoiceProducts.size() - 1].Enddate__c
        );
    }

    private static void assertServiceInvoiceTotals(Id contractServiceId) {
        List<InvoiceProduct__c> invoiceProducts = [
            SELECT Amount__c, ContractHistory__r.Version__c
            FROM InvoiceProduct__c
            WHERE ContractHistory__r.ContractService__c = :contractServiceId
        ];

        System.assertEquals(34, invoiceProducts.size(), 'サービス全体の請求商品件数');
        System.assertEquals(580000, sumAmounts(invoiceProducts), 'サービス全体 Amount 合計');
    }

    private static void assertArr(Id priorHistoryId, Id changeHistoryId) {
        Map<Id, ContractHistory__c> histories = new Map<Id, ContractHistory__c>([
            SELECT ARR__c, DeltaARR__c
            FROM ContractHistory__c
            WHERE Id IN :new Set<Id>{ priorHistoryId, changeHistoryId }
        ]);

        ContractHistory__c priorHistory = histories.get(priorHistoryId);
        ContractHistory__c changeHistory = histories.get(changeHistoryId);

        System.assertEquals(360000, priorHistory.ARR__c, 'V1 ARR');
        System.assertEquals(360000, priorHistory.DeltaARR__c, 'V1 DeltaARR');
        System.assertEquals(600000, changeHistory.ARR__c, 'V2 ARR');
        System.assertEquals(240000, changeHistory.DeltaARR__c, 'V2 DeltaARR');
    }

    private static void assertNegativeExpectations(
        Id priorHistoryId,
        Id changeHistoryId
    ) {
        Integer priorCount = [
            SELECT COUNT()
            FROM InvoiceProduct__c
            WHERE ContractHistory__c = :priorHistoryId
        ];
        System.assertEquals(12, priorCount, 'N1: V1 請求商品 12 件が残存');

        Integer priorCreditNotes = [
            SELECT COUNT()
            FROM InvoiceProduct__c
            WHERE ContractHistory__c = :priorHistoryId
            AND Amount__c < 0
        ];
        System.assertEquals(0, priorCreditNotes, 'N2: V1 に赤伝なし');

        Integer aprilOnV2 = [
            SELECT COUNT()
            FROM InvoiceProduct__c
            WHERE ContractHistory__c = :changeHistoryId
            AND StartDate__c = :Date.newInstance(2026, 4, 1)
        ];
        System.assertEquals(0, aprilOnV2, 'N3: V2 に 4 月分なし');

        Integer v2CreditNotes = [
            SELECT COUNT()
            FROM InvoiceProduct__c
            WHERE ContractHistory__c = :changeHistoryId
            AND Amount__c < 0
        ];
        System.assertEquals(11, v2CreditNotes, 'N4: V2 に反転行 11 件');
    }

    private static void assertScenario002LockedExpectations(Id priorHistoryId) {
        InvoiceProduct__c aprilInvoice = [
            SELECT Amount__c, ActualInvoiceDate__c
            FROM InvoiceProduct__c
            WHERE ContractHistory__c = :priorHistoryId
            AND StartDate__c = :TERM_START
            LIMIT 1
        ];
        System.assertEquals(
            APRIL_INVOICED_DATE,
            aprilInvoice.ActualInvoiceDate__c,
            'N4: V1 4月行は請求済ロックのまま'
        );
        System.assertEquals(
            V1_UNIT_PRICE,
            aprilInvoice.Amount__c,
            'N4: V1 4月行 Amount 不変'
        );

        Integer unlockedCount = [
            SELECT COUNT()
            FROM InvoiceProduct__c
            WHERE ContractHistory__c = :priorHistoryId
            AND StartDate__c > :TERM_START
            AND ActualInvoiceDate__c = NULL
            AND LatestExportDate__c = NULL
        ];
        System.assertEquals(11, unlockedCount, 'N5: V1 5月以降 11 件は未ロック');
    }

    private static void assertV3V2ContractProducts(Id changeHistoryId) {
        List<ContractProduct__c> contractProducts = [
            SELECT Type__c, StartDate__c, Enddate__c, UnitPrice__c, Quantity__c
            FROM ContractProduct__c
            WHERE ContractHistory__c = :changeHistoryId
        ];

        System.assertEquals(3, contractProducts.size(), 'V2 契約商品件数');

        ContractProduct__c originalRow = findContractProduct(
            contractProducts,
            'Original',
            TERM_START,
            TERM_END
        );
        ContractProduct__c preEffectiveRemake = findContractProduct(
            contractProducts,
            'Remake',
            TERM_START,
            PRE_EFFECTIVE_END
        );
        ContractProduct__c postEffectiveRemake = findContractProduct(
            contractProducts,
            'Remake',
            CHANGE_EFFECTIVE_DATE,
            TERM_END
        );

        System.assertNotEquals(null, originalRow, 'Original 行');
        System.assertEquals(V1_UNIT_PRICE, originalRow.UnitPrice__c);
        System.assertEquals(V1_QUANTITY, originalRow.Quantity__c);

        System.assertNotEquals(null, preEffectiveRemake, '有効日前 Remake 行');
        System.assertEquals(V1_UNIT_PRICE, preEffectiveRemake.UnitPrice__c);
        System.assertEquals(V1_QUANTITY, preEffectiveRemake.Quantity__c);

        System.assertNotEquals(null, postEffectiveRemake, '有効日以降 Remake 行');
        System.assertEquals(V2_UNIT_PRICE, postEffectiveRemake.UnitPrice__c);
        System.assertEquals(V3_QUANTITY, postEffectiveRemake.Quantity__c);
    }

    private static void assertV3V2InvoiceProducts(Id changeHistoryId) {
        List<InvoiceProduct__c> invoiceProducts = [
            SELECT
                Amount__c,
                Quantity__c,
                UnitPrice__c,
                ContractProduct__r.Quantity__c,
                ContractProduct__r.UnitPrice__c,
                ContractProduct__r.Type__c,
                StartDate__c,
                Enddate__c,
                InvoiceDate__c,
                PaymentScheduledDate__c,
                invoicetype__c
            FROM InvoiceProduct__c
            WHERE ContractHistory__c = :changeHistoryId
            ORDER BY StartDate__c ASC, Amount__c ASC
        ];

        System.assertEquals(22, invoiceProducts.size(), 'V2 請求商品件数（±2行×11ヶ月）');
        System.assertEquals(
            770000,
            sumAmounts(invoiceProducts),
            'V2 Amount 合計'
        );

        Date expectedInvoiceDate = Date.newInstance(2026, 5, 5);
        Date expectedPaymentScheduledDate = Date.newInstance(2026, 6, 30);

        for (Integer index = 0; index < invoiceProducts.size(); index += 2) {
            InvoiceProduct__c reversalLine = invoiceProducts[index];
            InvoiceProduct__c chargeLine = invoiceProducts[index + 1];

            System.assert(
                reversalLine.StartDate__c >= CHANGE_EFFECTIVE_DATE,
                'V2 は 5 月以降のみ'
            );
            System.assertEquals(
                -V1_UNIT_PRICE,
                reversalLine.Amount__c,
                '反転行 Amount: ' + reversalLine.StartDate__c
            );
            System.assertEquals(
                V2_UNIT_PRICE * V3_QUANTITY,
                chargeLine.Amount__c,
                '新規行 Amount: ' + chargeLine.StartDate__c
            );
            System.assertEquals(
                V1_QUANTITY,
                reversalLine.Quantity__c,
                '反転行 Quantity: ' + reversalLine.StartDate__c
            );
            System.assertEquals(
                V3_QUANTITY,
                chargeLine.Quantity__c,
                '新規行 Quantity: ' + chargeLine.StartDate__c
            );
            System.assertEquals(
                V1_UNIT_PRICE,
                reversalLine.UnitPrice__c,
                '反転行 UnitPrice: ' + reversalLine.StartDate__c
            );
            System.assertEquals(
                V2_UNIT_PRICE,
                chargeLine.UnitPrice__c,
                '新規行 UnitPrice: ' + chargeLine.StartDate__c
            );
            System.assertEquals(
                INVOICE_SETTING_PREPAID,
                reversalLine.invoicetype__c,
                '反転行 invoicetype: ' + reversalLine.StartDate__c
            );
            System.assertEquals(
                INVOICE_SETTING_PREPAID,
                chargeLine.invoicetype__c,
                '新規行 invoicetype: ' + chargeLine.StartDate__c
            );
            System.assertEquals(
                chargeLine.InvoiceDate__c,
                reversalLine.InvoiceDate__c,
                '反転行 InvoiceDate: ' + reversalLine.StartDate__c
            );
            System.assertEquals(
                chargeLine.PaymentScheduledDate__c,
                reversalLine.PaymentScheduledDate__c,
                '反転行 PaymentScheduledDate: ' + reversalLine.StartDate__c
            );
            System.assertEquals(
                expectedInvoiceDate,
                chargeLine.InvoiceDate__c,
                'V2 InvoiceDate: ' + chargeLine.StartDate__c
            );
            System.assertEquals(
                expectedPaymentScheduledDate,
                chargeLine.PaymentScheduledDate__c,
                'V2 PaymentScheduledDate: ' + chargeLine.StartDate__c
            );
        }
    }

    private static void assertV3ServiceInvoiceTotals(Id contractServiceId) {
        List<InvoiceProduct__c> invoiceProducts = [
            SELECT Amount__c
            FROM InvoiceProduct__c
            WHERE ContractHistory__r.ContractService__c = :contractServiceId
        ];

        System.assertEquals(34, invoiceProducts.size(), 'サービス全体の請求商品件数');
        System.assertEquals(
            1130000,
            sumAmounts(invoiceProducts),
            'サービス全体 Amount 合計'
        );
    }

    private static void assertV3Arr(Id priorHistoryId, Id changeHistoryId) {
        Map<Id, ContractHistory__c> histories = new Map<Id, ContractHistory__c>([
            SELECT ARR__c, DeltaARR__c
            FROM ContractHistory__c
            WHERE Id IN :new Set<Id>{ priorHistoryId, changeHistoryId }
        ]);

        ContractHistory__c priorHistory = histories.get(priorHistoryId);
        ContractHistory__c changeHistory = histories.get(changeHistoryId);

        System.assertEquals(360000, priorHistory.ARR__c, 'V1 ARR');
        System.assertEquals(360000, priorHistory.DeltaARR__c, 'V1 DeltaARR');
        System.assertEquals(1200000, changeHistory.ARR__c, 'V2 ARR');
        System.assertEquals(840000, changeHistory.DeltaARR__c, 'V2 DeltaARR');
    }

    private static Decimal sumAmounts(List<InvoiceProduct__c> invoiceProducts) {
        Decimal total = 0;
        for (InvoiceProduct__c invoiceProduct : invoiceProducts) {
            total += invoiceProduct.Amount__c == null ? 0 : invoiceProduct.Amount__c;
        }
        return total;
    }
}
