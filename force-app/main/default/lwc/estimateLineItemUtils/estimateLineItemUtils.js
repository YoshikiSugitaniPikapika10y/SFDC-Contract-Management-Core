export const BILLING_TYPE_RECURRING = '継続課金';

export const MONTHLY_BILLING_CYCLE = '月';

export const BILLING_TYPE_ONE_TIME = '一回課金';

export const INVOICE_BILLING_CATEGORY_RECURRING = 'Recurring';

export const INVOICE_BILLING_CATEGORY_ONE_TIME = 'OneTime';

export const INVOICE_SETTING_PREPAID_START = '一括前払';
export const INVOICE_SETTING_POSTPAID_NEXT_DAY = '一括後払';
export const INVOICE_SETTING_SPLIT_MONTHLY = '月次分割';

const LEGACY_INVOICE_SETTING_MAP = {
    継続課金_前請求: INVOICE_SETTING_PREPAID_START,
    継続課金_後請求: INVOICE_SETTING_POSTPAID_NEXT_DAY,
    継続課金_月次請求: INVOICE_SETTING_SPLIT_MONTHLY,
    '前請求（開始日）': INVOICE_SETTING_PREPAID_START,
    '後請求（翌日）': INVOICE_SETTING_POSTPAID_NEXT_DAY,
    '分割月次請求': INVOICE_SETTING_SPLIT_MONTHLY,
    一回課金_開始日請求: INVOICE_SETTING_PREPAID_START,
    '一回課金_終了日請求': INVOICE_SETTING_POSTPAID_NEXT_DAY
};

const RECURRING_INVOICE_SETTING_LABELS = [
    INVOICE_SETTING_PREPAID_START,
    INVOICE_SETTING_POSTPAID_NEXT_DAY,
    INVOICE_SETTING_SPLIT_MONTHLY
];

const ONE_TIME_INVOICE_SETTING_LABELS = [
    INVOICE_SETTING_PREPAID_START,
    INVOICE_SETTING_POSTPAID_NEXT_DAY
];

export function getAllowedInvoiceSettingLabels(billingType) {
    if (billingType === BILLING_TYPE_RECURRING) {
        return RECURRING_INVOICE_SETTING_LABELS;
    }
    if (billingType === BILLING_TYPE_ONE_TIME) {
        return ONE_TIME_INVOICE_SETTING_LABELS;
    }
    return [];
}

export function isAllowedInvoiceSettingForBillingType(billingType, invoiceType) {
    const normalizedInvoiceType = normalizeInvoiceSettingLabel(invoiceType);
    if (!normalizedInvoiceType) {
        return false;
    }
    return getAllowedInvoiceSettingLabels(billingType).includes(
        normalizedInvoiceType
    );
}

export const PRODUCT_TYPE_RENEW = 'Renew';

export const PRODUCT_TYPE_ORIGINAL = 'Original';

export const PRODUCT_TYPE_REMAKE = 'Remake';

export const LEGACY_PRODUCT_TYPE_DERIVATIVE = 'derivative';

export const PRODUCT_TYPE_NEW = 'New';

export function normalizeProductRecordType(recordType) {
    if (!recordType) {
        return PRODUCT_TYPE_NEW;
    }
    const value = String(recordType).trim();
    if (value.toLowerCase() === LEGACY_PRODUCT_TYPE_DERIVATIVE) {
        return PRODUCT_TYPE_REMAKE;
    }
    if (value === PRODUCT_TYPE_ORIGINAL) {
        return PRODUCT_TYPE_ORIGINAL;
    }
    if (value === PRODUCT_TYPE_REMAKE) {
        return PRODUCT_TYPE_REMAKE;
    }
    if (value === PRODUCT_TYPE_RENEW) {
        return PRODUCT_TYPE_RENEW;
    }
    if (value === PRODUCT_TYPE_NEW) {
        return PRODUCT_TYPE_NEW;
    }
    return value;
}

export function isChangeOriginalLine(line) {
    if (!line) {
        return false;
    }
    const recordType = normalizeProductRecordType(line.recordType);
    if (recordType === PRODUCT_TYPE_ORIGINAL) {
        return true;
    }
    return recordType === PRODUCT_TYPE_REMAKE && line.isReadonly === true;
}

export function isChangeRemakeLine(line) {
    if (!line || !line.sourceContractProductId) {
        return false;
    }
    if (isChangeOriginalLine(line)) {
        return false;
    }
    return normalizeProductRecordType(line.recordType) === PRODUCT_TYPE_REMAKE;
}

export function resolveProductTypeBadge(recordType, typeLabel) {
    const normalized = normalizeProductRecordType(recordType);
    const label =
        typeLabel ||
        (normalized === PRODUCT_TYPE_ORIGINAL
            ? 'Original'
            : normalized === PRODUCT_TYPE_REMAKE
              ? 'Remake'
              : normalized === PRODUCT_TYPE_RENEW
                ? 'Renew'
                : 'New');
    const badgeClassByType = {
        [PRODUCT_TYPE_ORIGINAL]: 'est-type-badge_original',
        [PRODUCT_TYPE_REMAKE]: 'est-type-badge_remake',
        [PRODUCT_TYPE_NEW]: 'est-type-badge_new',
        [PRODUCT_TYPE_RENEW]: 'est-type-badge_renew'
    };
    return {
        showTypeBadge: true,
        typeBadgeLabel: label,
        typeBadgeClass: `est-type-badge ${badgeClassByType[normalized] || 'est-type-badge_new'}`
    };
}

