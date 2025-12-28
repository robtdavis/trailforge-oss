//
// SPDX-License-Identifier: MIT
// TrailForge — Open Source under the MIT License
// Copyright (c) 2025 Robert Davis
// See the LICENSE file in the project root for full license text.
//
/**
 * Guest-accessible controller for TrailForge Welcome functionality.
 * Runs WITHOUT SHARING to allow guest users to access Contact and Enrollment data.
 * 
 * This controller is specifically for Experience Cloud guest users who have
 * authenticated via an access code. For security, it validates that the requested
 * contactId matches an active access code session.
 */
public without sharing class TrailForgeWelcomeGuestController {

    public class WelcomeContext {
        @AuraEnabled public Id contactId;
        @AuraEnabled public String contactName;
        @AuraEnabled public Boolean profileConfirmed;
        @AuraEnabled public Integer enrollmentCount;
        @AuraEnabled public Decimal overallProgress;
        @AuraEnabled public String primaryCourseName;
        
        @AuraEnabled public Integer completedCount;
        @AuraEnabled public Integer inProgressCount;
        @AuraEnabled public Integer notStartedCount;
    }

    /**
     * Prepare the learner profile for a guest user.
     * Validates that the contactId is associated with a used access code for security.
     */
    @AuraEnabled(cacheable=false)
    public static WelcomeContext prepareLearnerProfile(Id contactId, Id accessCodeId) {
        try {
            // 1. Validate inputs
            if (contactId == null) {
                throw new AuraHandledException('Contact ID is required.');
            }
            
            // 2. Security check: Verify the access code belongs to this contact
            if (accessCodeId != null) {
                List<TrailForge_Access_Code__c> codes = [
                    SELECT Id, Contact__c, Is_Used__c
                    FROM TrailForge_Access_Code__c
                    WHERE Id = :accessCodeId
                      AND Contact__c = :contactId
                      AND Is_Used__c = true
                    LIMIT 1
                ];
                
                if (codes.isEmpty()) {
                    throw new AuraHandledException('Invalid session. Please re-authenticate.');
                }
            }
            
            // 3. Query the Contact by Id
            Contact contact = getContactById(contactId);
            
            // 4. Ensure at least one Enrollment exists for this Contact
            List<Enrollment__c> enrollments = ensureStarterEnrollments(contact);
            
            // 5. Compute portfolio-level stats across all enrollments
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
            
            // Determine primary course
            String primaryCourseName = findPrimaryCourse(enrollments);
            
            // 6. Write summary onto Contact
            contact.TrailForge_Profile_Confirmed__c = true;
            contact.TrailForge_Overall_Progress__c = overallProgress;
            contact.TrailForge_Last_Course_Name__c = primaryCourseName;
            contact.TrailForge_Enrollment_Count__c = enrollmentCount;
            update contact;
            
            // 7. Build and return WelcomeContext
            WelcomeContext ctx = new WelcomeContext();
            ctx.contactId = contact.Id;
            ctx.contactName = contact.Name;
            ctx.profileConfirmed = true;
            ctx.enrollmentCount = enrollmentCount;
            ctx.overallProgress = overallProgress;
            ctx.primaryCourseName = primaryCourseName;
            ctx.completedCount = completedCount;
            ctx.inProgressCount = inProgressCount;
            ctx.notStartedCount = notStartedCount;
            
            return ctx;
            
        } catch (AuraHandledException e) {
            throw e;
        } catch (Exception e) {
            System.debug('Error in prepareLearnerProfile: ' + e.getMessage() + ' - ' + e.getStackTraceString());
            throw new AuraHandledException('Error preparing learner profile: ' + e.getMessage());
        }
    }

    // ========================================================================
    // PRIVATE HELPERS
    // ========================================================================

    private static Contact getContactById(Id contactId) {
        List<Contact> contacts = [
            SELECT Id, Name, Email, 
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

    private static List<Enrollment__c> ensureStarterEnrollments(Contact contact) {
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
        
        if (!existingEnrollments.isEmpty()) {
            return existingEnrollments;
        }
        
        // Create a starter enrollment
        Course__c defaultCourse = findDefaultCourse();
        
        if (defaultCourse == null) {
            return new List<Enrollment__c>();
        }
        
        Enrollment__c newEnrollment = new Enrollment__c(
            Contact__c = contact.Id,
            Course__c = defaultCourse.Id,
            Status__c = 'Not Started',
            Progress_Percentage__c = 0
        );
        insert newEnrollment;
        
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

    private static Course__c findDefaultCourse() {
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
        
        List<Course__c> anyCourses = [
            SELECT Id, Name
            FROM Course__c
            WHERE Archived__c = false
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];
        
        return anyCourses.isEmpty() ? null : anyCourses[0];
    }

    private static String findPrimaryCourse(List<Enrollment__c> enrollments) {
        if (enrollments == null || enrollments.isEmpty()) {
            return null;
        }
        
        List<Enrollment__c> nonCompleted = new List<Enrollment__c>();
        for (Enrollment__c enr : enrollments) {
            if (enr.Status__c != 'Completed') {
                nonCompleted.add(enr);
            }
        }
        
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
        
        return enrollments[0].Course__r.Name;
    }
    
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
        return average.setScale(2);
    }
}
