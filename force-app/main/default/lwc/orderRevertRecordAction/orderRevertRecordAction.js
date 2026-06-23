import { LightningElement, api } from 'lwc';
import { NavigationMixin } from 'c/orderWizardNavigation';
import {
    closeOrderRecordAction,
    markOrderRecordForRefresh,
    refreshOnRecordActionUnmount
} from 'c/orderWizardClose';
import { resizeQuickActionPanel } from 'c/quickActionPanelResize';

export default class OrderRevertRecordAction extends NavigationMixin(
    LightningElement
) {
    @api recordId;

    pendingRecordRefresh;

    connectedCallback() {
        resizeQuickActionPanel(this);
    }

    renderedCallback() {
        resizeQuickActionPanel(this);
    }

    handleRequestClose(event) {
        const detail = event.detail || {};
        closeOrderRecordAction(this, {
            refresh: detail.refresh !== false,
            recordId: detail.recordId || this.recordId
        });
    }

    handleOrderRecordStatusChanged(event) {
        markOrderRecordForRefresh(this, event.detail?.recordId);
    }

    disconnectedCallback() {
        refreshOnRecordActionUnmount(this);
    }
}
