public without sharing class TaxCalculationUtil {
    public static final Decimal DEFAULT_TAX_PERCENT = 10;

    public static Decimal resolveTaxPercent(Decimal taxPercent) {
        if (taxPercent == null) {
            return DEFAULT_TAX_PERCENT;
        }
        if (taxPercent > 100) {
            return taxPercent / 100;
        }
        if (taxPercent > 0 && taxPercent <= 1) {
            return taxPercent * 100;
        }
        return taxPercent;
    }

    public static Decimal toPercentFieldStorage(Decimal displayPercent) {
        return resolveTaxPercent(displayPercent) / 100;
    }

    public static Decimal calculateTaxAmount(
        Decimal amountExclTax,
        Decimal taxPercent
    ) {
        if (amountExclTax == null || amountExclTax == 0) {
            return 0;
        }
        Decimal rate = resolveTaxPercent(taxPercent) / 100;
        return (amountExclTax * rate).setScale(0, RoundingMode.DOWN);
    }

    public static Decimal calculateAmountInclTax(
        Decimal amountExclTax,
        Decimal taxPercent
    ) {
        Decimal excl = amountExclTax == null ? 0 : amountExclTax;
        return excl + calculateTaxAmount(excl, taxPercent);
    }

    public static String formatTaxPercentLabel(Decimal taxPercent) {
        Decimal resolved = resolveTaxPercent(taxPercent);
        if (resolved == null) {
            return String.valueOf(DEFAULT_TAX_PERCENT.intValue());
        }
        if (resolved == resolved.intValue()) {
            return String.valueOf(resolved.intValue());
        }
        return String.valueOf(resolved.stripTrailingZeros());
    }
}
