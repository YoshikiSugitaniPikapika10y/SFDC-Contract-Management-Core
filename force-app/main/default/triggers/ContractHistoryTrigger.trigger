trigger ContractHistoryTrigger on ContractHistory__c (
    before update,
    before delete,
    after insert,
    after update
) {
    if (Trigger.isBefore && Trigger.isUpdate) {
        ContractHistoryTriggerHandler.handleBeforeUpdate(Trigger.new, Trigger.oldMap);
    }

    if (Trigger.isBefore && Trigger.isDelete) {
        ContractHistoryTriggerHandler.handleBeforeDelete(Trigger.old);
    }

    if (Trigger.isAfter && Trigger.isInsert) {
        ContractHistoryTriggerHandler.handleAfterInsert(Trigger.new);
    }

    if (Trigger.isAfter && Trigger.isUpdate) {
        ContractHistoryTriggerHandler.handleAfterUpdate(Trigger.new, Trigger.oldMap);
    }
}
