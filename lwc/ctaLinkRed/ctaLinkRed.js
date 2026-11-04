import { LightningElement, api } from 'lwc';
export default class ctaLinkRed extends LightningElement {
	@api ctaText;
	@api ctaUrl;
}