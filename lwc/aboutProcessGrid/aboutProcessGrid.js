import { LightningElement, api } from 'lwc';

/**
 * @slot ProcessCards
 */
export default class AboutProcessGrid extends LightningElement {
	@api processes;
}