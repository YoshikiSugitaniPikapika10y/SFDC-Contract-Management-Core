public without sharing class MonthlyBillingPeriodUtil {
    public class BillingPeriod {
        public Date startDate;
        public Date endDate;

        public BillingPeriod(Date startDate, Date endDate) {
            this.startDate = startDate;
            this.endDate = endDate;
        }
    }

    public static List<BillingPeriod> buildMonthlyPeriods(Date startDate, Date endDate) {
        List<BillingPeriod> periods = new List<BillingPeriod>();
        if (startDate == null || endDate == null || endDate < startDate) {
            return periods;
        }

        Date normalizedEndDate = resolveMonthlyEndDate(startDate, endDate);
        Date periodStart = startDate;
        while (true) {
            Date periodEnd = endOfMonthlyPeriod(periodStart);
            if (periodEnd > normalizedEndDate) {
                break;
            }
            periods.add(new BillingPeriod(periodStart, periodEnd));
            if (periodEnd == normalizedEndDate) {
                break;
            }
            periodStart = periodEnd.addDays(1);
        }
        return periods;
    }

    public static Date resolveMonthlyEndDate(Date startDate, Date endDate) {
        if (startDate == null || endDate == null || endDate < startDate) {
            return endDate;
        }
        if (countMonthlyCycles(startDate, endDate) >= 0) {
            return endDate;
        }

        Date periodStart = startDate;
        while (true) {
            Date periodEnd = endOfMonthlyPeriod(periodStart);
            if (endDate < periodStart) {
                break;
            }
            if (endDate <= periodEnd) {
                return periodEnd;
            }
            periodStart = periodEnd.addDays(1);
        }
        return endDate;
    }

    public static Integer countMonthlyCycles(Date startDate, Date endDate) {
        if (startDate == null || endDate == null || endDate < startDate) {
            return -1;
        }

        Integer cycles = 0;
        Date periodStart = startDate;
        while (true) {
            Date periodEnd = endOfMonthlyPeriod(periodStart);
            if (periodEnd > endDate) {
                return -1;
            }
            cycles++;
            if (periodEnd == endDate) {
                return cycles;
            }
            periodStart = periodEnd.addDays(1);
        }
        return -1;
    }

    public static Date endOfMonthlyPeriod(Date periodStart) {
        return periodStart.addMonths(1).addDays(-1);
    }

    public static Boolean isMonthlyPeriodStartDate(
        Date anchorStartDate,
        Date candidateDate
    ) {
        if (
            anchorStartDate == null ||
            candidateDate == null ||
            candidateDate < anchorStartDate
        ) {
            return false;
        }

        Date periodStart = anchorStartDate;
        while (periodStart <= candidateDate) {
            if (periodStart == candidateDate) {
                return true;
            }
            periodStart = endOfMonthlyPeriod(periodStart).addDays(1);
        }
        return false;
    }

    public static Date endOfCalendarMonth(Date referenceDate) {
        if (referenceDate == null) {
            return null;
        }
        return Date.newInstance(referenceDate.year(), referenceDate.month(), 1)
            .addMonths(1)
            .addDays(-1);
    }

    public static List<BillingPeriod> buildCalendarMonthPeriods(
        Date startDate,
        Date endDate
    ) {
        List<BillingPeriod> periods = new List<BillingPeriod>();
        if (startDate == null || endDate == null || endDate < startDate) {
            return periods;
        }

        Date periodStart = startDate;
        while (periodStart <= endDate) {
            Date calendarMonthEnd = endOfCalendarMonth(periodStart);
            Date periodEnd = calendarMonthEnd > endDate ? endDate : calendarMonthEnd;
            periods.add(new BillingPeriod(periodStart, periodEnd));
            if (periodEnd == endDate) {
                break;
            }
            periodStart = periodEnd.addDays(1);
        }
        return periods;
    }
}