export function setBillingCycleConfig(_options) {
    // 継続課金は月次固定のため、設定読込は不要。
}



export function parseLocalDate(isoDate) {

    if (!isoDate) {

        return null;

    }

    const parts = isoDate.split('-');

    return new Date(Number(parts[0]), Number(parts[1]) - 1, Number(parts[2]));

}



function addMonthsToDate(date, months) {

    const targetDay = date.getDate();

    const result = new Date(date.getFullYear(), date.getMonth(), 1);

    result.setMonth(result.getMonth() + months);

    const lastDayOfMonth = new Date(

        result.getFullYear(),

        result.getMonth() + 1,

        0

    ).getDate();

    result.setDate(Math.min(targetDay, lastDayOfMonth));

    return result;

}



function addYearsToDate(date, years) {

    const targetDay = date.getDate();

    const targetMonth = date.getMonth();

    const result = new Date(date.getFullYear() + years, targetMonth, 1);

    const lastDayOfMonth = new Date(

        result.getFullYear(),

        targetMonth + 1,

        0

    ).getDate();

    result.setDate(Math.min(targetDay, lastDayOfMonth));

    return result;

}



export function formatLocalDate(date) {

    const year = date.getFullYear();

    const month = String(date.getMonth() + 1).padStart(2, '0');

    const day = String(date.getDate()).padStart(2, '0');

    return `${year}-${month}-${day}`;

}



export function addDaysToIsoDate(isoDate, days) {

    const date = parseLocalDate(isoDate);

    if (!date) {

        return '';

    }

    return formatLocalDate(addDays(date, days));

}



export function addYearsToIsoDate(isoDate, years) {

    const date = parseLocalDate(isoDate);

    if (!date || years == null) {

        return '';

    }

    return formatLocalDate(addYearsToDate(date, years));

}



export function addMonthsToIsoDate(isoDate, months) {

    const date = parseLocalDate(isoDate);

    if (!date || months == null) {

        return '';

    }

    return formatLocalDate(addMonthsToDate(date, months));

}



export function addYearsMinusOneDay(isoStartDate, years) {

    const date = parseLocalDate(isoStartDate);

    if (!date || years == null) {

        return '';

    }

    const adjusted = addYearsToDate(date, years);

    adjusted.setDate(adjusted.getDate() - 1);

    return formatLocalDate(adjusted);

}



export function addOneYearMinusOneDay(isoStartDate) {

    return addYearsMinusOneDay(isoStartDate, 1);

}



export function addMonthsMinusOneDay(isoStartDate, months) {

    const date = parseLocalDate(isoStartDate);

    if (!date || months == null) {

        return '';

    }

    const adjusted = addMonthsToDate(date, months);

    adjusted.setDate(adjusted.getDate() - 1);

    return formatLocalDate(adjusted);

}



export function normalizeDateInput(value) {

    if (!value) {

        return '';

    }

    const trimmed = String(value).trim();

    if (!/^\d{4}-\d{2}-\d{2}$/.test(trimmed)) {

        return trimmed;

    }

    const date = parseLocalDate(trimmed);

    if (!date) {

        return trimmed;

    }

    return formatLocalDate(date);

}



export function isValidIsoDate(value) {

    if (!value || !/^\d{4}-\d{2}-\d{2}$/.test(value)) {

        return false;

    }

    const date = parseLocalDate(value);

    return !!date && formatLocalDate(date) === value;

}



export function sameDate(left, right) {

    return (

        left.getFullYear() === right.getFullYear() &&

        left.getMonth() === right.getMonth() &&

        left.getDate() === right.getDate()

    );

}



export function addDays(date, days) {

    const result = new Date(date);

    result.setDate(result.getDate() + days);

    return result;

}



export function endOfMonthlyPeriod(periodStart) {

    const end = addMonthsToDate(new Date(periodStart), 1);

    end.setDate(end.getDate() - 1);

    return end;

}



export function buildDisplayUnit(unitName, billingType, billingCycle) {
    if (billingType === BILLING_TYPE_RECURRING) {
        const baseUnit = unitName || '';
        return baseUnit
            ? `${baseUnit}・${MONTHLY_BILLING_CYCLE}`
            : MONTHLY_BILLING_CYCLE;
    }

    return unitName || '';
}



export function resolveDisplayUnit(unit, unitName, billingType, billingCycle) {

    if (unitName) {

        return unitName;

    }

    if (!unit) {

        return '';

    }

    if (billingType === BILLING_TYPE_RECURRING && billingCycle) {

        const suffix = `・${billingCycle}`;

        if (unit.endsWith(suffix)) {

            return unit.slice(0, -suffix.length);

        }

        const legacySuffix = `/${billingCycle}`;

        if (unit.endsWith(legacySuffix)) {

            return unit.slice(0, -legacySuffix.length);

        }

    }

    return unit;

}



