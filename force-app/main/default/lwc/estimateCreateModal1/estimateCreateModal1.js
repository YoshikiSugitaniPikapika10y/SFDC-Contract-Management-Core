import { LightningElement, api, wire, track } from 'lwc';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';
import OPP_NAME_FIELD from '@salesforce/schema/Opportunity.Name';
import ACCOUNT_NAME_FIELD from '@salesforce/schema/Opportunity.Account.Name';

export default class EstimateCreateModal1 extends LightningElement {
    @api recordId;
    @api selectedType = 'New';
    @api presetOpportunityName = '';
    @api presetAccountName = '';

    @track opportunityName = '';
    @track accountName = '';

    get displayOpportunityName() {
        return this.opportunityName || this.presetOpportunityName || '';
    }

    get displayAccountName() {
        return this.accountName || this.presetAccountName || '';
    }

    get isNewSelected() { return this.selectedType === 'New'; }
    get isChangeSelected() { return this.selectedType === 'Change'; }
    get isRenewSelected() { return this.selectedType === 'Renew'; }
    get isCancelSelected() { return this.selectedType === 'Cancel'; }

    @wire(getRecord, { recordId: '$recordId', fields: [OPP_NAME_FIELD, ACCOUNT_NAME_FIELD] })
    wiredOpportunity({ error, data }) {
        if (data) {
            this.opportunityName = getFieldValue(data, OPP_NAME_FIELD);
            this.accountName = getFieldValue(data, ACCOUNT_NAME_FIELD);
        }
    }

    // 値が変わるたびに「即座に」親コンポーネントのデータを書き換える
    handleTypeChange(event) {
        this.selectedType = event.target.value;
        this.dispatchEvent(new CustomEvent('changefield', {
            detail: { selectedType: this.selectedType }
        }));
    }
}