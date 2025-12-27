public with sharing class TrailForgeWelcomeService {

    public class WelcomeContext {
        @AuraEnabled public Id contactId;
        @AuraEnabled public Boolean profileConfirmed;
        @AuraEnabled public Integer enrollmentCount;
        @AuraEnabled public Decimal overallProgress;
        @AuraEnabled public String primaryCourseName;
        
        @AuraEnabled public Integer completedCount;
        @AuraEnabled public Integer inProgressCount;
        @AuraEnabled public Integer notStartedCount;
    }

    @AuraEnabled(cacheable=false)
    public static WelcomeContext prepareLearnerProfile(Id contactId) {
        try {
            // 1. Validate contactId
            if (contactId == null) {
                throw new AuraHandledException('Contact ID is required.');
            }
            
            // 2. Query the Contact by Id
            Contact contact = getContactById(contactId);
            
            // 3. Ensure at least one Enrollment exists for this Contact
            List<Enrollment__c> enrollments = ensureStarterEnrollments(contact);
            
            // 4. Compute portfolio-level stats across all enrollments
            Decimal overallProgress = computeOverallProgress(enrollments);
            Integer enrollmentCount = enrollments.size();
            
            Integer completedCount = 0;
            Integer inProgressCount = 0;
            Integer notStartedCount = 0;
            
            for (Enrollment__c enr : enrollments) {
                if (enr.Status__c == 'Completed') {
                    completedCount++;
                } else if (enr.Status__c == 'In Progress') {
                    inProgressCount++;
                } else if (enr.Status__c == 'Not Started') {
                    notStartedCount++;
                }
            }
            
            // Determine primary course (non-completed with lowest progress > 0, or first non-completed, or first enrollment)
            String primaryCourseName = findPrimaryCourse(enrollments);
            
            // 5. Write summary onto Contact
            contact.TrailForge_Profile_Confirmed__c = true;
            contact.TrailForge_Overall_Progress__c = overallProgress;
            contact.TrailForge_Last_Course_Name__c = primaryCourseName;
            contact.TrailForge_Enrollment_Count__c = enrollmentCount;
            update contact;
            
            // 6. Build and return WelcomeContext
            WelcomeContext ctx = new WelcomeContext();
            ctx.contactId = contact.Id;
            ctx.profileConfirmed = true;
            ctx.enrollmentCount = enrollmentCount;
            ctx.overallProgress = overallProgress;
            ctx.primaryCourseName = primaryCourseName;
            ctx.completedCount = completedCount;
            ctx.inProgressCount = inProgressCount;
            ctx.notStartedCount = notStartedCount;
            
            return ctx;
            
        } catch (Exception e) {
            throw new AuraHandledException('Error preparing learner profile: ' + e.getMessage());
        }
    }

    // ========================================================================
    // PRIVATE HELPERS
    // ========================================================================

    /**
     * Query Contact by Id
     */
    private static Contact getContactById(Id contactId) {
        List<Contact> contacts = [
            SELECT Id, Email, 
                   TrailForge_Profile_Confirmed__c,
                   TrailForge_Overall_Progress__c,
                   TrailForge_Last_Course_Name__c,
                   TrailForge_Enrollment_Count__c
            FROM Contact
            WHERE Id = :contactId
            LIMIT 1
        ];
        
        if (contacts.isEmpty()) {
            throw new AuraHandledException('Contact not found.');
        }
        
        return contacts[0];
    }

    /**
     * Ensure Contact has at least one Enrollment, creating a starter enrollment if needed
     */
    private static List<Enrollment__c> ensureStarterEnrollments(Contact contact) {
        // Query existing enrollments for this Contact
        List<Enrollment__c> existingEnrollments = [
            SELECT Id, 
                   Contact__c,
                   Course__c,
                   Course__r.Name,
                   Status__c,
                   Progress_Percentage__c,
                   Quiz_Passed__c,
                   Quiz_Score__c
            FROM Enrollment__c
            WHERE Contact__c = :contact.Id
            ORDER BY CreatedDate DESC
        ];
        
        // If enrollments exist, return them
        if (!existingEnrollments.isEmpty()) {
            return existingEnrollments;
        }
        
        // Otherwise, create a starter enrollment
        Course__c defaultCourse = findDefaultCourse();
        
        if (defaultCourse == null) {
            // No courses available - return empty list
            return new List<Enrollment__c>();
        }
        
        Enrollment__c newEnrollment = new Enrollment__c(
            Contact__c = contact.Id,
            Course__c = defaultCourse.Id,
            Status__c = 'Not Started',
            Progress_Percentage__c = 0
        );
        insert newEnrollment;
        
        // Re-query to get Course relationship data
        List<Enrollment__c> enrollments = [
            SELECT Id,
                   Contact__c,
                   Course__c,
                   Course__r.Name,
                   Status__c,
                   Progress_Percentage__c,
                   Quiz_Passed__c,
                   Quiz_Score__c
            FROM Enrollment__c
            WHERE Id = :newEnrollment.Id
        ];
        
        return enrollments;
    }

    /**
     * Find a default course for new enrollments
     * Prefers 'TrailForge 101', otherwise picks the first active course
     */
    private static Course__c findDefaultCourse() {
        // Try to find "TrailForge 101" course
        List<Course__c> preferredCourses = [
            SELECT Id, Name
            FROM Course__c
            WHERE Name = 'TrailForge 101'
              AND Archived__c = false
            LIMIT 1
        ];
        
        if (!preferredCourses.isEmpty()) {
            return preferredCourses[0];
        }
        
        // Otherwise, find any active (non-archived) course
        List<Course__c> anyCourses = [
            SELECT Id, Name
            FROM Course__c
            WHERE Archived__c = false
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];
        
        return anyCourses.isEmpty() ? null : anyCourses[0];
    }

    /**
     * Find the primary course to highlight (non-completed with progress, or first non-completed, or first enrollment)
     */
    private static String findPrimaryCourse(List<Enrollment__c> enrollments) {
        if (enrollments == null || enrollments.isEmpty()) {
            return null;
        }
        
        // Find non-completed enrollments
        List<Enrollment__c> nonCompleted = new List<Enrollment__c>();
        for (Enrollment__c enr : enrollments) {
            if (enr.Status__c != 'Completed') {
                nonCompleted.add(enr);
            }
        }
        
        // If there are non-completed enrollments, pick the one with lowest progress > 0
        if (!nonCompleted.isEmpty()) {
            Enrollment__c primary = nonCompleted[0];
            Decimal lowestProgress = primary.Progress_Percentage__c != null ? primary.Progress_Percentage__c : 0;
            
            for (Enrollment__c enr : nonCompleted) {
                Decimal progress = enr.Progress_Percentage__c != null ? enr.Progress_Percentage__c : 0;
                if (progress > 0 && (lowestProgress == 0 || progress < lowestProgress)) {
                    primary = enr;
                    lowestProgress = progress;
                }
            }
            
            return primary.Course__r.Name;
        }
        
        // All completed - return first enrollment
        return enrollments[0].Course__r.Name;
    }
    
    /**
     * Compute average progress across all enrollments
     */
    private static Decimal computeOverallProgress(List<Enrollment__c> enrollments) {
        if (enrollments == null || enrollments.isEmpty()) {
            return 0;
        }
        
        Decimal totalProgress = 0;
        Integer count = 0;
        
        for (Enrollment__c enr : enrollments) {
            if (enr.Progress_Percentage__c != null) {
                totalProgress += enr.Progress_Percentage__c;
            }
            count++;
        }
        
        if (count == 0) {
            return 0;
        }
        
        Decimal average = totalProgress / count;
        return average.setScale(2); // Round to 2 decimal places
    }
}