export function buildUnitPriceSuffix(billingType, billingCycle) {
    if (billingType === BILLING_TYPE_RECURRING) {
        return `/${MONTHLY_BILLING_CYCLE}`;
    }

    return '';
}



export function normalizeInvoiceSettingLabel(invoiceSettingLabel) {
    if (!invoiceSettingLabel) {
        return invoiceSettingLabel;
    }
    return LEGACY_INVOICE_SETTING_MAP[invoiceSettingLabel] || invoiceSettingLabel;
}

export function isSplitMonthlyInvoiceSetting(invoiceSettingLabel) {
    return (
        normalizeInvoiceSettingLabel(invoiceSettingLabel) ===
        INVOICE_SETTING_SPLIT_MONTHLY
    );
}

export function validateInvoiceSettingForBillingType(
    billingType,
    invoiceType,
    allOptions
) {
    const normalizedInvoiceType = normalizeInvoiceSettingLabel(invoiceType);
    if (!normalizedInvoiceType) {
        return null;
    }

    if (
        billingType === BILLING_TYPE_ONE_TIME &&
        isSplitMonthlyInvoiceSetting(normalizedInvoiceType)
    ) {
        return '一回課金では月次分割は選択できません。';
    }

    if (isAllowedInvoiceSettingForBillingType(billingType, normalizedInvoiceType)) {
        return null;
    }

    if (billingType === BILLING_TYPE_ONE_TIME) {
        return '一回課金では月次分割は選択できません。';
    }
    if (billingType === BILLING_TYPE_RECURRING) {
        return '継続課金に対応した請求設定を選択してください。';
    }
    return '請求設定が不正です。';
}

export function resolveInvoiceSettingBillingCategory(billingType) {

    if (billingType === BILLING_TYPE_ONE_TIME) {

        return INVOICE_BILLING_CATEGORY_ONE_TIME;

    }

    if (billingType === BILLING_TYPE_RECURRING) {

        return INVOICE_BILLING_CATEGORY_RECURRING;

    }

    return null;

}



export function filterInvoiceSettingOptions(options, billingType) {
    const allowedLabels = getAllowedInvoiceSettingLabels(billingType);
    if (!allowedLabels.length) {
        return [];
    }

    return allowedLabels.map((label, index) => {
        const matched = (options || []).find((option) => option.label === label);
        return {
            label,
            billingCategory: resolveInvoiceSettingBillingCategory(billingType),
            sortOrder: matched?.sortOrder ?? (index + 1) * 10
        };
    });
}



export function resolveInvoiceTypeForBillingType(

    invoiceType,

    billingType,

    allOptions,

    fallbackLabel

) {

    const category = resolveInvoiceSettingBillingCategory(billingType);

    if (!category) {

        return '';

    }

    const normalizedInvoiceType = normalizeInvoiceSettingLabel(invoiceType);

    const filteredOptions = filterInvoiceSettingOptions(allOptions, billingType);

    if (

        normalizedInvoiceType &&

        filteredOptions.some((option) => option.label === normalizedInvoiceType)

    ) {

        return normalizedInvoiceType;

    }

    if (filteredOptions.length > 0) {

        return filteredOptions[0].label;

    }

    const optionsLoaded = Array.isArray(allOptions) && allOptions.length > 0;
    if (optionsLoaded) {
        const normalizedFallback = normalizeInvoiceSettingLabel(fallbackLabel);
        if (isAllowedInvoiceSettingForBillingType(billingType, normalizedFallback)) {
            return normalizedFallback;
        }
    }

    return normalizedInvoiceType || '';

}



export function countBillingCycles(startDate, endDate, billingCycle) {
    if (!startDate || !endDate) {
        return null;
    }

    return countMonthlyCycles(startDate, endDate);
}



export function resolveMonthlyEndDate(startDate, endDate) {

    if (!startDate || !endDate) {

        return endDate || '';

    }

    if (countMonthlyCycles(startDate, endDate) >= 0) {

        return endDate;

    }



    const start = parseLocalDate(startDate);

    const end = parseLocalDate(endDate);

    if (!start || !end || end < start) {

        return endDate;

    }



    let periodStart = new Date(start);

    while (true) {

        const periodEnd = endOfMonthlyPeriod(periodStart);

        if (end < periodStart) {

            break;

        }

        if (end <= periodEnd) {

            return formatLocalDate(periodEnd);

        }

        periodStart = addDays(periodEnd, 1);

    }

    return endDate;

}



function countMonthlyCycles(startDate, endDate) {

    const start = parseLocalDate(startDate);

    const end = parseLocalDate(endDate);

    if (!start || !end || end < start) {

        return -1;

    }



    let cycles = 0;

    let periodStart = new Date(start);

    while (true) {

        const periodEnd = endOfMonthlyPeriod(periodStart);

        if (periodEnd > end) {

            return -1;

        }

        cycles++;

        if (sameDate(periodEnd, end)) {

            return cycles;

        }

        periodStart = addDays(periodEnd, 1);

    }

}



