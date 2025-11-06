global with sharing class StorageUsageSnapshotJob implements Schedulable {
global void execute(SchedulableContext sc) {
System.enqueueJob(new StorageUsageSnapshotHelper.SnapshotQueue());
}
}