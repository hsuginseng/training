import { LightningElement, api } from 'lwc';
import fetchPreferredLanguage from '@salesforce/apex/UserUtility.fetchPreferredLanguage';
import { NavigationMixin } from "lightning/navigation";
import SITE_ID from "@salesforce/site/Id";

export default class D2cRefreshPreferredLanguageCookie extends NavigationMixin(LightningElement) {
    @api userId;
    @api currentPage='CoreSite';
    siteId = SITE_ID;
    siteUrl = window.location.host;
    preferredLanguage;

    connectedCallback() {
        if(this.currentPage=='CoreSite'){
            let preferredLanguageSet = sessionStorage.getItem('preferred-language-set');
            if(preferredLanguageSet == 'true'){ return; }

            fetchPreferredLanguage().then(result => {
                console.log('Preferred Language Result', result);
                this.preferredLanguage = result;
                console.log('Preferred Language Set', this.preferredLanguage);
            }).catch(error => {
                console.error('fetchPreferredLanguage Error: ' + error);
            }).finally(() => {
                console.log('Setting Preferred Language Cookie to', this.preferredLanguage);
                this.setPreferredLanguageCookie();
            });
        } else if(this.currentPage=='Login'){
            sessionStorage.setItem('preferred-language-set', false);
        }
    }

    setPreferredLanguageCookie() {
        var expirationDate = new Date();
        expirationDate.setHours(expirationDate.getHours() + 12);
        
        let currentPage = window.location.href;
        console.log('Origin page', currentPage);
        let redirectPage;

        if(this.preferredLanguage){ sessionStorage.setItem('preferred-language-set', true); }

        if(this.preferredLanguage == 'en-US' && (currentPage.includes('zh-CN') || currentPage.includes('zh-TW'))){    
            if(currentPage.includes('zh-CN')){
                if(currentPage.includes('.com/english')){ redirectPage = currentPage.replace('/english/zh-CN/', '/english/'); }
                else { redirectPage = currentPage.replace('.com/zh-CN/', '.com/'); }
            } else if(currentPage.includes('zh-TW')){
                if(currentPage.includes('.com/english')){ redirectPage = currentPage.replace('/english/zh-TW/', '/english/'); }
                else { redirectPage = currentPage.replace('.com/zh-TW/', '.com/'); }
            }
        } else if(this.preferredLanguage == 'zh-CN'){
            if(!currentPage.includes('zh-CN')){
                if(currentPage.includes('.com/english')){ redirectPage = currentPage.replace('/english/', '/english/zh-CN/').replace('/zh-TW/', '/'); }
                else { redirectPage = currentPage.replace('.com/', '.com/zh-CN/').replace('/zh-TW/', '/'); }
            }
        } else if(this.preferredLanguage == 'zh-TW'){
            if(!currentPage.includes('zh-TW')){
                if(currentPage.includes('.com/english')){ redirectPage = currentPage.replace('/english/', '/english/zh-TW/').replace('/zh-CN/', '/'); }
                else { redirectPage = currentPage.replace('.com/', '.com/zh-TW/').replace('/zh-CN/', '/'); }
            }
        }

        console.log('Calculated redirect page', redirectPage);

        if(redirectPage){
            this[NavigationMixin.GenerateUrl](
                { type: 'standard__webPage', attributes: { url: redirectPage } }
            ).then(generatedUrl => {
                console.log('Generated page url', generatedUrl);
                const generatedPage = new URL(generatedUrl);
                const generatedPageParams = new URLSearchParams(generatedPage.search);
                generatedPageParams.set('redirect', 'false');
                generatedPage.search = generatedPageParams.toString();
                let finalUrl = generatedPage.href;
    
                redirectForLocale({
                    defaultLocale: this.preferredLanguage,
                    activeLanguages: ["en-US", "zh-CN", "zh-TW"],
                    cookieKey: 'PreferredLanguage'+this.siteId,
                    basePath: '/', //generatedPage.pathname+generatedPage.search,
                    useCombinedLanguageSearch: true,
                    userAgentsToSkipRedirect: ["Prerender (+https://github.com/prerender/prerender)"]
                });
                window.location.href = finalUrl;
            });
    
        }
    }
}