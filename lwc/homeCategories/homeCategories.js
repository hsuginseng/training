import { LightningElement, api } from 'lwc';

export default class HomeCategories extends LightningElement {
	@api title = 'Explore Featured Categories';
    @api set content(data){
		this._content = data;
		try { this.categories=JSON.parse(this._content); } catch(err){ console.error(err); }
	} 
	get content(){ return this._content; }

    @api categories = [
        {
            id: '1',
            imageUrl: '/sfsites/c/cms/delivery/media/MCMGFUKQJLJBAZXH26NUC5JJ4DZE',
			imageAlt: 'image alt',
			ctaText: 'Shop American Ginseng',
			ctaUrl: '#',
        },
        {
            id: '2',
            imageUrl: '/sfsites/c/cms/delivery/media/MCX22XL5SDLRG6LJTESFSG4IOMBI',
			imageAlt: 'image alt',
			ctaText: 'Shop Bird’s Nest',
			ctaUrl: '#',
        },
        {
            id: '3',
            imageUrl: '/sfsites/c/cms/delivery/media/MC4ZZ6ERA5JNGINNM7BNSXGHHVME',
			imageAlt: 'image alt',
			ctaText: 'Shop Reishi',
			ctaUrl: '#',
		}
    ];
}