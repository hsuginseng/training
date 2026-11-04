import { LightningElement, api } from 'lwc';

export default class AboutIntro extends LightningElement {
	@api imageUrl = '/public/assets/images/carousel-slide.jpg';
	@api youTubeEmbed = 'https://www.youtube.com/embed/2Cc0Tmr3QAA';
	@api youTubeTitle = 'YouTube Video Title';
	@api text = 'Family-owned and independently operated, the company is committed to maintaining its farms, production facilities and world headquarters in Wausau, Wisconsin, while expanding its international distribution network of branch offices around the globe as it transitions to the next generation of family leadership as a leader in the ginseng industry.';

	handleVideo(e) {
		this.template.querySelector('.video-image').classList.add('hide');
		this.template.querySelector('.video-btn').classList.add('hide');
		this.template.querySelector('iframe').classList.add('show');
	}
}