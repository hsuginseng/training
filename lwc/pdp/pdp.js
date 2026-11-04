import { LightningElement } from 'lwc';

export default class Pdp extends LightningElement {

	pdpInitialized = false;
	renderedCallback() {
        if (this.pdpInitialized) {
            return;
        }
        this.pdpInitialized = true;
		document.documentElement.style.boxSizing = 'border-box';
        document.body.style.margin = 0;
        document.body.style.padding = 0;
    }
}