export function hasCustomFieldValues(customFields = {}) {
    return Object.keys(customFields).some((key) => {
        const value = customFields[key];
        return value !== null && value !== undefined && value !== '';
    });
}

export function buildCustomFieldInputs(
    definitions,
    customFields = {},
    keyPrefix,
    isReadonly = false
) {
    if (!definitions || !definitions.length) {
        return [];
    }

    return definitions.map((field) => {
        const rawValue = customFields[field.apiName];
        const isPicklist = field.fieldType === 'PICKLIST';
        const value =
            rawValue === null || rawValue === undefined
                ? ''
                : isPicklist
                  ? String(rawValue)
                  : rawValue;
        const isCheckbox = field.fieldType === 'BOOLEAN';
        const isNumber = [
            'DOUBLE',
            'CURRENCY',
            'PERCENT',
            'INTEGER',
            'LONG'
        ].includes(field.fieldType);
        const isDate = field.fieldType === 'DATE';
        const isTextarea =
            field.fieldType === 'TEXTAREA' || field.fieldType === 'LONGTEXTAREA';

        return {
            apiName: field.apiName,
            label: field.label,
            required: field.required === true,
            fieldType: field.fieldType,
            key: `${keyPrefix}-${field.apiName}`,
            value,
            displayValue: isCheckbox
                ? value === true || value === 'true'
                    ? 'はい'
                    : 'いいえ'
                : String(value || ''),
            isCheckbox,
            isPicklist,
            isNumber,
            isDate,
            isTextarea,
            isText: !isCheckbox && !isPicklist && !isNumber && !isDate && !isTextarea,
            isReadonly,
            checked: value === true || value === 'true',
            picklistOptions: (field.picklistOptions || []).map((option) => ({
                label: option.label,
                value: option.value,
                key: `${keyPrefix}-${field.apiName}-${option.value}`,
                selected: option.value === value
            }))
        };
    });
}
