/**
 * Minimal Schedulable wrapper to run daily.
 */
global with sharing class StorageUsageSnapshotJob implements Schedulable {
    global void execute(SchedulableContext sc) {
        new StorageUsageSnapshotHelper().run();
    }
}