public with sharing class InvoiceProductInvoicedController {
    public class InvoiceProductRow {
        @AuraEnabled
        public Id id;

        @AuraEnabled
        public String name;

        @AuraEnabled
        public Date invoiceDate;

        @AuraEnabled
        public Date startDate;

        @AuraEnabled
        public Date endDate;

        @AuraEnabled
        public Decimal amount;

        @AuraEnabled
        public Date actualInvoiceDate;

        @AuraEnabled
        public Boolean invoiced;

        @AuraEnabled
        public Date latestExportDate;

        @AuraEnabled
        public Boolean exported;

        @AuraEnabled
        public Boolean locked;

        @AuraEnabled
        public String invoiceType;

        @AuraEnabled
        public Integer rowNumber;
    }

    @AuraEnabled
    public static List<InvoiceProductRow> getInvoiceProducts(Id contractHistoryId) {
        if (contractHistoryId == null) {
            return new List<InvoiceProductRow>();
        }

        List<InvoiceProductRow> rows = new List<InvoiceProductRow>();
        Integer rowNumber = 0;
        for (InvoiceProduct__c product : [
            SELECT
                Id,
                Name,
                InvoiceDate__c,
                StartDate__c,
                Enddate__c,
                Amount__c,
                ActualInvoiceDate__c,
                LatestExportDate__c,
                invoicetype__c
            FROM InvoiceProduct__c
            WHERE ContractHistory__c = :contractHistoryId
            ORDER BY InvoiceDate__c ASC NULLS LAST, StartDate__c ASC NULLS LAST, Name ASC
        ]) {
            rowNumber++;
            InvoiceProductRow row = new InvoiceProductRow();
            row.id = product.Id;
            row.name = product.Name;
            row.invoiceDate = product.InvoiceDate__c;
            row.startDate = product.StartDate__c;
            row.endDate = product.Enddate__c;
            row.amount = product.Amount__c;
            row.actualInvoiceDate = product.ActualInvoiceDate__c;
            row.invoiced = InvoiceProductLockUtil.isInvoiced(product);
            row.latestExportDate = product.LatestExportDate__c;
            row.exported = InvoiceProductLockUtil.isExported(product);
            row.locked = InvoiceProductLockUtil.isLocked(product);
            row.invoiceType = product.invoicetype__c;
            row.rowNumber = rowNumber;
            rows.add(row);
        }
        return rows;
    }

    @AuraEnabled
    public static Integer updateInvoicedFlag(
        Id contractHistoryId,
        List<Id> invoiceProductIds,
        Boolean invoiced,
        Date actualInvoiceDate
    ) {
        if (
            contractHistoryId == null ||
            invoiceProductIds == null ||
            invoiceProductIds.isEmpty()
        ) {
            return 0;
        }

        List<InvoiceProduct__c> products = queryProductsForUpdate(
            contractHistoryId,
            invoiceProductIds
        );
        return applyActualInvoiceDate(products, invoiced, actualInvoiceDate);
    }

    @AuraEnabled
    public static Integer updateInvoicedFlagByInvoiceDateRange(
        Id contractHistoryId,
        Date invoiceDateFrom,
        Date invoiceDateTo,
        Boolean invoiced,
        Date actualInvoiceDate
    ) {
        if (contractHistoryId == null) {
            return 0;
        }
        if (invoiceDateFrom == null && invoiceDateTo == null) {
            throw new AuraHandledException('請求日の範囲を指定してください。');
        }
        if (
            invoiceDateFrom != null &&
            invoiceDateTo != null &&
            invoiceDateFrom > invoiceDateTo
        ) {
            throw new AuraHandledException(
                '請求日（開始）は請求日（終了）以前の日付を指定してください。'
            );
        }

        String query =
            'SELECT Id, ActualInvoiceDate__c FROM InvoiceProduct__c ' +
            'WHERE ContractHistory__c = :contractHistoryId';
        if (invoiceDateFrom != null) {
            query += ' AND InvoiceDate__c >= :invoiceDateFrom';
        }
        if (invoiceDateTo != null) {
            query += ' AND InvoiceDate__c <= :invoiceDateTo';
        }
        query += ' ORDER BY InvoiceDate__c ASC NULLS LAST, Name ASC';

        List<InvoiceProduct__c> products = Database.query(query);
        if (products.isEmpty()) {
            throw new AuraHandledException('指定範囲に該当する請求商品がありません。');
        }
        return applyActualInvoiceDate(products, invoiced, actualInvoiceDate);
    }

    private static List<InvoiceProduct__c> queryProductsForUpdate(
        Id contractHistoryId,
        List<Id> invoiceProductIds
    ) {
        return [
            SELECT Id, ActualInvoiceDate__c
            FROM InvoiceProduct__c
            WHERE ContractHistory__c = :contractHistoryId
            AND Id IN :invoiceProductIds
        ];
    }

    private static Integer applyActualInvoiceDate(
        List<InvoiceProduct__c> products,
        Boolean invoiced,
        Date actualInvoiceDate
    ) {
        if (products == null || products.isEmpty()) {
            return 0;
        }

        Date targetDate = invoiced == true
            ? (actualInvoiceDate == null ? Date.today() : actualInvoiceDate)
            : null;
        List<InvoiceProduct__c> updates = new List<InvoiceProduct__c>();
        for (InvoiceProduct__c product : products) {
            if (product.ActualInvoiceDate__c == targetDate) {
                continue;
            }
            updates.add(
                new InvoiceProduct__c(
                    Id = product.Id,
                    ActualInvoiceDate__c = targetDate
                )
            );
        }

        if (updates.isEmpty()) {
            return 0;
        }

        update updates;
        return updates.size();
    }
}
