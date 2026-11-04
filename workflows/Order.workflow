<?xml version="1.0" encoding="UTF-8"?>
<Workflow xmlns="http://soap.sforce.com/2006/04/metadata">
    <alerts>
        <fullName>Order_Approved_Message</fullName>
        <description>Order Approved Message</description>
        <protected>false</protected>
        <recipients>
            <field>Sales_Representative__c</field>
            <type>userLookup</type>
        </recipients>
        <senderType>CurrentUser</senderType>
        <template>unfiled$public/Order_Approved_Message</template>
    </alerts>
    <alerts>
        <fullName>Order_Rejected_Message</fullName>
        <description>Order Rejected Message</description>
        <protected>false</protected>
        <recipients>
            <field>Sales_Representative__c</field>
            <type>userLookup</type>
        </recipients>
        <senderType>CurrentUser</senderType>
        <template>unfiled$public/Order_Rejected_Message</template>
    </alerts>
    <fieldUpdates>
        <fullName>Activate_Order</fullName>
        <field>Status</field>
        <literalValue>Activated</literalValue>
        <name>Activate Order</name>
        <notifyAssignee>false</notifyAssignee>
        <operation>Literal</operation>
        <protected>false</protected>
        <reevaluateOnChange>false</reevaluateOnChange>
    </fieldUpdates>
    <fieldUpdates>
        <fullName>Order_Approved</fullName>
        <field>Approved__c</field>
        <literalValue>1</literalValue>
        <name>Order Approved</name>
        <notifyAssignee>false</notifyAssignee>
        <operation>Literal</operation>
        <protected>false</protected>
        <reevaluateOnChange>false</reevaluateOnChange>
    </fieldUpdates>
    <fieldUpdates>
        <fullName>Order_Rejected</fullName>
        <field>Status</field>
        <literalValue>Rejected</literalValue>
        <name>Order Rejected</name>
        <notifyAssignee>false</notifyAssignee>
        <operation>Literal</operation>
        <protected>false</protected>
        <reevaluateOnChange>false</reevaluateOnChange>
    </fieldUpdates>
</Workflow>
