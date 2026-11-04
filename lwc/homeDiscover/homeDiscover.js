import { LightningElement, api } from 'lwc';

export default class HomeDiscover extends LightningElement {
	@api title;
	@api imageUrl;
	@api set content(data){
		this._content = data;
		try { this.accordions=JSON.parse(this._content); } catch(err){ console.error(err); }
	} 
	get content(){ return this._content; }

    @api accordions = [
        {
            id: '1',
			toggle: 'Accordion 1',
			text: 'Lorem ipsum dolor sit amet consectetur.',
			ctaText: 'Learn More',
			ctaUrl: 'https://google.com/',
        },
        {
            id: '2',
			toggle: 'Accordion 2',
			text: 'Lorem ipsum dolor sit amet consectetur. Velit cursus id iaculis libero arcu in in elementum etiam.',
			ctaText: 'Learn More',
			ctaUrl: 'https://google.com/',
        },
        {
            id: '3',
			toggle: 'Accordion 3',
			text: 'Lorem ipsum dolor sit amet consectetur. ',
			ctaText: 'Learn More',
			ctaUrl: 'https://google.com/',
		}
    ];
}