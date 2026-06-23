@IsTest
private class EstimateDocumentServiceTest {
    @TestSetup
    static void setupAccess() {
        ContractTestDataFactory.initTestContext();
    }

    @IsTest
    static void loadContext_buildsLinesAndTotals() {
        System.runAs(ContractTestDataFactory.getAdminUser()) {
            EstimateFixture fixture = createEstimateFixture();

            EstimateDocumentService.DocumentContext context =
                EstimateDocumentService.loadContext(fixture.history.Id);

            System.assertEquals('サンプル見積タイトル', context.documentTitle);
            System.assertEquals('サンプル株式会社', context.companyName);
            System.assertEquals('テスト取引先', context.addresseeName);
            System.assertEquals(1, context.lines.size());
            System.assertEquals(144000, context.lines[0].amount);
            System.assertEquals(144000, context.lineTotal);
            System.assertEquals(10, context.taxPercent);
            System.assertEquals(14400, context.taxAmount);
            System.assertEquals(158400, context.lineTotalInclTax);
            System.assertEquals('10', context.taxPercentLabel);
            System.assertEquals('定型備考', context.masterNoteText);
        }
    }

    @IsTest
    static void buildFileName_usesTitleAndIssueDate() {
        ContractHistory__c history = new ContractHistory__c(
            Name = 'H-001',
            EstimateTitleName__c = '2026年度更新'
        );
        Date issueDate = Date.newInstance(2026, 6, 20);

        String fileName = EstimateDocumentService.buildFileName(history, issueDate);

        System.assertEquals('2026年度更新_2026_06_20.pdf', fileName);
    }

    @IsTest
    static void sanitizeFileName_replacesInvalidCharacters() {
        String sanitized = EstimateDocumentService.sanitizeFileName('見積/テスト 01');

        System.assertEquals('見積_テスト_01', sanitized);
    }

    @IsTest
    static void ensureIssueDate_setsIssueAndEstimateDates() {
        System.runAs(ContractTestDataFactory.getAdminUser()) {
            EstimateFixture fixture = createEstimateFixture();
            fixture.history.EstimateIssueDate__c = null;
            fixture.history.EstimateDate__c = null;
            update fixture.history;

            Date issueDate = EstimateDocumentService.ensureIssueDate(fixture.history);

            System.assertEquals(Date.today(), issueDate);

            ContractHistory__c updated = [
                SELECT EstimateIssueDate__c, EstimateDate__c
                FROM ContractHistory__c
                WHERE Id = :fixture.history.Id
            ];
            System.assertEquals(Date.today(), updated.EstimateIssueDate__c);
            System.assertEquals(Date.today(), updated.EstimateDate__c);
        }
    }

    @IsTest
    static void issueEstimateDocument_savesPdfFileToHistory() {
        System.runAs(ContractTestDataFactory.getAdminUser()) {
            EstimateFixture fixture = createEstimateFixture();

            EstimateDocumentService.IssueResult result =
                EstimateDocumentService.issueEstimateDocument(fixture.history.Id);

            System.assertNotEquals(null, result.contentVersionId);
            System.assertEquals(
                'サンプル見積タイトル_' +
                    EstimateDocumentService.formatFileDate(Date.today()) +
                    '.pdf',
                result.fileName
            );

            List<ContentDocumentLink> links = [
                SELECT Id, LinkedEntityId
                FROM ContentDocumentLink
                WHERE LinkedEntityId = :fixture.history.Id
            ];
            System.assertEquals(1, links.size());

            ContractHistory__c updated = [
                SELECT EstimateIssueDate__c, EstimateDate__c
                FROM ContractHistory__c
                WHERE Id = :fixture.history.Id
            ];
            System.assertEquals(Date.today(), updated.EstimateIssueDate__c);
            System.assertEquals(Date.today(), updated.EstimateDate__c);
        }
    }

    @IsTest
    static void loadContext_nullId_throwsException() {
        Boolean thrown = false;
        try {
            EstimateDocumentService.loadContext(null);
        } catch (EstimateDocumentService.EstimateDocumentException ex) {
            thrown = true;
            System.assertEquals('契約履歴IDが指定されていません。', ex.getMessage());
        }
        System.assertEquals(true, thrown);
    }

