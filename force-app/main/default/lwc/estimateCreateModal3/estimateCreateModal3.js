import { LightningElement, api, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';
import getProductDefaults from '@salesforce/apex/EstimateCreateController.getProductDefaults';
import getRecurringContractProducts from '@salesforce/apex/EstimateCreateController.getRecurringContractProducts';
import getRenewContractProducts from '@salesforce/apex/EstimateCreateController.getRenewContractProducts';
import getContractHistoryInfo from '@salesforce/apex/EstimateCreateController.getContractHistoryInfo';
import getEstimateRemarkMasterText from '@salesforce/apex/EstimateCreateController.getEstimateRemarkMasterText';
import getInvoiceSettingOptions from '@salesforce/apex/EstimateCreateController.getInvoiceSettingOptions';
import getDefaultInvoiceSettingLabel from '@salesforce/apex/EstimateCreateController.getDefaultInvoiceSettingLabel';
import CONTRACT_SERVICE_NAME from '@salesforce/schema/ContractService__c.Name';
import {
    BILLING_TYPE_RECURRING,
    MONTHLY_BILLING_CYCLE,
    buildDisplayUnit,
    resolveDisplayUnit,
    calculateLineAmount,
    isHeaderDatesReady,
    validateHeaderDates,
    filterInvoiceSettingOptions,
    resolveInvoiceTypeForBillingType,
    validateInvoiceSettingForBillingType,
    INVOICE_SETTING_PREPAID_START,
    addOneYearMinusOneDay,
    addYearsMinusOneDay,
    addMonthsMinusOneDay,
    addYearsToIsoDate,
    addMonthsToIsoDate,
    addDaysToIsoDate,
    normalizeDateInput,
    isValidIsoDate,
    PRODUCT_TYPE_NEW,
    PRODUCT_TYPE_RENEW,
    PRODUCT_TYPE_ORIGINAL,
    PRODUCT_TYPE_REMAKE,
    isChangeOriginalLine,
    isChangeRemakeLine,
    resolveProductTypeBadge,
    isChangeContinuationLine
} from 'c/estimateLineItemUtils';

export default class EstimateCreateModal3 extends LightningElement {
    @api recordId;

    _wizardData;
    _isConnected = false;
    _wizardBootstrapKey = '';

    @api
    get wizardData() {
        return this._wizardData;
    }

    set wizardData(value) {
        this._wizardData = value;
        if (this._isConnected) {
            this.bootstrapFromWizardData();
        }
    }

    @track _selectedType = '';
    @track itemList = [];
    @track lookupContractServiceName = '';
    @track isLoadingChangeProducts = false;
    @track isLoadingRenewProducts = false;
    @track changeLoadError = '';
    @track renewLoadError = '';
    @track previousTermStartDate = '';
    @track previousTermEndDate = '';
    @track cancelLoadError = '';
    @track contractStartDate = '';
    @track contractEndDate = '';
    @track contractEffectiveDate = '';
    @track fixedEffectiveDate = '';
    @track contractHistoryName = '';
    @track isStartDateReadonly = false;
    @track isEndDateReadonly = false;
    @track isLoadingDates = false;
    @track estimateRemarkMasterId = '';
    @track estimateRemarks = '';
    @track remarkMasterPickerKey = 'remark-master-0';
    @track invoiceSettingOptions = [];
    defaultInvoiceType = '';
    @track productModalRowId = null;
    @track productModalProductId = '';

    rowCounter = 0;
    _isBootstrapping = false;

    matchingInfo = {
        primaryField: {
            fieldPath: 'Name'
        }
    };

    productDisplayInfo = {
        additionalFields: ['ProductCode']
    };

    remarkMasterMatchingInfo = {
        primaryField: {
            fieldPath: 'Name'
        }
    };

    remarkMasterDisplayInfo = {
        additionalFields: ['NoteText__c']
    };

    @wire(getInvoiceSettingOptions)
    wiredInvoiceSettingOptions({ data }) {
        if (data) {
            this.invoiceSettingOptions = data;
            this.refreshRowInvoiceSettings();
        }
    }

    @wire(getDefaultInvoiceSettingLabel)
    wiredDefaultInvoiceSettingLabel({ data }) {
        if (data) {
            this.defaultInvoiceType = data;
            this.refreshRowInvoiceSettings();
        }
    }

    get resolvedDefaultInvoiceType() {
        return this.defaultInvoiceType || INVOICE_SETTING_PREPAID_START;
    }

    refreshRowInvoiceSettings() {
        if (!this.itemList.length) {
            return;
        }
        this.itemList = this.decorateAllRows(
            this.itemList.map((item, index) => {
            const billingType = item.billingType || '';
            const invoiceType = resolveInvoiceTypeForBillingType(
                item.invoiceType,
                billingType,
                this.invoiceSettingOptions,
                this.resolvedDefaultInvoiceType
            );
            return {
                ...item,
                invoiceType
            };
            })
        );
        if (!this._isBootstrapping) {
            this.notifyParent();
        }
    }

    @api
    flushToParent() {
        this.refreshRowInvoiceSettings();
        this.notifyParent();
    }

    buildInvoiceTypeOptions(invoiceType, billingType) {
        return filterInvoiceSettingOptions(
            this.invoiceSettingOptions,
            billingType
        ).map((option) => ({
            label: option.label,
            value: option.label,
            isSelected: option.label === invoiceType
        }));
    }

    resolveRowInvoiceType(invoiceType, billingType) {
        return resolveInvoiceTypeForBillingType(
            invoiceType,
            billingType,
            this.invoiceSettingOptions,
            this.resolvedDefaultInvoiceType
        );
    }

    @api
    get selectedType() {
        return this._selectedType;
    }
    set selectedType(value) {
        this._selectedType = value || '';
    }

    get effectiveSelectedType() {
        return (
            this._selectedType ||
            (this._wizardData && this._wizardData.selectedType) ||
            ''
        );
    }

    get isNewType() {
        return this.effectiveSelectedType === 'New';
    }

    get isChangeType() {
        return this.effectiveSelectedType === 'Change';
    }

    get isRenewType() {
        return this.effectiveSelectedType === 'Renew';
    }

    get isCancelType() {
        return this.effectiveSelectedType === 'Cancel';
    }

    get isEffectiveDateReadonly() {
        return (
            this.isNewType ||
            this.isRenewType ||
            this.isCancelType
        );
    }

    get showProductTable() {
        const type = this.effectiveSelectedType;
        return type === 'New' || type === 'Change' || type === 'Renew';
    }

    get showAddRowButton() {
        return this.showProductTable && this.canEditProducts && !this.isChangeType;
    }

    get changeProductGroups() {
        if (!this.isChangeType) {
            return [];
        }
        const groups = [];
        const groupMap = new Map();

        for (const row of this.itemList) {
            if (isChangeOriginalLine(row)) {
                const group = {
                    pairId: row.pairId,
                    sourceContractProductId: row.sourceContractProductId,
                    productName: row.productName || '',
                    original: row,
                    remakeRows: []
                };
                groupMap.set(row.pairId, group);
                groups.push(group);
                continue;
            }
            if (isChangeRemakeLine(row) && row.pairId) {
                const group = groupMap.get(row.pairId);
                if (group) {
                    group.remakeRows.push(row);
                }
            }
        }

        return groups.map((group) => ({
            ...group,
            remakeCount: group.remakeRows.length,
            addButtonKey: `add-${group.pairId}`
        }));
    }

    get changeNewProductRows() {
        if (!this.isChangeType) {
            return [];
        }
        return this.itemList.filter((row) => isChangeContinuationLine(row));
    }

    get displayItemList() {
        if (!this.isChangeType) {
            return this.itemList;
        }

        const rows = [];
        for (const group of this.changeProductGroups) {
            rows.push({
                id: `group-header-${group.pairId}`,
                isGroupHeader: true,
                isSectionHeader: false,
                groupHeaderTitle: group.productName || '（商品未選択）',
                groupHeaderSubtitle: '変更前 → 変更後',
                groupHeaderClass: 'est-change-group-card__header'
            });
            rows.push({
                ...group.original,
                rowContext: 'changeOriginal',
                changeGroupBoundary: 'start'
            });
            group.remakeRows.forEach((remake, index) => {
                rows.push({
                    ...remake,
                    rowContext: 'changeRemake',
                    canDelete: group.remakeRows.length > 1,
                    showAddRemakeButton:
                        index === group.remakeRows.length - 1,
                    groupPairId: group.pairId,
                    changeGroupBoundary:
                        index === group.remakeRows.length - 1 ? 'end' : 'middle'
                });
            });
            if (group.remakeRows.length === 0) {
                const lastOriginal = rows[rows.length - 1];
                if (lastOriginal) {
                    lastOriginal.changeGroupBoundary = 'end';
                }
            }
        }

        rows.push({
            id: '__new_products_header__',
            rowContext: 'newSectionHeader',
            isGroupHeader: true,
            isSectionHeader: true,
            groupHeaderTitle: '新しい商品',
            groupHeaderSubtitle: '前回Versionにない商品を追加します',
            groupHeaderClass:
                'est-change-group-card__header est-change-group-card__header_new'
        });

        const newRows = this.changeNewProductRows;
        newRows.forEach((row, index) => {
            rows.push({
                ...row,
                rowContext: 'changeNew',
                canDelete: true,
                changeGroupBoundary: index === newRows.length - 1 ? 'end' : 'middle'
            });
        });
        if (newRows.length === 0) {
            const headerRow = rows[rows.length - 1];
            if (headerRow) {
                headerRow.changeGroupBoundary = 'end';
            }
        }

        return rows.map((row) => this.applyChangeGroupBoundaryClass(row));
    }

    applyChangeGroupBoundaryClass(row) {
        if (!row || row.isGroupHeader || !row.changeGroupBoundary) {
            return row;
        }
        const boundaryClass =
            row.changeGroupBoundary === 'start'
                ? 'est-change-group-boundary_start'
                : row.changeGroupBoundary === 'middle'
                  ? 'est-change-group-boundary_middle'
                  : row.changeGroupBoundary === 'end'
                    ? 'est-change-group-boundary_end'
                    : '';
        if (!boundaryClass) {
            return row;
        }
        const baseClass = row.tableRowClass || 'est-table-row';
        return {
            ...row,
            tableRowClass: `${baseClass} ${boundaryClass}`.trim()
        };
    }

    get headerDateError() {
        return validateHeaderDates(
            this.contractStartDate,
            this.contractEndDate
        );
    }

    get isHeaderDatesReady() {
        return isHeaderDatesReady(
            this.contractStartDate,
            this.contractEndDate
        );
    }

    get canEditProducts() {
        if (this.isRenewType) {
            return !this.renewLoadError && this.itemList.length > 0;
        }
        if (!this.isNewType) {
            return true;
        }
        return this.isHeaderDatesReady;
    }

    get showHeaderDatePrompt() {
        return (
            this.isNewType &&
            !this.isHeaderDatesReady &&
            !this.headerDateError
        );
    }

    get headerDatePromptMessage() {
        if (
            this.contractStartDate &&
            this.contractEndDate &&
            this.headerDateError
        ) {
            return this.headerDateError;
        }
        return '商品明細を入力する前に、期間開始日と期間終了日を入力してください。';
    }

    get productTableScrollClass() {
        let scrollClass = 'est-table-wrap';
        if (!this.canEditProducts) {
            scrollClass += ' est-table-wrap_disabled';
        }
        return scrollClass;
    }

    get isProductModalOpen() {
        return this.productModalRowId != null;
    }

    get isProductModalConfirmDisabled() {
        return !this.productModalProductId;
    }

    get showRemarksSection() {
        return (
            this.showProductTable &&
            this.isHeaderDatesReady &&
            this.itemList.length > 0
        );
    }

    get showTotalSummary() {
        return this.showRemarksSection;
    }

    get totalAmount() {
        return this.itemList.reduce(
            (sum, item) =>
                sum + (item.amount != null ? Number(item.amount) : 0),
            0
        );
    }

    get formattedTotalAmount() {
        return new Intl.NumberFormat('ja-JP', {
            style: 'currency',
            currency: 'JPY'
        }).format(this.totalAmount);
    }

    get totalLineCount() {
        return this.itemList.length;
    }

    get contractServiceRecordId() {
        if (this.isNewType || !this._wizardData) {
            return undefined;
        }
        return this._wizardData.contractServiceId || undefined;
    }

    @wire(getRecord, {
        recordId: '$contractServiceRecordId',
        fields: [CONTRACT_SERVICE_NAME]
    })
    wiredContractService({ data, error }) {
        if (data) {
            this.lookupContractServiceName =
                getFieldValue(data, CONTRACT_SERVICE_NAME) || '';
        } else if (error) {
            this.lookupContractServiceName = '';
        }
    }

    get contractServiceName() {
        if (!this._wizardData) {
            return '';
        }
        if (this.isNewType) {
            return this._wizardData.contractServiceName || '';
        }
        return this.lookupContractServiceName;
    }

    get displayNewHistoryVersion() {
        if (this.isNewType) {
            return '1';
        }
        const value =
            this._wizardData && this._wizardData.nextHistoryVersion != null
                ? this._wizardData.nextHistoryVersion
                : null;
        return this.formatVersionValue(value);
    }

    get displayBaseHistoryVersion() {
        const value =
            this._wizardData && this._wizardData.baseHistoryVersion != null
                ? this._wizardData.baseHistoryVersion
                : null;
        return this.formatVersionValue(value);
    }

    get baseHistoryName() {
        return (this._wizardData && this._wizardData.autoHistoryName) || '';
    }

    get showBaseHistoryContext() {
        return (
            !this.isNewType &&
            this.baseHistoryName &&
            this.displayBaseHistoryVersion &&
            this.displayNewHistoryVersion
        );
    }

    formatVersionValue(value) {
        if (value == null || value === '') {
            return '';
        }
        const numeric = Number(value);
        return Number.isFinite(numeric) ? String(numeric) : '';
    }

    initContractHistoryName() {
        const saved =
            (this._wizardData && this._wizardData.contractHistoryName) || '';
        if (saved.trim()) {
            this.contractHistoryName = saved;
            return;
        }

        const autoName =
            (this._wizardData && this._wizardData.autoHistoryName) || '';
        const type = this.effectiveSelectedType;

        if (type === 'Change' || type === 'Renew') {
            this.contractHistoryName = autoName || type;
        } else if (type === 'Cancel') {
            this.contractHistoryName = autoName
                ? `${autoName} Churn`
                : 'Cancel Churn';
        } else {
            this.contractHistoryName = saved;
        }
    }

    getDefaultDates() {
        return {
            startDate: this.contractStartDate || '',
            endDate: this.contractEndDate || ''
        };
    }

    addOneDay(isoDate) {
        return addDaysToIsoDate(isoDate, 1);
    }

    addOneYearEndDate(isoStartDate) {
        return addOneYearMinusOneDay(isoStartDate);
    }

    addOneMonthEndDate(isoStartDate) {
        return addMonthsMinusOneDay(isoStartDate, 1);
    }

    addYearsMinusOneDayEndDate(isoStartDate, years) {
        return addYearsMinusOneDay(isoStartDate, years);
    }

    addMonthsMinusOneDayEndDate(isoStartDate, months) {
        return addMonthsMinusOneDay(isoStartDate, months);
    }

    get showContractEndDateShortcuts() {
        return (
            !this.isEndDateReadonly &&
            !!(this.contractEndDate || this.contractStartDate)
        );
    }

    ensureCancelDates() {
        if (!this.isCancelType) {
            return;
        }
        const cancelDate =
            this.contractStartDate ||
            this.contractEndDate ||
            '';
        if (cancelDate) {
            this.contractStartDate = cancelDate;
            this.contractEndDate = cancelDate;
        }
    }

    ensureRenewEndDate() {
        if (
            this.isRenewType &&
            this.contractStartDate &&
            !this.contractEndDate
        ) {
            this.contractEndDate = this.addOneYearEndDate(
                this.contractStartDate
            );
        }
    }

    async initContractDates() {
        const savedStart =
            (this._wizardData && this._wizardData.contractStartDate) || '';
        const savedEnd = (this._wizardData && this._wizardData.endDate) || '';

        if (this.isNewType) {
            this.isStartDateReadonly = false;
            this.isEndDateReadonly = false;
            this.contractStartDate = savedStart;
            this.contractEndDate = savedEnd;
            this.notifyParent();
            return;
        }

        if (this.isRenewType) {
            this.isStartDateReadonly = true;
            this.isEndDateReadonly = false;

            if (savedStart && savedEnd) {
                this.contractStartDate = savedStart;
                this.contractEndDate = savedEnd;
                this.notifyParent();
                return;
            }

            await this.loadHistoryDates();

            if (savedStart) {
                this.contractStartDate = savedStart;
            }
            this.ensureRenewEndDate();
            this.notifyParent();
            return;
        }

        if (this.isCancelType) {
            this.isStartDateReadonly = true;
            this.isEndDateReadonly = true;

            if (savedStart && savedEnd) {
                this.contractStartDate = savedStart;
                this.contractEndDate = savedEnd;
                this.notifyParent();
                return;
            }

            await this.loadHistoryDates();
            this.ensureCancelDates();
            this.notifyParent();
            return;
        }

        if (this.isChangeType) {
            this.isStartDateReadonly = true;
            this.isEndDateReadonly = false;
        }

        if (savedStart || savedEnd) {
            this.contractStartDate = savedStart;
            this.contractEndDate = savedEnd;
            this.notifyParent();
            return;
        }

        await this.loadHistoryDates();
    }

    async loadHistoryDates() {
        const contractHistoryId =
            this._wizardData && this._wizardData.contractHistoryId;
        if (!contractHistoryId) {
            return;
        }

        this.isLoadingDates = true;
        try {
            const info = await getContractHistoryInfo({
                contractHistoryId
            });
            if (!info) {
                return;
            }

            if (this.isChangeType) {
                this.previousTermStartDate = info.termStartDate || '';
                this.previousTermEndDate = info.termEndDate || '';
                this.contractStartDate = info.termStartDate || '';
                this.contractEndDate = info.termEndDate || '';
            } else if (this.isCancelType) {
                this.previousTermEndDate = info.termEndDate || '';
                const cancelDate = this.addOneDay(info.termEndDate);
                this.fixedEffectiveDate = cancelDate;
                this.contractStartDate = cancelDate;
                this.contractEndDate = cancelDate;
            } else if (this.isRenewType) {
                this.previousTermEndDate = info.termEndDate || '';
                const startDate = this.addOneDay(info.termEndDate);
                this.fixedEffectiveDate = startDate;
                this.contractStartDate = startDate;
                this.contractEndDate = this.addOneYearEndDate(startDate);
            }
            this.syncFixedEffectiveDate();
            this.notifyParent();
        } catch (error) {
            const message =
                error.body && error.body.message
                    ? error.body.message
                    : '契約履歴の日付取得に失敗しました。';
            if (this.isRenewType) {
                this.renewLoadError = message;
            } else if (this.isCancelType) {
                this.cancelLoadError = message;
            } else {
                this.changeLoadError = message;
            }
        } finally {
            this.isLoadingDates = false;
        }
    }

    handleContractStartDateChange(event) {
        this.contractStartDate = normalizeDateInput(event.target.value);
        if (
            this.contractStartDate &&
            (this.isRenewType || this.isNewType) &&
            isValidIsoDate(this.contractStartDate)
        ) {
            this.contractEndDate = this.addOneYearEndDate(this.contractStartDate);
        }
        this.syncFixedEffectiveDate();
        this.ensureNewInitialRow();
        this.notifyParent();
    }

    handleContractEndDateChange(event) {
        this.contractEndDate = normalizeDateInput(event.target.value);
        this.ensureNewInitialRow();
        this.notifyParent();
    }

    handleEffectiveDateChange(event) {
        this.contractEffectiveDate = normalizeDateInput(event.target.value);
        this.notifyParent();
    }

    handleFillContractEndOneYear() {
        this.adjustContractEndDate({ years: 1 });
    }

    handleFillContractEndOneMonth() {
        this.adjustContractEndDate({ months: 1 });
    }

    handleFillContractEndMinusOneYear() {
        this.adjustContractEndDate({ years: -1 });
    }

    handleFillContractEndMinusOneMonth() {
        this.adjustContractEndDate({ months: -1 });
    }

    adjustContractEndDate({ years = 0, months = 0 }) {
        const base = this.contractEndDate || this.contractStartDate;
        if (!base) {
            return;
        }
        let next = base;
        if (years) {
            next = addYearsToIsoDate(next, years);
        }
        if (months) {
            next = addMonthsToIsoDate(next, months);
        }
        if (!next) {
            return;
        }
        this.contractEndDate = next;
        this.ensureNewInitialRow();
        this.notifyParent();
    }

    resolveLineStartAdjustBase(row) {
        return (
            row.startDate ||
            row.endDate ||
            this.contractStartDate ||
            this.contractEndDate ||
            ''
        );
    }

    resolveLineEndAdjustBase(row) {
        return (
            row.endDate ||
            row.startDate ||
            this.contractEndDate ||
            this.contractStartDate ||
            ''
        );
    }

    adjustLineStartDate(rowId, { years = 0, months = 0 }) {
        const row = this.itemList.find((item) => item.id === rowId);
        if (!row) {
            return;
        }
        const base = this.resolveLineStartAdjustBase(row);
        if (!base) {
            return;
        }
        let next = base;
        if (years) {
            next = addYearsToIsoDate(next, years);
        }
        if (months) {
            next = addMonthsToIsoDate(next, months);
        }
        if (!next) {
            return;
        }
        this.updateRow(rowId, { startDate: next });
    }

    adjustLineEndDate(rowId, { years = 0, months = 0 }) {
        const row = this.itemList.find((item) => item.id === rowId);
        if (!row) {
            return;
        }
        const base = this.resolveLineEndAdjustBase(row);
        if (!base) {
            return;
        }
        let next = base;
        if (years) {
            next = addYearsToIsoDate(next, years);
        }
        if (months) {
            next = addMonthsToIsoDate(next, months);
        }
        if (!next) {
            return;
        }
        this.updateRow(rowId, { endDate: next });
    }

    ensureNewInitialRow() {
        if (
            !this.isNewType ||
            !this.isHeaderDatesReady ||
            this.itemList.length > 0
        ) {
            return;
        }
        this.addRow(false);
    }

    initHistoryMetaDates() {
        const savedEffective =
            (this._wizardData && this._wizardData.contractEffectiveDate) || '';

        if (this._wizardData) {
            if (this._wizardData.previousTermStartDate) {
                this.previousTermStartDate = this._wizardData.previousTermStartDate;
            }
            if (this._wizardData.previousTermEndDate) {
                this.previousTermEndDate = this._wizardData.previousTermEndDate;
            }
        }

        if (savedEffective) {
            this.contractEffectiveDate = savedEffective;
        } else if (this.isChangeType) {
            this.contractEffectiveDate = this.contractStartDate || '';
        } else if (this.isRenewType || this.isCancelType) {
            this.contractEffectiveDate = this.contractStartDate || '';
        }

        this.syncFixedEffectiveDate();
        this.notifyParent();
    }

    syncFixedEffectiveDate() {
        if (this.isNewType) {
            this.contractEffectiveDate = this.contractStartDate || '';
            return;
        }
        if (this.contractEffectiveDate) {
            return;
        }
        if ((this.isRenewType || this.isCancelType) && this.fixedEffectiveDate) {
            this.contractEffectiveDate = this.fixedEffectiveDate;
        }
    }

    handleContractHistoryNameChange(event) {
        this.contractHistoryName = event.target.value;
        this.notifyParent();
    }

    buildWizardBootstrapKey() {
        const data = this._wizardData;
        if (!data) {
            return '';
        }
        const productCount = Array.isArray(data.selectedProducts)
            ? data.selectedProducts.length
            : 0;
        return [
            data.selectedType || '',
            data.contractServiceId || '',
            data.contractHistoryId || '',
            data.contractHistoryName || '',
            data.contractStartDate || '',
            data.endDate || '',
            data.contractEffectiveDate || '',
            data.estimateRemarkMasterId || '',
            data.estimateRemarks || '',
            productCount
        ].join('|');
    }

    async bootstrapFromWizardData() {
        const bootstrapKey = this.buildWizardBootstrapKey();
        if (!bootstrapKey || bootstrapKey === this._wizardBootstrapKey) {
            return;
        }
        this._wizardBootstrapKey = bootstrapKey;

        this._isBootstrapping = true;

        if (this._wizardData && this._wizardData.selectedType) {
            this._selectedType = this._wizardData.selectedType;
        }

        this.initContractHistoryName();

        await this.initContractDates();
        this.initHistoryMetaDates();

        if (this._wizardData) {
            this.applyRemarkPresetFromWizardData();
        }

        const type = this.effectiveSelectedType;
        if (this.hasPresetSelectedProducts()) {
            this.applyPresetSelectedProducts();
        } else if (type === 'Renew') {
            await this.loadRenewProducts();
        } else if (type === 'New') {
            if (this.isHeaderDatesReady) {
                this.addRow(false);
            }
        } else if (type === 'Change') {
            await this.loadChangeProducts();
        } else if (type === 'Cancel') {
            this.itemList = [];
            this.initCancelEligibility();
        }

        this._isBootstrapping = false;
        this.notifyParent();
    }

    connectedCallback() {
        this._isConnected = true;
        this.bootstrapFromWizardData();
    }

    hasPresetSelectedProducts() {
        return (
            this._wizardData &&
            Array.isArray(this._wizardData.selectedProducts) &&
            this._wizardData.selectedProducts.length > 0
        );
    }

    applyPresetSelectedProducts() {
        const defaultDates = this.getDefaultDates();
        const rows = this._wizardData.selectedProducts.map((item) => {
            this.rowCounter += 1;
            return this.applyAmount(
                this.normalizeRow({
                    ...item,
                    id: item.id || `row-${this.rowCounter}`,
                    isReadonly:
                        item.isReadonly === true ||
                        item.recordType === PRODUCT_TYPE_ORIGINAL ||
                        (item.recordType === PRODUCT_TYPE_REMAKE &&
                            item.isReadonly === true),
                    startDate: item.startDate || defaultDates.startDate,
                    endDate: item.endDate || defaultDates.endDate
                })
            );
        });
        this.itemList = this.decorateAllRows(rows);
    }

    initCancelEligibility() {
        if (!this.isCancelType) {
            return;
        }
        if (this._wizardData && this._wizardData.renewEligible === false) {
            this.cancelLoadError =
                '前回Versionの期間終了日と一致する継続課金商品がありません。Cancelできません。Newで作成してください。';
        }
    }

    async loadRenewProducts() {
        const contractServiceId =
            this._wizardData && this._wizardData.contractServiceId;
        if (!contractServiceId) {
            this.renewLoadError =
                '契約サービスが設定されていません。2/3 に戻って契約サービスを選択してください。';
            this.addRow(false);
            return;
        }

        this.isLoadingRenewProducts = true;
        this.renewLoadError = '';
        try {
            const products = await getRenewContractProducts({
                contractServiceId
            });
            this.itemList = this.buildRenewItemList(products || []);
            if (this.itemList.length === 0) {
                this.renewLoadError =
                    '前回Versionの期間終了日と一致する継続課金商品がありません。Renewできません。Newで作成してください。';
                this.itemList = [];
            } else {
                this.renewLoadError = '';
            }
            this.notifyParent();
        } catch (error) {
            this.renewLoadError =
                error.body && error.body.message
                    ? error.body.message
                    : '契約商品の取得に失敗しました。';
            this.itemList = [];
        } finally {
            this.isLoadingRenewProducts = false;
        }
    }

    buildRenewItemList(products) {
        const { startDate, endDate } = this.getDefaultDates();
        const items = [];
        products.forEach((product) => {
            const unitPrice = product.unitPrice != null ? product.unitPrice : 0;
            const quantity =
                product.quantity != null ? product.quantity : 1;
            this.rowCounter++;
            items.push(
                this.applyAmount({
                        id: `row-${this.rowCounter}`,
                        productId: product.productId,
                        productName: product.productName || '',
                        unitName: product.unitName || '',
                        unit:
                            product.unit ||
                            buildDisplayUnit(
                                product.unitName,
                                product.billingType || BILLING_TYPE_RECURRING,
                                product.billingCycle
                            ),
                        billingType:
                            product.billingType || BILLING_TYPE_RECURRING,
                        billingCycle:
                            product.billingType === BILLING_TYPE_RECURRING
                                ? MONTHLY_BILLING_CYCLE
                                : product.billingCycle || '',
                        unitPrice,
                        quantity,
                        startDate,
                        endDate,
                        invoiceType:
                            product.invoiceType || this.resolvedDefaultInvoiceType,
                        recordType: PRODUCT_TYPE_RENEW,
                        typeLabel: 'Renew',
                        isReadonly: false,
                        rowClass: ''
                    })
            );
        });
        return this.decorateAllRows(items);
    }

    async loadChangeProducts() {
        const contractHistoryId =
            this._wizardData && this._wizardData.contractHistoryId;
        if (!contractHistoryId) {
            this.changeLoadError =
                '契約履歴が設定されていません。2/3 に戻って契約サービスを選択してください。';
            return;
        }

        this.isLoadingChangeProducts = true;
        this.changeLoadError = '';
        try {
            const products = await getRecurringContractProducts({
                contractHistoryId
            });
            this.itemList = this.buildChangeItemList(products || []);
            if (this.itemList.length === 0) {
                this.changeLoadError =
                    '継続課金の契約商品がありません。';
            } else {
                this.notifyParent();
            }
        } catch (error) {
            this.changeLoadError =
                error.body && error.body.message
                    ? error.body.message
                    : '契約商品の取得に失敗しました。';
            this.itemList = [];
        } finally {
            this.isLoadingChangeProducts = false;
        }
    }

    buildChangeItemList(products) {
        const items = [];
        products.forEach((product, index) => {
            const pairId = `pair-${index + 1}`;
            const unitPrice = product.unitPrice != null ? product.unitPrice : 0;
            const positiveQuantity =
                product.quantity != null ? product.quantity : 1;
            const baseRow = {
                productId: product.productId,
                productName: product.productName || '',
                unitName: product.unitName || '',
                unit:
                    product.unit ||
                    buildDisplayUnit(
                        product.unitName,
                        product.billingType || BILLING_TYPE_RECURRING,
                        product.billingCycle
                    ),
                billingType: product.billingType || BILLING_TYPE_RECURRING,
                billingCycle:
                    product.billingType === BILLING_TYPE_RECURRING
                        ? MONTHLY_BILLING_CYCLE
                        : product.billingCycle || '',
                unitPrice,
                quantity: positiveQuantity,
                startDate: product.startDate || '',
                endDate: product.endDate || '',
                invoiceType: product.invoiceType || this.resolvedDefaultInvoiceType,
                sourceContractProductId: product.contractProductId,
                pairId
            };

            this.rowCounter++;
            items.push(
                this.applyAmount({
                        ...baseRow,
                        id: `row-${this.rowCounter}`,
                        recordType: PRODUCT_TYPE_ORIGINAL,
                        typeLabel: 'Original',
                        isReadonly: true,
                        rowClass: 'est-row-readonly'
                    })
            );

            this.rowCounter++;
            items.push(
                this.applyAmount({
                        ...baseRow,
                        id: `row-${this.rowCounter}`,
                        recordType: PRODUCT_TYPE_REMAKE,
                        typeLabel: 'Remake',
                        isReadonly: false,
                        isDuplicate: false,
                        rowClass: ''
                    })
            );
        });
        return this.decorateAllRows(items);
    }

    decorateRow(row, rowIndex = -1) {
        const rowClass = row.rowClass || '';
        const billingType = row.billingType || '';
        const invoiceType = this.resolveRowInvoiceType(
            row.invoiceType,
            billingType
        );
        const invoiceTypeOptions = this.buildInvoiceTypeOptions(
            invoiceType,
            billingType
        );
        const canCopyDatesFromAbove =
            !row.isReadonly && rowIndex > 0;
        const canDuplicate =
            !this.isChangeType &&
            !row.isReadonly &&
            (this.isNewType || this.isRenewType);
        const remakeCountForPair = this.isChangeType
            ? this.itemList.filter(
                  (item) =>
                      isChangeRemakeLine(item) &&
                      item.pairId === row.pairId
              ).length
            : 0;
        const canDelete =
            this.isNewType ||
            this.isRenewType ||
            (this.isChangeType &&
                isChangeRemakeLine(row) &&
                remakeCountForPair > 1) ||
            (this.isChangeType && isChangeContinuationLine(row));
        const typeBadge = resolveProductTypeBadge(row.recordType, row.typeLabel);
        const boundaryClass =
            row.changeGroupBoundary === 'start'
                ? 'est-change-group-boundary_start'
                : row.changeGroupBoundary === 'middle'
                  ? 'est-change-group-boundary_middle'
                  : row.changeGroupBoundary === 'end'
                    ? 'est-change-group-boundary_end'
                    : '';
        return {
            ...row,
            ...typeBadge,
            rowIndex,
            invoiceType,
            invoiceTypeOptions,
            isInvoiceTypeDisabled:
                !billingType || invoiceTypeOptions.length === 0,
            canCopyDatesFromAbove,
            gridRowClass: `est-line ${rowClass}`.trim(),
            tableRowClass: `est-table-row ${rowClass} ${boundaryClass}`.trim(),
            isEditable: !row.isReadonly,
            canDuplicate,
            canDelete,
            displayUnitName: resolveDisplayUnit(
                row.unit,
                row.unitName,
                billingType,
                row.billingCycle
            ),
            showPriceCycle: billingType === BILLING_TYPE_RECURRING,
            priceCycleLabel: `/${MONTHLY_BILLING_CYCLE}`,
            showPriceMeta:
                billingType === BILLING_TYPE_RECURRING ||
                !!resolveDisplayUnit(
                    row.unit,
                    row.unitName,
                    billingType,
                    MONTHLY_BILLING_CYCLE
                )
        };
    }

    decorateAllRows(items) {
        const decorated = items.map((item, index) => this.decorateRow(item, index));
        return this.applyLineNumbers(decorated);
    }

    applyLineNumbers(items) {
        let counter = 0;
        return items.map((item) => {
            if (isChangeOriginalLine(item)) {
                return {
                    ...item,
                    showLineNumber: false,
                    lineNumberLabel: ''
                };
            }
            counter += 1;
            return {
                ...item,
                showLineNumber: true,
                lineNumberLabel: String(counter)
            };
        });
    }

    handleAddRow() {
        if (!this.canEditProducts) {
            return;
        }
        this.addRow(true);
    }

    handleAddChangeRemake(event) {
        if (!this.canEditProducts) {
            return;
        }
        const pairId = event.currentTarget.dataset.pairId;
        const group = this.changeProductGroups.find((item) => item.pairId === pairId);
        if (!group || !group.original) {
            return;
        }
        const templateRow =
            group.remakeRows[group.remakeRows.length - 1] ||
            group.original;
        this.insertChangeRemakeRow(templateRow, group);
    }

    handleAddChangeNewProduct() {
        if (!this.canEditProducts) {
            return;
        }
        this.addChangeNewRow(true);
    }

    insertChangeRemakeRow(source, group) {
        const insertAfterIndex = this.findLastIndexByPairId(group.pairId);
        const duplicate = this.buildCopiedRow(source, {
            recordType: PRODUCT_TYPE_REMAKE,
            typeLabel: 'Remake',
            isDuplicate: false,
            sourceContractProductId: group.sourceContractProductId,
            pairId: group.pairId
        });
        const newList = [...this.itemList];
        newList.splice(insertAfterIndex + 1, 0, duplicate);
        this.itemList = this.decorateAllRows(newList);
        this.notifyParent();
    }

    findLastIndexByPairId(pairId) {
        let lastIndex = -1;
        this.itemList.forEach((item, index) => {
            if (item.pairId === pairId) {
                lastIndex = index;
            }
        });
        return lastIndex;
    }

    addChangeNewRow(notifyParent) {
        this.rowCounter++;
        const { startDate, endDate } = this.getDefaultDates();
        this.itemList = this.decorateAllRows([
            ...this.itemList,
            this.applyAmount({
                id: 'row-' + this.rowCounter,
                productId: '',
                productName: '',
                quantity: 1,
                unit: '',
                billingType: '',
                billingCycle: '',
                unitPrice: 0,
                amount: 0,
                startDate,
                endDate,
                recordType: PRODUCT_TYPE_NEW,
                typeLabel: 'New',
                invoiceType: '',
                sourceContractProductId: null,
                pairId: null,
                isReadonly: false,
                rowClass: ''
            })
        ]);
        if (notifyParent) {
            this.notifyParent();
        }
    }

    findPreviousEditableRow(rowIndex) {
        for (let index = rowIndex - 1; index >= 0; index--) {
            const row = this.itemList[index];
            if (!row.isReadonly) {
                return row;
            }
        }
        return null;
    }

    buildCopiedRow(source, options = {}) {
        this.rowCounter++;
        const recordType =
            options.recordType ??
            source.recordType ??
            PRODUCT_TYPE_NEW;
        const typeLabel =
            options.typeLabel ??
            (recordType === PRODUCT_TYPE_RENEW
                ? 'Renew'
                : recordType === PRODUCT_TYPE_REMAKE
                  ? 'Remake'
                  : recordType === PRODUCT_TYPE_ORIGINAL
                    ? 'Original'
                    : 'New');
        const copied = {
            ...source,
            id: `row-${this.rowCounter}`,
            recordType,
            typeLabel,
            isDuplicate: options.isDuplicate === true,
            isReadonly: false,
            rowClass: ''
        };
        if (Object.prototype.hasOwnProperty.call(options, 'sourceContractProductId')) {
            copied.sourceContractProductId = options.sourceContractProductId;
        }
        if (Object.prototype.hasOwnProperty.call(options, 'pairId')) {
            copied.pairId = options.pairId;
        }
        return this.applyAmount(copied);
    }

    insertCopiedRow(source, insertAfterIndex = null) {
        const copyOptions = {
            isDuplicate: false,
            recordType: PRODUCT_TYPE_NEW,
            typeLabel: 'New',
            sourceContractProductId: null,
            pairId: null
        };
        const duplicate = this.buildCopiedRow(source, copyOptions);
        const newList = [...this.itemList];
        const index =
            insertAfterIndex == null
                ? newList.length
                : insertAfterIndex + 1;
        newList.splice(index, 0, duplicate);
        this.itemList = this.decorateAllRows(newList);
        this.notifyParent();
    }

    addRow(notifyParent) {
        this.rowCounter++;
        const { startDate, endDate } = this.getDefaultDates();
        this.itemList = this.decorateAllRows([
            ...this.itemList,
            this.applyAmount({
                id: 'row-' + this.rowCounter,
                productId: '',
                productName: '',
                quantity: 1,
                unit: '',
                billingType: '',
                billingCycle: '',
                unitPrice: 0,
                amount: 0,
                startDate,
                endDate,
                recordType: PRODUCT_TYPE_NEW,
                typeLabel: 'New',
                invoiceType: '',
                isReadonly: false,
                rowClass: ''
            })
        ]);
        if (notifyParent) {
            this.notifyParent();
        }
    }

    normalizeRow(item) {
        const { startDate, endDate } = this.getDefaultDates();
        let recordType = item.recordType || PRODUCT_TYPE_NEW;
        let sourceContractProductId = item.sourceContractProductId;
        let pairId = item.pairId;

        if (this.isChangeType) {
            if (recordType === PRODUCT_TYPE_NEW) {
                sourceContractProductId = null;
                pairId = null;
            }
        }

        return {
            quantity: 1,
            unit: '',
            productName: '',
            billingType: '',
            billingCycle: '',
            amount: 0,
            unitPrice: 0,
            startDate,
            endDate,
            invoiceType: '',
            typeLabel:
                item.typeLabel ||
                (recordType === PRODUCT_TYPE_ORIGINAL
                    ? 'Original'
                    : recordType === PRODUCT_TYPE_REMAKE
                      ? 'Remake'
                      : recordType === PRODUCT_TYPE_RENEW
                        ? 'Renew'
                        : 'New'),
            isReadonly: item.isReadonly === true,
            rowClass: item.isReadonly ? 'est-row-readonly' : '',
            ...item,
            recordType,
            sourceContractProductId,
            pairId
        };
    }

    applyAmount(row) {
        const normalized = {
            ...row,
            quantity: Number(row.quantity) || 0,
            unitPrice: Number(row.unitPrice) || 0,
            billingCycle:
                row.billingType === BILLING_TYPE_RECURRING
                    ? MONTHLY_BILLING_CYCLE
                    : row.billingCycle
        };
        let amount = calculateLineAmount(normalized);
        const amountInvalid =
            amount == null &&
            normalized.billingType === BILLING_TYPE_RECURRING &&
            !!normalized.startDate &&
            !!normalized.endDate;

        if (isChangeOriginalLine(row) && amount != null) {
            amount = -Math.abs(amount);
        }
        return {
            ...normalized,
            amount,
            amountInvalid
        };
    }

    updateRow(rowId, updates) {
        if (!this.canEditProducts) {
            return;
        }
        const numericUpdates = { ...updates };
        if ('quantity' in numericUpdates) {
            numericUpdates.quantity = Number(numericUpdates.quantity) || 0;
        }
        if ('unitPrice' in numericUpdates) {
            numericUpdates.unitPrice = Number(numericUpdates.unitPrice) || 0;
        }

        this.itemList = this.decorateAllRows(
            this.itemList.map((item) => {
            if (item.id !== rowId) {
                return item;
            }
            if (item.isReadonly) {
                return item;
            }
            let updated = this.applyAmount({ ...item, ...numericUpdates });
            if (
                'startDate' in numericUpdates &&
                updated.startDate &&
                isValidIsoDate(updated.startDate) &&
                (!updated.endDate || !isValidIsoDate(updated.endDate))
            ) {
                updated = this.applyAmount({
                    ...updated,
                    endDate: this.addOneYearEndDate(updated.startDate)
                });
            }
            return updated;
            })
        );
        this.notifyParent();
    }

    handleDeleteRow(event) {
        if (!this.canEditProducts) {
            return;
        }
        const rowId = event.currentTarget.dataset.id;
        const target = this.itemList.find((item) => item.id === rowId);
        if (!target || !target.canDelete) {
            return;
        }
        this.itemList = this.decorateAllRows(
            this.itemList.filter((item) => item.id !== rowId)
        );
        this.notifyParent();
    }

    handleDuplicateRow(event) {
        const rowId = event.currentTarget.dataset.id;
        const sourceIndex = this.itemList.findIndex((item) => item.id === rowId);
        if (sourceIndex === -1) {
            return;
        }

        const source = this.itemList[sourceIndex];
        if (!source.canDuplicate) {
            return;
        }

        this.insertCopiedRow(source, sourceIndex);
    }

    handleLineDateInputChange(event) {
        const rowId = event.currentTarget.dataset.id;
        const field = event.currentTarget.dataset.field;
        const value = normalizeDateInput(event.target.value);
        if (field === 'startDate') {
            this.updateRow(rowId, { startDate: value });
            return;
        }
        if (field === 'endDate') {
            this.updateRow(rowId, { endDate: value });
        }
    }

    handleCopyDateFromAbove(event) {
        const rowId = event.currentTarget.dataset.id;
        const field = event.currentTarget.dataset.field;
        const rowIndex = this.itemList.findIndex((item) => item.id === rowId);
        if (rowIndex <= 0) {
            return;
        }
        const previous = this.findPreviousEditableRow(rowIndex);
        if (!previous) {
            return;
        }
        if (field === 'startDate') {
            this.updateRow(rowId, { startDate: previous.startDate || '' });
            return;
        }
        if (field === 'endDate') {
            this.updateRow(rowId, { endDate: previous.endDate || '' });
            return;
        }
        this.updateRow(rowId, {
            startDate: previous.startDate || '',
            endDate: previous.endDate || ''
        });
    }

    handleFillLineStartFromContract(event) {
        const rowId = event.currentTarget.dataset.id;
        this.updateRow(rowId, { startDate: this.contractStartDate || '' });
    }

    handleFillLineStartOneYear(event) {
        this.adjustLineStartDate(event.currentTarget.dataset.id, { years: 1 });
    }

    handleFillLineStartOneMonth(event) {
        this.adjustLineStartDate(event.currentTarget.dataset.id, { months: 1 });
    }

    handleFillLineStartMinusOneYear(event) {
        this.adjustLineStartDate(event.currentTarget.dataset.id, { years: -1 });
    }

    handleFillLineStartMinusOneMonth(event) {
        this.adjustLineStartDate(event.currentTarget.dataset.id, { months: -1 });
    }

    handleFillLineEndFromContract(event) {
        const rowId = event.currentTarget.dataset.id;
        this.updateRow(rowId, { endDate: this.contractEndDate || '' });
    }

    handleFillLineEndOneYear(event) {
        this.adjustLineEndDate(event.currentTarget.dataset.id, { years: 1 });
    }

    handleFillLineEndOneMonth(event) {
        this.adjustLineEndDate(event.currentTarget.dataset.id, { months: 1 });
    }

    handleFillLineEndMinusOneYear(event) {
        this.adjustLineEndDate(event.currentTarget.dataset.id, { years: -1 });
    }

    handleFillLineEndMinusOneMonth(event) {
        this.adjustLineEndDate(event.currentTarget.dataset.id, { months: -1 });
    }

    handleOpenProductModal(event) {
        const rowId = event.currentTarget.dataset.id;
        const row = this.itemList.find((item) => item.id === rowId);
        this.productModalRowId = rowId;
        this.productModalProductId = row ? row.productId || '' : '';
    }

    handleCloseProductModal() {
        this.productModalRowId = null;
        this.productModalProductId = '';
    }

    handleModalProductChange(event) {
        this.productModalProductId = event.detail.recordId || '';
    }

    async handleConfirmProductModal() {
        const rowId = this.productModalRowId;
        const selectedProductId = this.productModalProductId;
        if (!rowId || !selectedProductId) {
            return;
        }

        this.handleCloseProductModal();
        await this.applyProductSelection(rowId, selectedProductId);
    }

    async applyProductSelection(rowId, selectedProductId) {
        if (!selectedProductId) {
            this.updateRow(rowId, {
                productId: '',
                productName: '',
                unit: '',
                billingType: '',
                billingCycle: '',
                unitPrice: 0
            });
            return;
        }

        try {
            const defaults = await getProductDefaults({
                productId: selectedProductId
            });
            const billingType =
                defaults && defaults.billingType ? defaults.billingType : '';
            const invoiceType = this.resolveRowInvoiceType(
                defaults && defaults.invoiceType ? defaults.invoiceType : '',
                billingType
            );

            this.updateRow(rowId, {
                productId: selectedProductId,
                productName:
                    defaults && defaults.productName ? defaults.productName : '',
                unitName:
                    defaults && defaults.unitName ? defaults.unitName : '',
                unit:
                    defaults && defaults.displayUnit
                        ? defaults.displayUnit
                        : buildDisplayUnit(
                              defaults ? defaults.unitName : '',
                              billingType,
                              defaults ? defaults.billingCycle : ''
                          ),
                billingType,
                billingCycle:
                    billingType === BILLING_TYPE_RECURRING
                        ? MONTHLY_BILLING_CYCLE
                        : defaults && defaults.billingCycle
                          ? defaults.billingCycle
                          : '',
                unitPrice:
                    defaults && defaults.unitPrice != null
                        ? defaults.unitPrice
                        : 0,
                invoiceType
            });
        } catch (error) {
            this.updateRow(rowId, { productId: selectedProductId });
        }
    }

    handleQuantityChange(event) {
        const rowId = event.currentTarget.dataset.id;
        this.updateRow(rowId, { quantity: event.target.value });
    }

    handleUnitPriceChange(event) {
        const rowId = event.currentTarget.dataset.id;
        this.updateRow(rowId, { unitPrice: event.target.value });
    }

    handleInvoiceTypeChange(event) {
        const rowId = event.currentTarget.dataset.id;
        const value = event.target.value;
        const row = this.itemList.find((item) => item.id === rowId);
        if (!row) {
            return;
        }
        const validationError = validateInvoiceSettingForBillingType(
            row.billingType,
            value,
            this.invoiceSettingOptions
        );
        if (validationError) {
            event.target.value = row.invoiceType;
            return;
        }
        this.updateRow(rowId, {
            invoiceType: value
        });
    }

    applyRemarkPresetFromWizardData() {
        const masterId = this._wizardData.estimateRemarkMasterId || '';
        const remarks = this._wizardData.estimateRemarks || '';
        this.estimateRemarkMasterId = masterId;
        this.estimateRemarks = remarks;
        if (masterId || remarks) {
            this.remarkMasterPickerKey = `remark-master-${Date.now()}`;
        }
    }

    async handleRemarkMasterChange(event) {
        const masterId = event.detail.recordId || '';
        const previousMasterId = this.estimateRemarkMasterId || '';

        if (masterId === previousMasterId) {
            return;
        }

        if (!masterId) {
            if (this.hasEstimateRemarksText()) {
                const confirmed = window.confirm(
                    '見積備考マスタの選択を解除すると、見積備考の内容もクリアされます。よろしいですか？'
                );
                if (!confirmed) {
                    await this.revertRemarkMasterPicker(previousMasterId);
                    return;
                }
            }
            this.estimateRemarkMasterId = '';
            this.estimateRemarks = '';
            this.notifyParent();
            return;
        }

        let masterText = '';
        try {
            masterText =
                (await getEstimateRemarkMasterText({ masterId })) || '';
        } catch (error) {
            await this.revertRemarkMasterPicker(previousMasterId);
            this.showToast(
                '見積備考マスタの取得に失敗しました。',
                this.reduceErrorMessage(error),
                'error'
            );
            return;
        }

        if (this.hasEstimateRemarksText()) {
            const confirmed = window.confirm(
                '見積備考に入力済みの文章があります。選択した見積備考マスタの内容で上書きしますか？'
            );
            if (!confirmed) {
                await this.revertRemarkMasterPicker(previousMasterId);
                return;
            }
        }

        this.estimateRemarkMasterId = masterId;
        this.estimateRemarks = masterText;
        this.notifyParent();
    }

    hasEstimateRemarksText() {
        return String(this.estimateRemarks || '').trim().length > 0;
    }

    async revertRemarkMasterPicker(previousMasterId) {
        this.estimateRemarkMasterId = null;
        await Promise.resolve();
        this.estimateRemarkMasterId = previousMasterId || null;
        this.remarkMasterPickerKey = `remark-master-${Date.now()}`;
    }

    reduceErrorMessage(error) {
        if (error && error.body && error.body.message) {
            return error.body.message;
        }
        if (error && error.message) {
            return error.message;
        }
        return '不明なエラーが発生しました。';
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

    handleRemarksChange(event) {
        this.estimateRemarks = event.target.value;
        this.notifyParent();
    }

    notifyParent() {
        const detail = {
            contractStartDate: this.contractStartDate,
            endDate: this.contractEndDate,
            contractEffectiveDate: this.contractEffectiveDate,
            previousTermStartDate: this.previousTermStartDate,
            previousTermEndDate: this.previousTermEndDate,
            contractHistoryName: this.contractHistoryName,
            estimateRemarkMasterId: this.estimateRemarkMasterId || '',
            estimateRemarks: this.estimateRemarks || ''
        };

        if (!(this._isBootstrapping && this.itemList.length === 0)) {
            detail.selectedProducts = this.itemList.map((item) => ({ ...item }));
        }

        this.dispatchEvent(
            new CustomEvent('changefield', {
                bubbles: true,
                composed: true,
                detail
            })
        );
    }
}