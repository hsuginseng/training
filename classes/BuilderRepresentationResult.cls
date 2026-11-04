public with sharing class BuilderRepresentationResult {
    public BuilderRepresentationResult() {

    }

    @InvocableVariable(label='Builder Representation Output' description='Builder Representation Output' required=true)
    @AuraEnabled
    public BuilderRepresentationOutput builderOutput;
    
}