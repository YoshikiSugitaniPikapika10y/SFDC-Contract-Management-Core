@IsTest
private class OrderCreateControllerTest {
    @IsTest
    static void getOrderContext_returnsEstimateHistory() {
        System.runAs(ContractTestDataFactory.getAdminUser()) {
            OrderTestContext context = createEstimateContext();

            OrderCreateController.OrderContextDto dto =
                OrderCreateController.getOrderContext(context.history.Id);

            System.assertEquals(context.history.Id, dto.contractHistoryId);
            System.assertEquals('Estimate', dto.historyStatus);
            System.assertEquals(true, dto.canOrder);
            System.assertEquals(false, dto.isOrdered);
            System.assertEquals(1, dto.products.size());
            System.assertEquals(context.billingAccount.Id, dto.billingAccountId);
            System.assertEquals('当月末', dto.billingCustomFields.get('PaymentTerm__c'));
            System.assertEquals('25', dto.billingCustomFields.get('BillingDayOfMonth__c'));
            System.assertEquals(false, dto.billingCustomFields.get('AdjustInvoiceDateToBusinessDay__c'));
        }
    }

    @IsTest
    static void saveOrderStep1_updatesHistoryFields() {
        System.runAs(ContractTestDataFactory.getAdminUser()) {
            OrderTestContext context = createEstimateContext();
            String fieldsJson = '{"Note__c":"受注時備考"}';

            OrderCreateController.saveOrderStep1(context.history.Id, fieldsJson);

            ContractHistory__c updated = [
                SELECT Note__c
                FROM ContractHistory__c
                WHERE Id = :context.history.Id
            ];
            System.assertEquals('受注時備考', updated.Note__c);
        }
    }

    @IsTest
    static void saveOrderStep2_updatesBillingAccountFields() {
        System.runAs(ContractTestDataFactory.getAdminUser()) {
            OrderTestContext context = createEstimateContext();
            String fieldsJson =
                '{"BillingAddressee__c":"受注時 御中","BillingEmailTo__c":"order-to@example.com","BillingEmailCc__c":"order-cc@example.com","BillingEmailBcc__c":"order-bcc@example.com","PaymentTerm__c":"翌月15日","BillingDayOfMonth__c":"15","AdjustInvoiceDateToBusinessDay__c":true}';

            OrderCreateController.saveOrderStep2(context.history.Id, fieldsJson);

            BillingAccount__c updated = [
                SELECT
                    BillingAddressee__c,
                    BillingEmailTo__c,
                    PaymentTerm__c,
                    BillingDayOfMonth__c,
                    AdjustInvoiceDateToBusinessDay__c
                FROM BillingAccount__c
                WHERE Id = :context.billingAccount.Id
            ];
            System.assertEquals('受注時 御中', updated.BillingAddressee__c);
            System.assertEquals('order-to@example.com', updated.BillingEmailTo__c);
            System.assertEquals('翌月15日', updated.PaymentTerm__c);
            System.assertEquals('15', updated.BillingDayOfMonth__c);
            System.assertEquals(true, updated.AdjustInvoiceDateToBusinessDay__c);
        }
    }

    @IsTest
    static void confirmOrder_appliesUpdatedBillingDayBeforeInvoiceGeneration() {
        System.runAs(ContractTestDataFactory.getAdminUser()) {
            OrderTestContext context = createEstimateContext();
            context.billingAccount.BillingDayOfMonth__c = '1';
            update context.billingAccount;

            String fieldsJson =
                '{"BillingAddressee__c":"株式会社テスト 御中","BillingEmailTo__c":"to@example.com","BillingEmailCc__c":"cc@example.com","BillingEmailBcc__c":"bcc@example.com","PaymentTerm__c":"当月末","BillingDayOfMonth__c":"15","AdjustInvoiceDateToBusinessDay__c":false}';

            OrderCreateController.confirmOrder(context.history.Id, fieldsJson);

            BillingAccount__c updatedBillingAccount = [
                SELECT BillingDayOfMonth__c
                FROM BillingAccount__c
                WHERE Id = :context.billingAccount.Id
            ];
            System.assertEquals('15', updatedBillingAccount.BillingDayOfMonth__c);

            List<InvoiceProduct__c> invoiceProducts = [
                SELECT
                    InvoiceDate__c,
                    BillingDayOfMonthSnapShot__c
                FROM InvoiceProduct__c
                WHERE ContractHistory__c = :context.history.Id
                ORDER BY InvoiceDate__c ASC NULLS LAST
            ];
            System.assert(invoiceProducts.size() > 0);
            System.assertEquals('15', invoiceProducts[0].BillingDayOfMonthSnapShot__c);
            System.assertEquals(15, invoiceProducts[0].InvoiceDate__c.day());
        }
    }