    @IsTest
    static void loadContext_usesOpportunityNameWhenTitleBlank() {
        System.runAs(ContractTestDataFactory.getAdminUser()) {
            EstimateFixture fixture = createEstimateFixture();
            fixture.history.EstimateTitleName__c = null;
            update fixture.history;

            EstimateDocumentService.DocumentContext context =
                EstimateDocumentService.loadContext(fixture.history.Id);

            System.assertEquals('Test Opportunity', context.documentTitle);
        }
    }

    @IsTest
    static void ensureIssueDate_keepsExistingIssueDate() {
        System.runAs(ContractTestDataFactory.getAdminUser()) {
            EstimateFixture fixture = createEstimateFixture();
            Date existingIssueDate = Date.newInstance(2026, 1, 15);
            fixture.history.EstimateIssueDate__c = existingIssueDate;
            fixture.history.EstimateDate__c = Date.newInstance(2026, 1, 10);
            update fixture.history;

            Date issueDate = EstimateDocumentService.ensureIssueDate(fixture.history);

            System.assertEquals(existingIssueDate, issueDate);
        }
    }

    @IsTest
    static void formatDisplayDate_formatsJapaneseLabel() {
        String label = EstimateDocumentService.formatDisplayDate(
            Date.newInstance(2026, 6, 20)
        );
        System.assertEquals('2026年06月20日', label);
    }

    @IsTest
    static void savePdfToRecord_nullRecordId_throwsException() {
        Boolean thrown = false;
        try {
            EstimateDocumentService.savePdfToRecord(null, 'test.pdf', Blob.valueOf('x'));
        } catch (EstimateDocumentService.EstimateDocumentException ex) {
            thrown = true;
        }
        System.assertEquals(true, thrown);
    }

    @IsTest
    static void issuePdfController_missingIdShowsError() {
        PageReference issuePage = Page.EstimateDocumentIssue;
        Test.setCurrentPage(issuePage);

        EstimateDocumentPdfController controller = new EstimateDocumentPdfController();
        PageReference result = controller.issuePdf();

        System.assertEquals(null, result);
        System.assertEquals(false, controller.hasContext);
    }

    @IsTest
    static void issuePdfController_redirectsToPdfPage() {
        System.runAs(ContractTestDataFactory.getAdminUser()) {
            EstimateFixture fixture = createEstimateFixture();

            PageReference issuePage = Page.EstimateDocumentIssue;
            issuePage.getParameters().put('id', fixture.history.Id);
            Test.setCurrentPage(issuePage);

            EstimateDocumentPdfController controller = new EstimateDocumentPdfController();
            PageReference result = controller.issuePdf();

            System.assertNotEquals(null, result);
            System.assert(
                result.getUrl().startsWith(Page.EstimateDocumentPdf.getUrl())
            );
            System.assertEquals(fixture.history.Id, result.getParameters().get('id'));
        }
    }

    @IsTest
    static void savePdfToRecord_emptyPdfBody_throwsException() {
        System.runAs(ContractTestDataFactory.getAdminUser()) {
            EstimateFixture fixture = createEstimateFixture();
            Boolean thrown = false;
            try {
                EstimateDocumentService.savePdfToRecord(
                    fixture.history.Id,
                    'test.pdf',
                    Blob.valueOf('')
                );
            } catch (EstimateDocumentService.EstimateDocumentException ex) {
                thrown = true;
            }
            System.assertEquals(true, thrown);
        }
    }

    @IsTest
    static void loadContext_unknownHistory_throwsException() {
        Boolean thrown = false;
        try {
            EstimateDocumentService.loadContext(
                ContractHistory__c.SObjectType.getDescribe().getKeyPrefix() +
                    '000000000000'
            );
        } catch (EstimateDocumentService.EstimateDocumentException ex) {
            thrown = true;
        }
        System.assertEquals(true, thrown);
    }

