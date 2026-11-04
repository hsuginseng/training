import { LightningElement } from 'lwc';

/**
 * @slot banner-video
 * @slot banner-carousel
 * @slot about
 * @slot wellness
 * @slot tours
 * @slot difference
 * @slot featured-categories
 * @slot discover
 * @slot recommended-categories
 */

export default class d2cHomePageTemplate extends LightningElement {
    connectedCallback(){
		window.addEventListener('load', function(){
			let requestFullWidthPageEvent = new CustomEvent('fullwidthpagerequest', { bubbles: true, composed: true });
			document.dispatchEvent(requestFullWidthPageEvent);	
		});

		let requestFullWidthPageEvent = new CustomEvent('fullwidthpagerequest', { bubbles: true, composed: true });
		document.dispatchEvent(requestFullWidthPageEvent);
	}
}