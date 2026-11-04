import { LightningElement, api } from "lwc";
import { loadStyle, loadScript } from 'lightning/platformResourceLoader';
import swiperjs from '@salesforce/resourceUrl/swiper';

export default class HomeRecommendedCarousel extends LightningElement {
	static renderMode = 'light';

	@api products;
	currSlideIndex = 1;
	get maxSlideCount(){ return this.products.length || 1; }

	swiperLoaded = false;
	swiperInitialized = false;
	_swiper;

	renderedCallback() {
		if (!this.swiperLoaded) {
			return;
		}

		if (!this.swiperInitialized) {
			if (this.products?.length > 0) {
				this.initializeSwiper();
			}
			return;
		}

		// Inventory/OOS updates after init: loop mode clones slides — refresh so disabled state matches LWC.
		if (this._swiper && this.products?.length > 0) {
			this._swiper.update();
		}
	}

	async connectedCallback(){
		await Promise.all([
			loadStyle(this, swiperjs + '/swiper.css'), loadScript(this, swiperjs + '/swiper.js')
		]).then(() => { this.swiperLoaded = true; });
	}

	initializeSwiper() {
		const carousel = this.querySelector('.home-rec-carousel');
		const carouselSlides = this.querySelectorAll('.home-rec-carousel-slide');
		const carouselPrev = this.querySelector('.home-rec-carousel-prev');
		const carouselNext = this.querySelector('.home-rec-carousel-next');
		const carouselCurrentSlide = this.querySelector('.home-rec-carousel-current-slide');
		const carouselTotalSlides = this.querySelector('.home-rec-carousel-total-slides');

		this._swiper = new Swiper(carousel, {
			loop: true,
			observer: true,
			observeParents: true,
			slidesPerView: 1,
			spaceBetween: 10,
			breakpoints: {
				620: {
				  slidesPerView: 2.05,
				  spaceBetween: 30
				},
				900: {
				  slidesPerView: 3.05,
				  spaceBetween: 30
				}
			}
		});

		carouselPrev.addEventListener('click', (e) => {
			this._swiper.slidePrev(500, false);
			let newSlideNumber = this.currSlideIndex - 1;
			if(newSlideNumber < 1){ this.currSlideIndex = this.maxSlideCount; }
			else { this.currSlideIndex = newSlideNumber; }
		});
		carouselNext.addEventListener('click', (e) => {
			this._swiper.slideNext(500, false);
			let newSlideNumber = this.currSlideIndex + 1;
			if(newSlideNumber > this.maxSlideCount){ this.currSlideIndex = 1;}
			else { this.currSlideIndex = newSlideNumber; }
		});

		this.swiperInitialized = true;
	}
}