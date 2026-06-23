public without sharing class ContractWizardFieldService {
    public class PicklistOptionDefinition {
        @AuraEnabled
        public String label;

        @AuraEnabled
        public String value;
    }

    public class WizardFieldDefinition {
        @AuraEnabled
        public String apiName;

        @AuraEnabled
        public String label;

        @AuraEnabled
        public String fieldType;

        @AuraEnabled
        public Boolean required;

        @AuraEnabled
        public Integer sortOrder;

        @AuraEnabled
        public Integer maxLength;

        @AuraEnabled
        public Integer precision;

        @AuraEnabled
        public Integer scale;

        @AuraEnabled
        public List<PicklistOptionDefinition> picklistOptions;
    }

    public enum WizardTarget {
        ContractProduct,
        ContractService,
        ContractHistory
    }

    private class FieldConfig {
        public String fieldApiName;
        public String label;
        public Boolean required;
        public Integer sortOrder;
    }

    private static List<FieldConfig> contractProductFields() {
        FieldConfig billingType = new FieldConfig();
        billingType.fieldApiName = 'BillingType__c';
        billingType.label = '課金形態';
        billingType.required = false;
        billingType.sortOrder = 10;

        return new List<FieldConfig>{
            billingType
        };
    }

    private static List<FieldConfig> contractHistoryFields() {
        FieldConfig note = new FieldConfig();
        note.fieldApiName = 'Note__c';
        note.label = '備考（短）';
        note.required = false;
        note.sortOrder = 10;
        return new List<FieldConfig>{ note };
    }

    public static void resetCache() {
    }

    @AuraEnabled(cacheable=true)
    public static List<WizardFieldDefinition> getContractProductFieldDefinitions() {
        return getActiveFieldDefinitions(
            ContractProduct__c.SObjectType,
            contractProductFields()
        );
    }

    @AuraEnabled(cacheable=true)
    public static List<WizardFieldDefinition> getContractServiceFieldDefinitions() {
        return getActiveFieldDefinitions(
            ContractService__c.SObjectType,
            new List<FieldConfig>()
        );
    }

    @AuraEnabled(cacheable=true)
    public static List<WizardFieldDefinition> getContractHistoryFieldDefinitions() {
        return getActiveFieldDefinitions(
            ContractHistory__c.SObjectType,
            contractHistoryFields()
        );
    }

    public static List<WizardFieldDefinition> getActiveFieldDefinitions(
        Schema.SObjectType sobjectType,
        List<FieldConfig> fieldConfigs
    ) {
        List<WizardFieldDefinition> definitions = new List<WizardFieldDefinition>();
        Map<String, Schema.SObjectField> fieldMap = sobjectType.getDescribe().fields.getMap();

        for (FieldConfig config : fieldConfigs) {
            String apiName = config.fieldApiName;
            if (String.isBlank(apiName) || !fieldMap.containsKey(apiName)) {
                continue;
            }
            Schema.DescribeFieldResult describe = fieldMap.get(apiName).getDescribe();
            if (!isSupportedType(describe.getType())) {
                continue;
            }

            WizardFieldDefinition definition = new WizardFieldDefinition();
            definition.apiName = apiName;
            definition.label = String.isNotBlank(config.label)
                ? config.label
                : describe.getLabel();
            definition.fieldType = describe.getType().name();
            definition.required = config.required == true;
            definition.sortOrder = config.sortOrder == null ? 0 : config.sortOrder;
            definition.maxLength = describe.getLength();
            definition.precision = describe.getPrecision();
            definition.scale = describe.getScale();
            definition.picklistOptions = buildPicklistOptions(describe);
            definitions.add(definition);
        }

        return definitions;
    }

    public static Map<String, Object> extractCustomFields(
        SObject record,
        WizardTarget target
    ) {
        Map<String, Object> values = new Map<String, Object>();
        if (record == null) {
            return values;
        }

        List<FieldConfig> fieldConfigs = getFieldConfigs(target);
        Set<String> allowedFields = getConfiguredFieldApiNames(fieldConfigs);
        for (String apiName : allowedFields) {
            Object value = record.get(apiName);
            if (value == null) {
                continue;
            }
            if (value instanceof Date) {
                values.put(apiName, String.valueOf((Date) value));
            } else {
                values.put(apiName, value);
            }
        }
        return values;
    }

    public static void applyCustomFields(
        SObject record,
        Map<String, Object> customFields,
        WizardTarget target
    ) {
        if (record == null || customFields == null || customFields.isEmpty()) {
            return;
        }

        Schema.SObjectType sobjectType = record.getSObjectType();
        List<FieldConfig> fieldConfigs = getFieldConfigs(target);
        Map<String, Schema.SObjectField> fieldMap = sobjectType.getDescribe().fields.getMap();
        Set<String> allowedFields = getConfiguredFieldApiNames(fieldConfigs);

        for (String apiName : customFields.keySet()) {
            if (String.isBlank(apiName) || !allowedFields.contains(apiName)) {
                continue;
            }
            if (!fieldMap.containsKey(apiName)) {
                continue;
            }
            Schema.DescribeFieldResult describe = fieldMap.get(apiName).getDescribe();
            Object coerced = coerceValue(describe, customFields.get(apiName));
            if (coerced == null && !describe.isNillable()) {
                continue;
            }
            record.put(apiName, coerced);
        }
    }

    private static List<FieldConfig> getFieldConfigs(WizardTarget target) {
        if (target == WizardTarget.ContractProduct) {
            return contractProductFields();
        }
        if (target == WizardTarget.ContractHistory) {
            return contractHistoryFields();
        }
        return new List<FieldConfig>();
    }

    private static Set<String> getConfiguredFieldApiNames(List<FieldConfig> fieldConfigs) {
        Set<String> apiNames = new Set<String>();
        for (FieldConfig config : fieldConfigs) {
            if (String.isNotBlank(config.fieldApiName)) {
                apiNames.add(config.fieldApiName);
            }
        }
        return apiNames;
    }

    private static Boolean isSupportedType(Schema.DisplayType fieldType) {
        return fieldType == Schema.DisplayType.STRING ||
            fieldType == Schema.DisplayType.TEXTAREA ||
            fieldType == Schema.DisplayType.EMAIL ||
            fieldType == Schema.DisplayType.PHONE ||
            fieldType == Schema.DisplayType.URL ||
            fieldType == Schema.DisplayType.DOUBLE ||
            fieldType == Schema.DisplayType.CURRENCY ||
            fieldType == Schema.DisplayType.PERCENT ||
            fieldType == Schema.DisplayType.INTEGER ||
            fieldType == Schema.DisplayType.LONG ||
            fieldType == Schema.DisplayType.DATE ||
            fieldType == Schema.DisplayType.BOOLEAN ||
            fieldType == Schema.DisplayType.PICKLIST;
    }

    private static List<PicklistOptionDefinition> buildPicklistOptions(
        Schema.DescribeFieldResult describe
    ) {
        if (describe.getType() != Schema.DisplayType.PICKLIST) {
            return new List<PicklistOptionDefinition>();
        }

        List<PicklistOptionDefinition> options = new List<PicklistOptionDefinition>();
        for (Schema.PicklistEntry entry : describe.getPicklistValues()) {
            if (!entry.isActive()) {
                continue;
            }
            PicklistOptionDefinition option = new PicklistOptionDefinition();
            option.label = entry.getLabel();
            option.value = entry.getValue();
            options.add(option);
        }
        return options;
    }

    public static Object coerceValue(
        Schema.DescribeFieldResult describe,
        Object rawValue
    ) {
        if (rawValue == null) {
            return null;
        }

        Schema.DisplayType fieldType = describe.getType();
        if (fieldType == Schema.DisplayType.BOOLEAN) {
            if (rawValue instanceof Boolean) {
                return rawValue;
            }
            String text = String.valueOf(rawValue).trim();
            if (String.isBlank(text)) {
                return null;
            }
            return text == 'true' || text == '1';
        }

        if (fieldType == Schema.DisplayType.DATE) {
            String text = String.valueOf(rawValue).trim();
            return String.isBlank(text) ? null : Date.valueOf(text);
        }

        if (fieldType == Schema.DisplayType.INTEGER ||
            fieldType == Schema.DisplayType.LONG) {
            String text = String.valueOf(rawValue).trim();
            return String.isBlank(text) ? null : Integer.valueOf(text);
        }

        if (fieldType == Schema.DisplayType.DOUBLE ||
            fieldType == Schema.DisplayType.CURRENCY ||
            fieldType == Schema.DisplayType.PERCENT) {
            String text = String.valueOf(rawValue).trim();
            return String.isBlank(text) ? null : Decimal.valueOf(text);
        }

        String text = String.valueOf(rawValue).trim();
        return String.isBlank(text) ? null : text;
    }
}