    @IsTest
    static void confirmOrder_appliesBillingDayForPrepaidInvoiceDate() {
        System.runAs(ContractTestDataFactory.getAdminUser()) {
            OrderTestContext context = createEstimateContext();
            ContractProduct__c contractProduct = [
                SELECT Id, InvoiceSetting__c
                FROM ContractProduct__c
                WHERE ContractHistory__c = :context.history.Id
                LIMIT 1
            ];
            contractProduct.InvoiceSetting__c = '一括前払';
            update contractProduct;

            String fieldsJson =
                '{"BillingAddressee__c":"株式会社テスト 御中","BillingEmailTo__c":"to@example.com","BillingEmailCc__c":"cc@example.com","BillingEmailBcc__c":"bcc@example.com","PaymentTerm__c":"当月末","BillingDayOfMonth__c":"5","AdjustInvoiceDateToBusinessDay__c":false}';

            OrderCreateController.confirmOrder(context.history.Id, fieldsJson);

            List<InvoiceProduct__c> invoiceProducts = [
                SELECT InvoiceDate__c
                FROM InvoiceProduct__c
                WHERE ContractHistory__c = :context.history.Id
                ORDER BY StartDate__c ASC
            ];
            System.assert(invoiceProducts.size() > 0);
            for (InvoiceProduct__c invoiceProduct : invoiceProducts) {
                System.assertEquals(
                    Date.newInstance(2026, 6, 5),
                    invoiceProduct.InvoiceDate__c,
                    '一括前払でも請求基準日5日が請求日に反映される'
                );
            }
        }
    }

    @IsTest
    static void confirmOrder_triggersInvoiceGenerationViaStatusUpdate() {
        System.runAs(ContractTestDataFactory.getAdminUser()) {
            OrderTestContext context = createEstimateContext();

            OrderCreateController.confirmOrder(context.history.Id, null);

            ContractHistory__c updated = [
                SELECT historystatus__c
                FROM ContractHistory__c
                WHERE Id = :context.history.Id
            ];
            System.assertEquals('Ordered', updated.historystatus__c);

            List<InvoiceProduct__c> invoiceProducts = [
                SELECT Id
                FROM InvoiceProduct__c
                WHERE ContractHistory__c = :context.history.Id
            ];
            System.assert(invoiceProducts.size() > 0);
        }
    }

    @IsTest
    static void confirmOrder_blocksWithoutBillingAccount() {
        System.runAs(ContractTestDataFactory.getAdminUser()) {
            OrderTestContext context = createEstimateContext();
            context.service.BiilingAcccount__c = null;
            update context.service;

            Boolean thrown = false;
            try {
                OrderCreateController.confirmOrder(context.history.Id, null);
            } catch (Exception ex) {
                thrown = true;
            }
            System.assertEquals(true, thrown);

            ContractHistory__c history = [
                SELECT historystatus__c
                FROM ContractHistory__c
                WHERE Id = :context.history.Id
            ];
            System.assertEquals('Estimate', history.historystatus__c);
        }
    }

    @IsTest
    static void revertOrder_blocksWhenInvoicedProductsExist() {
        System.runAs(ContractTestDataFactory.getAdminUser()) {
            OrderTestContext context = createEstimateContext();
            OrderCreateController.confirmOrder(context.history.Id, null);

            List<InvoiceProduct__c> products = [
                SELECT Id
                FROM InvoiceProduct__c
                WHERE ContractHistory__c = :context.history.Id
                LIMIT 1
            ];
            System.assertEquals(false, products.isEmpty());
            products[0].ActualInvoiceDate__c = Date.today();
            update products[0];

            OrderCreateController.OrderContextDto dto =
                OrderCreateController.getOrderContext(context.history.Id);
            System.assertEquals(false, dto.canRevert);
            System.assert(
                dto.revertBlockedReason.contains('請求済またはエクスポート済')
            );

            Boolean thrown = false;
            try {
                OrderCreateController.revertOrder(context.history.Id);
            } catch (Exception ex) {
                thrown = true;
            }
            System.assertEquals(true, thrown);
        }
    }

    @IsTest
    static void revertOrder_returnsHistoryToEstimate() {
        System.runAs(ContractTestDataFactory.getAdminUser()) {
            OrderTestContext context = createEstimateContext();
            OrderCreateController.confirmOrder(context.history.Id, null);

            OrderCreateController.revertOrder(context.history.Id);

            ContractHistory__c updated = [
                SELECT historystatus__c
                FROM ContractHistory__c
                WHERE Id = :context.history.Id
            ];
            System.assertEquals('Estimate', updated.historystatus__c);
        }
    }

    @IsTest
    static void revertOrder_blocksEstimateHistory() {
        System.runAs(ContractTestDataFactory.getAdminUser()) {
            OrderTestContext context = createEstimateContext();

            Boolean thrown = false;
            try {
                OrderCreateController.revertOrder(context.history.Id);
            } catch (Exception ex) {
                thrown = true;
            }
            System.assertEquals(true, thrown);
        }
    }

