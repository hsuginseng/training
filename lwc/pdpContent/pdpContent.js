import { LightningElement, api } from 'lwc';

export default class PdpContent extends LightningElement {
    @api accordions = [
        {
            id: '1',
            toggle: 'Description',
			text: 'Open the bottle to smell and savor the earthy aroma of Pure Wisconsin American Ginseng direct from the Hsu’s Ginseng Farm. A terroir like none other. Hsu’s American Ginseng Capsules are a quick, convenient way to take American Ginseng daily. Capsules contain 100% Wisconsin American Ginseng Root Powder and can be taken conveniently at any time of day. No Caffeine, No Sugar, No Artificial Flavors, Gluten-Free, Vegan, non-GMO, and No Preservatives. Direct from the farm. Buying direct from the farm ensures high quality American Ginseng Capsules and a source you can trust in Hsu’s Ginseng because you know the farmer– unlike other ginseng capsules from 3rd party vendors. (1) Bottle Contains 100 American Ginseng Capsules. Cap is shrink-wrapped to ensure safety and freshness. * These statements have not been evaluated by the Food and Drug Administration. These products are not intended to diagnose, treat, cure or prevent any disease. ** American Ginseng is not classified as a drug. Please consult your physician if you have a potential or existing medical condition.'
        },
		{
            id: '2',
            toggle: 'Usage',
			text: 'For best absorption, take 2-4 capsules at least 40 minutes before consuming food.'
        }
	]
}