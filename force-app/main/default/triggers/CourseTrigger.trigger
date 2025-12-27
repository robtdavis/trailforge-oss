/**
 * Trigger for Course__c - Cascade delete protection
 * Prevents deletion of courses with active enrollments or progress records
 */
trigger CourseTrigger on Course__c (before delete) {
    
    if (Trigger.isBefore && Trigger.isDelete) {
        // Collect course IDs being deleted
        Set<Id> courseIds = Trigger.oldMap.keySet();
        
        // Check for active enrollments
        List<Enrollment__c> enrollments = [
            SELECT Id, Course__c, Course__r.Name
            FROM Enrollment__c
            WHERE Course__c IN :courseIds
            LIMIT 1
        ];
        
        if (!enrollments.isEmpty()) {
            Enrollment__c firstEnrollment = enrollments[0];
            Course__c course = Trigger.oldMap.get(firstEnrollment.Course__c);
            
            course.addError(
                'Cannot delete course "' + course.Name + '" because it has active enrollments. ' +
                'Please archive the course instead by setting Archived = true.'
            );
        }
        
        // Check for progress records
        List<Progress__c> progressRecords = [
            SELECT Id, Lesson__r.Module__r.Course__c, Lesson__r.Module__r.Course__r.Name
            FROM Progress__c
            WHERE Lesson__r.Module__r.Course__c IN :courseIds
            LIMIT 1
        ];
        
        if (!progressRecords.isEmpty()) {
            Progress__c firstProgress = progressRecords[0];
            Course__c course = Trigger.oldMap.get(firstProgress.Lesson__r.Module__r.Course__c);
            
            course.addError(
                'Cannot delete course "' + course.Name + '" because learners have progress records. ' +
                'Please archive the course instead by setting Archived = true.'
            );
        }
    }
}