/**
 * Test class that test two apex classes:
 * StorageUsageSnapshotHelper - logic for a scheduled job to get the storage usage data snapshot
 * StorageUsageSnapshotJob - scheduled job
 */

@IsTest
public class StorageUsageSnapshotTests {
    
    private StorageUsageData__c fetchLatestSnapshot() {
        return [
            SELECT Id, Snapshot_Date__c,
                   Data_Storage_Limit__c, Data_Storage_Used__c, Data_Storage_Percentage_Used__c,
                   File_Storage_Limit__c, File_Storage_Used__c, File_Storage_Percentage_Used__c,
                   Accounts_Record_Count__c
            FROM StorageUsageData__c
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];
    }
    
    @IsTest
    static void helper_run_creates_snapshot_with_counts_and_limits() {
        insert new Account(Name='A');
        insert new Account(Name='B');
        insert new Account(Name='C');

        Test.setMock(HttpCalloutMock.class, new LimitsSuccessMock());

        Test.startTest();
        new StorageUsageSnapshotHelper().run();
        Test.stopTest();

        StorageUsageSnapshotTests t = new StorageUsageSnapshotTests();
        StorageUsageData__c snap = t.fetchLatestSnapshot();
        System.assertEquals(Date.today(), snap.Snapshot_Date__c, 'Snapshot date should be today');

        // Limits parsed correctly
        System.assertEquals(100, snap.Data_Storage_Limit__c, 'Data storage limit (MB)');
        System.assertEquals(50, snap.Data_Storage_Used__c, 'Data storage used (MB)');
        System.assertEquals(50, snap.Data_Storage_Percentage_Used__c, 'Data storage % used');
        System.assertEquals(200, snap.File_Storage_Limit__c, 'File storage limit (MB)');
        System.assertEquals(100, snap.File_Storage_Used__c, 'File storage used (MB)');
        System.assertEquals(50, snap.File_Storage_Percentage_Used__c, 'File storage % used');

        // Object counts captured 
        System.assertEquals(3, snap.Accounts_Record_Count__c, 'Should count inserted Accounts');
    }


    // Scheduled job test
    @IsTest
    static void scheduled_job_executes_helper_and_creates_snapshot() {

        Test.setMock(HttpCalloutMock.class, new LimitsSuccessMock());


        Test.startTest();
        String jobId = System.schedule('Storage Snapshot Daily Test', '0 0 0 ? * MON-FRI', new StorageUsageSnapshotJob());
        Test.stopTest();


        StorageUsageSnapshotTests t = new StorageUsageSnapshotTests();
        StorageUsageData__c snap = t.fetchLatestSnapshot();
        System.assertNotEquals(null, snap, 'Snapshot should exist after scheduled run');
        System.assertEquals(100, snap.Data_Storage_Limit__c);
        System.assertEquals(200, snap.File_Storage_Limit__c);
    }

    // Error Path
    @IsTest
    static void helper_throws_when_limits_api_fails() {
        Test.setMock(HttpCalloutMock.class, new LimitsErrorMock());

        Boolean threw = false;
        Test.startTest();
        try {
            new StorageUsageSnapshotHelper().run();
        } catch (Exception e) {
            threw = true;
        }
        Test.stopTest();

        System.assertEquals(true, threw, 'Helper should bubble the error when /limits returns non-200');
    }
    
	//Test unknown object api name
	@IsTest
    static void helper_skips_unknown_object_key_without_failing() {
        Test.setMock(HttpCalloutMock.class, new LimitsSuccessMock());

        StorageUsageSnapshotHelper h = new StorageUsageSnapshotHelper();
        h.USAGE_MAP = new Map<String, StorageUsageSnapshotHelper.ObjectMapping>{
            'NoSuch__c' => new StorageUsageSnapshotHelper.ObjectMapping('Accounts_Record_Count__c', 'Accounts_Data_Storage__c')
        };

        Test.startTest();
        h.run();
        Test.stopTest();

        StorageUsageSnapshotTests t = new StorageUsageSnapshotTests();
        StorageUsageData__c snap = t.fetchLatestSnapshot();
        System.assertNotEquals(null, snap, 'Snapshot should be created even if map contains unknown object');
    }
    
     // Inner class mocking success
	private class LimitsSuccessMock implements HttpCalloutMock {
    	public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('{"DataStorageMB":{"Max":100,"Remaining":50},"FileStorageMB":{"Max":200,"Remaining":100}}');
            return res;
        }
    }

    // Inner class mocking error
    private class LimitsErrorMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(503);
            res.setBody('Service Unavailable');
            return res;
        }
    }
}