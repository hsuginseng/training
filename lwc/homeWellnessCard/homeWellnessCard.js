import { LightningElement, api } from 'lwc';
export default class HomeWellnessCard extends LightningElement {
    @api id;
    @api imageUrl;
	@api imageAlt;
    @api ctaUrl;
    @api ctaText;
}