//
// SPDX-License-Identifier: MIT
// TrailForge — Open Source under the MIT License
// Copyright (c) 2025 Robert Davis
// See the LICENSE file in the project root for full license text.
//
/**
 * Guest-accessible version of ProgressService.
 * Runs WITHOUT SHARING to allow guest users to track lesson progress.
 * 
 * Service layer for Progress tracking
 * Orchestrates lesson and module completion logic
 */
public without sharing class ProgressGuestService {
    
    /**
     * Mark a lesson as completed for an enrollment
     * @param enrollmentId The enrollment ID
     * @param lessonId The lesson ID
     * @return ProgressStatusDTO with completion details
     */
    @AuraEnabled
    public static ProgressService.ProgressStatusDTO markLessonCompleted(Id enrollmentId, Id lessonId) {
        try {
            if (enrollmentId == null || lessonId == null) {
                throw new AuraHandledException('Enrollment ID and Lesson ID are required');
            }
            
            // Query or create Progress record
            List<Progress__c> existingProgress = [
                SELECT Id, Status__c, Lesson__c, Enrollment__c
                FROM Progress__c
                WHERE Enrollment__c = :enrollmentId
                  AND Lesson__c = :lessonId
                LIMIT 1
            ];
            
            Progress__c progress;
            if (existingProgress.isEmpty()) {
                progress = new Progress__c(
                    Enrollment__c = enrollmentId,
                    Lesson__c = lessonId,
                    Status__c = 'Completed'
                );
                insert progress;
            } else {
                progress = existingProgress[0];
                progress.Status__c = 'Completed';
                update progress;
            }
            
            // Build and return DTO
            ProgressService.ProgressStatusDTO dto = new ProgressService.ProgressStatusDTO();
            dto.progressId = progress.Id;
            dto.status = progress.Status__c;
            dto.lessonId = progress.Lesson__c;
            dto.enrollmentId = progress.Enrollment__c;
            
            return dto;
            
        } catch (Exception e) {
            System.debug('Error in markLessonCompleted: ' + e.getMessage() + ' - ' + e.getStackTraceString());
            throw new AuraHandledException('Error marking lesson completed: ' + e.getMessage());
        }
    }
    
    /**
     * Mark a lesson as started (In Progress) for an enrollment
     * @param enrollmentId The enrollment ID
     * @param lessonId The lesson ID
     * @return ProgressStatusDTO with status details
     */
    @AuraEnabled
    public static ProgressService.ProgressStatusDTO markLessonStarted(Id enrollmentId, Id lessonId) {
        try {
            if (enrollmentId == null || lessonId == null) {
                throw new AuraHandledException('Enrollment ID and Lesson ID are required');
            }
            
            // Query or create Progress record
            List<Progress__c> existingProgress = [
                SELECT Id, Status__c, Lesson__c, Enrollment__c
                FROM Progress__c
                WHERE Enrollment__c = :enrollmentId
                  AND Lesson__c = :lessonId
                LIMIT 1
            ];
            
            Progress__c progress;
            if (existingProgress.isEmpty()) {
                progress = new Progress__c(
                    Enrollment__c = enrollmentId,
                    Lesson__c = lessonId,
                    Status__c = 'In Progress'
                );
                insert progress;
            } else {
                progress = existingProgress[0];
                // Only update if not already completed
                if (progress.Status__c != 'Completed') {
                    progress.Status__c = 'In Progress';
                    update progress;
                }
            }
            
            // Build and return DTO
            ProgressService.ProgressStatusDTO dto = new ProgressService.ProgressStatusDTO();
            dto.progressId = progress.Id;
            dto.status = progress.Status__c;
            dto.lessonId = progress.Lesson__c;
            dto.enrollmentId = progress.Enrollment__c;
            
            return dto;
            
        } catch (Exception e) {
            System.debug('Error in markLessonStarted: ' + e.getMessage() + ' - ' + e.getStackTraceString());
            throw new AuraHandledException('Error marking lesson started: ' + e.getMessage());
        }
    }
    
    /**
     * Check if all lessons in a module are completed
     * @param moduleId The module ID
     * @param enrollmentId The enrollment ID
     * @return True if all lessons in module are completed
     */
    @AuraEnabled(cacheable=true)
    public static Boolean isModuleCompleted(Id moduleId, Id enrollmentId) {
        try {
            if (moduleId == null || enrollmentId == null) {
                return false;
            }
            
            // Get all lessons for the module
            List<Lesson__c> lessons = [
                SELECT Id
                FROM Lesson__c
                WHERE Module__c = :moduleId
                  AND Archived__c = false
            ];
            
            if (lessons.isEmpty()) {
                return false;
            }
            
            // Build set of lesson IDs
            Set<Id> lessonIds = new Set<Id>();
            for (Lesson__c lesson : lessons) {
                lessonIds.add(lesson.Id);
            }
            
            // Count completed progress records
            Integer completedCount = [
                SELECT COUNT()
                FROM Progress__c
                WHERE Enrollment__c = :enrollmentId
                  AND Lesson__c IN :lessonIds
                  AND Status__c = 'Completed'
            ];
            
            // Module is complete if all lessons are completed
            return completedCount == lessons.size();
            
        } catch (Exception e) {
            System.debug('Error checking module completion: ' + e.getMessage());
            return false;
        }
    }
}
