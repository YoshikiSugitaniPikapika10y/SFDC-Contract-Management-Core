@IsTest
private class OrderWizardFieldServiceTest {
    @IsTest
    static void getOrderHistoryFieldDefinitions_readsConfiguredFields() {
        OrderWizardFieldService.resetCache();
        List<ContractWizardFieldService.WizardFieldDefinition> definitions =
            OrderWizardFieldService.getOrderHistoryFieldDefinitions();

        Boolean hasNote = false;
        for (ContractWizardFieldService.WizardFieldDefinition definition : definitions) {
            if (definition.apiName == 'Note__c') {
                hasNote = true;
                System.assertEquals('備考', definition.label);
            }
        }
        System.assertEquals(true, hasNote);
    }

    @IsTest
    static void getOrderHistoryFieldDefinitions_returnsConfiguredFields() {
        List<ContractWizardFieldService.WizardFieldDefinition> definitions =
            OrderWizardFieldService.getOrderHistoryFieldDefinitions();

        Set<String> apiNames = new Set<String>();
        for (ContractWizardFieldService.WizardFieldDefinition definition : definitions) {
            apiNames.add(definition.apiName);
        }
        System.assert(apiNames.contains('Note__c'));
    }

    @IsTest
    static void getOrderBillingFieldDefinitions_returnsConfiguredFields() {
        List<ContractWizardFieldService.WizardFieldDefinition> definitions =
            OrderWizardFieldService.getOrderBillingFieldDefinitions();

        Set<String> apiNames = new Set<String>();
        for (ContractWizardFieldService.WizardFieldDefinition definition : definitions) {
            apiNames.add(definition.apiName);
        }
        System.assert(apiNames.contains('PaymentTerm__c'));
        System.assert(apiNames.contains('BillingDayOfMonth__c'));
        System.assert(apiNames.contains('AdjustInvoiceDateToBusinessDay__c'));
        System.assert(apiNames.contains('BillingAddressee__c'));
        System.assert(apiNames.contains('BillingEmailTo__c'));
        System.assert(apiNames.contains('BillingEmailCc__c'));
        System.assert(apiNames.contains('BillingEmailBcc__c'));
        System.assert(!apiNames.contains('Name'));
    }

    @IsTest
    static void getOrderBillingFieldDefinitions_marksRequiredFields() {
        List<ContractWizardFieldService.WizardFieldDefinition> definitions =
            OrderWizardFieldService.getOrderBillingFieldDefinitions();

        Map<String, Boolean> requiredByApiName = new Map<String, Boolean>();
        for (ContractWizardFieldService.WizardFieldDefinition definition : definitions) {
            requiredByApiName.put(definition.apiName, definition.required);
        }
        System.assertEquals(true, requiredByApiName.get('BillingAddressee__c'));
        System.assertEquals(true, requiredByApiName.get('BillingEmailTo__c'));
        System.assertEquals(true, requiredByApiName.get('PaymentTerm__c'));
        System.assertEquals(true, requiredByApiName.get('BillingDayOfMonth__c'));
        System.assertEquals(false, requiredByApiName.get('BillingEmailCc__c'));
    }

    @IsTest
    static void validateBillingCustomFields_requiresAddresseeToPaymentTermAndBillingDay() {
        String error = OrderWizardFieldService.validateBillingCustomFields(
            new Map<String, Object>{
                'AdjustInvoiceDateToBusinessDay__c' => false
            }
        );
        System.assertNotEquals(null, error);
        System.assert(error.contains('請求先宛名'));
        System.assert(error.contains('請求書送付先（To）'));
        System.assert(error.contains('支払サイト'));
        System.assert(error.contains('請求日'));
    }

    @IsTest
    static void validateBillingCustomFields_requiresAddresseeAndToOnly() {
        String error = OrderWizardFieldService.validateBillingCustomFields(
            new Map<String, Object>{
                'PaymentTerm__c' => '当月末',
                'BillingDayOfMonth__c' => '15',
                'AdjustInvoiceDateToBusinessDay__c' => false
            }
        );
        System.assertNotEquals(null, error);
        System.assert(error.contains('請求先宛名'));
        System.assert(error.contains('請求書送付先（To）'));
    }

    @IsTest
    static void validateBillingCustomFields_acceptsMinimalRequiredPayload() {
        String error = OrderWizardFieldService.validateBillingCustomFields(
            new Map<String, Object>{
                'BillingAddressee__c' => '株式会社テスト 御中',
                'BillingEmailTo__c' => 'to@example.com',
                'PaymentTerm__c' => '当月末',
                'BillingDayOfMonth__c' => '15',
                'AdjustInvoiceDateToBusinessDay__c' => false
            }
        );
        System.assertEquals(null, error);
    }
}
