public with sharing class InvoiceProductExportController {
    public class ExportLineDto {
        @AuraEnabled
        public Id invoiceProductId;

        @AuraEnabled
        public Date invoiceDate;

        @AuraEnabled
        public Date paymentScheduledDate;

        @AuraEnabled
        public Date startDate;

        @AuraEnabled
        public Date endDate;

        @AuraEnabled
        public Decimal amount;

        @AuraEnabled
        public String invoiceType;

        @AuraEnabled
        public String productName;

        @AuraEnabled
        public String billingAccountName;

        @AuraEnabled
        public Boolean exported;
    }

    public class MarkExportedResponse {
        @AuraEnabled
        public Integer updatedCount;

        @AuraEnabled
        public Date exportDate;
    }

    @AuraEnabled
    public static List<ExportLineDto> getExportCandidates(
        Id contractHistoryId,
        Date invoiceDateFrom,
        Date invoiceDateTo
    ) {
        try {
            List<ExportLineDto> rows = new List<ExportLineDto>();
            for (InvoiceProductExportService.ExportLine line : InvoiceProductExportService.getExportCandidates(
                contractHistoryId,
                invoiceDateFrom,
                invoiceDateTo
            )) {
                ExportLineDto dto = new ExportLineDto();
                dto.invoiceProductId = line.invoiceProductId;
                dto.invoiceDate = line.invoiceDate;
                dto.paymentScheduledDate = line.paymentScheduledDate;
                dto.startDate = line.startDate;
                dto.endDate = line.endDate;
                dto.amount = line.amount;
                dto.invoiceType = line.invoiceType;
                dto.productName = line.productName;
                dto.billingAccountName = line.billingAccountName;
                dto.exported = false;
                rows.add(dto);
            }
            return rows;
        } catch (InvoiceProductExportService.ExportServiceException ex) {
            throw new AuraHandledException(ex.getMessage());
        }
    }

    @AuraEnabled
    public static MarkExportedResponse markAsExportedByInvoiceDateRange(
        Id contractHistoryId,
        Date invoiceDateFrom,
        Date invoiceDateTo,
        Date exportDate
    ) {
        try {
            InvoiceProductExportService.MarkExportedResult result =
                InvoiceProductExportService.markAsExportedByInvoiceDateRange(
                    contractHistoryId,
                    invoiceDateFrom,
                    invoiceDateTo,
                    exportDate
                );
            MarkExportedResponse response = new MarkExportedResponse();
            response.updatedCount = result.updatedCount;
            response.exportDate = result.exportDate;
            return response;
        } catch (InvoiceProductExportService.ExportServiceException ex) {
            throw new AuraHandledException(ex.getMessage());
        }
    }

    @AuraEnabled
    public static MarkExportedResponse markAsExported(
        Id contractHistoryId,
        List<Id> invoiceProductIds,
        Date exportDate
    ) {
        try {
            InvoiceProductExportService.MarkExportedResult result =
                InvoiceProductExportService.markAsExported(
                    contractHistoryId,
                    invoiceProductIds,
                    exportDate
                );
            MarkExportedResponse response = new MarkExportedResponse();
            response.updatedCount = result.updatedCount;
            response.exportDate = result.exportDate;
            return response;
        } catch (InvoiceProductExportService.ExportServiceException ex) {
            throw new AuraHandledException(ex.getMessage());
        }
    }

    @AuraEnabled
    public static Integer clearExportDate(
        Id contractHistoryId,
        List<Id> invoiceProductIds
    ) {
        try {
            return InvoiceProductExportService.clearExportDate(
                contractHistoryId,
                invoiceProductIds
            );
        } catch (InvoiceProductExportService.ExportServiceException ex) {
            throw new AuraHandledException(ex.getMessage());
        }
    }
}
