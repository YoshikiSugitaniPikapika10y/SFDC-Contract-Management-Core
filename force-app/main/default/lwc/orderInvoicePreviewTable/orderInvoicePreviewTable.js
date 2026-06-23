import { LightningElement, api } from 'lwc';

export default class OrderInvoicePreviewTable extends LightningElement {
    @api preview;

    get hasBlocks() {
        return this.dateBlocks.length > 0;
    }

    get dateBlocks() {
        return (this.preview?.blocks || []).map((block, index) => {
            const lines = (block.lines || []).map((line, lineIndex) => {
                const locked = line.locked === true;
                return {
                    key: line.id || `line-${index}-${lineIndex}`,
                    versionLabel: line.historyVersionLabel || '—',
                    productName: line.productName,
                    periodLabel: line.periodLabel,
                    paymentScheduledDate: line.paymentScheduledDate || '—',
                    amount: line.amount,
                    taxAmount: line.taxAmount,
                    amountClass: locked ? 'amount-locked' : 'amount-normal',
                    rowClass: this.buildRowClass(line)
                };
            });

            return {
                key: `block-${index}`,
                blockNumber: index + 1,
                invoiceDate: block.invoiceDate || '—',
                unlockedSubtotal: block.subtotal ?? 0,
                lockedSubtotal: block.lockedSubtotal ?? 0,
                unlockedTaxSubtotal: block.taxSubtotal ?? 0,
                lockedTaxSubtotal: block.taxLockedSubtotal ?? 0,
                lineCount: lines.length,
                lines
            };
        });
    }

    get unlockedSubtotal() {
        return this.preview?.unlockedTotal ?? 0;
    }

    get lockedSubtotal() {
        return this.preview?.lockedTotal ?? 0;
    }

    get unlockedTaxSubtotal() {
        return this.preview?.unlockedTaxTotal ?? 0;
    }

    get lockedTaxSubtotal() {
        return this.preview?.lockedTaxTotal ?? 0;
    }

    get unlockedCount() {
        return this.preview?.unlockedCount ?? 0;
    }

    get lockedCount() {
        return this.preview?.lockedCount ?? 0;
    }

    buildRowClass(line) {
        const classes = [];
        if (line.locked) {
            classes.push('row-locked');
        }
        if (line.isAdjustment) {
            classes.push('row-adjustment');
        }
        return classes.join(' ');
    }
}
