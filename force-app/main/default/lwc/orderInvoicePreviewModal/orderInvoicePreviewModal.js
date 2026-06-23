import LightningModal from 'lightning/modal';
import { api } from 'lwc';
import { handleOrderModalRequestClose } from 'c/orderWizardClose';

export default class OrderInvoicePreviewModal extends LightningModal {
    @api recordId;
    handleRequestClose(event) {
        handleOrderModalRequestClose(this, event);
    }
}
