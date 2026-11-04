import { LightningElement, api } from 'lwc';

export default class PdpBannerGallery extends LightningElement {
    
    images = [];
    displayedImage;
    _previousDisplayedImage;

    @api
    get mediaGroups(){ return this._mediaGroups}
    set mediaGroups(data){ 
        this._mediaGroups = data; 
        if(data) {
            this.displayedImage = this.mediaGroups[0].mediaItems[0].url;
            
            /* this.mediaGroups[0] ==> List Image */
            /* this.mediaGroups[1] ==> Detail Images */
            let tempImages = [];
            tempImages.push({id: 0, url: this.mediaGroups[0].mediaItems[0].url, selected: true });
            for(let i = 0; i < this.mediaGroups[1].mediaItems.length; i++) {
                let currentMediaItem = this.mediaGroups[1].mediaItems[i];
                if((currentMediaItem.url) != this.displayedImage){ tempImages.push({ id: i+1, url: currentMediaItem.url, selected: false }); }
            }

            this.images = tempImages;
        }
    }
    _mediaGroups;

    /* TODO: Handle Selection Logic for Aria */
    handleImageClick(event) {
        let buttonElement = event.currentTarget;
        let buttonDataset = buttonElement.dataset;

        this.displayedImage = buttonDataset.url;
        this._previousDisplayedImage = buttonDataset.url;
    }

    handleImageMouseEnter(event) {
        let buttonElement = event.currentTarget;
        let buttonDataset = buttonElement.dataset;

        this._previousDisplayedImage = this.displayedImage;
        this.displayedImage = buttonDataset.url;
    }

    handleImageMouseLeave(event) {
        this.displayedImage = this._previousDisplayedImage;
    }
}