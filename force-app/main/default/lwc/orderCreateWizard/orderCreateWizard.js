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
import saveOrderStep2 from '@salesforce/apex/OrderCreateController.saveOrderStep2';
import confirmOrder from '@salesforce/apex/OrderCreateController.confirmOrder';

export default class OrderCreateWizard extends NavigationMixin(
    LightningElement
) {
    @api recordId;

    @track isTabView = false;
    @track isLoading = true;
    @track isSaving = false;
    @track errorMessage = '';
    @track context;
    @track billingCustomFields = {};

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
        this.isTabView = isOrderWizardTabView(pageRef, 'order');
    }

    get pageClass() {
        return this.isTabView
            ? 'ord-page ord-page_tab'
            : 'ord-page ord-page_modal';
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
                    'アーカイブ済みの契約履歴では受注は利用できません。';
                return;
            }

            if (data.isOrdered) {
                this.errorMessage =
                    '受注済みの契約履歴です。「請求プレビュー」「差し戻し」ボタンをご利用ください。';
                return;
            }

            this.context = data;
            this.billingCustomFields = { ...(data.billingCustomFields || {}) };
        } catch (error) {
            this.errorMessage = this.reduceError(error);
        } finally {
            this.isLoading = false;
        }
    }

    get hasContext() {
        return !!this.context;
    }

    get showMissingRecordError() {
        return !this.recordId && this._recordActionMissingHandled;
    }

    get showBootstrapLoading() {
        return isOrderActionBootstrapping(this);
    }

    get canOrder() {
        return this.context?.canOrder === true;
    }

    get hasBillingAccount() {
        return Boolean(this.context?.billingAccountId);
    }

    get isBusy() {
        return this.isLoading || this.isSaving;
    }

    handleBillingFieldChange(event) {
        const { fieldApi, value } = event.detail;
        this.billingCustomFields = {
            ...this.billingCustomFields,
            [fieldApi]: value
        };
    }

    collectBillingCustomFields() {
        const billingStep = this.template.querySelector(
            'c-order-create-step-billing'
        );
        if (billingStep && typeof billingStep.getBillingCustomFields === 'function') {
            return billingStep.getBillingCustomFields();
        }
        return { ...(this.billingCustomFields || {}) };
    }

    validateBillingStep() {
        const billingStep = this.template.querySelector(
            'c-order-create-step-billing'
        );
        if (billingStep && typeof billingStep.validateBillingFields === 'function') {
            return billingStep.validateBillingFields();
        }
        return null;
    }

    async handleSaveAndExit() {
        if (this.isSaving) {
            return;
        }
        this.isSaving = true;
        this.errorMessage = '';
        try {
            const validationError = this.validateBillingStep();
            if (validationError) {
                this.errorMessage = validationError;
                this.showToast('入力エラー', validationError, 'error');
                this.isSaving = false;
                return;
            }
            await saveOrderStep2({
                contractHistoryId: this.recordId,
                billingCustomFieldsJson: JSON.stringify(
                    this.collectBillingCustomFields()
                )
            });
            this.showToast('保存しました', '請求設定を保存しました。', 'success');
            this.closeAction({ refresh: false });
        } catch (error) {
            this.errorMessage = this.reduceError(error);
            this.showToast('保存エラー', this.errorMessage, 'error');
        } finally {
            this.isSaving = false;
        }
    }

    async handleConfirmOrder() {
        if (this.isSaving || !this.canOrder) {
            return;
        }
        if (!this.hasBillingAccount) {
            this.errorMessage =
                '請求アカウントが未設定のため受注できません。';
            return;
        }

        this.isSaving = true;
        this.errorMessage = '';
        try {
            const validationError = this.validateBillingStep();
            if (validationError) {
                this.errorMessage = validationError;
                this.showToast('入力エラー', validationError, 'error');
                this.isSaving = false;
                return;
            }
            const billingCustomFields = this.collectBillingCustomFields();
            await confirmOrder({
                contractHistoryId: this.recordId,
                billingCustomFieldsJson: JSON.stringify(billingCustomFields)
            });
            notifyOrderRecordStatusChanged(this, this.recordId);
            this.showToast('受注完了', 'ステータスを Ordered に更新しました。', 'success');
            this.closeAction();
        } catch (error) {
            this.errorMessage = this.reduceError(error);
            this.showToast('受注エラー', this.errorMessage, 'error');
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
