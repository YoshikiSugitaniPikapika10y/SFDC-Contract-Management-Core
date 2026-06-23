@IsTest
private class ContractProductAmountUtilTest {
    @IsTest
    static void calculateUnsignedAmount_recurringMultipliesByMonthlyCycles() {
        Decimal amount = ContractProductAmountUtil.calculateUnsignedAmount(
            1,
            12000,
            '継続課金',
            Date.newInstance(2026, 4, 1),
            Date.newInstance(2027, 3, 31)
        );

        System.assertEquals(144000, amount);
    }

    @IsTest
    static void calculateUnsignedAmount_oneTimeUsesQuantityTimesUnitPrice() {
        Decimal amount = ContractProductAmountUtil.calculateUnsignedAmount(
            2,
            5000,
            '一回課金',
            Date.newInstance(2026, 4, 1),
            Date.newInstance(2027, 3, 31)
        );

        System.assertEquals(10000, amount);
    }

    @IsTest
    static void applyProductTypeSign_originalIsNegative() {
        System.assertEquals(
            -144000,
            ContractProductAmountUtil.applyProductTypeSign(144000, 'Original')
        );
    }

    @IsTest
    static void calculateSignedAmount_originalIsNegative() {
        ContractProduct__c product = new ContractProduct__c(
            Quantity__c = 1,
            UnitPrice__c = 12000,
            BillingType__c = '継続課金',
            StartDate__c = Date.newInstance(2026, 4, 1),
            Enddate__c = Date.newInstance(2027, 3, 31),
            Type__c = 'Original'
        );

        System.assertEquals(
            -144000,
            ContractProductAmountUtil.calculateSignedAmount(product, '継続課金')
        );
    }
}
