public without sharing class ContractProductAmountUtil {
    private static final String PRODUCT_TYPE_ORIGINAL = 'Original';
    private static final String PRODUCT_TYPE_REMAKE = 'Remake';
    private static final String LEGACY_PRODUCT_TYPE_DERIVATIVE = 'derivative';

    public static Decimal calculateSignedAmount(
        ContractProduct__c product,
        String productBillingType
    ) {
        if (product == null) {
            return null;
        }
        Decimal unsignedAmount = calculateUnsignedAmount(
            product.Quantity__c,
            product.UnitPrice__c,
            resolveBillingType(product, productBillingType),
            product.StartDate__c,
            product.Enddate__c
        );
        return applyProductTypeSign(unsignedAmount, product);
    }

    private static Decimal applyProductTypeSign(
        Decimal amount,
        ContractProduct__c product
    ) {
        if (amount == null || product == null) {
            return amount;
        }
        if (isReversalProductType(product)) {
            return -Math.abs(amount);
        }
        return amount;
    }

    private static Boolean isReversalProductType(ContractProduct__c product) {
        if (product.Type__c == PRODUCT_TYPE_ORIGINAL) {
            return true;
        }
        return product.Type__c == PRODUCT_TYPE_REMAKE &&
            product.Amount__c != null &&
            product.Amount__c < 0;
    }

    public static Decimal calculateUnsignedAmount(
        Decimal quantity,
        Decimal unitPrice,
        String billingType,
        Date startDate,
        Date endDate
    ) {
        Decimal qty = quantity == null ? 0 : quantity;
        Decimal price = unitPrice == null ? 0 : unitPrice;
        if (qty <= 0 || price == 0) {
            return 0;
        }

        if (!ContractMetadataService.isRecurringBillingType(billingType)) {
            return qty * price;
        }
        if (startDate == null || endDate == null) {
            return null;
        }

        Date normalizedEndDate = MonthlyBillingPeriodUtil.resolveMonthlyEndDate(
            startDate,
            endDate
        );
        Integer cycles = MonthlyBillingPeriodUtil.countMonthlyCycles(
            startDate,
            normalizedEndDate
        );
        if (cycles == null || cycles < 0) {
            return null;
        }
        return qty * price * cycles;
    }

    public static Decimal applyProductTypeSign(Decimal amount, String productType) {
        if (amount == null) {
            return null;
        }
        if (productType == PRODUCT_TYPE_ORIGINAL) {
            return -Math.abs(amount);
        }
        return amount;
    }

    private static String resolveBillingType(
        ContractProduct__c product,
        String productBillingType
    ) {
        if (product != null && String.isNotBlank(product.BillingType__c)) {
            return product.BillingType__c;
        }
        return productBillingType;
    }
}