export function calculateLineAmount(row) {
    const qty = Number(row.quantity) || 0;
    const price = Number(row.unitPrice) || 0;

    if (
        row.billingType === BILLING_TYPE_RECURRING &&
        row.startDate &&
        row.endDate
    ) {
        const endDate = resolveMonthlyEndDate(row.startDate, row.endDate);
        const cycles = countBillingCycles(
            row.startDate,
            endDate,
            row.billingCycle
        );

        if (cycles == null || cycles < 0) {

            return null;

        }

        return qty * price * cycles;

    }



    return qty * price;

}



export function validateBillingPeriod(row) {
    if (row.billingType !== BILLING_TYPE_RECURRING) {
        return null;
    }

    if (!row.startDate || !row.endDate) {
        return '開始日と終了日を入力してください。';
    }

    const endDate = resolveMonthlyEndDate(row.startDate, row.endDate);
    const cycles = countBillingCycles(row.startDate, endDate, MONTHLY_BILLING_CYCLE);

    if (cycles == null || cycles < 1) {
        return '開始日・終了日が月次単位（期間開始日基準）の倍数ではありません。';
    }

    return null;
}



export function isActiveLine(row) {

    return !!(row.productId && Number(row.quantity) > 0);

}



export function validateHeaderDates(startDate, endDate) {

    if (!startDate || !endDate) {

        return null;

    }

    if (startDate > endDate) {

        return '期間開始日は期間終了日以前の日付を入力してください。';

    }

    return null;

}



export function isHeaderDatesReady(startDate, endDate) {

    return !!(startDate && endDate && !validateHeaderDates(startDate, endDate));

}



export function validateLineDateOrder(row) {

    if (!row.startDate || !row.endDate) {

        return null;

    }

    if (row.startDate > row.endDate) {

        return '開始日は終了日以前の日付を入力してください。';

    }

    return null;

}



export function validateLineWithinHeader(row, headerStart, headerEnd) {

    if (!row.startDate || !row.endDate || !headerStart || !headerEnd) {

        return null;

    }

    if (row.startDate < headerStart) {

        return '開始日は期間開始日以降の日付を入力してください。';

    }

    if (row.endDate > headerEnd) {

        return '終了日は期間終了日以前の日付を入力してください。';

    }

    return null;

}



export function isRecurringLine(row) {

    if (row.billingType === BILLING_TYPE_RECURRING) {

        return true;

    }

    if (row.billingType === BILLING_TYPE_ONE_TIME) {
        return false;
    }

    if (!row.invoiceType) {
        return false;
    }

    const normalizedInvoiceType = normalizeInvoiceSettingLabel(row.invoiceType);
    return (
        normalizedInvoiceType === INVOICE_SETTING_PREPAID_START ||
        normalizedInvoiceType === INVOICE_SETTING_POSTPAID_NEXT_DAY ||
        normalizedInvoiceType === INVOICE_SETTING_SPLIT_MONTHLY
    );

}



export function validateNewHeaderMonthlyPeriod(headerStart, headerEnd) {

    if (!headerStart || !headerEnd) {

        return null;

    }

    const cycles = countBillingCycles(headerStart, headerEnd, MONTHLY_BILLING_CYCLE);

    if (cycles == null || cycles < 1) {

        return '期間開始日と期間終了日の間が、月次単位（期間開始日基準）の倍数である必要があります。';

    }

    return null;

}



export function validateNewRecurringEndpointCoverage(products, headerStart, headerEnd) {

    const recurringLines = (products || []).filter(

        (line) => isActiveLine(line) && isRecurringLine(line)

    );

    if (!recurringLines.length) {

        return null;

    }

    const hasStartMatch = recurringLines.some(

        (line) => line.startDate === headerStart

    );

    const hasEndMatch = recurringLines.some(

        (line) => line.endDate === headerEnd

    );



    if (!hasStartMatch) {

        return '期間開始日と一致する開始日の継続課金明細が1件以上必要です。';

    }

    if (!hasEndMatch) {

        return '期間終了日と一致する終了日の継続課金明細が1件以上必要です。';

    }

    return null;

}

export function validateChangeRecurringEndEndpointCoverage(products, headerEnd) {
    const recurringLines = (products || []).filter(
        (line) =>
            !isChangeOriginalLine(line) &&
            isActiveLine(line) &&
            isRecurringLine(line)
    );

    if (!recurringLines.length) {
        return null;
    }

    const hasEndMatch = recurringLines.some((line) => line.endDate === headerEnd);

    if (!hasEndMatch) {
        return '期間終了日と一致する終了日の継続課金明細が1件以上必要です。';
    }

    return null;
}

export function validateNewProductPeriodOverlap(products) {

    const activeLines = (products || []).filter(isActiveLine);



    for (let i = 0; i < activeLines.length; i++) {

        const left = activeLines[i];

        if (!left.startDate || !left.endDate) {

            continue;

        }



        for (let j = i + 1; j < activeLines.length; j++) {

            const right = activeLines[j];

            if (left.productId !== right.productId) {

                continue;

            }

            if (!right.startDate || !right.endDate) {

                continue;

            }

            if (left.startDate <= right.endDate && left.endDate >= right.startDate) {

                return '同一商品の契約期間が重複しています。商品ごとに期間が重ならないよう入力してください。';

            }

        }

    }

    return null;

}



