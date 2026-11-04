import { LightningElement, api } from 'lwc';

export default class HomeWellness extends LightningElement {
	@api title;
	@api set content(data){
		this._content = data;
		try { this.products=JSON.parse(this._content); } catch(err){ console.error(err); }
	} 
	get content(){ return this._content; }
    @api products = [
        {
           "id":"1",
           "imageUrl":"/sfsites/c/cms/delivery/media/MCMGFUKQJLJBAZXH26NUC5JJ4DZE",
           "imageAlt":"image alt",
           "ctaText":"Shop American Ginseng",
           "ctaUrl":"https://google.com/"
        },
        {
           "id":"2",
           "imageUrl":"/sfsites/c/cms/delivery/media/MCX22XL5SDLRG6LJTESFSG4IOMBI",
           "imageAlt":"image alt",
           "ctaText":"Shop Bird’s Nest",
           "ctaUrl":"https://google.com/"
        },
        {
           "id":"3",
           "imageUrl":"/sfsites/c/cms/delivery/media/MC4ZZ6ERA5JNGINNM7BNSXGHHVME",
           "imageAlt":"image alt",
           "ctaText":"Shop Reishi",
           "ctaUrl":"https://google.com/"
        },
        {
           "id":"4",
           "imageUrl":"/sfsites/c/cms/delivery/media/MCYKUQCPZJ65DYNFPMG5Z4ZUXTEY",
           "imageAlt":"image alt",
           "ctaText":"[Placeholder]",
           "ctaUrl":"https://google.com/"
        }
    ];
}