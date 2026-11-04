public with sharing class BuilderRankAverageDistanceInput {
    public BuilderRankAverageDistanceInput() {

    }

    @AuraEnabled
    @InvocableVariable(label='Find Routes With Fewest Splits Output Representation' description='Find Routes With Fewest Splits Output Representation' required=true)
    public ConnectApi.FindRoutesWithFewestSplitsOutputRepresentation findRoutesWithFewestSplitsOutput;

    @AuraEnabled
    @InvocableVariable(label='Delivery Postal Code' description='Delivery Postal Code' required=true)
    public String deliveryPostalCode;

    @AuraEnabled
    @InvocableVariable(label='Delivery Country Code' description='Delivery Country Code' required=true)
    public String deliveryCountryCode;

    @AuraEnabled
    @InvocableVariable(label='Distance Unit' description='Distance Unit' required=true)
    public String distanceUnit;

    @AuraEnabled
    @InvocableVariable(label='Sort Result' description='Sort Result' required=true)
    public String sortResult;


}