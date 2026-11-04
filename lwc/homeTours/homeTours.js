import { LightningElement, api } from 'lwc';

export default class HomeTours extends LightningElement {
	@api title = 'Tour Headline Lorem Ipsum Dolor';
	@api ctaUrl = '#';
    @api ctaText = 'Book a Tour';
	@api imageUrl = '/public/assets/images/farm.jpg';

}