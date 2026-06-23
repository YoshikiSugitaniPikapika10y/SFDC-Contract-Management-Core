import { LightningElement, api } from 'lwc';

export default class OrderCreateStepConfirm extends LightningElement {
    @api context;

    get historyName() {
        return this.context?.historyName || '';
    }

    get billingAccountName() {
        return this.context?.billingAccountName || '';
    }

    get billingDayLabel() {
        return this.context?.billingSettings?.billingDayOfMonthLabel || '—';
    }

    get paymentTerm() {
        return this.context?.billingSettings?.paymentTerm || '—';
    }

    get adjustBusinessDayLabel() {
        return this.context?.billingSettings?.adjustInvoiceDateToBusinessDay
            ? 'あり'
            : 'なし';
    }

    get productCount() {
        return (this.context?.products || []).length;
    }
}
