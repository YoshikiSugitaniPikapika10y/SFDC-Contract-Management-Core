@IsTest
public class ContractTestDataFactory {
    private static User cachedAdminUser;
    private static Boolean permissionSetAssigned = false;
    private static final String PERMISSION_SET_NAME = 'ContractEstimateAccess';

    public static User getAdminUser() {
        if (cachedAdminUser == null) {
            cachedAdminUser = [
                SELECT Id
                FROM User
                WHERE IsActive = true AND Profile.PermissionsModifyAllData = true
                LIMIT 1
            ];
        }
        assignPermissionSetIfNeeded(cachedAdminUser.Id);
        return cachedAdminUser;
    }

    private static Id currentUserId() {
        return UserInfo.getUserId();
    }

    public static void initTestContext() {
        assignPermissionSetIfNeeded(getAdminUser().Id);
    }

    private static void assignPermissionSetIfNeeded(Id userId) {
        if (permissionSetAssigned) {
            return;
        }
        List<PermissionSet> permissionSets = [
            SELECT Id
            FROM PermissionSet
            WHERE Name = :PERMISSION_SET_NAME
            LIMIT 1
        ];
        if (permissionSets.isEmpty()) {
            return;
        }
        if ([
            SELECT COUNT()
            FROM PermissionSetAssignment
            WHERE AssigneeId = :userId AND PermissionSetId = :permissionSets[0].Id
        ] == 0) {
            insert new PermissionSetAssignment(
                AssigneeId = userId,
                PermissionSetId = permissionSets[0].Id
            );
        }
        permissionSetAssigned = true;
    }

    public static void applyRequiredFields(SObject record) {
        Schema.SObjectType objectType = record.getSObjectType();
        Map<String, Schema.SObjectField> fieldMap = objectType.getDescribe().fields.getMap();
        for (Schema.SObjectField fieldToken : fieldMap.values()) {
            Schema.DescribeFieldResult fieldDescribe = fieldToken.getDescribe();
            if (
                !fieldDescribe.isCustom() ||
                !fieldDescribe.isCreateable() ||
                fieldDescribe.isNillable() ||
                fieldDescribe.isCalculated()
            ) {
                continue;
            }
            String fieldName = fieldDescribe.getName();
            if (record.get(fieldName) != null) {
                continue;
            }
            Object defaultValue = defaultValueFor(fieldDescribe);
            if (defaultValue != null) {
                record.put(fieldName, defaultValue);
            }
        }
    }

    private static Object defaultValueFor(Schema.DescribeFieldResult fieldDescribe) {
        Schema.DisplayType fieldType = fieldDescribe.getType();
        if (fieldType == Schema.DisplayType.REFERENCE) {
            List<Schema.SObjectType> referenceTypes = fieldDescribe.getReferenceTo();
            for (Schema.SObjectType referenceType : referenceTypes) {
                if (referenceType == User.SObjectType) {
                    return currentUserId();
                }
            }
            return null;
        }
        if (fieldType == Schema.DisplayType.BOOLEAN) {
            return false;
        }
        if (
            fieldType == Schema.DisplayType.PICKLIST ||
            fieldType == Schema.DisplayType.MULTIPICKLIST
        ) {
            for (Schema.PicklistEntry entry : fieldDescribe.getPicklistValues()) {
                if (entry.isActive()) {
                    return entry.getValue();
                }
            }
        }
        if (fieldType == Schema.DisplayType.DATE) {
            return Date.today();
        }
        if (fieldType == Schema.DisplayType.DATETIME) {
            return System.now();
        }
        if (
            fieldType == Schema.DisplayType.DOUBLE ||
            fieldType == Schema.DisplayType.CURRENCY ||
            fieldType == Schema.DisplayType.PERCENT ||
            fieldType == Schema.DisplayType.INTEGER
        ) {
            return 0;
        }
        return 'Test';
    }

    public static Product2 buildProduct(String name) {
        Product2 product = new Product2(
            Name = name,
            IsActive = true
        );
        applyRequiredFields(product);
        return product;
    }

    public static void insertProduct(Product2 product) {
        applyRequiredFields(product);
        insert product;
    }

    public static void insertProducts(List<Product2> products) {
        for (Product2 product : products) {
            applyRequiredFields(product);
        }
        insert products;
    }

    public static Account insertAccount(String name) {
        Account account = new Account(Name = name);
        insert account;
        return account;
    }

    public static Contact insertContact(Id accountId, String lastName) {
        Contact contact = new Contact(
            LastName = lastName,
            AccountId = accountId
        );
        insert contact;
        return contact;
    }

    public static Opportunity insertOpportunity(Id accountId, String name) {
        return insertOpportunity(accountId, name, null, false);
    }

    public static Opportunity insertOpportunity(
        Id accountId,
        String name,
        Id previousOpportunityId,
        Boolean renewEstimateAutoCreate
    ) {
        Contact contact = insertContact(accountId, 'Test Contact');
        Opportunity opportunity = buildOpportunity(
            accountId,
            name,
            previousOpportunityId,
            renewEstimateAutoCreate
        );
        opportunity.ContactId = contact.Id;
        insert opportunity;
        return opportunity;
    }

    public static Opportunity buildOpportunity(
        Id accountId,
        String name,
        Id previousOpportunityId,
        Boolean renewEstimateAutoCreate
    ) {
        Opportunity opportunity = new Opportunity(
            Name = name,
            AccountId = accountId,
            OwnerId = currentUserId(),
            StageName = resolveDefaultStageName(),
            CloseDate = Date.today().addMonths(1),
            PreviousOpportunity__c = previousOpportunityId,
            RenewEstimateAutoCreateCheck__c = renewEstimateAutoCreate == true
        );
        applyRequiredFields(opportunity);
        if (Schema.sObjectType.Opportunity.fields.getMap().containsKey('OpportunityCreater__c')) {
            opportunity.put('OpportunityCreater__c', currentUserId());
        }
        if (Schema.sObjectType.Opportunity.fields.getMap().containsKey('CustomFieldDefinition9__c')) {
            opportunity.put('CustomFieldDefinition9__c', Date.today());
        }
        return opportunity;
    }

    private static String resolveDefaultStageName() {
        for (Schema.PicklistEntry entry : Opportunity.StageName.getDescribe().getPicklistValues()) {
            if (entry.isActive() && entry.getValue() == '0%') {
                return entry.getValue();
            }
        }
        List<Schema.PicklistEntry> entries = Opportunity.StageName.getDescribe().getPicklistValues();
        return entries.isEmpty() ? 'Prospecting' : entries[0].getValue();
    }
}