    @IsTest
    static void pdfController_bindsContextFromRecordId() {
        System.runAs(ContractTestDataFactory.getAdminUser()) {
            EstimateFixture fixture = createEstimateFixture();

            PageReference pdfPage = Page.EstimateDocumentPdf;
            pdfPage.getParameters().put('id', fixture.history.Id);
            Test.setCurrentPage(pdfPage);

            EstimateDocumentPdfController controller = new EstimateDocumentPdfController();

            System.assertEquals(true, controller.hasContext);
            System.assertEquals('サンプル見積タイトル', controller.documentTitle);
            System.assertEquals(158400, controller.lineTotalInclTax);
            System.assertEquals(1, controller.lines.size());
        }
    }

    @IsTest
    static void buildFileName_fallsBackToHistoryName() {
        ContractHistory__c history = new ContractHistory__c(Name = 'EST-FALLBACK');
        String fileName = EstimateDocumentService.buildFileName(
            history,
            Date.newInstance(2026, 6, 20)
        );
        System.assertEquals('EST-FALLBACK_2026_06_20.pdf', fileName);
    }

    private class EstimateFixture {
        public ContractHistory__c history;
    }

    private static EstimateFixture createEstimateFixture() {
        Account account = ContractTestDataFactory.insertAccount('テスト取引先');
        BillingAccount__c billingAccount = new BillingAccount__c(
            Account__c = account.Id,
            BillingAddressee__c = 'テスト取引先',
            PaymentTerm__c = '当月末',
            BillingDayOfMonth__c = '25',
            AdjustInvoiceDateToBusinessDay__c = false
        );
        ContractTestDataFactory.applyRequiredFields(billingAccount);
        insert billingAccount;

        ContractService__c service = new ContractService__c(
            Name = 'Test Service',
            Account__c = account.Id,
            BiilingAcccount__c = billingAccount.Id
        );
        ContractTestDataFactory.applyRequiredFields(service);
        insert service;

        Opportunity opportunity = ContractTestDataFactory.insertOpportunity(
            account.Id,
            'Test Opportunity'
        );

        EstimateNoteMaster__c noteMaster = new EstimateNoteMaster__c(
            Name = 'Default Master',
            NoteText__c = '定型備考'
        );
        ContractTestDataFactory.applyRequiredFields(noteMaster);
        insert noteMaster;

        ContractHistory__c history = new ContractHistory__c(
            Name = 'EST-001',
            ContractService__c = service.Id,
            Opportunity__c = opportunity.Id,
            Type__c = 'New',
            historystatus__c = 'Estimate',
            Version__c = 1,
            CurrentTermStartDate__c = Date.newInstance(2026, 4, 1),
            CurrentTermEndDate__c = Date.newInstance(2027, 3, 31),
            EstimateTitleName__c = 'サンプル見積タイトル',
            EstimateValidDate__c = Date.newInstance(2026, 7, 31),
            Note__c = '個別備考',
            EstimateNoteMaster__c = noteMaster.Id
        );
        ContractTestDataFactory.applyRequiredFields(history);
        insert history;
        update new ContractHistory__c(
            Id = history.Id,
            EstimateTitleName__c = 'サンプル見積タイトル'
        );
        history = [
            SELECT
                Id,
                Name,
                EstimateTitleName__c,
                EstimateValidDate__c,
                EstimateIssueDate__c,
                EstimateDate__c,
                Opportunity__c
            FROM ContractHistory__c
            WHERE Id = :history.Id
        ];

        Product2 product = ContractTestDataFactory.buildProduct('Test Product');
        product.UnitName__c = '式';
        product.BillingType__c = '継続課金';
        product.invoicetype__c = '一括前払';
        ContractTestDataFactory.insertProduct(product);

        ContractProduct__c contractProduct = new ContractProduct__c(
            ContractHistory__c = history.Id,
            Account__c = account.Id,
            Product__c = product.Id,
            Quantity__c = 1,
            UnitPrice__c = 12000,
            Unit__c = '式/月',
            StartDate__c = Date.newInstance(2026, 4, 1),
            Enddate__c = Date.newInstance(2027, 3, 31),
            InvoiceSetting__c = '一括前払',
            BillingType__c = '継続課金',
            Type__c = 'New'
        );
        ContractTestDataFactory.applyRequiredFields(contractProduct);
        insert contractProduct;

        EstimateFixture fixture = new EstimateFixture();
        fixture.history = history;
        return fixture;
    }
}
