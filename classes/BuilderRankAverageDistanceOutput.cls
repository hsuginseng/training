public with sharing class BuilderRankAverageDistanceOutput {
    public BuilderRankAverageDistanceOutput() {

    }

    @InvocableVariable(label='Output of Generate Rank Average Distance Input' description='The output of Generate Rank Average Distance Input method' required=true)
    @AuraEnabled
    public ConnectApi.RankAverageDistanceInputRepresentation rankAverageDistanceInput;
}