import { LightningElement, api } from 'lwc';

export default class Home extends LightningElement {
	@api title = 'Root to Health';
	@api ctaText = 'Explore Our Story';
	@api ctaUrl = '#';
	@api videoUrl = "/public/assets/videos/farming.mp4";

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