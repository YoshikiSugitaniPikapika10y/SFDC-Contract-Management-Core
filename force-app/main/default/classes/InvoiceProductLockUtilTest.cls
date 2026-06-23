@IsTest
private class InvoiceProductLockUtilTest {
    @IsTest
    static void isLocked_returnsFalseForUnlockedProduct() {
        InvoiceProduct__c product = new InvoiceProduct__c(
            ActualInvoiceDate__c = null,
            LatestExportDate__c = null
        );
        System.assertEquals(false, InvoiceProductLockUtil.isLocked(product));
    }

    @IsTest
    static void isLocked_returnsTrueWhenInvoiced() {
        InvoiceProduct__c product = new InvoiceProduct__c(
            ActualInvoiceDate__c = Date.today(),
            LatestExportDate__c = null
        );
        System.assertEquals(true, InvoiceProductLockUtil.isLocked(product));
    }

    @IsTest
    static void isLocked_returnsTrueWhenExported() {
        InvoiceProduct__c product = new InvoiceProduct__c(
            ActualInvoiceDate__c = null,
            LatestExportDate__c = Date.today()
        );
        System.assertEquals(true, InvoiceProductLockUtil.isLocked(product));
    }

    @IsTest
    static void isExportedAndInvoiced_helpers() {
        InvoiceProduct__c exported = new InvoiceProduct__c(
            LatestExportDate__c = Date.today(),
            ActualInvoiceDate__c = null
        );
        InvoiceProduct__c invoiced = new InvoiceProduct__c(
            LatestExportDate__c = null,
            ActualInvoiceDate__c = Date.today()
        );
        System.assertEquals(true, InvoiceProductLockUtil.isExported(exported));
        System.assertEquals(false, InvoiceProductLockUtil.isInvoiced(exported));
        System.assertEquals(true, InvoiceProductLockUtil.isInvoiced(invoiced));
    }
}
