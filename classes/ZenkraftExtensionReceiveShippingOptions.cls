global class ZenkraftExtensionReceiveShippingOptions implements sfdc_checkout.CartShippingCharges {

    global sfdc_checkout.IntegrationStatus startCartProcessAsync(sfdc_checkout.IntegrationInfo jobInfo, Id cartId) {
        System.debug(LoggingLevel.DEBUG, 'ZenkraftExtensionReceiveShippingOptions.startCartProcessAsync cartId' + cartId);
        System.debug(LoggingLevel.DEBUG, 'jobInfo.siteLanguage:' + jobInfo.siteLanguage);
        System.debug(LoggingLevel.DEBUG, 'Current User:' + UserInfo.getUserId());
        System.debug(LoggingLevel.DEBUG, 'User Language:' + UserInfo.getLanguage());

        //a true value of this boolean indicates a new fresh product cart delivery group created/cart items arranged between cart delivery groups
        Boolean isNewCDGCreated = false;
        try{
            isNewCDGCreated = D2cCheckoutCustomShippingLogicController.createOrderDeliveryGroup(cartId);
        }catch (Exception e) {
            CartValidationOutput error = new CartValidationOutput(
                BackgroundOperationId = jobInfo.jobId,
                CartId = cartId,
                Level = 'Error',
                Message = 'Fresh ginseng cannot be shipped to your location.',
                Name = (String) cartId + ':' + jobInfo.jobId,
                RelatedEntityId = cartId,
                Type = 'Shipping'
            );
            insert (error);

            sfdc_checkout.IntegrationStatus failedStatus = new sfdc_checkout.IntegrationStatus();
            failedStatus.status = sfdc_checkout.IntegrationStatus.Status.FAILED;
            return failedStatus;
        }

        if(isNewCDGCreated) {
            CartValidationOutput error = new CartValidationOutput(
                BackgroundOperationId = jobInfo.jobId,
                CartId = cartId,
                Level = 'Error',
                Message = 'Shipment must be split. Please refresh the page.',
                Name = 'splitShipmentCreated' + (String) cartId + ':' + jobInfo.jobId,
                RelatedEntityId = cartId,
                Type = 'Shipping'
            );
            insert (error);

            //return fail status so CDG can commit to database
            sfdc_checkout.IntegrationStatus failedStatus = new sfdc_checkout.IntegrationStatus();
            failedStatus.status = sfdc_checkout.IntegrationStatus.Status.FAILED;
            return failedStatus;
            // returnZenkraftExtensionReceiveShippingOptions.startCartProcessAsync(jobInfo, cartId);
            // return status;
        }else {
            //following same logic as zenkraft's split shipment integration class
            zklb2b.MCB2BReceiveShippingOptions zkApexClass = new zklb2b.MCB2BReceiveShippingOptions();
            sfdc_checkout.IntegrationStatus zkIntegrationStatus = zkApexClass.startCartProcessAsync(jobInfo, cartId);

            List<CartDeliveryGroup> cdgList = [SELECT Id, Total_Shipping_Weight_LBs__c FROM CartDeliveryGroup WHERE CartId =: cartId];

            //final check to ensure all Cart Delivery Groups have cart items. Delete any CDG without cart items. Furthermore, delete cart if all CDGs are empty.
            if(cdgList.size() > 1) {
                List<CartDeliveryGroup> cdgsToDelete = new List<CartDeliveryGroup>();
                for(CartDeliveryGroup cdg: cdgList) {
                    if(cdg.Total_Shipping_Weight_LBs__c == 0)
                        cdgsToDelete.add(cdg);
                }
                if(cdgsToDelete.size() > 0) {
                    if(cdgList.size() == cdgsToDelete.size()) {
                        WebCart cart = [SELECT Id FROM WebCart WHERE Id =: cartId];
                        delete cart;
                    }else {
                        delete cdgsToDelete;
                    }
                }
            }            
            return zkIntegrationStatus;
        }


        //ORIGINAL  zklb2b
        // zklb2b.MCB2CReceiveShippingOptions zkApexClass = new zklb2b.MCB2CReceiveShippingOptions();

        // //following same logic as zenkraft's split shipment integration class
        // zklb2b.MCB2BReceiveShippingOptions zkApexClass = new zklb2b.MCB2BReceiveShippingOptions();
        // sfdc_checkout.IntegrationStatus zkIntegrationStatus = zkApexClass.startCartProcessAsync(jobInfo, cartId);

        // return zkIntegrationStatus;
        // }

        // check result
        // if (zkIntegrationStatus.status == sfdc_checkout.IntegrationStatus.Status.SUCCESS) {
        //     // replace result (if needed)
        //     if (serviceTypeMap.containsKey(jobInfo.siteLanguage)) {
        //         List<CartDeliveryGroupMethod> cartDeliveryGroupMethods = [SELECT Id, Name FROM CartDeliveryGroupMethod WHERE WebCartId =:cartId];
        //         List<CartDeliveryGroupMethod> updateCardDeliveryGroupMethods = new List<CartDeliveryGroupMethod>();
        //         if (cartDeliveryGroupMethods != null) {
        //             for (CartDeliveryGroupMethod cartDeliveryGroupMethod: cartDeliveryGroupMethods) {
        //                 System.debug(LoggingLevel.DEBUG, 'cartDeliveryGroupMethod:' + cartDeliveryGroupMethod);
        //                 Map<String, String> translateServiceTypeMap = serviceTypeMap.get(jobInfo.siteLanguage);
        //                 for (String oldValue: translateServiceTypeMap.keySet()) {
        //                     String newValue = translateServiceTypeMap.get(oldValue);
        //                     if (cartDeliveryGroupMethod.Name.contains(oldValue)) {
        //                         cartDeliveryGroupMethod.Name = cartDeliveryGroupMethod.Name.replaceAll(oldValue, newValue);
        //                         updateCardDeliveryGroupMethods.add(cartDeliveryGroupMethod);
        //                     }
        //                 }
        //             }
        //             if (!cartDeliveryGroupMethods.isEmpty()) {
        //                 update updateCardDeliveryGroupMethods;
        //             }
        //         }
        //     }
        // }
    }

    // Chinese - Simplified (zh_CN) and Chinese - Traditional (zh_TW)
    static final Map<String, Map<String, String>> serviceTypeMap = new Map<String, Map<String, String>> {
        'zh_CN' => new Map<String, String> { // Chinese - Simplified
            'UPS Ground -' => 'UPS Ground -',
            'UPS Second Day Air -' => 'UPS Second Day Air -',
            'UPS Standard -' => 'UPS Standard -',
            'UPS Worldwide Express Plus -' => 'UPS Worldwide Express Plus -',
            'USPS Ground Advantage -' => 'USPS Ground Advantage -',
            'USPS Priority Express -' => 'USPS Priority Express -',
            'USPS Priority Mail International -' => 'USPS Priority Mail International -',
            'USPS Express Mail International -' => 'USPS Express Mail International -'
        },
        'zh_TW' => new Map<String, String> { // Chinese - Traditional
            'UPS Ground -' => 'UPS Ground -',
            'UPS Second Day Air -' => 'UPS Second Day Air -',
            'UPS Standard -' => 'UPS Standard -',
            'UPS Worldwide Express Plus -' => 'UPS Worldwide Express Plus -',
            'USPS Ground Advantage -' => 'USPS Ground Advantage -',
            'USPS Priority Express -' => 'USPS Priority Express -',
            'USPS Priority Mail International -' => 'USPS Priority Mail International -',
            'USPS Express Mail International -' => 'USPS Express Mail International -'
        }
        
        /*
        'zh_CN' => new Map<String, String> { // Chinese - Simplified
            'UPS Ground -' => 'UPS 地面运输 -',
            'UPS Second Day Air -' => 'UPS 第二日航空服务 -',
            'UPS Standard -' => 'UPS 标准服务 -',
            'UPS Worldwide Express Plus -' => 'UPS 全球特快加急 -',
            'USPS Ground Advantage -' => '美国邮政地面优势服务 -',
            'USPS Priority Express -' => '美国邮政优先快递 -',
            'USPS Priority Mail International -' => '美国邮政优先国际邮件 -',
            'USPS Express Mail International -' => '美国邮政国际快递邮件 -'
        },
        'zh_TW' => new Map<String, String> { // Chinese - Traditional
            'UPS Ground -' => 'UPS 地面運輸 -',
            'UPS Second Day Air -' => 'UPS 第二日航空服務 -',
            'UPS Standard -' => 'UPS 標準服務 -',
            'UPS Worldwide Express Plus -' => 'UPS 全球特快加急 -',
            'USPS Ground Advantage -' => '美國郵政地面優勢服務 -',
            'USPS Priority Express -' => '美國郵政優先快遞 -',
            'USPS Priority Mail International -' => '美國郵政優先國際郵件 -',
            'USPS Express Mail International -' => '美國郵政國際快遞郵件 -'
        }

		*/
    };
}