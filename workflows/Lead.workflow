<?xml version="1.0" encoding="UTF-8"?>
<Workflow xmlns="http://soap.sforce.com/2006/04/metadata">
    <alerts>
        <fullName>D2C_English_Contact_Us_Submission</fullName>
        <ccEmails>inquiry@hsuginseng.com</ccEmails>
        <description>D2C English Contact Us Submission</description>
        <protected>false</protected>
        <recipients>
            <recipient>Contact_Us_Submissions</recipient>
            <type>group</type>
        </recipients>
        <senderAddress>inquiry@hsuginseng.com</senderAddress>
        <senderType>OrgWideEmailAddress</senderType>
        <template>unfiled$public/D2C_English_Contact_Us</template>
    </alerts>
    <alerts>
        <fullName>D2C_English_Tour_Form_Submission</fullName>
        <ccEmails>englishtours@hsuginseng.com</ccEmails>
        <description>D2C English Tour Form Submission</description>
        <protected>false</protected>
        <recipients>
            <recipient>D2C_English_Tour_Form_Submissions</recipient>
            <type>group</type>
        </recipients>
        <senderAddress>englishtours@hsuginseng.com</senderAddress>
        <senderType>OrgWideEmailAddress</senderType>
        <template>unfiled$public/D2C_English_Tour_Submission</template>
    </alerts>
</Workflow>
