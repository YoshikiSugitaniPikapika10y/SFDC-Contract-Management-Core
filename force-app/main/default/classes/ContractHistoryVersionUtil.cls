public without sharing class ContractHistoryVersionUtil {
    public static Map<Id, Decimal> buildVersionAllocator(Set<Id> contractServiceIds) {
        Map<Id, Decimal> allocator = new Map<Id, Decimal>();
        if (contractServiceIds == null || contractServiceIds.isEmpty()) {
            return allocator;
        }

        for (Id contractServiceId : contractServiceIds) {
            allocator.put(contractServiceId, 0);
        }

        for (AggregateResult result : [
            SELECT ContractService__c serviceId, MAX(Version__c) maxVersion
            FROM ContractHistory__c
            WHERE ContractService__c IN :contractServiceIds
            WITH SYSTEM_MODE
            GROUP BY ContractService__c
        ]) {
            Decimal maxVersion = (Decimal) result.get('maxVersion');
            allocator.put(
                (Id) result.get('serviceId'),
                maxVersion == null ? 0 : maxVersion
            );
        }
        return allocator;
    }

    public static Decimal allocateNextVersion(
        Map<Id, Decimal> versionAllocator,
        Id contractServiceId
    ) {
        if (contractServiceId == null) {
            return 1;
        }

        Decimal currentMax = versionAllocator != null &&
            versionAllocator.containsKey(contractServiceId)
            ? versionAllocator.get(contractServiceId)
            : 0;
        Decimal nextVersion = currentMax == null || currentMax == 0
            ? 1
            : currentMax + 1;

        if (versionAllocator != null) {
            versionAllocator.put(contractServiceId, nextVersion);
        }
        return nextVersion;
    }

    public static Decimal getNextHistoryVersion(Id contractServiceId) {
        if (contractServiceId == null) {
            return 1;
        }
        Map<Id, Decimal> allocator = buildVersionAllocator(
            new Set<Id>{ contractServiceId }
        );
        return allocateNextVersion(allocator, contractServiceId);
    }
}
