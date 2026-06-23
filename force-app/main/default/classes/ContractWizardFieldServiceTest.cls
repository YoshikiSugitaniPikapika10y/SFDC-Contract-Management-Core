@IsTest
private class ContractWizardFieldServiceTest {
    @IsTest
    static void getContractServiceFieldDefinitions_returnsListWithoutError() {
        ContractWizardFieldService.resetCache();
        System.assertNotEquals(
            null,
            ContractWizardFieldService.getContractServiceFieldDefinitions()
        );
    }

    @IsTest
    static void getContractHistoryFieldDefinitions_returnsConfiguredFields() {
        ContractWizardFieldService.resetCache();
        List<ContractWizardFieldService.WizardFieldDefinition> definitions =
            ContractWizardFieldService.getContractHistoryFieldDefinitions();
        System.assertEquals(1, definitions.size());
        System.assertEquals('Note__c', definitions[0].apiName);
    }

    @IsTest
    static void applyCustomFields_ignoresUnknownFields() {
        ContractService__c record = new ContractService__c();
        ContractWizardFieldService.applyCustomFields(
            record,
            new Map<String, Object>{ 'UnknownField__c' => 'value' },
            ContractWizardFieldService.WizardTarget.ContractService
        );
        System.assertEquals(null, record.Name);
    }
}
