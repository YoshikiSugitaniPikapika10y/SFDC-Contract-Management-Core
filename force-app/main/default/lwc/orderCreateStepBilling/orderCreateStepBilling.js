import { LightningElement, api, wire } from 'lwc';
import getOrderBillingFieldDefinitions from '@salesforce/apex/OrderWizardFieldService.getOrderBillingFieldDefinitions';
import getBillingAccountInvoiceSettings from '@salesforce/apex/EstimateCreateController.getBillingAccountInvoiceSettings';
import { buildCustomFieldInputs } from 'c/estimateWizardCustomFields';

const EMPTY_LABEL = '—';

export default class OrderCreateStepBilling extends LightningElement {
    @api context;

    _billingCustomFields = {};
    _pendingBillingCustomFields = null;

    fieldDefinitions = [];

    @api
    get billingCustomFields() {
        return this._billingCustomFields;
    }

    set billingCustomFields(value) {
        const nextValues = value ? { ...value } : {};
        if (this.fieldDefinitions.length === 0) {
            this._pendingBillingCustomFields = nextValues;
            return;
        }
        this._billingCustomFields = this.mergeBillingCustomFields(nextValues);
        this._pendingBillingCustomFields = null;
    }

    @api
    getBillingCustomFields() {
        return this.buildCompleteBillingCustomFields();
    }

    @api
    validateBillingFields() {
        const missingLabels = [];
        for (const field of this.fieldDefinitions) {
            if (!field.required) {
                continue;
            }
            const value = this.resolveBillingFieldValue(field.apiName, field.fieldType);
            if (this.isMissingBillingFieldValue(field.fieldType, value)) {
                missingLabels.push(field.label);
            }
        }
        if (missingLabels.length === 0) {
            return null;
        }
        return `請求アカウントの必須項目を入力してください: ${missingLabels.join('、')}`;
    }

    buildCompleteBillingCustomFields() {
        const values = { ...this._billingCustomFields };
        for (const field of this.fieldDefinitions) {
            if (Object.prototype.hasOwnProperty.call(values, field.apiName)) {
                continue;
            }
            values[field.apiName] = field.fieldType === 'BOOLEAN' ? false : '';
        }
        return values;
    }

    resolveBillingFieldValue(fieldApiName, fieldType) {
        if (Object.prototype.hasOwnProperty.call(this._billingCustomFields, fieldApiName)) {
            return this._billingCustomFields[fieldApiName];
        }
        return fieldType === 'BOOLEAN' ? false : '';
    }

    isMissingBillingFieldValue(fieldType, value) {
        if (fieldType === 'BOOLEAN') {
            return false;
        }
        if (value === null || value === undefined) {
            return true;
        }
        return String(value).trim() === '';
    }

    @wire(getOrderBillingFieldDefinitions)
    wiredFieldDefinitions({ data }) {
        if (!data) {
            return;
        }
        this.fieldDefinitions = data;
        const baseValues = this._pendingBillingCustomFields || this._billingCustomFields;
        this._billingCustomFields = this.mergeBillingCustomFields(baseValues);
        this._pendingBillingCustomFields = null;
        this.applyBillingSettingsFallback(this.context?.billingSettings);
    }

    get billingAccountId() {
        return this.context?.billingAccountId || null;
    }

    @wire(getBillingAccountInvoiceSettings, { billingAccountId: '$billingAccountId' })
    wiredBillingAccountInvoiceSettings({ data }) {
        if (!data || !this.fieldDefinitions.length) {
            return;
        }
        this.applyBillingSettingsFallback(data);
    }

    applyBillingSettingsFallback(invoiceSettings) {
        if (!invoiceSettings) {
            return;
        }
        this._billingCustomFields = this.mergeBillingCustomFields(
            this._billingCustomFields,
            invoiceSettings
        );
    }

    mergeBillingCustomFields(baseValues = {}, invoiceSettings = null) {
        const merged = { ...(baseValues || {}) };

        if (invoiceSettings) {
            if (
                this.isBlankPicklistValue(merged.PaymentTerm__c) &&
                invoiceSettings.paymentTerm
            ) {
                merged.PaymentTerm__c = invoiceSettings.paymentTerm;
            }
            if (
                this.isBlankPicklistValue(merged.BillingDayOfMonth__c) &&
                invoiceSettings.billingDayOfMonthPicklistValue
            ) {
                merged.BillingDayOfMonth__c =
                    invoiceSettings.billingDayOfMonthPicklistValue;
            }
            if (
                !Object.prototype.hasOwnProperty.call(
                    merged,
                    'AdjustInvoiceDateToBusinessDay__c'
                )
            ) {
                merged.AdjustInvoiceDateToBusinessDay__c =
                    invoiceSettings.adjustInvoiceDateToBusinessDay === true;
            }
        }

        return merged;
    }

    isBlankPicklistValue(value) {
        return value === null || value === undefined || String(value).trim() === '';
    }

    get hasBillingAccount() {
        return Boolean(this.context?.billingAccountId);
    }

    get billingCustomerAccountName() {
        return this.context?.billingCustomerAccountName || EMPTY_LABEL;
    }

    get billingAccountName() {
        return this.context?.billingAccountName || EMPTY_LABEL;
    }

    get billingFieldInputs() {
        return buildCustomFieldInputs(
            this.fieldDefinitions,
            this._billingCustomFields,
            'order-billing'
        );
    }

    handleCustomFieldChange(event) {
        const { fieldApi, value } = event.detail;
        this._billingCustomFields = {
            ...this._billingCustomFields,
            [fieldApi]: value
        };
        this.dispatchEvent(
            new CustomEvent('billingfieldchange', {
                detail: {
                    fieldApi,
                    value
                }
            })
        );
    }
}
