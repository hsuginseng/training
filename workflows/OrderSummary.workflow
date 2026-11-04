<?xml version="1.0" encoding="UTF-8"?>
<Workflow xmlns="http://soap.sforce.com/2006/04/metadata">
    <alerts>
        <fullName>Order_Summary_Confirmation</fullName>
        <description>Order Summary Confirmation</description>
        <protected>false</protected>
        <recipients>
            <field>BillingEmailAddress</field>
            <type>email</type>
        </recipients>
        <senderAddress>support@hsuginseng.com</senderAddress>
        <senderType>OrgWideEmailAddress</senderType>
        <template>unfiled$public/Order_Summary_Confirmation_Email_Simple_1772550875234</template>
    </alerts>
    <alerts>
        <fullName>Order_Summary_Confirmation_MSimplified</fullName>
        <description>Order Summary Confirmation (MSimplified)</description>
        <protected>false</protected>
        <recipients>
            <field>BillingEmailAddress</field>
            <type>email</type>
        </recipients>
        <senderType>DefaultWorkflowUser</senderType>
        <template>unfiled$public/Order_Summary_Confirmation_Email_MSimplified_1776956935077</template>
    </alerts>
    <alerts>
        <fullName>Order_Summary_Confirmation_MTraditional</fullName>
        <description>Order Summary Confirmation (MTraditional)</description>
        <protected>false</protected>
        <recipients>
            <field>BillingEmailAddress</field>
            <type>email</type>
        </recipients>
        <senderType>CurrentUser</senderType>
        <template>unfiled$public/Order_Summary_Confirmation_Email_MTraditional_1776956962051</template>
    </alerts>
</Workflow>
