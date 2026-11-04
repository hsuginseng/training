import { LightningElement, api } from 'lwc';
export default class HomeDifferenceCard extends LightningElement {
    @api id;
    @api imageUrl;
	@api imageAlt;
	@api title;
	@api desc;
    @api ctaUrl;
    @api ctaText;
}