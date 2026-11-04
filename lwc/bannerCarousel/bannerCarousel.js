import { LightningElement, api } from 'lwc';
import { loadStyle, loadScript } from 'lightning/platformResourceLoader';
import swiperjs from '@salesforce/resourceUrl/swiper';

export default class bannerCarousel extends LightningElement {
	static renderMode = 'light';
	@api set content(data){
		this._content = data;
		try { this.slides=JSON.parse(this._content); } catch(err){ console.error(err); }
	} 
	get content(){ return this._content; }

	@api slides = [
		{
			id: '1',
			title: 'Banner Carousel Option',
			desc: 'Lorem ipsum dolor sit amet consectetur. Velit cursus id iaculis libero arcu in in elementum etiam. Diam vulputate a sed urna.',
			ctaText: 'Explore Our Story',
			ctaUrl: '#',
            imageUrl: '/sfsites/c/cms/delivery/media/MCRYAARKQJ6ZGJJJKWW4HN4O7WQU',
			imageAlt: 'image 1 alt text'
		},
		{
			id: '2',
			title: 'Root to Health 1',
			desc: 'Lorem ipsum dolor sit amet consectetur. Velit cursus id iaculis libero arcu in in elementum etiam. Diam vulputate a sed urna.',
			ctaText: 'Explore Our Story',
			ctaUrl: '#',
            imageUrl: '/public/assets/images/carousel-slide.jpg',
			imageAlt: 'image 2 alt text'
		},
		{
			id: '3',
			title: 'Root to Health 2',
			desc: 'Lorem ipsum dolor sit amet consectetur. Velit cursus id iaculis libero arcu in in elementum etiam. Diam vulputate a sed urna.',
			ctaText: 'Explore Our Story',
			ctaUrl: '#',
            imageUrl: '/public/assets/images/carousel-slide.jpg',
			imageAlt: 'image 3 alt text'
		}
	];

	swiperInitialized = false;

	renderedCallback() {
	  if (this.swiperInitialized) {
		return;
	  }
	  this.swiperInitialized = true;
	//   this.initializeSwiper();
	}

	async connectedCallback(){
		await Promise.all([
            loadStyle(this, swiperjs + '/swiper.css'),
            loadScript(this, swiperjs + '/swiper.js'),
        ]).then(() => {
			this.initializeSwiper();
		});
	}

	initializeSwiper() {
		const carousel = this.querySelector('.banner-carousel-swiper');
		const carouselPaginationBtn = this.querySelectorAll('.banner-carousel-pagination-btn');
		const swiper = new Swiper(carousel, {
			slidesPerView: 1,
		});

		carouselPaginationBtn.forEach((button, index) => {
			if (index === 0) {
				button.classList.add('current');
			}
			button.addEventListener('click', (e) => {
				carouselPaginationBtn.forEach((btn) => {
					btn.classList.remove('current');
				})
				e.target.classList.add('current');
				swiper.slideTo(index, 600);
			});
		});
	}
}