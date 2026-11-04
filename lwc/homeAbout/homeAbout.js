import { LightningElement, api } from 'lwc';
export default class HomeAbout extends LightningElement {
	@api title = 'From Farm to Table';
	@api desc = 'Lorem ipsum dolor sit amet consectetur. Velit cursus id iaculis libero arcu in in elementum etiam. Diam vulputate a sed urna.'
	@api ctaText = 'About Us';
	@api ctaUrl = '#';
	@api imageUrl = '/sfsites/c/cms/delivery/media/MCAZLW23ZOBNFOLGMBJWKWFHBOPU';
}