export function validateNewEndpointCoverage(products, headerStart, headerEnd) {

    return validateNewRecurringEndpointCoverage(products, headerStart, headerEnd);

}



export function isBlankProductLine(row) {

    return !row.productId && (row.quantity == null || Number(row.quantity) <= 0);

}



export function validateNewEffectiveDate(periodStartDate, effectiveDate) {

    if (!effectiveDate) {

        return null;

    }

    if (periodStartDate && effectiveDate !== periodStartDate) {

        return '有効日は期間開始日と一致している必要があります。';

    }

    return null;

}



export function validateRenewEffectiveDate(
    periodStartDate,
    effectiveDate,
    previousTermEndDate
) {
    if (previousTermEndDate && periodStartDate) {
        const expectedStart = addDaysToIsoDate(previousTermEndDate, 1);
        if (periodStartDate !== expectedStart) {
            return '期間開始日は前回Versionの期間終了日の翌日である必要があります。';
        }
    }

    return validateNewEffectiveDate(periodStartDate, effectiveDate);
}



export function validateCancelEffectiveDate(
    cancelDate,
    effectiveDate,
    previousTermEndDate
) {
    if (previousTermEndDate && cancelDate) {
        const expectedCancelDate = addDaysToIsoDate(previousTermEndDate, 1);
        if (cancelDate !== expectedCancelDate) {
            return '解約日は前回Versionの期間終了日の翌日である必要があります。';
        }
    }

    if (effectiveDate && cancelDate && effectiveDate !== cancelDate) {
        return '有効日は解約日と一致している必要があります。';
    }

    return null;
}

export function validateCancelProducts(products) {
    const activeLines = (products || []).filter(isActiveLine);
    if (activeLines.length > 0) {
        return 'Cancelでは商品明細を入力できません。';
    }
    return null;
}

function decimalsEqual(left, right) {
    if (left == null && right == null) {
        return true;
    }
    if (left == null || right == null) {
        return false;
    }
    return Number(left) === Number(right);
}

export function isChangeContinuationLine(line) {
    if (!line || isChangeOriginalLine(line) || isChangeRemakeLine(line)) {
        return false;
    }
    const recordType = normalizeProductRecordType(line.recordType);
    if (recordType === PRODUCT_TYPE_NEW && !line.sourceContractProductId) {
        return true;
    }
    if (recordType === PRODUCT_TYPE_REMAKE && !line.sourceContractProductId) {
        return true;
    }
    return false;
}

function isReconstitutionSegment(line) {
    return !!(
        line &&
        line.productId &&
        line.startDate &&
        line.endDate &&
        Number(line.quantity) > 0
    );
}

function buildSameProductReconstitutionSegments(derivatives, continuationLines, productId) {
    const segments = [];
    for (const derivative of derivatives || []) {
        if (isReconstitutionSegment(derivative)) {
            segments.push(derivative);
        }
    }
    for (const line of continuationLines || []) {
        if (!isChangeContinuationLine(line) || !isReconstitutionSegment(line)) {
            continue;
        }
        if (line.productId !== productId) {
            continue;
        }
        segments.push(line);
    }
    segments.sort((left, right) => left.startDate.localeCompare(right.startDate));
    return segments;
}

function hasReplacementCoverage(
    continuationLines,
    originalProductId,
    contractEndDate,
    lastEndDate
) {
    if (!contractEndDate || !lastEndDate || lastEndDate === contractEndDate) {
        return lastEndDate === contractEndDate;
    }
    const expectedStart = addDaysToIsoDate(lastEndDate, 1);
    return (continuationLines || []).some((line) => {
        if (!isChangeContinuationLine(line) || !isReconstitutionSegment(line)) {
            return false;
        }
        if (line.productId === originalProductId) {
            return false;
        }
        return line.startDate === expectedStart && line.endDate === contractEndDate;
    });
}

export function validateChangeReconstitutionCoverage(
    original,
    derivatives,
    continuationLines,
    contractStartDate,
    contractEndDate,
    effectiveDate
) {
    if (!original || !derivatives || !derivatives.length) {
        return '相殺後の商品明細を1行以上入力してください。';
    }

    const segments = buildSameProductReconstitutionSegments(
        derivatives,
        continuationLines,
        original.productId
    );
    if (!segments.length) {
        return '相殺後の商品明細を1行以上入力してください。';
    }

    if (
        contractStartDate &&
        segments[0].startDate !== contractStartDate &&
        !(
            segments.length === 1 &&
            effectiveDate &&
            segments[0].startDate === effectiveDate
        )
    ) {
        return '変更後の商品明細は期間開始日から連続して入力してください。';
    }

    for (let index = 0; index < segments.length - 1; index += 1) {
        const expectedNextStart = addDaysToIsoDate(segments[index].endDate, 1);
        if (segments[index + 1].startDate !== expectedNextStart) {
            return '変更後の商品明細の期間に空きがあります。期間開始日から連続して入力してください。';
        }
    }

    const lastSegment = segments[segments.length - 1];
    if (
        contractEndDate &&
        lastSegment.endDate !== contractEndDate &&
        !hasReplacementCoverage(
            continuationLines,
            original.productId,
            contractEndDate,
            lastSegment.endDate
        )
    ) {
        return '変更後の商品明細は期間終了日まで連続して入力してください。';
    }

    return null;
}

