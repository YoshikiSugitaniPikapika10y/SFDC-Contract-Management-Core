import { LightningElement, api, wire } from 'lwc';
import getOrderHistoryFieldDefinitions from '@salesforce/apex/OrderWizardFieldService.getOrderHistoryFieldDefinitions';
import {
    buildCustomFieldInputs
} from 'c/estimateWizardCustomFields';

const TYPE_LABELS = {
    New: '新規',
    Change: '変更',
    Renew: '更新',
    Cancel: '解約'
};

export default class OrderCreateStepReview extends LightningElement {
    @api context;
    @api historyCustomFields = {};

    fieldDefinitions = [];

    @wire(getOrderHistoryFieldDefinitions)
    wiredFieldDefinitions({ data }) {
        if (data) {
            this.fieldDefinitions = data;
        }
    }

    get hasContext() {
        return !!this.context;
    }

    get historyName() {
        return this.context?.historyName || '';
    }

    get versionLabel() {
        return this.context?.version ?? '';
    }

    get contractServiceName() {
        return this.context?.contractServiceName || '';
    }

    get accountName() {
        return this.context?.accountName || '';
    }

    get termPeriodLabel() {
        const start = this.context?.termStartDate || '';
        const end = this.context?.termEndDate || '';
        if (!start && !end) {
            return '';
        }
        return `${start} 〜 ${end}`;
    }

    get effectiveDate() {
        return this.context?.effectiveDate || '';
    }

    get hasEffectiveDate() {
        return Boolean(this.effectiveDate);
    }

    get typeLabel() {
        return TYPE_LABELS[this.context?.historyType] || this.context?.historyType || '';
    }

    get productRows() {
        return (this.context?.products || []).map((product, index) => ({
            key: `product-${index}`,
            productName: product.productName,
            quantity: product.quantity,
            unitPrice: product.unitPrice,
            unit: product.unit,
            billingType: product.billingType,
            invoiceSetting: product.invoiceSetting,
            periodLabel: this.buildPeriodLabel(product.startDate, product.endDate),
            lineAmount: product.lineAmount
        }));
    }

    get hasProducts() {
        return this.productRows.length > 0;
    }

    get historyFieldInputs() {
        return buildCustomFieldInputs(
            this.fieldDefinitions,
            this.historyCustomFields,
            'order-history'
        );
    }

    get showHistoryFields() {
        return this.historyFieldInputs.length > 0;
    }

    buildPeriodLabel(startDate, endDate) {
        if (!startDate && !endDate) {
            return '';
        }
        if (!endDate) {
            return startDate;
        }
        return `${startDate} 〜 ${endDate}`;
    }

    handleCustomFieldChange(event) {
        const { fieldApi, value } = event.detail;
        this.dispatchEvent(
            new CustomEvent('historyfieldchange', {
                detail: {
                    fieldApi,
                    value
                }
            })
        );
    }
}
