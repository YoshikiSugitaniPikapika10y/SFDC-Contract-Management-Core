import LightningModal from 'lightning/modal';
import { api } from 'lwc';
import {
    handleOrderModalRequestClose,
    markOrderRecordForRefresh,
    refreshOnRecordActionUnmount
} from 'c/orderWizardClose';

export default class OrderCreateModal extends LightningModal {
    @api recordId;

    pendingRecordRefresh;

    handleRequestClose(event) {
        handleOrderModalRequestClose(this, event);
    }

    handleOrderRecordStatusChanged(event) {
        markOrderRecordForRefresh(this, event.detail?.recordId);
    }

    disconnectedCallback() {
        refreshOnRecordActionUnmount(this);
    }
}