function resolvePostEffectiveRemakeLine(
    derivative,
    continuationSegments,
    effectiveDate,
    contractEndDate
) {
    if (!derivative) {
        return null;
    }

    const postSegment = (continuationSegments || [])
        .filter(
            (line) =>
                isReconstitutionSegment(line) && line.startDate >= effectiveDate
        )
        .sort((left, right) => left.startDate.localeCompare(right.startDate))[0];

    if (derivative.startDate >= effectiveDate) {
        return { ...derivative };
    }

    if (postSegment) {
        return { ...postSegment };
    }

    if (derivative.endDate >= effectiveDate) {
        const clippedStart =
            effectiveDate > derivative.startDate ? effectiveDate : derivative.startDate;
        if (derivative.endDate >= clippedStart) {
            return {
                ...derivative,
                startDate: clippedStart
            };
        }
    }

    if (derivative.endDate < effectiveDate) {
        return {
            ...derivative,
            quantity: 0,
            amount: 0,
            startDate: effectiveDate,
            endDate: contractEndDate
        };
    }

    return { ...derivative };
}

function shouldMergeSameProductNewLine(postLine, newLine) {
    if (!postLine || !newLine) {
        return false;
    }
    return (
        newLine.productId === postLine.productId &&
        newLine.startDate === postLine.startDate &&
        newLine.endDate === postLine.endDate &&
        decimalsEqual(newLine.quantity, postLine.quantity) &&
        decimalsEqual(newLine.unitPrice, postLine.unitPrice) &&
        newLine.invoiceType === postLine.invoiceType
    );
}

export function normalizeChangeProductsForSave(
    products,
    effectiveDate,
    contractStartDate,
    contractEndDate
) {
    if (!products || !products.length || !effectiveDate) {
        return products || [];
    }

    const originals = products.filter(isChangeOriginalLine);
    const remakesBySourceId = new Map();
    const continuationLines = [];

    for (const line of products) {
        if (isChangeOriginalLine(line)) {
            continue;
        }
        if (isChangeRemakeLine(line)) {
            const sourceId = line.sourceContractProductId;
            if (!remakesBySourceId.has(sourceId)) {
                remakesBySourceId.set(sourceId, []);
            }
            remakesBySourceId.get(sourceId).push(line);
            continue;
        }
        if (isChangeContinuationLine(line)) {
            continuationLines.push(line);
        }
    }

    const normalized = originals.map((line) => ({ ...line }));
    const mergedContinuationKeys = new Set();

    for (const original of originals) {
        const sourceId = original.sourceContractProductId;
        const derivatives = (remakesBySourceId.get(sourceId) || []).slice();
        if (!derivatives.length) {
            continue;
        }

        derivatives.sort((left, right) =>
            (left.startDate || '').localeCompare(right.startDate || '')
        );

        if (derivatives.length > 1) {
            for (const derivative of derivatives) {
                normalized.push({
                    ...derivative,
                    recordType: PRODUCT_TYPE_REMAKE,
                    typeLabel: 'Remake',
                    sourceContractProductId: sourceId
                });
            }
            continue;
        }

        const sameProductNews = continuationLines.filter(
            (line) => line.productId === original.productId
        );
        const primaryDerivative = derivatives[0];
        const continuationSegments = [...derivatives.slice(1), ...sameProductNews];
        const postLine = resolvePostEffectiveRemakeLine(
            primaryDerivative,
            continuationSegments,
            effectiveDate,
            contractEndDate
        );
        if (!postLine) {
            continue;
        }

        normalized.push({
            ...postLine,
            recordType: PRODUCT_TYPE_REMAKE,
            typeLabel: 'Remake',
            sourceContractProductId: sourceId
        });

        for (const newLine of sameProductNews) {
            if (shouldMergeSameProductNewLine(postLine, newLine)) {
                mergedContinuationKeys.add(newLine.id || JSON.stringify(newLine));
            }
        }
    }

    for (const line of continuationLines) {
        const key = line.id || JSON.stringify(line);
        if (mergedContinuationKeys.has(key)) {
            continue;
        }
        normalized.push({
            ...line,
            recordType: PRODUCT_TYPE_NEW,
            typeLabel: 'New'
        });
    }

    return normalized;
}

export function validateChangeEffectiveDate(
    effectiveDate,
    previousTermStartDate,
    previousTermEndDate,
    contractStartDate
) {
    if (previousTermStartDate && effectiveDate && effectiveDate < previousTermStartDate) {
        return '有効日は前回Versionの期間開始日から期間終了日の間で入力してください。';
    }
    if (previousTermEndDate && effectiveDate && effectiveDate > previousTermEndDate) {
        return '有効日は前回Versionの期間開始日から期間終了日の間で入力してください。';
    }
    if (
        contractStartDate &&
        effectiveDate &&
        contractStartDate !== effectiveDate &&
        !isMonthlyPeriodStartDate(contractStartDate, effectiveDate)
    ) {
        return '有効日は期間開始日基準の請求期間開始日である必要があります（日割りはできません）。';
    }
    return null;
}

