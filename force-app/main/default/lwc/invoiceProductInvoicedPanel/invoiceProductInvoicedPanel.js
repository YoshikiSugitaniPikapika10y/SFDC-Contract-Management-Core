import { LightningElement, api, wire } from 'lwc';
import { refreshApex } from '@salesforce/apex';
import { registerRefreshHandler, unregisterRefreshHandler } from 'lightning/refresh';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getInvoiceProducts from '@salesforce/apex/InvoiceProductInvoicedController.getInvoiceProducts';
import updateInvoicedFlag from '@salesforce/apex/InvoiceProductInvoicedController.updateInvoicedFlag';
import updateInvoicedFlagByInvoiceDateRange from '@salesforce/apex/InvoiceProductInvoicedController.updateInvoicedFlagByInvoiceDateRange';
import markAsExported from '@salesforce/apex/InvoiceProductExportController.markAsExported';
import markAsExportedByInvoiceDateRange from '@salesforce/apex/InvoiceProductExportController.markAsExportedByInvoiceDateRange';
import clearExportDate from '@salesforce/apex/InvoiceProductExportController.clearExportDate';
import HISTORY_STATUS_FIELD from '@salesforce/schema/ContractHistory__c.historystatus__c';

const COLUMNS = [
    { label: 'No', fieldName: 'rowNumber', type: 'number', initialWidth: 60 },
    { label: '請求商品名', fieldName: 'name', type: 'text' },
    { label: '請求日', fieldName: 'invoiceDate', type: 'date-local', initialWidth: 110 },
    { label: '開始日', fieldName: 'startDate', type: 'date-local', initialWidth: 110 },
    { label: '終了日', fieldName: 'endDate', type: 'date-local', initialWidth: 110 },
    {
        label: '金額',
        fieldName: 'amount',
        type: 'currency',
        typeAttributes: { currencyCode: 'JPY' },
        initialWidth: 110
    },
    { label: '請求設定', fieldName: 'invoiceType', type: 'text' },
    {
        label: '連携済',
        fieldName: 'exported',
        type: 'boolean',
        initialWidth: 80
    },
    {
        label: '連携日',
        fieldName: 'latestExportDate',
        type: 'date-local',
        initialWidth: 110
    },
    {
        label: '実際請求日',
        fieldName: 'actualInvoiceDate',
        type: 'date-local',
        initialWidth: 110
    },
    {
        label: 'ロック',
        fieldName: 'locked',
        type: 'boolean',
        initialWidth: 80
    }
];

export default class InvoiceProductInvoicedPanel extends LightningElement {
    @api recordId;

    columns = COLUMNS;
    invoiceDateFrom = '';
    invoiceDateTo = '';
    rowRangeFrom = '';
    rowRangeTo = '';
    exportDate = '';
    actualInvoiceDate = '';
    selectedRowIds = [];
    isLoading = false;

    wiredProductsResult;

    _refreshHandler;
    _previousHistoryStatus;

    connectedCallback() {
        this._refreshHandler = registerRefreshHandler(this, () =>
            this.refreshInvoiceProducts()
        );
    }

    disconnectedCallback() {
        if (this._refreshHandler) {
            unregisterRefreshHandler(this._refreshHandler);
        }
    }

    @wire(getRecord, { recordId: '$recordId', fields: [HISTORY_STATUS_FIELD] })
    wiredHistoryStatus({ data }) {
        if (!data) {
            return;
        }

        const status = getFieldValue(data, HISTORY_STATUS_FIELD) || '';
        if (
            this._previousHistoryStatus !== undefined &&
            status !== this._previousHistoryStatus
        ) {
            this.refreshInvoiceProducts();
        }
        this._previousHistoryStatus = status;
    }

    @wire(getInvoiceProducts, { contractHistoryId: '$recordId' })
    wiredProducts(result) {
        this.wiredProductsResult = result;
    }

    get rows() {
        return this.wiredProductsResult?.data || [];
    }

    get hasRows() {
        return this.rows.length > 0;
    }

