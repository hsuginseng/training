import { LightningElement, api } from 'lwc';
export default class BannerCarouselSlide extends LightningElement {
    @api id;
    @api title;
    @api desc;
    @api ctaText;
    @api ctaUrl;
	@api imageUrl;
	@api imageAlt;
}