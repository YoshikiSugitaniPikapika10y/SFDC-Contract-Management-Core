import { LightningElement, api } from 'lwc';
import { VALIDATION_ALERT_TITLES } from 'c/estimateValidationAlertUtils';

export default class EstimateValidationAlert extends LightningElement {
    @api title = VALIDATION_ALERT_TITLES.wizard;
    @api messages = [];
    @api compact = false;

    get alertClass() {
        let css = 'est-alert est-alert_error';
        if (this.compact) {
            css += ' est-alert_compact';
        }
        return css;
    }
}
