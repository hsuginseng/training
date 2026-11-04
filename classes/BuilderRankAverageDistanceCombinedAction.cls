public with sharing class BuilderRankAverageDistanceCombinedAction {
    public BuilderRankAverageDistanceCombinedAction() {

    }

    @InvocableMethod(label='Generate Rank Average Distance Combined Input Representation' description='Generate Rank Average Distance Combined Input Representation' category='Order Management')
    public static List<BuilderRankAverageDistanceResult> generateRankAverageDistanceInput(List<BuilderRankAverageDistanceCombinedInput> inputs){

        
        Set<String> locationIdentifierSet = new Set<String>();

        for (BuilderRankAverageDistanceCombinedInput input : inputs) {
            for(ConnectApi.FindRoutesWithFewestSplitsWithInventoryOutputRepresentation result : input.findRoutesWithFewestSplitsUsingOCIOutput.results){
                for (ConnectApi.AvailableLocationOutputRepresentation targetLocation : result.targetLocations){
                    locationIdentifierSet.addAll(targetLocation.locations);
                }
            }            
        }

        List<Schema.Location> locations = [SELECT Id, ExternalReference, VisitorAddress.PostalCode, VisitorAddress.Country 
                                           FROM Location WHERE ExternalReference IN: locationIdentifierSet];

        Map<String, Schema.Location> locationMap = new Map<String, Schema.Location>();
        for (Schema.Location location : locations) {
            locationMap.put(location.ExternalReference, location);         
        }


        List<BuilderRankAverageDistanceResult> resultList = new List<BuilderRankAverageDistanceResult>();

        for (BuilderRankAverageDistanceCombinedInput input : inputs) {
            
            for(ConnectApi.FindRoutesWithFewestSplitsWithInventoryOutputRepresentation targetResult : input.findRoutesWithFewestSplitsUsingOCIOutput.results){
            
                BuilderRankAverageDistanceOutput output = new BuilderRankAverageDistanceOutput();
                List<ConnectApi.TargetLocationInputRepresentation> targetLocationsToRankList = new List<ConnectApi.TargetLocationInputRepresentation>();
                
    
                for (ConnectApi.AvailableLocationOutputRepresentation inputTargetLocation : targetResult.targetLocations){
                    List<ConnectApi.LocationInputRepresentation> locationsToRankList = new List<ConnectApi.LocationInputRepresentation>();
                    for(String location : inputTargetLocation.locations){
                        Schema.Location dbLocation = locationMap.get(location);
                        ConnectApi.LocationInputRepresentation locationToRank = new ConnectApi.LocationInputRepresentation();
                        locationToRank.locationIdentifier = dbLocation.ExternalReference;
                        locationToRank.postalCode = dbLocation.VisitorAddress.PostalCode;
                        locationToRank.countryCode = dbLocation.VisitorAddress.Country;
                        locationsToRankList.add(locationToRank);
                    }
                    ConnectApi.TargetLocationInputRepresentation targetLocationsToRank = new ConnectApi.TargetLocationInputRepresentation();
                    targetLocationsToRank.locations = locationsToRankList;
                    targetLocationsToRankList.add(targetLocationsToRank);
    
                }
                
                ConnectApi.RankAverageDistanceInputRepresentation rankAverageDistanceInput = new ConnectApi.RankAverageDistanceInputRepresentation();
                rankAverageDistanceInput.deliveryPostalCode = input.deliveryPostalCode;
                rankAverageDistanceInput.deliveryCountryCode = input.deliveryCountryCode;
                rankAverageDistanceInput.distanceUnit = input.distanceUnit;
                rankAverageDistanceInput.sortResult = input.sortResult;
                rankAverageDistanceInput.targetLocations = targetLocationsToRankList;
    
    
                output.rankAverageDistanceInput = rankAverageDistanceInput;
    
                BuilderRankAverageDistanceResult result = new BuilderRankAverageDistanceResult();
                result.output = output;
                resultList.add(result);
            }           
        }

        return resultList;

    }
}