# SFDC Contract Management Core

Salesforce DX project for the contract management core package (billing accounts, contract services, contract history, contract products, invoice products).

## Package contents

- Custom objects: `BillingAccount__c`, `ContractService__c`, `ContractHistory__c`, `ContractProduct__c`, `InvoiceProduct__c`, `EstimateNoteMaster__c`
- LWC / Apex for estimate creation, order wizard, invoice generation
- Flow: `SetEstimateRelateFields` (sets estimate-related fields on contract history create)
- Manifest: `manifest/package-full.xml`

## Deploy

```bash
sf project deploy start -d force-app -o <target-org> --test-level NoTestRun
```

Run package tests:

```bash
sf apex run test --tests InvoiceProductScenarioTest --tests EstimateCreateControllerTest --tests OrderCreateControllerTest -o <target-org> --wait 30
```

## Releases

| Tag | Description |
|---|---|
| `20260624` | Initial AppExchange-ready package snapshot |

## Docs

- `docs/lwc-apex-required-fields.txt` — required fields and dependencies
