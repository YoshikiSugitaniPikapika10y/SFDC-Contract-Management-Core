@IsTest
private class MonthlyBillingPeriodUtilTest {
    @IsTest
    static void countMonthlyCycles_matchesFullYear() {
        Date startDate = Date.newInstance(2025, 1, 1);
        Date endDate = Date.newInstance(2025, 12, 31);

        System.assertEquals(
            12,
            MonthlyBillingPeriodUtil.countMonthlyCycles(startDate, endDate)
        );
    }

    @IsTest
    static void buildMonthlyPeriods_returnsAlignedPeriods() {
        Date startDate = Date.newInstance(2025, 1, 15);
        Date endDate = Date.newInstance(2025, 3, 14);

        List<MonthlyBillingPeriodUtil.BillingPeriod> periods =
            MonthlyBillingPeriodUtil.buildMonthlyPeriods(startDate, endDate);

        System.assertEquals(2, periods.size());
        System.assertEquals(startDate, periods[0].startDate);
        System.assertEquals(Date.newInstance(2025, 2, 14), periods[0].endDate);
        System.assertEquals(Date.newInstance(2025, 2, 15), periods[1].startDate);
        System.assertEquals(endDate, periods[1].endDate);
    }

    @IsTest
    static void resolveMonthlyEndDate_normalizesMisalignedEndDate() {
        Date startDate = Date.newInstance(2025, 1, 15);
        Date endDate = Date.newInstance(2025, 2, 10);

        System.assertEquals(
            Date.newInstance(2025, 2, 14),
            MonthlyBillingPeriodUtil.resolveMonthlyEndDate(startDate, endDate)
        );
    }

    @IsTest
    static void buildCalendarMonthPeriods_splitsByCalendarMonth() {
        Date startDate = Date.newInstance(2026, 6, 15);
        Date endDate = Date.newInstance(2027, 5, 31);

        List<MonthlyBillingPeriodUtil.BillingPeriod> periods =
            MonthlyBillingPeriodUtil.buildCalendarMonthPeriods(startDate, endDate);

        System.assertEquals(12, periods.size());
        System.assertEquals(startDate, periods[0].startDate);
        System.assertEquals(Date.newInstance(2026, 6, 30), periods[0].endDate);
        System.assertEquals(Date.newInstance(2026, 7, 1), periods[1].startDate);
        System.assertEquals(Date.newInstance(2026, 7, 31), periods[1].endDate);
        System.assertEquals(Date.newInstance(2027, 5, 1), periods[11].startDate);
        System.assertEquals(endDate, periods[11].endDate);
    }

    @IsTest
    static void endOfCalendarMonth_returnsLastDayOfMonth() {
        System.assertEquals(
            Date.newInstance(2026, 2, 28),
            MonthlyBillingPeriodUtil.endOfCalendarMonth(Date.newInstance(2026, 2, 10))
        );
    }

    @IsTest
    static void isMonthlyPeriodStartDate_matchesAnniversaryStarts() {
        Date anchor = Date.newInstance(2026, 4, 15);

        System.assertEquals(
            true,
            MonthlyBillingPeriodUtil.isMonthlyPeriodStartDate(
                anchor,
                Date.newInstance(2026, 10, 15)
            )
        );
        System.assertEquals(
            false,
            MonthlyBillingPeriodUtil.isMonthlyPeriodStartDate(
                anchor,
                Date.newInstance(2026, 10, 20)
            )
        );
        System.assertEquals(
            true,
            MonthlyBillingPeriodUtil.isMonthlyPeriodStartDate(anchor, anchor)
        );
    }

    @IsTest
    static void invalidDates_returnSafeDefaults() {
        System.assertEquals(-1, MonthlyBillingPeriodUtil.countMonthlyCycles(null, Date.today()));
        System.assertEquals(-1, MonthlyBillingPeriodUtil.countMonthlyCycles(Date.today(), null));
        System.assertEquals(0, MonthlyBillingPeriodUtil.buildMonthlyPeriods(null, Date.today()).size());
        System.assertEquals(
            Date.newInstance(2025, 2, 28),
            MonthlyBillingPeriodUtil.endOfMonthlyPeriod(Date.newInstance(2025, 2, 1))
        );
    }
}
