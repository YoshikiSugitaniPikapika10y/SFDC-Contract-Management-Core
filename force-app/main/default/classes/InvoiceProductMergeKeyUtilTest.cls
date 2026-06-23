@IsTest
private class InvoiceProductMergeKeyUtilTest {
    @IsTest
    static void buildMergeKey_formatsServiceProductPeriodQuantityUnitPriceAndUnit() {
        Account account = ContractTestDataFactory.insertAccount('Merge Key Account');
        ContractService__c service = new ContractService__c(
            Name = 'Merge Key Service',
            Account__c = account.Id
        );
        insert service;

        Product2 product = ContractTestDataFactory.buildProduct('Merge Key Product');
        ContractTestDataFactory.insertProduct(product);

        Date startDate = Date.newInstance(2026, 6, 1);
        Date endDate = Date.newInstance(2026, 6, 30);
        String mergeKey = InvoiceProductMergeKeyUtil.buildMergeKey(
            service.Id,
            product.Id,
            startDate,
            endDate,
            2,
            8000,
            'ID/月'
        );

        System.assertEquals(
            String.valueOf(service.Id) +
                '_' +
                String.valueOf(product.Id) +
                '_' +
                String.valueOf(startDate) +
                '_' +
                String.valueOf(endDate) +
                '_2_8000_ID/月',
            mergeKey
        );
    }
}
