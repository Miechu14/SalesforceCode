/**
 * Service class to capture a daily snapshot of Salesforce storage usage
 * and global limits, storing the data in StorageUsageData__c.
 */
public with sharing class StorageUsageSnapshotHelper {

    // ====== Config ======
    private static final String SNAPSHOT_DATE_FIELD = 'Snapshot_Date__c';
    private static final Integer DECIMALS_MB = 2;
    private static final Integer DECIMALS_PCT = 2;

    // Map: sObject API Name -> field mappings on StorageUsageData__c
    @TestVisible
    private Map<String, ObjectMapping> USAGE_MAP = new Map<String, ObjectMapping>{
        'EmailMessage'                   => new ObjectMapping('Email_Messages_Record_Count__c',                  'Email_Messages_Data_Storage__c'),
        'FrameworkProductDiscount__c'    => new ObjectMapping('Framework_Product_Discounts_Record_Count__c',     'Framework_Product_Discounts_Data_Storage__c'),
        'EmailMessageArchive__c'         => new ObjectMapping('Email_Messages_Archive_Record_Count__c',          'Email_Messages_Archive_Data_Storage__c'),
        'AccountAggregates__c'           => new ObjectMapping('Account_Aggregates_Record_Count__c',              'Account_Aggregates_Data_Storage__c'),
        'Task'                           => new ObjectMapping('Tasks_Record_Count__c',                            'Tasks_Data_Storage__c'),
        'Deleted_Email_Attachment__c'    => new ObjectMapping('Deleted_Email_Attachments_Record_Count__c',       'Deleted_Email_Attachments_Data_Storage__c'),
        'Case'                           => new ObjectMapping('Cases_Record_Count__c',                            'Cases_Data_Storage__c'),
        'Event'                          => new ObjectMapping('Events_Record_Count__c',                           'Events_Data_Storage__c'),
        'Account'                        => new ObjectMapping('Accounts_Record_Count__c',                         'Accounts_Data_Storage__c'),
        'Contact'                        => new ObjectMapping('Contacts_Record_Count__c',                         'Contacts_Data_Storage__c'),
        'recordval__rv2JobResult__c'     => new ObjectMapping('Verify_Job_Results_Record_Count__c',              'Verify_Job_Results_Data_Storage__c'),
        'Basket__c'                      => new ObjectMapping('Baskets_Record_Count__c',                          'Baskets_Data_Storage__c'),
        'Opportunity'                    => new ObjectMapping('Opportunities_Record_Count__c',                    'Opportunities_Data_Storage__c'),
        'ProductTranslation__c'          => new ObjectMapping('Product_Translations_Record_Count__c',             'Product_Translations_Data_Storage__c'),
        'CaseRelatedInvoice__c'          => new ObjectMapping('Case_Related_Invoices_Record_Count__c',           'Case_Related_Invoices_Data_Storage__c'),
        'InterfaceLog__c'                => new ObjectMapping('Interface_Logs_Record_Count__c',                   'Interface_Logs_Data_Storage__c'),
        'Lead'                           => new ObjectMapping('Leads_Record_Count__c',                            'Leads_Data_Storage__c'),
        'LiveChatTranscript'             => new ObjectMapping('Chat_Transcript_Events_Record_Count__c',           'Chat_Transcript_Events_Data_Storage__c'),
        'copado__Deployment_History__c'  => new ObjectMapping('Copado_Deployment_History_Record_Count__c',       'Copado_Deployment_History_Data_Storage__c'),
        'FrameworkAgreementAccount__c'   => new ObjectMapping('FA_Accounts_Record_Count__c', 				     'FA_Accounts_Data_Storage__c'),
        'Project__c'                     => new ObjectMapping('Projects_Record_Count__c',                         'Projects_Data_Storage__c'),
        'CampaignMember'                 => new ObjectMapping('Campaign_Members_Record_Count__c',                'Campaign_Members_Data_Storage__c'),
        'SurveyInvitation'               => new ObjectMapping('Survey_Invitations_Record_Count__c',              'Survey_Invitations_Data_Storage__c'),
        'SurveySubject'                  => new ObjectMapping('Survey_Subjects_Record_Count__c',                 'Survey_Subjects_Data_Storage__c'),
        'ProjectAssignment__c'           => new ObjectMapping('Project_Assignments_Record_Count__c',             'Project_Assignments_Data_Storage__c'),
        'maps__Analytic__c'              => new ObjectMapping('Maps_Analytics_Record_Count__c',                  'Maps_Analytics_Data_Storage__c'),
        'FrameworkAgreement__c'          => new ObjectMapping('Framework_Agreements_Record_Count__c',            'Framework_Agreements_Data_Storage__c'),
        'spr_sf__SocialPost__c'          => new ObjectMapping('Sprinklr_Social_Posts_Record_Count__c',           'Sprinklr_Social_Posts_Data_Storage__c')
    };
 
    // ====== Entry point ======
    public void run() {
        StorageUsageData__c snapshot = new StorageUsageData__c();
        snapshot.put(SNAPSHOT_DATE_FIELD, Date.today());
        populateObjectUsage(snapshot);
        populateGlobalLimits(snapshot);
        insert snapshot;
    }
  
    //=== Object usage ======
    private void populateObjectUsage(StorageUsageData__c snapshot) {
        Map<String, Schema.SObjectType> gd = Schema.getGlobalDescribe();
        for (String objectApiName : USAGE_MAP.keySet()) {
            if (!gd.containsKey(objectApiName)) {
                System.debug(LoggingLevel.WARN, 'Skipping unknown sObject: ' + objectApiName);
                continue;
            }
            ObjectMapping mapping = USAGE_MAP.get(objectApiName);
            Integer recordCount = 0;
            try {
                recordCount = (Integer) Database.countQuery('SELECT COUNT() FROM ' + objectApiName);
            } catch (Exception e) {
                System.debug(LoggingLevel.WARN, 'Skipping ' + objectApiName + ' due to query error: ' + e.getMessage());
                continue;
            }
            snapshot.put(mapping.countFieldApiName, recordCount);
            // Estimate data storage in **MB** using ~2 KB/record except for EmailMessage. EmailMessage uses estimated mean size of record size.
            Decimal sizeMb = 0;
            if (recordCount != 0) {
            	if (objectApiName == 'EmailMessage'){
                    sizeMb = (Decimal.valueOf(recordCount) * 33) / 1024;
                } else {
                sizeMb = (Decimal.valueOf(recordCount) * 2) / 1024;
                } 
            }         
            snapshot.put(mapping.sizeMbFieldApiName, sizeMb.setScale(DECIMALS_MB));
        }
    }
  
    // ====== Org limits ======
    private void populateGlobalLimits(StorageUsageData__c snapshot) {
        LimitsData l = getLimits();
        // Data storage
        snapshot.put('Data_Storage_Limit__c', l.dataLimitMB.setScale(DECIMALS_MB));
        snapshot.put('Data_Storage_Used__c',  l.dataUsedMB.setScale(DECIMALS_MB));
        Decimal dataPct = 0;
        if (l.dataLimitMB > 0) {
        	dataPct = (l.dataUsedMB / l.dataLimitMB * 100);
        }
        snapshot.put('Data_Storage_Percentage_Used__c', dataPct.setScale(DECIMALS_PCT));
        // File storage
        snapshot.put('File_Storage_Limit__c', l.fileLimitMB.setScale(DECIMALS_MB));
        snapshot.put('File_Storage_Used__c',  l.fileUsedMB.setScale(DECIMALS_MB));
        Decimal filePct = 0;
        if (l.fileLimitMB > 0) {
        	filePct = (l.fileUsedMB / l.fileLimitMB * 100);
        }
        snapshot.put('File_Storage_Percentage_Used__c', filePct.setScale(DECIMALS_PCT));
    }

      // Default provider that calls REST /limits against this org (self‑callout).
        private LimitsData getLimits() {
            HttpRequest req = new HttpRequest();
            req.setMethod('GET');
            req.setEndpoint(URL.getOrgDomainUrl().toExternalForm() + '/services/data/v62.0/limits');
            req.setHeader('Authorization', 'Bearer ' + UserInfo.getSessionId());
            req.setTimeout(120000);
            HttpResponse res = new Http().send(req);
            if (res.getStatusCode() != 200) {
                throw new CalloutException('Limits API failed: ' + res.getStatus() + ' ' + res.getBody());
            }
            LimitsEnvelope env = (LimitsEnvelope) JSON.deserialize(res.getBody(), LimitsEnvelope.class);
            LimitsData out = new LimitsData();
            // Data storage
			Decimal dataRemaining = 0;
            if (env.DataStorageMB != null){
                out.dataLimitMB = Decimal.valueOf(env.DataStorageMB.Max);
                    } else {
                       out.dataLimitMB = 0; 
                    }
             if (env.DataStorageMB != null){
                dataRemaining = Decimal.valueOf(env.DataStorageMB.Remaining);
                    }
            Decimal dataUsed = out.dataLimitMB - dataRemaining; 
            if (dataUsed < 0) {
                dataUsed = 0;
            } 
            out.dataUsedMB = dataUsed;
            // File storage
			Decimal fileRemaining = 0;
            if (env.FileStorageMB != null){
                out.fileLimitMB = Decimal.valueOf(env.FileStorageMB.Max);
                    } else {
                       out.fileLimitMB = 0; 
                    }
             if (env.FileStorageMB != null){
                fileRemaining = Decimal.valueOf(env.FileStorageMB.Remaining);
                    }
            Decimal fileUsed = out.fileLimitMB - fileRemaining; 
            if (fileUsed < 0) {
                fileUsed = 0;
            } 
            out.fileUsedMB = fileUsed;           
            return out;
        }

    private class LimitsEnvelope { 
        public Node DataStorageMB; 
        public Node FileStorageMB; 
    }
    private class Node { 
        public Integer Max; 
        public Integer Remaining; 
    }

    // Simple mapping holder: destination count field + destination size (MB) field
    public class ObjectMapping {
        public String countFieldApiName;
        public String sizeMbFieldApiName;
        public ObjectMapping(String countFieldApiName, String sizeMbFieldApiName) {
            this.countFieldApiName = countFieldApiName;
            this.sizeMbFieldApiName = sizeMbFieldApiName;
        }
    }

    // ====== Queueable wrapper ======
    public class StorageUsageSnapshotQueue
    implements Queueable, Database.AllowsCallouts {
        public void execute(QueueableContext ctx) {
        new StorageUsageSnapshotHelper().run();
        }
    }
    
      // ====== Limits retrieval (injectable for testing) ======
    private class LimitsData {
        public Decimal dataLimitMB;
        public Decimal dataUsedMB;
        public Decimal fileLimitMB;
        public Decimal fileUsedMB;
    }       
}