    @IsTest
    static void getInvoicePreview_separatesLockedAndUnlockedSubtotals() {
        System.runAs(ContractTestDataFactory.getAdminUser()) {
            OrderTestContext context = createEstimateContext();
            OrderCreateController.confirmOrder(context.history.Id, null);

            List<InvoiceProduct__c> products = [
                SELECT Id, Amount__c, TaxAmount__c
                FROM InvoiceProduct__c
                WHERE ContractHistory__c = :context.history.Id
                ORDER BY Amount__c DESC
                LIMIT 1
            ];
            System.assertEquals(false, products.isEmpty());

            products[0].ActualInvoiceDate__c = Date.today();
            update products[0];

            OrderCreateController.InvoicePreviewDto preview =
                OrderCreateController.getInvoicePreview(context.history.Id);

            System.assertEquals(1, preview.lockedCount);
            System.assert(preview.unlockedCount > 0);
            System.assertEquals(
                products[0].Amount__c,
                preview.lockedTotal
            );
            System.assertEquals(
                products[0].TaxAmount__c,
                preview.lockedTaxTotal
            );
            System.assert(
                preview.unlockedTotal > 0,
                'Unlocked total should exclude locked line amount'
            );
            System.assert(
                preview.unlockedTaxTotal > 0,
                'Unlocked tax total should exclude locked line tax amount'
            );

            OrderCreateController.InvoiceDateBlockDto block = preview.blocks[0];
            System.assertEquals(
                products[0].Amount__c,
                block.lockedSubtotal
            );
            System.assertEquals(
                products[0].TaxAmount__c,
                block.taxLockedSubtotal
            );
            System.assert(
                block.subtotal < preview.unlockedTotal + products[0].Amount__c,
                'Block unlocked subtotal should exclude locked lines'
            );
        }
    }

    @IsTest
    static void getInvoicePreview_returnsServiceWideLinesAfterOrder() {
        System.runAs(ContractTestDataFactory.getAdminUser()) {
            OrderTestContext context = createEstimateContext();
            OrderCreateController.confirmOrder(context.history.Id, null);

            OrderCreateController.InvoicePreviewDto preview =
                OrderCreateController.getInvoicePreview(context.history.Id);

            System.assert(preview.unlockedCount > 0);
            System.assert(preview.blocks.size() > 0);
            System.assert(preview.blocks[0].lines.size() > 0);
            System.assertNotEquals(null, preview.blocks[0].lines[0].taxAmount);
            System.assert(preview.unlockedTaxTotal > 0);
        }
    }

    private class OrderTestContext {
        public Account account;
        public BillingAccount__c billingAccount;
        public ContractService__c service;
        public ContractHistory__c history;
    }

    private static OrderTestContext createEstimateContext() {
        OrderTestContext context = new OrderTestContext();
        context.account = ContractTestDataFactory.insertAccount('Order Wizard Account');

        context.billingAccount = new BillingAccount__c(
            Account__c = context.account.Id,
            BillingAddressee__c = '株式会社テスト 御中',
            BillingEmailTo__c = 'to@example.com',
            BillingEmailCc__c = 'cc@example.com',
            BillingEmailBcc__c = 'bcc@example.com',
            PaymentTerm__c = '当月末',
            BillingDayOfMonth__c = '25',
            AdjustInvoiceDateToBusinessDay__c = false
        );
        ContractTestDataFactory.applyRequiredFields(context.billingAccount);
        insert context.billingAccount;

        context.service = new ContractService__c(
            Name = 'Order Wizard Service',
            Account__c = context.account.Id,
            BiilingAcccount__c = context.billingAccount.Id
        );
        insert context.service;

        context.history = new ContractHistory__c(
            Name = 'Order Wizard History',
            ContractService__c = context.service.Id,
            Type__c = 'New',
            historystatus__c = 'Estimate',
            Version__c = 1,
            CurrentTermStartDate__c = Date.newInstance(2026, 6, 1),
            CurrentTermEndDate__c = Date.newInstance(2027, 5, 31)
        );
        insert context.history;

        Product2 product = ContractTestDataFactory.buildProduct('Order Wizard Product');
        product.BillingType__c = '継続課金';
        ContractTestDataFactory.insertProduct(product);

        insert new ContractProduct__c(
            ContractHistory__c = context.history.Id,
            Product__c = product.Id,
            Quantity__c = 10,
            UnitPrice__c = 5000,
            Unit__c = 'ID',
            StartDate__c = Date.newInstance(2026, 6, 1),
            Enddate__c = Date.newInstance(2027, 5, 31),
            InvoiceSetting__c = '月次分割',
            BillingType__c = '継続課金',
            Type__c = 'New'
        );

        return context;
    }
}