export function validateChangePeriodDates(
    contractStartDate,
    contractEndDate,
    previousTermStartDate,
    previousTermEndDate
) {
    if (
        previousTermStartDate &&
        contractStartDate &&
        contractStartDate !== previousTermStartDate
    ) {
        return '期間開始日は前回Versionの期間開始日と一致している必要があります。';
    }
    if (
        previousTermEndDate &&
        contractEndDate &&
        contractEndDate < previousTermEndDate
    ) {
        return '期間終了日は前回Versionの期間終了日以降の日付を入力してください。';
    }
    if (contractStartDate && contractEndDate) {
        const headerPeriodError = validateNewHeaderMonthlyPeriod(
            contractStartDate,
            contractEndDate
        );
        if (headerPeriodError) {
            return headerPeriodError;
        }
    }
    return null;
}

export function validateChangeProductPeriodOverlap(products) {
    const activeLines = (products || []).filter(
        (line) => isActiveLine(line) && !isChangeOriginalLine(line)
    );

    for (let i = 0; i < activeLines.length; i++) {
        const left = activeLines[i];
        if (!left.startDate || !left.endDate) {
            continue;
        }
        for (let j = i + 1; j < activeLines.length; j++) {
            const right = activeLines[j];
            if (left.productId !== right.productId) {
                continue;
            }
            if (!right.startDate || !right.endDate) {
                continue;
            }
            if (left.startDate <= right.endDate && left.endDate >= right.startDate) {
                return '同一商品の契約期間が重複しています。商品ごとに期間が重ならないよう入力してください。';
            }
        }
    }
    return null;
}

function validateChangeEditableLine(row, headerStart, headerEnd) {
    if (isBlankProductLine(row)) {
        return null;
    }
    if (isChangeRemakeLine(row)) {
        const qty = Number(row.quantity);
        if (Number.isNaN(qty) || qty < 0) {
            return '数量は0以上を入力してください。';
        }
        if (qty === 0) {
            return null;
        }
    } else if (row.quantity == null || Number(row.quantity) <= 0) {
        return '数量を入力してください。';
    }

    if (!row.startDate || !row.endDate) {
        return '開始日と終了日を入力してください。';
    }

    const orderError = validateLineDateOrder(row);
    if (orderError) {
        return orderError;
    }

    const rangeError = validateLineWithinHeader(row, headerStart, headerEnd);
    if (rangeError) {
        return rangeError;
    }

    if (!row.invoiceType) {
        return '請求設定を選択してください。';
    }

    return validateBillingPeriod(row);
}

export function validateChangeProducts(
    products,
    contractStartDate,
    contractEndDate,
    effectiveDate,
    previousTermStartDate,
    previousTermEndDate
) {
    const lines = products || [];
    const originalBySourceId = new Map();
    const remakesBySourceId = new Map();
    const overlapCandidates = [];

    for (let i = 0; i < lines.length; i++) {
        const line = lines[i];
        const label = line.typeLabel || `${i + 1}行目`;

        if (isChangeOriginalLine(line)) {
            if (!line.sourceContractProductId) {
                return `商品明細（${label}）: Remake行に元の契約商品が指定されていません。`;
            }
            if (originalBySourceId.has(line.sourceContractProductId)) {
                return 'Remake行が重複しています。';
            }
            originalBySourceId.set(line.sourceContractProductId, line);
            continue;
        }

        if (isChangeRemakeLine(line)) {
            if (!line.sourceContractProductId) {
                return `商品明細（${label}）: Remake行に元の契約商品が指定されていません。`;
            }
            if (!remakesBySourceId.has(line.sourceContractProductId)) {
                remakesBySourceId.set(line.sourceContractProductId, []);
            }
            remakesBySourceId.get(line.sourceContractProductId).push(line);
            if (isActiveLine(line)) {
                const lineError = validateChangeEditableLine(
                    line,
                    contractStartDate,
                    contractEndDate
                );
                if (lineError) {
                    return `商品明細（${label}）: ${lineError}`;
                }
                overlapCandidates.push(line);
            }
            continue;
        }

        if (isChangeContinuationLine(line)) {
            if (isActiveLine(line)) {
                const lineError = validateChangeEditableLine(
                    line,
                    contractStartDate,
                    contractEndDate
                );
                if (lineError) {
                    return `商品明細（${label}）: ${lineError}`;
                }
                overlapCandidates.push(line);
            }
            continue;
        }

        if (isActiveLine(line)) {
            const lineError = validateChangeEditableLine(
                line,
                contractStartDate,
                contractEndDate
            );
            if (lineError) {
                return `商品明細（${label}）: ${lineError}`;
            }
            overlapCandidates.push(line);
        }
    }

    if (!originalBySourceId.size) {
        return '商品明細を1行以上入力してください。';
    }

    const continuationLines = lines.filter(isChangeContinuationLine);

    for (const [sourceId, original] of originalBySourceId.entries()) {
        const derivatives = remakesBySourceId.get(sourceId) || [];
        if (!derivatives.length) {
            return '前回Versionの継続課金商品すべてにRemake行を1件以上入力してください。';
        }

        const reconError = validateChangeReconstitutionCoverage(
            original,
            derivatives,
            continuationLines,
            contractStartDate,
            contractEndDate,
            effectiveDate
        );
        if (reconError) {
            return reconError;
        }
    }

    const overlapError = validateChangeProductPeriodOverlap(overlapCandidates);
    if (overlapError) {
        return overlapError;
    }

    const endpointError = validateChangeRecurringEndEndpointCoverage(
        lines,
        contractEndDate
    );
    if (endpointError) {
        return endpointError;
    }

    for (let i = 0; i < lines.length; i++) {
        const line = lines[i];
        if (isBlankProductLine(line)) {
            continue;
        }
        const label = line.typeLabel || `${i + 1}行目`;
        if (line.amount == null && line.productId) {
            const qty = Number(line.quantity);
            if (Number.isNaN(qty) || qty !== 0) {
                return `商品明細（${label}）: 金額を計算できません。期間を確認してください。`;
            }
        }
    }

    return null;
}

