import { LightningElement, api } from 'lwc';
export default class HomeCategoriesCard extends LightningElement {
    @api id;
    @api imageUrl;
	@api imageAlt;
    @api ctaUrl;
    @api ctaText;
}