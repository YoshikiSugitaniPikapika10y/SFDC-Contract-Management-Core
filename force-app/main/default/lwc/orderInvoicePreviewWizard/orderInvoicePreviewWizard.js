import { LightningElement, api, track, wire } from 'lwc';
import { CurrentPageReference } from 'lightning/navigation';
import { resolveSaveErrorAlert } from 'c/estimateValidationAlertUtils';
import {
    closeOrderWizardTab,
    initializeOrderWizardFromUrl,
    isOrderWizardTabView,
    NavigationMixin,
    readOrderWizardRecordId
} from 'c/orderWizardNavigation';
import {
    HISTORY_STATUS_ARCHIVE,
    isOrderActionBootstrapping,
    requestOrderWizardClose,
    scheduleRecordActionLoad
} from 'c/orderWizardClose';
import getOrderContext from '@salesforce/apex/OrderCreateController.getOrderContext';
import getInvoicePreview from '@salesforce/apex/OrderCreateController.getInvoicePreview';

export default class OrderInvoicePreviewWizard extends NavigationMixin(
    LightningElement
) {
    @api recordId;

    @track isTabView = false;
    @track isLoading = true;
    @track errorMessage = '';
    @track historyName = '';
    @track invoicePreview;

    connectedCallback() {
        initializeOrderWizardFromUrl(this);
        scheduleRecordActionLoad(this, () => this.loadPreview());
    }

    renderedCallback() {
        scheduleRecordActionLoad(this, () => this.loadPreview());
    }

    @wire(CurrentPageReference)
    setCurrentPageReference(pageRef) {
        const recordId = readOrderWizardRecordId(pageRef);
        if (recordId) {
            this.recordId = recordId;
        }
        this.isTabView = isOrderWizardTabView(pageRef, 'preview');
    }

    get pageClass() {
        return this.isTabView
            ? 'preview-page preview-page_tab'
            : 'preview-page preview-page_modal';
    }

    async loadPreview() {
        if (!this.recordId) {
            return;
        }

        this.isLoading = true;
        this.errorMessage = '';
        this.invoicePreview = undefined;
        try {
            const context = await getOrderContext({
                contractHistoryId: this.recordId
            });

            if (context.historyStatus === HISTORY_STATUS_ARCHIVE) {
                this.errorMessage =
                    'アーカイブ済みの契約履歴では請求プレビューは利用できません。';
                return;
            }

            if (!context.isOrdered) {
                this.errorMessage =
                    'Estimate 状態の契約履歴です。「受注」ボタンをご利用ください。';
                return;
            }

            this.historyName = context.historyName || '';
            this.invoicePreview = await getInvoicePreview({
                contractHistoryId: this.recordId
            });
        } catch (error) {
            this.errorMessage = this.reduceError(error);
        } finally {
            this.isLoading = false;
        }
    }

    get hasPreview() {
        return Boolean(this.invoicePreview);
    }

    get showBootstrapLoading() {
        return isOrderActionBootstrapping(this);
    }

    handleClose() {
        this.closeAction({ refresh: false });
    }

    closeAction({ refresh = false } = {}) {
        if (this.isTabView) {
            closeOrderWizardTab(this, {
                recordId: this.recordId,
                refresh
            });
            return;
        }
        requestOrderWizardClose(this, { recordId: this.recordId, refresh });
    }

    reduceError(error) {
        const alert = resolveSaveErrorAlert(error);
        return alert.messages.map((entry) => entry.text).join('\n');
    }
}
