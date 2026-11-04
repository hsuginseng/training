import { LightningElement, api } from 'lwc';

export default class bannerVideo extends LightningElement {
	@api title;
	@api ctaText;
	@api ctaUrl;
	@api videoUrl;

	_initialized = false;

	renderedCallback() {
		if (this._initialized) {
			return;
		}
		const video = this.template.querySelector('video');
		if (!video) {
			return;
		}
		this._initialized = true;

		// Safari only honors the `muted` DOM property, not the declarative
		// `muted` attribute on framework-rendered elements. Without this it
		// treats the video as having audio and blocks autoplay.
		video.muted = true;
		video.setAttribute('playsinline', '');

		const playPromise = video.play();
		if (playPromise !== undefined) {
			playPromise.catch(() => {
				// Autoplay was still rejected — surface the play control.
				this.template.querySelector('.pause').classList.remove('show');
				this.template.querySelector('.play').classList.add('show');
			});
		}
	}

	handlePause(e) {
		e.target.classList.remove('show');
		this.template.querySelector('.play').classList.add('show');
		this.template.querySelector('video').pause();
	}

	handlePlay(e) {
		e.target.classList.remove('show');
		this.template.querySelector('.pause').classList.add('show');
		this.template.querySelector('video').play();
	}
}