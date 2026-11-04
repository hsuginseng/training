import { LightningElement, api } from 'lwc';

export default class AboutMilestones extends LightningElement {
	static renderMode = 'light';

	@api title = 'Milestones';
	@api set content(data){
		this._content = data;
		try { this.milestones=JSON.parse(this._content); } catch(err){ console.error(err); }
	} 
	get content(){ return this._content; }

    @api milestones = [
        {
            id: '1',
            imageUrl: '/sfsites/c/cms/delivery/media/MCRYAARKQJ6ZGJJJKWW4HN4O7WQU',
			imageAlt: 'image alt',
			year: 'year',
			title: 'Milestone Event Title 1',
			text: 'Lorem ipsum dolor sit amet consectetur. Velit cursus id iaculis libero arcu in in elementum etiam.',
        },
        {
            id: '2',
            imageUrl: '/sfsites/c/cms/delivery/media/MCRYAARKQJ6ZGJJJKWW4HN4O7WQU',
			imageAlt: 'image alt',
			year: 'year',
			title: 'Milestone Event Title 2',
			text: 'Lorem ipsum dolor sit amet consectetur. Velit cursus id iaculis libero arcu in in elementum etiam.',
        },
        {
            id: '3',
            imageUrl: '/sfsites/c/cms/delivery/media/MCRYAARKQJ6ZGJJJKWW4HN4O7WQU',
			imageAlt: 'image alt',
			year: 'year',
			title: 'Milestone Event Title 3',
			text: 'Lorem ipsum dolor sit amet consectetur. Velit cursus id iaculis libero arcu in in elementum etiam.',
		},
        {
            id: '4',
            imageUrl: '/sfsites/c/cms/delivery/media/MCRYAARKQJ6ZGJJJKWW4HN4O7WQU',
			imageAlt: 'image alt',
			year: 'year',
			title: 'Milestone Event Title 4',
			text: 'Lorem ipsum dolor sit amet consectetur. Velit cursus id iaculis libero arcu in in elementum etiam.',
        },
        {
            id: '5',
            imageUrl: '/sfsites/c/cms/delivery/media/MCRYAARKQJ6ZGJJJKWW4HN4O7WQU',
			imageAlt: 'image alt',
			year: 'year',
			title: 'Milestone Event Title 5',
			text: 'Lorem ipsum dolor sit amet consectetur. Velit cursus id iaculis libero arcu in in elementum etiam.',
        },
        {
            id: '6',
            imageUrl: '/sfsites/c/cms/delivery/media/MCRYAARKQJ6ZGJJJKWW4HN4O7WQU',
			imageAlt: 'image alt',
			year: 'year',
			title: 'Milestone Event Title 6',
			text: 'Lorem ipsum dolor sit amet consectetur. Velit cursus id iaculis libero arcu in in elementum etiam.',
		},
    ];
}