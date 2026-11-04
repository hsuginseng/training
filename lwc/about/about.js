import { LightningElement, api } from 'lwc';

export default class About extends LightningElement {
	@api title = 'Providing Traditional Herbal Remedies and Culinary Delicacies Since 1974';
	@api videoUrl = "/public/assets/videos/plowing.mp4";

	homejsInitialized = false;
	renderedCallback() {
		if (this.homejsInitialized) {
			return;
		}
		this.homejsInitialized = true;
		document.documentElement.style.boxSizing = 'border-box';
		document.body.style.margin = 0;
		document.body.style.padding = 0;
	}
}