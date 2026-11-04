import { LightningElement, api } from "lwc";

export default class pdpContentAccordion extends LightningElement {
	static renderMode = 'light';

	@api id;
	@api toggle;
	@api text;

	accordionInitialized = false;
	renderedCallback() {
        if (this.accordionInitialized) { return; }

        this.accordionInitialized = true;
		const accordionToggle = this.querySelector('.accordion-toggle');
		const accordionPanel = this.querySelector('.accordion-text');

		accordionToggle?.setAttribute('id', 'toggle-'+this.id);
		accordionToggle?.setAttribute('aria-controls', 'panel-'+this.id)
		accordionPanel?.setAttribute('id', 'panel-'+this.id);
		accordionPanel?.setAttribute('aria-labelledby', 'toggle-'+this.id);
    }
	
	handleToggle(e) {
		const expanded = e.target.getAttribute('aria-expanded');

		if (expanded === 'true') {
			e.target.setAttribute('aria-expanded', 'false');
		}
		else {
			e.target.setAttribute('aria-expanded', 'true');
		}
	}
}