    get isBusy() {
        return this.isLoading || this.wiredProductsResult?.loading;
    }

    get selectedCount() {
        return this.selectedRowIds.length;
    }

    handleInvoiceDateFromChange(event) {
        this.invoiceDateFrom = event.target.value;
    }

    handleInvoiceDateToChange(event) {
        this.invoiceDateTo = event.target.value;
    }

    handleExportDateChange(event) {
        this.exportDate = event.target.value;
    }

    handleActualInvoiceDateChange(event) {
        this.actualInvoiceDate = event.target.value;
    }

    handleRowRangeFromChange(event) {
        this.rowRangeFrom = event.target.value;
    }

    handleRowRangeToChange(event) {
        this.rowRangeTo = event.target.value;
    }

    handleRowSelection(event) {
        this.selectedRowIds = (event.detail.selectedRows || []).map((row) => row.id);
    }

    handleSelectByInvoiceDateRange() {
        const ids = this.filterRowsByInvoiceDateRange().map((row) => row.id);
        this.selectedRowIds = ids;
        this.syncDatatableSelection(ids);
    }

    handleSelectByRowRange() {
        const from = this.parsePositiveInteger(this.rowRangeFrom);
        const to = this.parsePositiveInteger(this.rowRangeTo);
        if (from == null || to == null) {
            this.showToast('入力エラー', '行番号の開始と終了を指定してください。', 'error');
            return;
        }
        if (from > to) {
            this.showToast('入力エラー', '行番号（開始）は行番号（終了）以下を指定してください。', 'error');
            return;
        }

        const ids = this.rows
            .filter((row) => row.rowNumber >= from && row.rowNumber <= to)
            .map((row) => row.id);
        if (!ids.length) {
            this.showToast('情報', '指定行番号に該当する請求商品がありません。', 'info');
            return;
        }
        this.selectedRowIds = ids;
        this.syncDatatableSelection(ids);
    }

    async handleMarkRangeInvoiced() {
        await this.applyRangeUpdate(true);
    }

    async handleMarkRangeUninvoiced() {
        await this.applyRangeUpdate(false);
    }

    async handleMarkSelectedInvoiced() {
        await this.applySelectedUpdate(true);
    }

    async handleMarkSelectedUninvoiced() {
        await this.applySelectedUpdate(false);
    }

    async handleMarkRangeExported() {
        await this.applyExportRangeUpdate();
    }

    async handleMarkSelectedExported() {
        await this.applyExportSelectedUpdate();
    }

    async handleClearSelectedExport() {
        if (!this.selectedRowIds.length) {
            this.showToast('情報', '連携解除する行を選択してください。', 'info');
            return;
        }

        this.isLoading = true;
        try {
            const updatedCount = await clearExportDate({
                contractHistoryId: this.recordId,
                invoiceProductIds: this.selectedRowIds
            });
            await this.refreshRows();
            this.showToast(
                '更新完了',
                `${updatedCount}件の連携済を解除しました。`,
                'success'
            );
        } catch (error) {
            this.showToast('更新エラー', this.resolveErrorMessage(error), 'error');
        } finally {
            this.isLoading = false;
        }
    }

    filterRowsByInvoiceDateRange() {
        if (!this.invoiceDateFrom && !this.invoiceDateTo) {
            return [];
        }
        return this.rows.filter((row) => {
            if (!row.invoiceDate) {
                return false;
            }
            if (this.invoiceDateFrom && row.invoiceDate < this.invoiceDateFrom) {
                return false;
            }
            if (this.invoiceDateTo && row.invoiceDate > this.invoiceDateTo) {
                return false;
            }
            return true;
        });
    }

