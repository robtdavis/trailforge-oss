/**
 * Trigger for Lesson__c - Cascade delete protection
 * Prevents deletion of lessons with active progress records
 */
trigger LessonTrigger on Lesson__c (before delete) {
    
    if (Trigger.isBefore && Trigger.isDelete) {
        // Collect lesson IDs being deleted
        Set<Id> lessonIds = Trigger.oldMap.keySet();
        
        // Check for progress records
        List<Progress__c> progressRecords = [
            SELECT Id, Lesson__c, Lesson__r.Name
            FROM Progress__c
            WHERE Lesson__c IN :lessonIds
            LIMIT 1
        ];
        
        if (!progressRecords.isEmpty()) {
            Progress__c firstProgress = progressRecords[0];
            Lesson__c lesson = Trigger.oldMap.get(firstProgress.Lesson__c);
            
            lesson.addError(
                'Cannot delete lesson "' + lesson.Name + '" because learners have progress records. ' +
                'Please archive the lesson instead by setting Archived = true.'
            );
        }
    }
}