export function validateRenewProducts(
    products,
    periodStart,
    periodEnd,
    previousTermEnd
) {
    const activeLines = (products || []).filter(isActiveLine);

    if (!activeLines.length) {
        return '商品明細を1行以上入力してください。';
    }

    const hasRecurring = activeLines.some((line) => isRecurringLine(line));
    if (!hasRecurring) {
        return 'Renewでは継続課金商品を1行以上指定してください。一回課金のみのRenewはできません。';
    }

    if (previousTermEnd && periodStart) {
        const expectedStart = addDaysToIsoDate(previousTermEnd, 1);
        if (periodStart !== expectedStart) {
            return '期間開始日は前回Versionの期間終了日の翌日である必要があります。';
        }
    }

    return validateNewProducts(products, periodStart, periodEnd, true);
}



export function validateNewLineItem(row, headerStart, headerEnd) {

    if (isBlankProductLine(row)) {

        return null;

    }

    if (!row.startDate || !row.endDate) {

        return '開始日と終了日を入力してください。';

    }

    if (row.quantity == null || Number(row.quantity) <= 0) {

        return '数量を入力してください。';

    }



    const orderError = validateLineDateOrder(row);

    if (orderError) {

        return orderError;

    }



    const rangeError = validateLineWithinHeader(row, headerStart, headerEnd);

    if (rangeError) {

        return rangeError;

    }



    if (isActiveLine(row) && !row.invoiceType) {

        return '請求設定を選択してください。';

    }



    return validateBillingPeriod(row);

}



export function validateNewProducts(
    products,
    headerStart,
    headerEnd,
    includeProductOverlap = true
) {

    const activeLines = (products || []).filter(isActiveLine);

    if (!activeLines.length) {

        return '商品明細を1行以上入力してください。';

    }

    const hasRecurring = activeLines.some(

        (line) => isRecurringLine(line)

    );

    if (hasRecurring) {

        const headerPeriodError = validateNewHeaderMonthlyPeriod(

            headerStart,

            headerEnd

        );

        if (headerPeriodError) {

            return headerPeriodError;

        }

        const endpointError = validateNewRecurringEndpointCoverage(

            products,

            headerStart,

            headerEnd

        );

        if (endpointError) {

            return endpointError;

        }

    }



    if (includeProductOverlap) {

        const overlapError = validateNewProductPeriodOverlap(products);

        if (overlapError) {

            return overlapError;

        }

    }



    for (let i = 0; i < products.length; i++) {

        const line = products[i];

        if (isBlankProductLine(line)) {

            continue;

        }

        const label = line.typeLabel || `${i + 1}行目`;

        const lineError = validateNewLineItem(line, headerStart, headerEnd);

        if (lineError) {

            return `商品明細（${label}）: ${lineError}`;

        }

        if (line.amount == null && line.productId) {

            const qty = Number(line.quantity);

            if (Number.isNaN(qty) || qty !== 0) {

                return `商品明細（${label}）: 金額を計算できません。期間を確認してください。`;

            }

        }

    }



    return null;

}

export function endOfMonthlyPeriodIsoDate(isoDate) {
    const date = parseLocalDate(isoDate);
    if (!date) {
        return null;
    }
    const periodEnd = addMonthsToDate(date, 1);
    periodEnd.setDate(periodEnd.getDate() - 1);
    return formatLocalDate(periodEnd);
}

export function isMonthlyPeriodStartDate(anchorStartIsoDate, candidateIsoDate) {
    if (!anchorStartIsoDate || !candidateIsoDate) {
        return false;
    }
    if (candidateIsoDate < anchorStartIsoDate) {
        return false;
    }

    let periodStart = anchorStartIsoDate;
    while (periodStart <= candidateIsoDate) {
        if (periodStart === candidateIsoDate) {
            return true;
        }
        periodStart = addDaysToIsoDate(endOfMonthlyPeriodIsoDate(periodStart), 1);
    }
    return false;
}

