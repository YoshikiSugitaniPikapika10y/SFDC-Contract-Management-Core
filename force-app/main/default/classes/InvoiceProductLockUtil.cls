public without sharing class InvoiceProductLockUtil {
    public static Boolean isLocked(InvoiceProduct__c invoiceProduct) {
        if (invoiceProduct == null) {
            return false;
        }
        return isInvoiced(invoiceProduct) || isExported(invoiceProduct);
    }

    public static Boolean isInvoiced(InvoiceProduct__c invoiceProduct) {
        return invoiceProduct != null && invoiceProduct.ActualInvoiceDate__c != null;
    }

    public static Boolean isExported(InvoiceProduct__c invoiceProduct) {
        return invoiceProduct != null && invoiceProduct.LatestExportDate__c != null;
    }
}
