//
// SPDX-License-Identifier: MIT
// TrailForge — Open Source under the MIT License
// Copyright (c) 2025 Robert Davis
// See the LICENSE file in the project root for full license text.
//
/**
 * Service layer for Progress tracking
 * Orchestrates lesson and module completion logic
 */
public with sharing class ProgressService {
    
    /**
     * Mark a lesson as completed for an enrollment
     * @param enrollmentId The enrollment ID
     * @param lessonId The lesson ID
     * @return ProgressStatusDTO with completion details
     */
    @AuraEnabled
    public static ProgressStatusDTO markLessonCompleted(Id enrollmentId, Id lessonId) {
        try {
            // Validate inputs
            if (enrollmentId == null || lessonId == null) {
                throw new AuraHandledException('Enrollment ID and Lesson ID are required');
            }
            
            // Upsert progress record via DAO
            Progress__c progress = ProgressDAO.upsertCompletedProgress(enrollmentId, lessonId);
            
            // Build and return DTO
            ProgressStatusDTO dto = new ProgressStatusDTO();
            dto.progressId = progress.Id;
            dto.status = progress.Status__c;
            dto.lessonId = progress.Lesson__c;
            dto.enrollmentId = progress.Enrollment__c;
            
            return dto;
            
        } catch (Exception e) {
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
    public static ProgressStatusDTO markLessonStarted(Id enrollmentId, Id lessonId) {
        try {
            // Validate inputs
            if (enrollmentId == null || lessonId == null) {
                throw new AuraHandledException('Enrollment ID and Lesson ID are required');
            }
            
            // Upsert progress record via DAO
            Progress__c progress = ProgressDAO.upsertStartedProgress(enrollmentId, lessonId);
            
            // Build and return DTO
            ProgressStatusDTO dto = new ProgressStatusDTO();
            dto.progressId = progress.Id;
            dto.status = progress.Status__c;
            dto.lessonId = progress.Lesson__c;
            dto.enrollmentId = progress.Enrollment__c;
            
            return dto;
            
        } catch (Exception e) {
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
            // Validate inputs
            if (moduleId == null || enrollmentId == null) {
                return false;
            }
            
            // Get all lessons for the module
            List<Lesson__c> lessons = ProgressDAO.getLessonsForModule(moduleId);
            
            if (lessons.isEmpty()) {
                return false;
            }
            
            // Build set of lesson IDs
            Set<Id> lessonIds = new Set<Id>();
            for (Lesson__c lesson : lessons) {
                lessonIds.add(lesson.Id);
            }
            
            // Count completed progress records
            Integer completedCount = ProgressDAO.countCompletedProgress(enrollmentId, lessonIds);
            
            // Module is complete if all lessons are completed
            return completedCount == lessons.size();
            
        } catch (Exception e) {
            // Log error and return false - don't block UI
            System.debug('Error checking module completion: ' + e.getMessage());
            return false;
        }
    }
    
    // ========================================================================
    // DTO CLASSES
    // ========================================================================
    
    /**
     * DTO for progress status information
     */
    public class ProgressStatusDTO {
        @AuraEnabled public Id progressId;
        @AuraEnabled public String status;
        @AuraEnabled public Id lessonId;
        @AuraEnabled public Id enrollmentId;
    }
}