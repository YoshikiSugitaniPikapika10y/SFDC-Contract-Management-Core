import { LightningElement, api } from 'lwc';

export default class EstimateWizardCustomFieldGrid extends LightningElement {
    @api fields = [];
    @api fieldTarget = '';

    handleFieldChange(event) {
        const fieldApi = event.currentTarget.dataset.field;
        const fieldDef = this.fields.find((field) => field.apiName === fieldApi);
        if (!fieldDef) {
            return;
        }

        let value;
        if (fieldDef.fieldType === 'BOOLEAN') {
            value = event.target.checked;
        } else {
            value = event.target.value;
        }

        this.dispatchEvent(
            new CustomEvent('customfieldchange', {
                bubbles: true,
                composed: true,
                detail: {
                    fieldTarget: this.fieldTarget,
                    fieldApi,
                    value
                }
            })
        );
    }
}
