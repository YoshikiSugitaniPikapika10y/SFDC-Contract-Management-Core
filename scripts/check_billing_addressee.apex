Schema.DescribeFieldResult addressee = BillingAccount__c.BillingAddressee__c.getDescribe();
System.debug('BillingAddressee__c updateable=' + addressee.isUpdateable());
System.debug('BillingAddressee__c createable=' + addressee.isCreateable());
System.debug('BillingAddressee__c accessible=' + addressee.isAccessible());
System.debug('BillingAddressee__c type=' + addressee.getType());

Schema.DescribeFieldResult emailTo = BillingAccount__c.BillingEmailTo__c.getDescribe();
System.debug('BillingEmailTo__c updateable=' + emailTo.isUpdateable());

Schema.DescribeFieldResult paymentTerm = BillingAccount__c.PaymentTerm__c.getDescribe();
System.debug('PaymentTerm__c updateable=' + paymentTerm.isUpdateable());

Schema.DescribeFieldResult nameField = BillingAccount__c.Name.getDescribe();
System.debug('Name updateable=' + nameField.isUpdateable());
System.debug('Name type=' + nameField.getType());
