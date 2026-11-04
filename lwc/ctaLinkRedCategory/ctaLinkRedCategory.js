import { LightningElement, api } from 'lwc';

export default class ctaLinkRedCategory extends LightningElement {
	@api ctaText;
	@api ctaUrl;
}