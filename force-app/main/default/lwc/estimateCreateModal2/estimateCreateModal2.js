import { LightningElement, api, track, wire } from 'lwc';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';
import OPP_NAME_FIELD from '@salesforce/schema/Opportunity.Name';
import OPP_ACCOUNT_ID_FIELD from '@salesforce/schema/Opportunity.AccountId';
import getLatestContractHistory from '@salesforce/apex/EstimateCreateController.getLatestContractHistory';
import getBillingAccountInvoiceSettings from '@salesforce/apex/EstimateCreateController.getBillingAccountInvoiceSettings';

export default class EstimateCreateModal2 extends LightningElement {
    @api recordId;

    _wizardData;
    _isConnected = false;

    @api
    get wizardData() {
        return this._wizardData;
    }

    set wizardData(value) {
        this._wizardData = value;
        if (this._isConnected) {
            this.applyWizardDataFromParent();
        }
    }

    @track _selectedType = '';
    @track isNewType = false;

    @track contractServiceName = '';
    @track contractHistoryName = '';
    @track contractServiceId = '';
    @track contractHistoryId = '';
    @track autoHistoryName = '';
    @track baseHistoryVersion = null;
    @track nextHistoryVersion = null;
    @track renewEligible = null;
    @track billingAccountId = '';
    @track billingAccountInvoiceSummary = '';
    @track opportunityAccountId = '';

    matchingInfo = {
        primaryField: {
            fieldPath: 'Name'
        }
    };

    billingAccountMatchingInfo = {
        primaryField: {
            fieldPath: 'Name'
        }
    };

    @api
    get selectedType() {
        return this._selectedType;
    }

    set selectedType(value) {
        this._selectedType = value;
        this.isNewType = value === 'New';
    }

    get billingAccountFilter() {
        if (!this.opportunityAccountId) {
            return null;
        }
        return {
            criteria: [
                {
                    fieldPath: 'Account__c',
                    operator: 'eq',
                    value: this.opportunityAccountId
                }
            ]
        };
    }

    get isBillingAccountPickerDisabled() {
        return !this.opportunityAccountId;
    }

    get showBillingAccountInvoiceSummary() {
        return Boolean(this.billingAccountInvoiceSummary);
    }

    @wire(getBillingAccountInvoiceSettings, { billingAccountId: '$billingAccountId' })
    wiredBillingAccountInvoiceSettings({ data }) {
        if (!this.billingAccountId) {
            this.billingAccountInvoiceSummary = '';
            return;
        }
        if (!data) {
            return;
        }

        const parts = [];
        if (data.billingDayOfMonthLabel) {
            parts.push(`請求日: ${data.billingDayOfMonthLabel}`);
        }
        if (data.adjustInvoiceDateToBusinessDay) {
            parts.push('土日スキップ: あり');
        }
        if (data.paymentTerm) {
            parts.push(`支払: ${data.paymentTerm}`);
        }
        this.billingAccountInvoiceSummary = parts.join(' / ');
    }

    get displayNewHistoryVersion() {
        return '1';
    }

    get displayBaseHistoryVersion() {
        return this.formatVersion(this.baseHistoryVersion);
    }

    @wire(getRecord, { recordId: '$recordId', fields: [OPP_NAME_FIELD, OPP_ACCOUNT_ID_FIELD] })
    wiredOpportunity({ data }) {
        if (!data) {
            return;
        }

        this.opportunityAccountId = getFieldValue(data, OPP_ACCOUNT_ID_FIELD) || '';

        if (this.isNewType) {
            const oppName = getFieldValue(data, OPP_NAME_FIELD) || '';
            if (!this.contractServiceName) {
                this.contractServiceName = oppName;
            }
            if (!this.contractHistoryName) {
                this.contractHistoryName = oppName;
            }
            Promise.resolve().then(() => this.notifyParent());
        }
    }

    connectedCallback() {
        this._isConnected = true;
        this.applyWizardDataFromParent();
        Promise.resolve().then(() => this.notifyParent());
    }

    applyWizardDataFromParent() {
        const data = this._wizardData;
        if (!data) {
            return;
        }

        this.contractServiceName = data.contractServiceName || '';
        this.contractHistoryName = data.contractHistoryName || '';
        this.contractServiceId = data.contractServiceId || '';
        this.contractHistoryId = data.contractHistoryId || '';
        this.autoHistoryName = data.autoHistoryName || '';
        this.baseHistoryVersion =
            data.baseHistoryVersion != null ? data.baseHistoryVersion : null;
        this.nextHistoryVersion =
            data.nextHistoryVersion != null ? data.nextHistoryVersion : null;
        this.renewEligible =
            data.renewEligible != null ? data.renewEligible : null;
        this.billingAccountId = data.billingAccountId || '';

        if (data.selectedType) {
            this._selectedType = data.selectedType;
            this.isNewType = data.selectedType === 'New';
        }
    }

    get changeBadgeClass() {
        return this._selectedType === 'Change'
            ? 'est-type-chip est-type-chip_active'
            : 'est-type-chip';
    }

    get renewBadgeClass() {
        return this._selectedType === 'Renew'
            ? 'est-type-chip est-type-chip_active'
            : 'est-type-chip';
    }

    get cancelBadgeClass() {
        return this._selectedType === 'Cancel'
            ? 'est-type-chip est-type-chip_active'
            : 'est-type-chip';
    }

    handleServiceNameChange(event) {
        this.contractServiceName = event.target.value;
        this.notifyParent();
    }

    handleHistoryNameChange(event) {
        this.contractHistoryName = event.target.value;
        this.notifyParent();
    }

    handleBillingAccountChange(event) {
        this.billingAccountId = event.detail.recordId || '';
        this.notifyParent();
    }

    async handleServiceLookupChange(event) {
        this.contractServiceId = event.detail.recordId || '';
        this.contractHistoryId = '';
        this.autoHistoryName = '';
        this.baseHistoryVersion = null;
        this.nextHistoryVersion = null;
        this.renewEligible = null;

        if (!this.contractServiceId) {
            this.notifyParent();
            return;
        }

        try {
            const result = await getLatestContractHistory({
                contractServiceId: this.contractServiceId
            });
            if (result) {
                this.contractHistoryId = result.historyId;
                this.autoHistoryName = result.historyName || '';
                this.baseHistoryVersion = result.version;
                this.nextHistoryVersion = result.nextVersion;
                this.renewEligible = result.renewEligible === true;
            }
        } catch (error) {
            this.contractHistoryId = '';
            this.autoHistoryName = '';
            this.baseHistoryVersion = null;
            this.nextHistoryVersion = null;
            this.renewEligible = null;
        }
        this.notifyParent();
    }

    formatVersion(value) {
        if (value == null || value === '') {
            return '';
        }
        const numeric = Number(value);
        return Number.isFinite(numeric) ? String(numeric) : '';
    }

    notifyParent() {
        this.dispatchEvent(
            new CustomEvent('changefield', {
                bubbles: true,
                composed: true,
                detail: {
                    contractServiceName: this.contractServiceName,
                    contractHistoryName: this.contractHistoryName,
                    contractServiceId: this.contractServiceId,
                    contractHistoryId: this.contractHistoryId,
                    autoHistoryName: this.autoHistoryName,
                    baseHistoryVersion: this.isNewType
                        ? null
                        : this.baseHistoryVersion,
                    nextHistoryVersion: this.isNewType
                        ? 1
                        : this.nextHistoryVersion,
                    renewEligible: this.isNewType ? null : this.renewEligible,
                    billingAccountId: this.billingAccountId
                }
            })
        );
    }
}
