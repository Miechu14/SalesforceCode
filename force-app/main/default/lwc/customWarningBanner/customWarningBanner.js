import { LightningElement, api, wire } from 'lwc';
import getLabel from '@salesforce/apex/CustomWarningBannerController.getLabel';

export default class customWarningBanner extends LightningElement {
    @api labelApiName;

    labelText;
    error;
    //error handling for label loading
    @wire(getLabel, { labelApiName: '$labelApiName' })
    wiredLabel({ data, error }) {
        if (data) {
            this.labelText = data;
            this.error = undefined;
        } else if (error) {
            this.labelText = undefined;
            this.error = 'Label could not be loaded.';
            console.error('Error loading label', error);
        } else {
            this.labelText = undefined;
            this.error = undefined;
        }
    }
}