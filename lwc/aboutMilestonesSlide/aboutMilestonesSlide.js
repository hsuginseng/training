import { LightningElement, api } from "lwc";

export default class AboutMilestonesSlide extends LightningElement {
	@api imageUrl;
	@api imageAlt;
	@api year;
	@api title;
	@api text;
}