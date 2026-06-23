import { LightningElement, api, track, wire } from 'lwc';
import { CurrentPageReference, NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import saveEstimate from '@salesforce/apex/EstimateCreateController.saveEstimate';
import getEstimateCopyPreset from '@salesforce/apex/EstimateCreateController.getEstimateCopyPreset';
import {
    validateBillingPeriod,
    validateNewProducts,
    validateNewEffectiveDate,
    validateRenewProducts,
    validateRenewEffectiveDate,
    validateCancelProducts,
    validateCancelEffectiveDate,
    validateChangeProducts,
    validateChangeEffectiveDate,
    validateChangePeriodDates,
    isValidIsoDate,
    isMonthlyPeriodStartDate
} from 'c/estimateLineItemUtils';
import {
    buildWizardValidationAlert,
    resolveSaveErrorAlert
} from 'c/estimateValidationAlertUtils';
import { requestEstimateWizardClose } from 'c/estimateWizardClose';

export default class EstimateCreateWizard extends LightningElement {
    @api recordId;
    @api modalMode = false;

    _copySourceHistoryId = '';

    @api
    get copySourceHistoryId() {
        return this._copySourceHistoryId;
    }
    set copySourceHistoryId(value) {
        const next = value || '';
        if (next === this._copySourceHistoryId) {
            return;
        }
        this._copySourceHistoryId = next;
        if (next) {
            this.copyFromHistoryId = next;
            if (this.showWizard) {
                this.ensureCopyPresetLoaded();
            }
        }
    }

    @track currentStep = 1;
    @track isSaving = false;
    @track validationAlert = null;
    @track opportunityRecordId = '';
    @track copyFromHistoryId = '';
    @track isLoadingCopy = false;
    @track copyLoadError = '';
    @track isTabView = false;

    _loadedCopyPresetHistoryId = '';

    @track wizardData = {
        selectedType: 'New',
        opportunityName: '',
        accountName: '',
        contractServiceName: '',
        contractHistoryName: '',
        contractServiceId: '',
        contractHistoryId: '',
        contractStartDate: '',
        endDate: '',
        contractEffectiveDate: '',
        autoHistoryName: '',
        baseHistoryVersion: null,
        nextHistoryVersion: null,
        previousTermStartDate: '',
        previousTermEndDate: '',
        renewEligible: null,
        selectedProducts: [],
        estimateRemarkMasterId: '',
        estimateRemarks: '',
        billingAccountId: ''
    };

    @wire(CurrentPageReference)
    setCurrentPageReference(pageRef) {
        if (pageRef?.state?.c__recordId) {
            this.opportunityRecordId = pageRef.state.c__recordId;
        }
        if (pageRef?.state?.c__copyFromHistoryId) {
            this.copyFromHistoryId = pageRef.state.c__copyFromHistoryId;
        }
        const componentName = pageRef?.attributes?.componentName || '';
        const apiName = pageRef?.attributes?.apiName || '';
        this.isTabView =
            apiName === 'Estimate_Create' ||
            pageRef?.type === 'standard__navItemPage' ||
            pageRef?.type === 'standard__namedPage' ||
            (pageRef?.type === 'standard__component' &&
                componentName.includes('estimateCreateWizard'));
    }

    get showWizard() {
        return this.isTabView || this.modalMode;
    }

    get pageClass() {
        return this.modalMode
            ? 'est-page est-page_modal'
            : 'est-page';
    }

    get showMissingRecordError() {
        return (
            !this.isLoadingCopy &&
            !this.effectiveRecordId &&
            !this.copyFromHistoryId
        );
    }

    get effectiveRecordId() {
        if (this.opportunityRecordId) {
            return this.opportunityRecordId;
        }
        if (this.copyFromHistoryId || this.copySourceHistoryId) {
            return '';
        }
        return this.recordId || '';
    }

    get isStep1() {
        return this.currentStep === 1;
    }
    get isStep2() {
        return this.currentStep === 2;
    }
    get isStep3() {
        return this.currentStep === 3;
    }
    get isNextDisabled() {
        return (
            this.isSaving ||
            this.isLoadingCopy ||
            !this.effectiveRecordId
        );
    }

    get hasValidationAlert() {
        return (
            this.validationAlert &&
            this.validationAlert.messages &&
            this.validationAlert.messages.length > 0
        );
    }

    handleSaveClick() {
        if (!this.effectiveRecordId) {
            this.showValidationAlert('商談IDが指定されていません。');
            return;
        }
        if (this.isSaving) {
            return;
        }
        const modal3 = this.template.querySelector('c-estimate-create-modal3');
        if (modal3) {
            modal3.flushToParent();
        }
        const step3Error = this.validateStep3();
        if (step3Error) {
            this.showValidationAlert(step3Error);
            return;
        }
        this.handleSave();
    }
    get modalTitle() {
        const typeLabel = this.wizardData.selectedType || 'New';
        return `見積作成 ${typeLabel} ${this.currentStep}/3`;
    }

    get typeLabel() {
        return this.wizardData.selectedType || 'New';
    }

    get copyRenderKey() {
        return (
            this._loadedCopyPresetHistoryId ||
            this.copyFromHistoryId ||
            this._copySourceHistoryId ||
            this.effectiveRecordId ||
            'create'
        );
    }

    get step2RenderKey() {
        return `step2-${this.copyRenderKey}-${this.wizardData.selectedType}`;
    }

    get step3RenderKey() {
        return `step3-${this.copyRenderKey}-${this.wizardData.selectedType}`;
    }

    get stepItems() {
        const labels = ['基本情報', '契約情報', '商品明細'];
        return labels.map((label, index) => {
            const num = index + 1;
            const isCurrent = this.currentStep === num;
            const canGoBack = num < this.currentStep;
            const canGoForward = this.canNavigateForwardTo(num);
            const isClickable =
                !this.isSaving && !isCurrent && (canGoBack || canGoForward);

            let itemClass = 'est-step';
            if (isCurrent) {
                itemClass += ' est-step_active';
            } else if (this.currentStep > num) {
                itemClass += ' est-step_done';
            } else if (!canGoForward) {
                itemClass += ' est-step_locked';
            }
            if (isClickable) {
                itemClass += ' est-step_clickable';
            }

            return {
                key: `step-${num}`,
                num,
                label,
                itemClass,
                isCurrent,
                isClickable,
                ariaCurrent: isCurrent ? 'step' : false,
                showConnector: num < 3,
                connectorClass:
                    this.currentStep > num
                        ? 'est-step-connector est-step-connector_done'
                        : 'est-step-connector'
            };
        });
    }

    canNavigateForwardTo(targetStep) {
        if (this.isLoadingCopy) {
            return false;
        }
        if (targetStep <= this.currentStep) {
            return true;
        }
        if (targetStep >= 2 && this.validateStep1()) {
            return false;
        }
        if (targetStep >= 3 && this.validateStep2()) {
            return false;
        }
        return true;
    }

    validateStep1() {
        if (!this.effectiveRecordId) {
            return '商談IDが指定されていません。';
        }
        if (!this.wizardData.selectedType) {
            return 'タイプを選択してください。';
        }
        return null;
    }

    connectedCallback() {
        this.initializeFromUrl();
    }

    initializeFromUrl() {
        if (typeof window === 'undefined') {
            return;
        }

        const href = window.location.href;
        const isWizardUrl =
            href.includes('/lightning/cmp/c__estimateCreateWizard') ||
            href.includes('/lightning/n/Estimate_Create');

        if (isWizardUrl) {
            this.isTabView = true;
        }

        try {
            const url = new URL(href);
            const recordId = url.searchParams.get('c__recordId');
            if (recordId) {
                this.opportunityRecordId = recordId;
            }
            const copyFromHistoryId = url.searchParams.get('c__copyFromHistoryId');
            if (copyFromHistoryId) {
                this.copyFromHistoryId = copyFromHistoryId;
            }
        } catch (e) {
            // URL解析失敗時は wire に任せる
        }
    }

    renderedCallback() {
        if (!this.showWizard) {
            return;
        }

        if (this.copyFromHistoryId || this._copySourceHistoryId) {
            this.ensureCopyPresetLoaded();
            return;
        }

        if (!this._wizardInitialized) {
            this._wizardInitialized = true;
            this.resetWizard();
        }
    }

    ensureCopyPresetLoaded() {
        const sourceId = this.copyFromHistoryId || this._copySourceHistoryId;
        if (!sourceId) {
            return;
        }
        if (!this.copyFromHistoryId) {
            this.copyFromHistoryId = sourceId;
        }
        if (
            this._loadedCopyPresetHistoryId === sourceId ||
            this.isLoadingCopy
        ) {
            return;
        }
        this.loadCopyPreset();
    }

    async loadCopyPreset() {
        const sourceId = this.copyFromHistoryId || this._copySourceHistoryId;
        if (!sourceId) {
            return;
        }

        this.isLoadingCopy = true;
        this.copyLoadError = '';
        try {
            const preset = await getEstimateCopyPreset({
                contractHistoryId: sourceId
            });
            if (preset?.opportunityId) {
                this.opportunityRecordId = preset.opportunityId;
            }
            this.wizardData = this.buildWizardDataFromPreset(preset);
            this.currentStep = 1;
            this.clearValidationAlert();
            this._loadedCopyPresetHistoryId = sourceId;
        } catch (error) {
            this._loadedCopyPresetHistoryId = '';
            this.copyLoadError =
                error?.body?.message ||
                error?.message ||
                '見積コピーの読み込みに失敗しました。';
            this.resetWizard();
        } finally {
            this.isLoadingCopy = false;
        }
    }

    buildWizardDataFromPreset(preset) {
        return {
            selectedType: preset.selectedType || 'New',
            opportunityName: preset.opportunityName || '',
            accountName: preset.accountName || '',
            contractServiceName: preset.contractServiceName || '',
            contractHistoryName: preset.contractHistoryName || '',
            contractServiceId: preset.contractServiceId || '',
            contractHistoryId: preset.contractHistoryId || '',
            contractStartDate: preset.contractStartDate || '',
            endDate: preset.endDate || '',
            contractEffectiveDate: preset.contractEffectiveDate || '',
            autoHistoryName: preset.autoHistoryName || '',
            baseHistoryVersion:
                preset.baseHistoryVersion != null ? preset.baseHistoryVersion : null,
            nextHistoryVersion:
                preset.nextHistoryVersion != null ? preset.nextHistoryVersion : null,
            previousTermStartDate: preset.previousTermStartDate || '',
            previousTermEndDate: preset.previousTermEndDate || '',
            renewEligible: preset.renewEligible != null ? preset.renewEligible : null,
            selectedProducts: preset.selectedProducts || [],
            estimateRemarkMasterId: preset.estimateRemarkMasterId || '',
            estimateRemarks: preset.estimateRemarks || '',
            billingAccountId: preset.billingAccountId || ''
        };
    }

    resetWizard() {
        this.currentStep = 1;
        this.wizardData = {
            selectedType: 'New',
            opportunityName: '',
            accountName: '',
            contractServiceName: '',
            contractHistoryName: '',
            contractServiceId: '',
            contractHistoryId: '',
            contractStartDate: '',
            endDate: '',
            autoHistoryName: '',
            baseHistoryVersion: null,
            nextHistoryVersion: null,
            previousTermStartDate: '',
            previousTermEndDate: '',
            renewEligible: null,
            selectedProducts: [],
            estimateRemarkMasterId: '',
            estimateRemarks: '',
            billingAccountId: ''
        };
    }

    getLightningBase() {
        const href = window.location.href;
        const lightningIndex = href.indexOf('/lightning/');
        return lightningIndex >= 0
            ? href.substring(0, lightningIndex)
            : window.location.origin;
    }

    handleStep1Change(event) {
        const nextType = event.detail.selectedType;
        if (nextType === this.wizardData.selectedType) {
            return;
        }

        this.wizardData = {
            ...this.wizardData,
            selectedType: nextType,
            contractStartDate: '',
            endDate: '',
            contractEffectiveDate: '',
            contractServiceId: '',
            contractHistoryId: '',
            autoHistoryName: '',
            baseHistoryVersion: null,
            nextHistoryVersion: null,
            previousTermStartDate: '',
            previousTermEndDate: '',
            renewEligible: null,
            selectedProducts: [],
            estimateRemarkMasterId: '',
            estimateRemarks: '',
            billingAccountId: '',
            contractCustomFieldsExpanded: false,
            contractServiceCustomFields: {},
            contractHistoryCustomFields: {}
        };
    }

    handleStep2Change(event) {
        this.wizardData = { ...this.wizardData, ...event.detail };
    }

    handleStep3Change(event) {
        this.wizardData = { ...this.wizardData, ...event.detail };
    }

    handleStepClick(event) {
        if (this.isSaving) {
            return;
        }

        const targetStep = Number(event.currentTarget.dataset.step);
        if (!targetStep || targetStep === this.currentStep) {
            return;
        }

        if (targetStep < this.currentStep) {
            this.clearValidationAlert();
            this.currentStep = targetStep;
            return;
        }

        const step1Error = this.validateStep1();
        if (step1Error) {
            this.showValidationAlert(step1Error);
            return;
        }

        if (targetStep >= 3) {
            const step2Error = this.validateStep2();
            if (step2Error) {
                this.showValidationAlert(step2Error);
                return;
            }
        }

        this.clearValidationAlert();
        this.currentStep = targetStep;
    }

    handlePrev() {
        if (this.isSaving) {
            return;
        }
        this.clearValidationAlert();
        if (this.currentStep === 3) {
            this.currentStep = 2;
        } else if (this.currentStep === 2) {
            this.currentStep = 1;
        }
    }

    handleNext() {
        if (!this.effectiveRecordId) {
            this.showValidationAlert('商談IDが指定されていません。');
            return;
        }

        if (this.currentStep === 1) {
            const step1Error = this.validateStep1();
            if (step1Error) {
                this.showValidationAlert(step1Error);
                return;
            }
            this.clearValidationAlert();
            this.currentStep = 2;
        } else if (this.currentStep === 2) {
            const step2Error = this.validateStep2();
            if (step2Error) {
                this.showValidationAlert(step2Error);
                return;
            }
            this.clearValidationAlert();
            this.currentStep = 3;
        }
    }

    validateStep2() {
        const d = this.wizardData;

        if (d.selectedType === 'New') {
            if (!d.contractServiceName || !d.contractServiceName.trim()) {
                return '契約サービス名を入力してください。';
            }
            if (!d.contractHistoryName || !d.contractHistoryName.trim()) {
                return '契約履歴名を入力してください。';
            }
            return null;
        }

        if (!d.contractServiceId) {
            return '契約サービスを選択してください。';
        }
        if (!d.contractHistoryId) {
            return '選択した契約サービスに、Estimate以外の契約履歴がありません。';
        }
        if (d.selectedType === 'Renew' && d.renewEligible === false) {
            return '前回Versionの期間終了日と一致する継続課金商品がありません。Renewできません。Newで作成してください。';
        }
        if (d.selectedType === 'Cancel' && d.renewEligible === false) {
            return '前回Versionの期間終了日と一致する継続課金商品がありません。Cancelできません。Newで作成してください。';
        }
        return null;
    }

    validateStep3() {
        const d = this.wizardData;
        const type = d.selectedType;

        if (!d.contractHistoryName || !d.contractHistoryName.trim()) {
            return '契約履歴名を入力してください。';
        }

        const periodStartLabel = '期間開始日';
        const periodEndLabel = '期間終了日';

        if (!d.contractStartDate) {
            return `${periodStartLabel}を入力してください。`;
        }

        if (!d.contractEffectiveDate) {
            return '有効日を入力してください。';
        }
        if (!isValidIsoDate(d.contractEffectiveDate)) {
            return '有効日は YYYY-MM-DD 形式で入力してください。';
        }

        if (type === 'New') {
            const effectiveDateError = validateNewEffectiveDate(
                d.contractStartDate,
                d.contractEffectiveDate
            );
            if (effectiveDateError) {
                return effectiveDateError;
            }
        }

        if (type === 'Renew') {
            const effectiveDateError = validateRenewEffectiveDate(
                d.contractStartDate,
                d.contractEffectiveDate,
                d.previousTermEndDate
            );
            if (effectiveDateError) {
                return effectiveDateError;
            }
        }

        if (type === 'Change') {
            const periodError = validateChangePeriodDates(
                d.contractStartDate,
                d.endDate,
                d.previousTermStartDate,
                d.previousTermEndDate
            );
            if (periodError) {
                return periodError;
            }
            const effectiveDateError = validateChangeEffectiveDate(
                d.contractEffectiveDate,
                d.previousTermStartDate,
                d.previousTermEndDate,
                d.contractStartDate
            );
            if (effectiveDateError) {
                return effectiveDateError;
            }
        }

        if (type === 'Cancel') {
            if (d.renewEligible === false) {
                return '前回Versionの期間終了日と一致する継続課金商品がありません。Cancelできません。Newで作成してください。';
            }
            if (!d.endDate) {
                return '解約日が取得できません。';
            }
            if (d.contractStartDate !== d.endDate) {
                return '解約日の開始日と終了日が一致しません。';
            }
            const cancelEffectiveError = validateCancelEffectiveDate(
                d.contractStartDate,
                d.contractEffectiveDate,
                d.previousTermEndDate
            );
            if (cancelEffectiveError) {
                return cancelEffectiveError;
            }
            const cancelProductsError = validateCancelProducts(d.selectedProducts);
            if (cancelProductsError) {
                return cancelProductsError;
            }
            return null;
        }

        if (type === 'New' || type === 'Renew' || type === 'Change') {
            if (!d.endDate) {
                return `${periodEndLabel}を入力してください。`;
            }
        }

        if (type === 'Change' || type === 'Renew' || type === 'New') {
            if (
                d.contractStartDate &&
                d.endDate &&
                d.contractStartDate > d.endDate
            ) {
                return '期間開始日は期間終了日以前の日付を入力してください。';
            }
        }

        const products = d.selectedProducts || [];

        if (type === 'New') {
            const newError = validateNewProducts(
                products,
                d.contractStartDate,
                d.endDate
            );
            if (newError) {
                return newError;
            }
            return null;
        }

        if (type === 'Renew') {
            if (d.renewEligible === false) {
                return '前回Versionの期間終了日と一致する継続課金商品がありません。Renewできません。Newで作成してください。';
            }
            const renewError = validateRenewProducts(
                products,
                d.contractStartDate,
                d.endDate,
                d.previousTermEndDate
            );
            if (renewError) {
                return renewError;
            }
            return null;
        }

        if (type === 'Change') {
            const changeError = validateChangeProducts(
                products,
                d.contractStartDate,
                d.endDate,
                d.contractEffectiveDate,
                d.previousTermStartDate,
                d.previousTermEndDate
            );
            if (changeError) {
                return changeError;
            }
            return null;
        }

        for (let i = 0; i < products.length; i++) {
            const line = products[i];
            const periodError = validateBillingPeriod(line);
            if (periodError) {
                const label = line.typeLabel || `${i + 1}行目`;
                return `商品明細（${label}）: ${periodError}`;
            }
            if (line.amount == null && line.productId) {
                const qty = Number(line.quantity);
                if (Number.isNaN(qty) || qty !== 0) {
                    const label = line.typeLabel || `${i + 1}行目`;
                    return `商品明細（${label}）: 金額を計算できません。期間を確認してください。`;
                }
            }
        }

        return null;
    }

    async handleSave() {
        const type = this.wizardData.selectedType;
        if (type !== 'New' && type !== 'Change' && type !== 'Renew' && type !== 'Cancel') {
            this.showToast('情報', 'New、Change、Renew、Cancelタイプのみ保存できます。', 'info');
            return;
        }

        const modal3 = this.template.querySelector('c-estimate-create-modal3');
        if (modal3) {
            modal3.flushToParent();
        }

        this.isSaving = true;
        try {
            const result = await saveEstimate({
                opportunityId: this.effectiveRecordId,
                selectedType: type,
                contractServiceName: this.wizardData.contractServiceName,
                contractHistoryName: this.wizardData.contractHistoryName,
                contractServiceId: this.wizardData.contractServiceId || null,
                previousHistoryId: this.wizardData.contractHistoryId || null,
                contractStartDate: this.wizardData.contractStartDate,
                contractEndDate: this.wizardData.endDate,
                effectiveDate: this.wizardData.contractEffectiveDate,
                productsJson: JSON.stringify(this.wizardData.selectedProducts || []),
                estimateRemarkMasterId:
                    this.wizardData.estimateRemarkMasterId || null,
                remarksText: this.wizardData.estimateRemarks || null,
                billingAccountId:
                    type === 'New' && this.wizardData.billingAccountId
                        ? this.wizardData.billingAccountId
                        : null,
                contractServiceCustomFieldsJson: JSON.stringify(
                    this.wizardData.contractServiceCustomFields || {}
                ),
                contractHistoryCustomFieldsJson: JSON.stringify(
                    this.wizardData.contractHistoryCustomFields || {}
                ),
                copyFromHistoryId: this.copyFromHistoryId || null
            });
            this.showToast('成功', '見積データを保存しました。', 'success');
            this.isSaving = false;
            if (this.modalMode) {
                requestEstimateWizardClose(this, {
                    refresh: true,
                    opportunityId: this.effectiveRecordId,
                    contractHistoryId: result?.contractHistoryId,
                    navigateToContractHistoryId: result?.contractHistoryId
                });
                this.dispatchEvent(
                    new CustomEvent('estimatesaved', {
                        bubbles: true,
                        composed: true,
                        detail: {
                            opportunityId: this.effectiveRecordId,
                            contractHistoryId: result?.contractHistoryId
                        }
                    })
                );
                return;
            }
            this.redirectToContractHistory(result?.contractHistoryId);
        } catch (error) {
            this.validationAlert = resolveSaveErrorAlert(error);
            this.scrollValidationAlertIntoView();
        } finally {
            this.isSaving = false;
        }
    }

    handleClose() {
        if (this.isSaving) {
            return;
        }
        if (this.modalMode) {
            requestEstimateWizardClose(this, {
                refresh: false,
                opportunityId: this.effectiveRecordId,
                contractHistoryId: this.copyFromHistoryId || null
            });
            return;
        }
        this.closeWizard();
    }

    closeWizard() {
        if (typeof window === 'undefined') {
            return;
        }
        window.close();
        setTimeout(() => {
            if (!window.closed) {
                this.redirectToOpportunity();
            }
        }, 150);
    }

    redirectToContractHistory(contractHistoryId) {
        if (typeof window === 'undefined') {
            return;
        }
        if (contractHistoryId) {
            window.location.href = `${this.getLightningBase()}/lightning/r/ContractHistory__c/${contractHistoryId}/view`;
            return;
        }
        this.redirectToOpportunity();
    }

    redirectToOpportunity() {
        if (typeof window === 'undefined') {
            return;
        }
        const recordId = this.effectiveRecordId;
        if (recordId) {
            window.location.href = `${this.getLightningBase()}/lightning/r/Opportunity/${recordId}/view`;
            return;
        }
        window.history.back();
    }

    showValidationAlert(message) {
        this.validationAlert = buildWizardValidationAlert(message);
        this.scrollValidationAlertIntoView();
    }

    clearValidationAlert() {
        this.validationAlert = null;
    }

    scrollValidationAlertIntoView() {
        if (typeof window === 'undefined') {
            return;
        }
        window.requestAnimationFrame(() => {
            const alertElement = this.template.querySelector(
                '[data-id="wizard-validation-alert"]'
            );
            if (alertElement) {
                alertElement.scrollIntoView({
                    behavior: 'smooth',
                    block: 'nearest'
                });
            }
        });
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
}
