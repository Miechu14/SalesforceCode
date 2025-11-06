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

        ExpectedLimits exp = computeExpected();

        Test.startTest();
        new StorageUsageSnapshotHelper().run();
        Test.stopTest();

        StorageUsageSnapshotTests t = new StorageUsageSnapshotTests();
        StorageUsageData__c snap = t.fetchLatestSnapshot();
        System.assertEquals(Date.today(), snap.Snapshot_Date__c, 'Snapshot date should be today');

        // Limits parsed correctly
        System.assertEquals(exp.dataLimit, snap.Data_Storage_Limit__c, 'Data storage limit (MB)');
        System.assertEquals(exp.dataUsed,  snap.Data_Storage_Used__c,  'Data storage used (MB)');
        System.assertEquals(exp.dataPct,   snap.Data_Storage_Percentage_Used__c, 'Data storage % used');
        System.assertEquals(exp.fileLimit, snap.File_Storage_Limit__c, 'File storage limit (MB)');
        System.assertEquals(exp.fileUsed,  snap.File_Storage_Used__c,  'File storage used (MB)');
        System.assertEquals(exp.filePct,   snap.File_Storage_Percentage_Used__c, 'File storage % used');

        // Object counts captured 
        System.assertEquals(3, snap.Accounts_Record_Count__c, 'Should count inserted Accounts');
    }

    // Scheduled job test
    @IsTest
    static void scheduled_job_executes_helper_and_creates_snapshot() {
        ExpectedLimits exp = computeExpected();

        Test.startTest();
        String jobId = System.schedule('Storage Snapshot Daily Test', '0 0 0 ? * MON-FRI', new StorageUsageSnapshotJob());
        Test.stopTest();

        StorageUsageSnapshotTests t = new StorageUsageSnapshotTests();
        StorageUsageData__c snap = t.fetchLatestSnapshot();
        System.assertNotEquals(null, snap, 'Snapshot should exist after scheduled run');
        System.assertEquals(exp.dataLimit, snap.Data_Storage_Limit__c);
        System.assertEquals(exp.fileLimit, snap.File_Storage_Limit__c);
    }

	//Test unknown object api name
	@IsTest
    static void helper_skips_unknown_object_key_without_failing() {
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
    private class ExpectedLimits {
        Decimal dataLimit, dataUsed, dataPct;
        Decimal fileLimit, fileUsed, filePct;
    }
    private static ExpectedLimits computeExpected() {
    // Retrieve current org limits for Data and File storage
    Map<String, System.OrgLimit> limitsMap = OrgLimits.getMap();
    System.OrgLimit data = limitsMap.get('DataStorageMB');
    System.OrgLimit file = limitsMap.get('FileStorageMB');

    Integer dataLimit;
    Integer dataUsed;
    Integer fileLimit;
    Integer fileUsed;

    // Determine Data Storage limits
    if (data != null) {
        dataLimit = data.getLimit();
        dataUsed = data.getValue();
    } else {
        dataLimit = 0;
        dataUsed = 0;
    }

    // Determine File Storage limits
    if (file != null) {
        fileLimit = file.getLimit();
        fileUsed = file.getValue();
    } else {
        fileLimit = 0;
        fileUsed = 0;
    }

    // Create the object with expected values
    ExpectedLimits exp = new ExpectedLimits();
    exp.dataLimit = Decimal.valueOf(dataLimit).setScale(2);
    exp.dataUsed  = Decimal.valueOf(dataUsed).setScale(2);
    exp.fileLimit = Decimal.valueOf(fileLimit).setScale(2);
    exp.fileUsed  = Decimal.valueOf(fileUsed).setScale(2);

    // Calculate percentages using full if statements for clarity
    if (dataLimit > 0) {
        exp.dataPct = (Decimal.valueOf(dataUsed) / Decimal.valueOf(dataLimit) * 100).setScale(2);
    } else {
        exp.dataPct = 0;
    }

    if (fileLimit > 0) {
        exp.filePct = (Decimal.valueOf(fileUsed) / Decimal.valueOf(fileLimit) * 100).setScale(2);
    } else {
        exp.filePct = 0;
    }

    // Return computed expected limits
    return exp;
    }
}
