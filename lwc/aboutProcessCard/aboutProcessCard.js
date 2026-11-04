import { LightningElement, api } from 'lwc';

export default class AboutProcessCard extends LightningElement {
	@api id;
	@api imageId;
    @api title;
	@api text;

	@api
	get imageUrl() {
		if(this.imageId) {
			return "/sfsites/c/cms/delivery/media/" + this.imageId;
		}else {
			return "";
		}
	}

}