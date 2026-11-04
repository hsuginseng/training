<?xml version="1.0" encoding="UTF-8"?>
<Workflow xmlns="http://soap.sforce.com/2006/04/metadata">
    <alerts>
        <fullName>ALEYS__Notifies_users_when_there_bug_report_is_ready_to_retest</fullName>
        <description>Notifies users when there bug report is ready to retest</description>
        <protected>false</protected>
        <recipients>
            <field>ALEYS__Submitted_By__c</field>
            <type>userLookup</type>
        </recipients>
        <senderType>CurrentUser</senderType>
        <template>ALEYS__Public_Email_Templates/ALEYS__Bug_Report_Email_Template</template>
    </alerts>
</Workflow>
