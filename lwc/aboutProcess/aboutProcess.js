import { LightningElement, api } from 'lwc';

/**
 * @slot ProcessCardGrid
 */
export default class AboutProcess extends LightningElement {

	@api title = 'What We Do';
    @api processes = [
        {
            id: '1',
			title: 'Grow',
			text: 'Lorem ipsum dolor sit amet consectetur. Velit cursus id iaculis libero arcu in in elementum etiam.',
        },
        {
            id: '2',
			title: 'Harvest',
			text: 'Lorem ipsum dolor sit amet consectetur. Velit cursus id iaculis libero arcu in in elementum etiam.',
        },
        {
            id: '3',
			title: 'Grade',
			text: 'Lorem ipsum dolor sit amet consectetur. Velit cursus id iaculis libero arcu in in elementum etiam.',
		},
        {
            id: '4',
			title: 'Package',
			text: 'Lorem ipsum dolor sit amet consectetur. Velit cursus id iaculis libero arcu in in elementum etiam.',
		},
        {
            id: '5',
			title: 'Distribute',
			text: 'Lorem ipsum dolor sit amet consectetur. Velit cursus id iaculis libero arcu in in elementum etiam.',
		}
    ];
}