import { LightningElement, api } from 'lwc';

export default class BannerSplit extends LightningElement {
	@api title;
	@api text;
	@api imageAlt;
	@api imageUrl;
}