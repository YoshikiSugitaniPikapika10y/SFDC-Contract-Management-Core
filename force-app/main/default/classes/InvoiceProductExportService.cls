public without sharing class InvoiceProductExportService {
    public class ExportLine {
        public Id invoiceProductId;
        public Id contractHistoryId;
        public String contractHistoryName;
        public Id contractProductId;
        public Id billingAccountId;
        public String billingAccountName;
        public Id accountId;
        public String accountName;
        public Date invoiceDate;
        public Date paymentScheduledDate;
        public Date startDate;
        public Date endDate;
        public Decimal amount;
        public String invoiceType;
        public String productName;
        public List<Id> sourceInvoiceProductIds;
    }

    public class ExportGroup {
        public Id billingAccountId;
        public String billingAccountName;
        public Id accountId;
        public String accountName;
        public Date invoiceDate;
        public Integer lineCount;
        public Decimal totalAmount;
        public List<ExportLine> lines;
    }

    public class MarkExportedResult {
        public Integer updatedCount;
        public Date exportDate;
    }

    public static List<ExportLine> getExportCandidates(
        Id contractHistoryId,
        Date invoiceDateFrom,
        Date invoiceDateTo
    ) {
        validateDateRange(invoiceDateFrom, invoiceDateTo);
        if (contractHistoryId == null) {
            return new List<ExportLine>();
        }

        Id contractServiceId = resolveContractServiceId(contractHistoryId);
        if (contractServiceId == null) {
            return new List<ExportLine>();
        }

        List<InvoiceProduct__c> products = queryUnexportedProductsByService(
            contractServiceId,
            null,
            null
        );
        return mapMergedExportLines(products, invoiceDateFrom, invoiceDateTo, true);
    }

    public static List<ExportGroup> buildExportGroups(
        Id contractHistoryId,
        Date invoiceDateFrom,
        Date invoiceDateTo
    ) {
        Map<String, ExportGroup> groupsByKey = new Map<String, ExportGroup>();
        for (ExportLine line : getExportCandidates(
            contractHistoryId,
            invoiceDateFrom,
            invoiceDateTo
        )) {
            String groupKey =
                String.valueOf(line.billingAccountId) +
                '|' +
                String.valueOf(line.invoiceDate);
            ExportGroup exportGroup = groupsByKey.get(groupKey);
            if (exportGroup == null) {
                exportGroup = new ExportGroup();
                exportGroup.billingAccountId = line.billingAccountId;
                exportGroup.billingAccountName = line.billingAccountName;
                exportGroup.accountId = line.accountId;
                exportGroup.accountName = line.accountName;
                exportGroup.invoiceDate = line.invoiceDate;
                exportGroup.lines = new List<ExportLine>();
                groupsByKey.put(groupKey, exportGroup);
            }
            exportGroup.lines.add(line);
        }

        List<ExportGroup> groups = new List<ExportGroup>();
        for (ExportGroup exportGroup : groupsByKey.values()) {
            exportGroup.lineCount = exportGroup.lines.size();
            exportGroup.totalAmount = sumAmounts(exportGroup.lines);
            groups.add(exportGroup);
        }
        groups.sort(new ExportGroupComparator());
        return groups;
    }

    public static MarkExportedResult markAsExported(
        Id contractHistoryId,
        List<Id> invoiceProductIds,
        Date exportDate
    ) {
        if (contractHistoryId == null || invoiceProductIds == null || invoiceProductIds.isEmpty()) {
            MarkExportedResult emptyResult = new MarkExportedResult();
            emptyResult.updatedCount = 0;
            emptyResult.exportDate = normalizeExportDate(exportDate);
            return emptyResult;
        }

        Id contractServiceId = resolveContractServiceId(contractHistoryId);
        Date targetExportDate = normalizeExportDate(exportDate);
        List<InvoiceProduct__c> allUnexportedProducts = queryUnexportedProductsByService(
            contractServiceId,
            null,
            null
        );
        Map<String, List<InvoiceProduct__c>> productsByMergeKey =
            groupProductsByMergeKey(allUnexportedProducts);
        Set<Id> productIdsToLock = new Set<Id>();
        for (Id invoiceProductId : invoiceProductIds) {
            for (List<InvoiceProduct__c> groupedProducts : productsByMergeKey.values()) {
                for (InvoiceProduct__c product : groupedProducts) {
                    if (product.Id == invoiceProductId) {
                        for (InvoiceProduct__c groupedProduct : groupedProducts) {
                            productIdsToLock.add(groupedProduct.Id);
                        }
                    }
                }
            }
        }

        List<InvoiceProduct__c> products = [
            SELECT Id, LatestExportDate__c
            FROM InvoiceProduct__c
            WHERE Id IN :productIdsToLock
            WITH SYSTEM_MODE
        ];
        return applyExportDate(products, targetExportDate);
    }

    public static MarkExportedResult markAsExportedByInvoiceDateRange(
        Id contractHistoryId,
        Date invoiceDateFrom,
        Date invoiceDateTo,
        Date exportDate
    ) {
        validateDateRange(invoiceDateFrom, invoiceDateTo);
        if (contractHistoryId == null) {
            MarkExportedResult emptyResult = new MarkExportedResult();
            emptyResult.updatedCount = 0;
            emptyResult.exportDate = normalizeExportDate(exportDate);
            return emptyResult;
        }

        Id contractServiceId = resolveContractServiceId(contractHistoryId);
        Date targetExportDate = normalizeExportDate(exportDate);
        List<InvoiceProduct__c> products = queryUnexportedProductsByService(
            contractServiceId,
            invoiceDateFrom,
            invoiceDateTo
        );
        Set<Id> productIdsToLock = collectMergeGroupProductIds(
            products,
            invoiceDateFrom,
            invoiceDateTo
        );
        List<InvoiceProduct__c> productsToUpdate = [
            SELECT Id, LatestExportDate__c
            FROM InvoiceProduct__c
            WHERE Id IN :productIdsToLock
            WITH SYSTEM_MODE
        ];
        return applyExportDate(productsToUpdate, targetExportDate);
    }

    public static Integer clearExportDate(
        Id contractHistoryId,
        List<Id> invoiceProductIds
    ) {
        if (contractHistoryId == null || invoiceProductIds == null || invoiceProductIds.isEmpty()) {
            return 0;
        }

        List<InvoiceProduct__c> products = [
            SELECT Id, LatestExportDate__c, ActualInvoiceDate__c
            FROM InvoiceProduct__c
            WHERE ContractHistory__c = :contractHistoryId
            AND Id IN :invoiceProductIds
            WITH SYSTEM_MODE
        ];

        List<InvoiceProduct__c> updates = new List<InvoiceProduct__c>();
        for (InvoiceProduct__c product : products) {
            if (product.LatestExportDate__c == null) {
                continue;
            }
            if (InvoiceProductLockUtil.isInvoiced(product)) {
                throw new ExportServiceException(
                    '請求済の請求商品は連携解除できません。'
                );
            }
            updates.add(
                new InvoiceProduct__c(
                    Id = product.Id,
                    LatestExportDate__c = null
                )
            );
        }

        if (updates.isEmpty()) {
            return 0;
        }
        SystemContextAccess.updateRecords(updates);
        return updates.size();
    }

    private static Id resolveContractServiceId(Id contractHistoryId) {
        List<ContractHistory__c> histories = [
            SELECT ContractService__c
            FROM ContractHistory__c
            WHERE Id = :contractHistoryId
            WITH SYSTEM_MODE
            LIMIT 1
        ];
        return histories.isEmpty() ? null : histories[0].ContractService__c;
    }

    private static List<InvoiceProduct__c> queryUnexportedProductsByService(
        Id contractServiceId,
        Date invoiceDateFrom,
        Date invoiceDateTo
    ) {
        if (contractServiceId == null) {
            return new List<InvoiceProduct__c>();
        }

        String query =
            'SELECT ' +
            'Id, Name, InvoiceDate__c, PaymentScheduledDate__c, StartDate__c, Enddate__c, ' +
            'Amount__c, invoicetype__c, LatestExportDate__c, ExportMergeKey__c, ' +
            'ContractHistory__c, ContractHistory__r.Name, ' +
            'ContractProduct__c, ContractProduct__r.Product__c, ContractProduct__r.Product__r.Name, ' +
            'ContractHistory__r.ContractService__c, ' +
            'ContractHistory__r.ContractService__r.Account__c, ' +
            'ContractHistory__r.ContractService__r.Account__r.Name, ' +
            'ContractHistory__r.ContractService__r.BiilingAcccount__c, ' +
            'ContractHistory__r.ContractService__r.BiilingAcccount__r.Name ' +
            'FROM InvoiceProduct__c ' +
            'WHERE ContractHistory__r.ContractService__c = :contractServiceId ' +
            'AND LatestExportDate__c = NULL ' +
            'AND ActualInvoiceDate__c = NULL ' +
            'AND Amount__c != NULL';
        if (invoiceDateFrom != null) {
            query += ' AND InvoiceDate__c >= :invoiceDateFrom';
        }
        if (invoiceDateTo != null) {
            query += ' AND InvoiceDate__c <= :invoiceDateTo';
        }
        query +=
            ' ORDER BY InvoiceDate__c ASC NULLS LAST, StartDate__c ASC NULLS LAST, Name ASC';
        return Database.query(query);
    }

    private static Map<String, List<InvoiceProduct__c>> groupProductsByMergeKey(
        List<InvoiceProduct__c> products
    ) {
        Map<String, List<InvoiceProduct__c>> productsByMergeKey =
            new Map<String, List<InvoiceProduct__c>>();
        for (InvoiceProduct__c product : products) {
            String mergeKey = InvoiceProductMergeKeyUtil.buildMergeKey(product);
            if (String.isBlank(mergeKey)) {
                continue;
            }
            if (!productsByMergeKey.containsKey(mergeKey)) {
                productsByMergeKey.put(mergeKey, new List<InvoiceProduct__c>());
            }
            productsByMergeKey.get(mergeKey).add(product);
        }
        return productsByMergeKey;
    }

    private static Set<Id> collectMergeGroupProductIds(
        List<InvoiceProduct__c> products,
        Date invoiceDateFrom,
        Date invoiceDateTo
    ) {
        Map<String, List<InvoiceProduct__c>> productsByMergeKey =
            groupProductsByMergeKey(products);
        Set<Id> productIds = new Set<Id>();
        for (List<InvoiceProduct__c> groupedProducts : productsByMergeKey.values()) {
            Boolean hasMemberInRange = false;
            for (InvoiceProduct__c product : groupedProducts) {
                if (isInvoiceDateInRange(product.InvoiceDate__c, invoiceDateFrom, invoiceDateTo)) {
                    hasMemberInRange = true;
                    break;
                }
            }
            if (!hasMemberInRange) {
                continue;
            }
            for (InvoiceProduct__c product : groupedProducts) {
                productIds.add(product.Id);
            }
        }
        return productIds;
    }

    private static List<ExportLine> mapMergedExportLines(
        List<InvoiceProduct__c> products,
        Date invoiceDateFrom,
        Date invoiceDateTo,
        Boolean excludeZeroNetGroups
    ) {
        Map<String, List<InvoiceProduct__c>> productsByMergeKey =
            groupProductsByMergeKey(products);
        List<ExportLine> lines = new List<ExportLine>();

        for (List<InvoiceProduct__c> groupedProducts : productsByMergeKey.values()) {
            Decimal totalAmount = 0;
            for (InvoiceProduct__c product : groupedProducts) {
                totalAmount += product.Amount__c == null ? 0 : product.Amount__c;
            }
            if (excludeZeroNetGroups && totalAmount == 0) {
                continue;
            }

            InvoiceProduct__c representative = groupedProducts[0];
            Boolean hasMemberInRange = false;
            for (InvoiceProduct__c product : groupedProducts) {
                if (isInvoiceDateInRange(product.InvoiceDate__c, invoiceDateFrom, invoiceDateTo)) {
                    hasMemberInRange = true;
                    representative = product;
                    break;
                }
            }
            if (!hasMemberInRange) {
                continue;
            }

            ExportLine line = mapExportLine(representative);
            line.amount = totalAmount;
            line.sourceInvoiceProductIds = new List<Id>();
            for (InvoiceProduct__c product : groupedProducts) {
                line.sourceInvoiceProductIds.add(product.Id);
            }
            lines.add(line);
        }
        return lines;
    }

    private static ExportLine mapExportLine(InvoiceProduct__c product) {
        ExportLine line = new ExportLine();
        line.invoiceProductId = product.Id;
        line.contractHistoryId = product.ContractHistory__c;
        line.contractHistoryName = product.ContractHistory__r.Name;
        line.contractProductId = product.ContractProduct__c;
        line.billingAccountId =
            product.ContractHistory__r.ContractService__r.BiilingAcccount__c;
        line.billingAccountName =
            product.ContractHistory__r.ContractService__r.BiilingAcccount__r == null
                ? null
                : product.ContractHistory__r.ContractService__r.BiilingAcccount__r.Name;
        line.accountId = product.ContractHistory__r.ContractService__r.Account__c;
        line.accountName =
            product.ContractHistory__r.ContractService__r.Account__r == null
                ? null
                : product.ContractHistory__r.ContractService__r.Account__r.Name;
        line.invoiceDate = product.InvoiceDate__c;
        line.paymentScheduledDate = product.PaymentScheduledDate__c;
        line.startDate = product.StartDate__c;
        line.endDate = product.Enddate__c;
        line.amount = product.Amount__c;
        line.invoiceType = product.invoicetype__c;
        line.productName = product.ContractProduct__r.Product__r == null
            ? product.Name
            : product.ContractProduct__r.Product__r.Name;
        return line;
    }

    private static Boolean isInvoiceDateInRange(
        Date invoiceDate,
        Date invoiceDateFrom,
        Date invoiceDateTo
    ) {
        if (invoiceDate == null) {
            return false;
        }
        if (invoiceDateFrom != null && invoiceDate < invoiceDateFrom) {
            return false;
        }
        if (invoiceDateTo != null && invoiceDate > invoiceDateTo) {
            return false;
        }
        return true;
    }

    private static MarkExportedResult applyExportDate(
        List<InvoiceProduct__c> products,
        Date exportDate
    ) {
        List<InvoiceProduct__c> updates = new List<InvoiceProduct__c>();
        for (InvoiceProduct__c product : products) {
            if (product.LatestExportDate__c == exportDate) {
                continue;
            }
            updates.add(
                new InvoiceProduct__c(
                    Id = product.Id,
                    LatestExportDate__c = exportDate
                )
            );
        }

        MarkExportedResult result = new MarkExportedResult();
        result.exportDate = exportDate;
        if (updates.isEmpty()) {
            result.updatedCount = 0;
            return result;
        }
        SystemContextAccess.updateRecords(updates);
        result.updatedCount = updates.size();
        return result;
    }

    private static Decimal sumAmounts(List<ExportLine> lines) {
        Decimal total = 0;
        for (ExportLine line : lines) {
            total += line.amount == null ? 0 : line.amount;
        }
        return total;
    }

    private static Date normalizeExportDate(Date exportDate) {
        return exportDate == null ? Date.today() : exportDate;
    }

    private static void validateDateRange(Date invoiceDateFrom, Date invoiceDateTo) {
        if (invoiceDateFrom != null && invoiceDateTo != null && invoiceDateFrom > invoiceDateTo) {
            throw new ExportServiceException(
                '請求日（開始）は請求日（終了）以前の日付を指定してください。'
            );
        }
    }

    public class ExportServiceException extends Exception {
    }

    private class ExportGroupComparator implements Comparator<ExportGroup> {
        public Integer compare(ExportGroup left, ExportGroup right) {
            if (left == null && right == null) {
                return 0;
            }
            if (left == null) {
                return -1;
            }
            if (right == null) {
                return 1;
            }
            if (left.invoiceDate == null && right.invoiceDate == null) {
                return compareString(left.billingAccountName, right.billingAccountName);
            }
            if (left.invoiceDate == null) {
                return -1;
            }
            if (right.invoiceDate == null) {
                return 1;
            }
            if (left.invoiceDate == right.invoiceDate) {
                return compareString(left.billingAccountName, right.billingAccountName);
            }
            return left.invoiceDate < right.invoiceDate ? -1 : 1;
        }

        private Integer compareString(String left, String right) {
            String leftValue = left == null ? '' : left;
            String rightValue = right == null ? '' : right;
            return leftValue.compareTo(rightValue);
        }
    }
}
