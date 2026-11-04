public with sharing class BuilderRankAverageDistanceResult {
    public BuilderRankAverageDistanceResult() {

    }

    @InvocableVariable(label='Builder Ouput' description='Builder Ouput' required=true)
    @AuraEnabled
    public BuilderRankAverageDistanceOutput output;

}