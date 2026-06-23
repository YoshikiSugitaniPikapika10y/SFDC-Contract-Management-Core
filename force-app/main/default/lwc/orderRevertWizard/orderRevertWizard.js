import { LightningElement, api, track, wire } from 'lwc';
import { CurrentPageReference } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
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
    notifyOrderRecordStatusChanged,
    requestOrderWizardClose,
    scheduleRecordActionLoad
} from 'c/orderWizardClose';
import getOrderContext from '@salesforce/apex/OrderCreateController.getOrderContext';
import revertOrder from '@salesforce/apex/OrderCreateController.revertOrder';

export default class OrderRevertWizard extends NavigationMixin(
    LightningElement
) {
    @api recordId;

    pendingRecordRefresh;

    @track isTabView = false;
    @track isLoading = true;
    @track isSaving = false;
    @track errorMessage = '';
    @track context;

    connectedCallback() {
        initializeOrderWizardFromUrl(this);
        scheduleRecordActionLoad(this, () => this.loadContext());
    }

    renderedCallback() {
        scheduleRecordActionLoad(this, () => this.loadContext());
    }

    @wire(CurrentPageReference)
    setCurrentPageReference(pageRef) {
        const recordId = readOrderWizardRecordId(pageRef);
        if (recordId) {
            this.recordId = recordId;
        }
        this.isTabView = isOrderWizardTabView(pageRef, 'revert');
    }

    get pageClass() {
        return this.isTabView
            ? 'revert-page revert-page_tab'
            : 'revert-page revert-page_modal';
    }

    async loadContext() {
        if (!this.recordId) {
            return;
        }

        this.isLoading = true;
        this.errorMessage = '';
        this.context = undefined;

        try {
            const data = await getOrderContext({
                contractHistoryId: this.recordId
            });

            if (data.historyStatus === HISTORY_STATUS_ARCHIVE) {
                this.errorMessage =
                    'アーカイブ済みの契約履歴では差し戻しは利用できません。';
                return;
            }

            if (!data.isOrdered) {
                this.errorMessage =
                    'Estimate 状態の契約履歴です。「受注」ボタンをご利用ください。';
                return;
            }

            this.context = data;
        } catch (error) {
            this.errorMessage = this.reduceError(error);
        } finally {
            this.isLoading = false;
        }
    }

    get canRevert() {
        return this.context?.canRevert === true;
    }

    get revertBlockedReason() {
        return this.context?.revertBlockedReason || '';
    }

    get showRevertBlockedNotice() {
        return Boolean(this.revertBlockedReason);
    }

    get hasContext() {
        return !!this.context;
    }

    get showBootstrapLoading() {
        return isOrderActionBootstrapping(this);
    }

    get historyName() {
        return this.context?.historyName || '';
    }

    get isBusy() {
        return this.isLoading || this.isSaving;
    }

    get isRevertDisabled() {
        return this.isBusy || !this.canRevert;
    }

    async handleRevert() {
        if (this.isSaving || !this.canRevert) {
            return;
        }
        this.isSaving = true;
        this.errorMessage = '';
        try {
            await revertOrder({ contractHistoryId: this.recordId });
            notifyOrderRecordStatusChanged(this, this.recordId);
            this.showToast(
                '差し戻し完了',
                'ステータスを Estimate に戻しました。',
                'success'
            );
            this.closeAction();
        } catch (error) {
            this.errorMessage = this.reduceError(error);
            this.showToast('差し戻しエラー', this.errorMessage, 'error');
        } finally {
            this.isSaving = false;
        }
    }

    handleClose() {
        this.closeAction({ refresh: false });
    }

    closeAction({ refresh = true } = {}) {
        if (this.isTabView) {
            closeOrderWizardTab(this, {
                recordId: this.recordId,
                refresh
            });
            return;
        }
        requestOrderWizardClose(this, { refresh, recordId: this.recordId });
    }

    showToast(title, message, variant) {
        this.dispatchEvent(
            new ShowToastEvent({
                title,
                message,
                variant
            })
        );
    }

    reduceError(error) {
        const alert = resolveSaveErrorAlert(error);
        return alert.messages.map((entry) => entry.text).join('\n');
    }
}
