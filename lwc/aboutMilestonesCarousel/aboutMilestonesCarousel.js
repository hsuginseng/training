import { LightningElement, api } from "lwc";
import { loadStyle, loadScript } from 'lightning/platformResourceLoader';
import swiperjs from '@salesforce/resourceUrl/swiper';

export default class AboutMilestonesCarousel extends LightningElement {
	static renderMode = 'light';

	@api milestones;

	swiperLoaded = false;
	swiperInitialized = false;

	renderedCallback() {
		if (!this.swiperLoaded) {
		  return;
		}
  
		if(this.swiperLoaded){
		  if(!this.swiperInitialized){
			  this.initializeSwiper();
		  } else {
			  return;
		  }
		}
	  }
  
	  async connectedCallback(){
		  await Promise.all([
			  loadStyle(this, swiperjs + '/swiper.css'),
			  loadScript(this, swiperjs + '/swiper.js'),
		  ]).then(() => {
			  this.swiperLoaded = true;
		  });
	  }

	
	initializeSwiper() {
		const carousel = this.querySelector('.about-milestones-carousel');
		const carouselSlides = this.querySelectorAll('.about-milestones-carousel-slide');
		const carouselPrev = this.querySelector('.about-milestones-carousel-prev');
		const carouselNext = this.querySelector('.about-milestones-carousel-next');
		const carouselCurrentSlide = this.querySelector('.about-milestones-carousel-current-slide');
		const carouselTotalSlides = this.querySelector('.about-milestones-carousel-total-slides');

		const swiper = new Swiper(carousel, {
			loop: true,
			slidesPerView: 1,
			spaceBetween: 10,
			breakpoints: {
				620: {
				  slidesPerView: 2.05,
				  spaceBetween: 30
				},
				768: {
				  slidesPerView: 3.05,
				  spaceBetween: 30
				},
				1200: {
				  slidesPerView: 4.05,
				  spaceBetween: 30
				}
			}
		});

		carouselCurrentSlide.innerHTML = 1;
		carouselTotalSlides.innerHTML = carouselSlides.length/2;

		carouselPrev.addEventListener('click', (e) => {
			swiper.slidePrev(500, false);
		});

		carouselNext.addEventListener('click', (e) => {
			swiper.slideNext(500, false);
		});

		swiper.on('activeIndexChange', function () {
			carouselCurrentSlide.innerHTML = swiper.realIndex + 1;
		});
	}
}