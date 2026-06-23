@IsTest
private class TaxCalculationUtilTest {
    @IsTest
    static void resolveTaxPercent_defaultsToTen() {
        System.assertEquals(10, TaxCalculationUtil.resolveTaxPercent(null));
        System.assertEquals(8, TaxCalculationUtil.resolveTaxPercent(8));
    }

    @IsTest
    static void calculateTaxAmount_floorsTax() {
        System.assertEquals(0, TaxCalculationUtil.calculateTaxAmount(null, 10));
        System.assertEquals(0, TaxCalculationUtil.calculateTaxAmount(0, 10));
        System.assertEquals(1200, TaxCalculationUtil.calculateTaxAmount(12000, 10));
        System.assertEquals(800, TaxCalculationUtil.calculateTaxAmount(8000, 10));
        System.assertEquals(-100, TaxCalculationUtil.calculateTaxAmount(-1000, 10));
    }

    @IsTest
    static void calculateAmountInclTax_addsTaxAmount() {
        System.assertEquals(
            13200,
            TaxCalculationUtil.calculateAmountInclTax(12000, 10)
        );
    }

    @IsTest
    static void toPercentFieldStorage_convertsDisplayPercent() {
        System.assertEquals(0.1, TaxCalculationUtil.toPercentFieldStorage(10));
        System.assertEquals(0.08, TaxCalculationUtil.toPercentFieldStorage(8));
    }

    @IsTest
    static void resolveTaxPercent_normalizesMisStoredPercent() {
        System.assertEquals(10, TaxCalculationUtil.resolveTaxPercent(1000));
        System.assertEquals(8, TaxCalculationUtil.resolveTaxPercent(0.08));
    }

    @IsTest
    static void formatTaxPercentLabel_formatsResolvedPercent() {
        System.assertEquals('10', TaxCalculationUtil.formatTaxPercentLabel(null));
        System.assertEquals('8', TaxCalculationUtil.formatTaxPercentLabel(8));
    }
}
