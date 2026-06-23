import fs from 'fs';
import path from 'path';

const objects = [
    'ContractService__c',
    'ContractHistory__c',
    'ContractProduct__c',
    'InvoiceProduct__c',
    'BillingAccount__c'
];

function localFields(obj) {
    const dir = path.join('force-app/main/default/objects', obj, 'fields');
    if (!fs.existsSync(dir)) {
        return [];
    }
    return fs
        .readdirSync(dir)
        .filter((f) => f.endsWith('.field-meta.xml'))
        .map((f) => f.replace('.field-meta.xml', ''))
        .sort();
}

function orgFields(obj) {
    const csvPath = `org-fields-final-${obj}.csv`;
    if (!fs.existsSync(csvPath)) {
        return [];
    }
    const lines = fs
        .readFileSync(csvPath, 'ascii')
        .split('\n')
        .map((l) => l.trim())
        .filter((l) => l && l !== 'QualifiedApiName' && !l.startsWith('Querying'));
    return lines.sort();
}

let allOk = true;
for (const obj of objects) {
    const loc = localFields(obj);
    const org = orgFields(obj);
    const onlyLoc = loc.filter((x) => !org.includes(x));
    const onlyOrg = org.filter((x) => !loc.includes(x));
    console.log(`=== ${obj} ===`);
    if (onlyLoc.length) {
        console.log(`ONLY LOCAL: ${onlyLoc.join(', ')}`);
        allOk = false;
    }
    if (onlyOrg.length) {
        console.log(`ONLY ORG: ${onlyOrg.join(', ')}`);
        allOk = false;
    }
    if (!onlyLoc.length && !onlyOrg.length) {
        console.log('OK');
    }
    console.log(`local ${loc.length} org ${org.length}`);
}
console.log(allOk ? '\nALL OBJECTS ALIGNED' : '\nMISMATCHES REMAIN');
