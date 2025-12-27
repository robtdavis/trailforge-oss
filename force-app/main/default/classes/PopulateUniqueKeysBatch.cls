/**
 * Batch class to backfill Unique_Key__c for existing Enrollment__c and Progress__c records
 * 
 * USAGE:
 * Run once in production after deploying unique key workflows to populate existing records.
 * 
 * For Enrollments:
 *   Database.executeBatch(new PopulateUniqueKeysBatch('Enrollment'), 100);
 * 
 * For Progress:
 *   Database.executeBatch(new PopulateUniqueKeysBatch('Progress'), 100);
 * 
 * The workflow rules will automatically populate Unique_Key__c on update.
 */
public class PopulateUniqueKeysBatch implements Database.Batchable<sObject> {
    
    private String objectType; // 'Enrollment' or 'Progress'
    
    /**
     * Constructor
     * @param objectType Either 'Enrollment' or 'Progress'
     */
    public PopulateUniqueKeysBatch(String objectType) {
        if (objectType != 'Enrollment' && objectType != 'Progress') {
            throw new IllegalArgumentException('objectType must be either "Enrollment" or "Progress"');
        }
        this.objectType = objectType;
    }
    
    /**
     * Start method - queries records with null Unique_Key__c
     */
    public Database.QueryLocator start(Database.BatchableContext bc) {
        if (objectType == 'Enrollment') {
            return Database.getQueryLocator([
                SELECT Id, Contact__c, Course__c, Unique_Key__c
                FROM Enrollment__c
                WHERE Unique_Key__c = null
            ]);
        } else {
            // objectType == 'Progress'
            return Database.getQueryLocator([
                SELECT Id, Contact__c, Lesson__c, Enrollment__c, Unique_Key__c
                FROM Progress__c
                WHERE Unique_Key__c = null
            ]);
        }
    }
    
    /**
     * Execute method - updates records to trigger workflow rule
     */
    public void execute(Database.BatchableContext bc, List<sObject> scope) {
        try {
            // Update records without changing any field values
            // The workflow rule will populate Unique_Key__c on update
            update scope;
            
            Logger.logInfo(
                'PopulateUniqueKeysBatch',
                'execute',
                'Successfully processed ' + scope.size() + ' ' + objectType + ' records'
            );
            
        } catch (Exception e) {
            Logger.logError(
                'PopulateUniqueKeysBatch',
                'execute',
                e,
                scope.size()
            );
            // Re-throw to mark batch as failed
            throw e;
        }
    }
    
    /**
     * Finish method - logs completion
     */
    public void finish(Database.BatchableContext bc) {
        AsyncApexJob job = [
            SELECT Id, 
                   Status, 
                   NumberOfErrors, 
                   JobItemsProcessed, 
                   TotalJobItems, 
                   CreatedDate,
                   CompletedDate
            FROM AsyncApexJob
            WHERE Id = :bc.getJobId()
        ];
        
        String completionMessage = String.format(
            'PopulateUniqueKeysBatch ({0}) completed. Status: {1}, Processed: {2}/{3}, Errors: {4}',
            new List<String>{
                objectType,
                job.Status,
                String.valueOf(job.JobItemsProcessed),
                String.valueOf(job.TotalJobItems),
                String.valueOf(job.NumberOfErrors)
            }
        );
        
        Logger.logInfo('PopulateUniqueKeysBatch', 'finish', completionMessage);
    }
}