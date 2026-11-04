@isTest
public class BuilderRankAverageDistanceCombActionTest {
    static final String DELIVERY_POSTAL_CODE = '33333';
    static final String DELIVERY_COUNTRY_CODE = 'US';
    static final String DISTANCE_UNIT = 'mi';
    static final String SORT_RESULT = 'asc';

    @isTest static void test_RankAverageDistanceCombinedAction_success() {

        // Arrange
        TestDataGenerator.seedLocationData();
        Test.startTest();
        List<BuilderRankAverageDistanceCombinedInput> inputs = createDistanceActionInputs();

        System.assertNotEquals(null, inputs, 'Rank Average Distance inputs list should not be null');
        
        // Act
        List<BuilderRankAverageDistanceResult> results = BuilderRankAverageDistanceCombinedAction.generateRankAverageDistanceInput(inputs);
        Test.stopTest();
        
        // Assert
        System.assertNotEquals(null, results, 'Rank Average Distance results list should not be null');
        System.assertEquals(inputs.size(), results.size(), 'Number of results should match number of inputs');
        for(BuilderRankAverageDistanceResult result : results){
            System.assertNotEquals(null, result.output, 'Rank Average Distance Output object should not be null');
            
            System.assertEquals(2, result.output.rankAverageDistanceInput.targetLocations.size(), 'Two target locations should be returned');
            System.assertEquals(DELIVERY_POSTAL_CODE, result.output.rankAverageDistanceInput.deliveryPostalCode, 'Delivery Postal Code does not match');
            System.assertEquals(DELIVERY_COUNTRY_CODE, result.output.rankAverageDistanceInput.deliveryCountryCode, 'Delivery Country Code does not match');
            System.assertEquals(DISTANCE_UNIT, result.output.rankAverageDistanceInput.distanceUnit, 'Distance Unit does not match');
            System.assertEquals(SORT_RESULT, result.output.rankAverageDistanceInput.sortResult, 'Sort Result does not match');
        }

    }

    private static List<BuilderRankAverageDistanceCombinedInput> createDistanceActionInputs(){
        List<BuilderRankAverageDistanceCombinedInput> inputs = new List<BuilderRankAverageDistanceCombinedInput>();


        // Create valid Routes to fulfill the order:
        // FindRoutesWithFewestSplitsWithInventoryOutputRepresentation.targetLocations
        List<ConnectApi.AvailableLocationOutputRepresentation> locationToRoute = 
            new List<ConnectApi.AvailableLocationOutputRepresentation>();
        ConnectApi.AvailableLocationOutputRepresentation route1 = new ConnectApi.AvailableLocationOutputRepresentation();
        route1.locations = new List<String>{'Loc-1', 'Loc-2'};
        ConnectApi.AvailableLocationOutputRepresentation route2 = new ConnectApi.AvailableLocationOutputRepresentation();
        route2.locations = new List<String>{'Loc-1', 'Loc-3'};   
        locationToRoute.add(route1);
        locationToRoute.add(route2);

        ConnectApi.FindRoutesWithFewestSplitsWithInventoryOutputRepresentation result = 
            new ConnectApi.FindRoutesWithFewestSplitsWithInventoryOutputRepresentation();
        result.targetLocations = locationToRoute;

        ConnectApi.FindRoutesWithFewestSplitsUsingOCIOutputRepresentation findRoutesWithFewestSplitsUsingOCIOutput = 
            new ConnectApi.FindRoutesWithFewestSplitsUsingOCIOutputRepresentation();

        findRoutesWithFewestSplitsUsingOCIOutput.results = new List<ConnectApi.FindRoutesWithFewestSplitsWithInventoryOutputRepresentation>();  
        findRoutesWithFewestSplitsUsingOCIOutput.results.add(result);

        
        BuilderRankAverageDistanceCombinedInput distanceInput = new BuilderRankAverageDistanceCombinedInput();
		distanceInput.findRoutesWithFewestSplitsUsingOCIOutput = findRoutesWithFewestSplitsUsingOCIOutput;
        distanceInput.deliveryPostalCode = DELIVERY_POSTAL_CODE;
        distanceInput.deliveryCountryCode = DELIVERY_COUNTRY_CODE;
        distanceInput.distanceUnit = DISTANCE_UNIT;
        distanceInput.sortResult = SORT_RESULT;
            
        inputs.add(distanceInput);
        
        return inputs;
    }
}