    async applyRangeUpdate(invoiced) {
        if (!this.invoiceDateFrom && !this.invoiceDateTo) {
            this.showToast('入力エラー', '請求日の範囲を指定してください。', 'error');
            return;
        }

        this.isLoading = true;
        try {
            const updatedCount = await updateInvoicedFlagByInvoiceDateRange({
                contractHistoryId: this.recordId,
                invoiceDateFrom: this.invoiceDateFrom || null,
                invoiceDateTo: this.invoiceDateTo || null,
                invoiced,
                actualInvoiceDate: invoiced ? this.actualInvoiceDate || null : null
            });
            await this.refreshRows();
            this.showToast(
                '更新完了',
                `${updatedCount}件を${invoiced ? '請求済' : '未請求'}に更新しました。`,
                'success'
            );
        } catch (error) {
            this.showToast('更新エラー', this.resolveErrorMessage(error), 'error');
        } finally {
            this.isLoading = false;
        }
    }

    async applySelectedUpdate(invoiced) {
        if (!this.selectedRowIds.length) {
            this.showToast('情報', '更新対象の行を選択してください。', 'info');
            return;
        }

        this.isLoading = true;
        try {
            const updatedCount = await updateInvoicedFlag({
                contractHistoryId: this.recordId,
                invoiceProductIds: this.selectedRowIds,
                invoiced,
                actualInvoiceDate: invoiced ? this.actualInvoiceDate || null : null
            });
            await this.refreshRows();
            this.showToast(
                '更新完了',
                `${updatedCount}件を${invoiced ? '請求済' : '未請求'}に更新しました。`,
                'success'
            );
        } catch (error) {
            this.showToast('更新エラー', this.resolveErrorMessage(error), 'error');
        } finally {
            this.isLoading = false;
        }
    }

    async applyExportRangeUpdate() {
        if (!this.invoiceDateFrom && !this.invoiceDateTo) {
            this.showToast('入力エラー', '請求日の範囲を指定してください。', 'error');
            return;
        }

        this.isLoading = true;
        try {
            const result = await markAsExportedByInvoiceDateRange({
                contractHistoryId: this.recordId,
                invoiceDateFrom: this.invoiceDateFrom || null,
                invoiceDateTo: this.invoiceDateTo || null,
                exportDate: this.exportDate || null
            });
            await this.refreshRows();
            this.showToast(
                '連携完了',
                `${result.updatedCount}件を連携済（${result.exportDate}）に更新しました。`,
                'success'
            );
        } catch (error) {
            this.showToast('更新エラー', this.resolveErrorMessage(error), 'error');
        } finally {
            this.isLoading = false;
        }
    }

    async applyExportSelectedUpdate() {
        if (!this.selectedRowIds.length) {
            this.showToast('情報', '連携対象の行を選択してください。', 'info');
            return;
        }

        this.isLoading = true;
        try {
            const result = await markAsExported({
                contractHistoryId: this.recordId,
                invoiceProductIds: this.selectedRowIds,
                exportDate: this.exportDate || null
            });
            await this.refreshRows();
            this.showToast(
                '連携完了',
                `${result.updatedCount}件を連携済（${result.exportDate}）に更新しました。`,
                'success'
            );
        } catch (error) {
            this.showToast('更新エラー', this.resolveErrorMessage(error), 'error');
        } finally {
            this.isLoading = false;
        }
    }

    async refreshInvoiceProducts() {
        if (!this.wiredProductsResult) {
            return false;
        }
        await refreshApex(this.wiredProductsResult);
        this.selectedRowIds = [];
        this.syncDatatableSelection([]);
        return true;
    }

    async refreshRows() {
        await this.refreshInvoiceProducts();
    }

    syncDatatableSelection(selectedIds) {
        const datatable = this.template.querySelector('lightning-datatable');
        if (!datatable) {
            return;
        }
        datatable.selectedRows = selectedIds;
    }

    parsePositiveInteger(value) {
        if (value === '' || value == null) {
            return null;
        }
        const parsed = Number.parseInt(String(value), 10);
        if (Number.isNaN(parsed) || parsed <= 0) {
            return null;
        }
        return parsed;
    }

    resolveErrorMessage(error) {
        if (error?.body?.message) {
            return error.body.message;
        }
        if (error?.message) {
            return error.message;
        }
        return '請求商品の更新に失敗しました。';
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
