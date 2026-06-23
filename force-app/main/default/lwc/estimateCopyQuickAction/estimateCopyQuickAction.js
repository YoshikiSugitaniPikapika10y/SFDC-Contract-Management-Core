import { LightningElement, api } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class EstimateCopyQuickAction extends NavigationMixin(
    LightningElement
) {
    @api recordId;

    @api
    invoke() {
        if (!this.recordId) {
            this.showError('契約履歴IDが取得できません。');
            return;
        }

        this[NavigationMixin.Navigate]({
            type: 'standard__navItemPage',
            attributes: {
                apiName: 'Estimate_Create'
            },
            state: {
                c__copyFromHistoryId: this.recordId
            }
        });
    }

    showError(message) {
        this.dispatchEvent(
            new ShowToastEvent({
                title: 'エラー',
                message,
                variant: 'error'
            })
        );
    }
}
