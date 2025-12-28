//
// SPDX-License-Identifier: MIT
// TrailForge — Open Source under the MIT License
// Copyright (c) 2025 Robert Davis
// See the LICENSE file in the project root for full license text.
//
/**
 * Data Access Object for Progress__c
 * All SOQL queries for Progress records live here
 */
public with sharing class ProgressDAO {
    
    /**
     * Find a progress record for a specific enrollment and lesson
     * @param enrollmentId The enrollment ID
     * @param lessonId The lesson ID
     * @return Progress__c record or null if not found
     */
    public static Progress__c getProgress(Id enrollmentId, Id lessonId) {
        List<Progress__c> progressRecords = [
            SELECT Id, Status__c, Enrollment__c, Lesson__c, Contact__c, 
                   Started_On__c, Completed_On__c
            FROM Progress__c
            WHERE Enrollment__c = :enrollmentId
            AND Lesson__c = :lessonId
            LIMIT 1
        ];
        
        return progressRecords.isEmpty() ? null : progressRecords[0];
    }
    
    /**
     * Upsert a progress record and mark it as completed
     * If record exists: update to Completed status
     * If not: insert new record with Completed status
     * @param enrollmentId The enrollment ID
     * @param lessonId The lesson ID
     * @return The upserted Progress__c record
     */
    public static Progress__c upsertCompletedProgress(Id enrollmentId, Id lessonId) {
        // First, get the contact from the enrollment
        Enrollment__c enrollment = [
            SELECT Id, Contact__c
            FROM Enrollment__c
            WHERE Id = :enrollmentId
            LIMIT 1
        ];
        
        // Find existing progress record
        Progress__c progress = getProgress(enrollmentId, lessonId);
        
        if (progress == null) {
            // Create new progress record
            progress = new Progress__c(
                Enrollment__c = enrollmentId,
                Lesson__c = lessonId,
                Contact__c = enrollment.Contact__c,
                Status__c = 'Completed',
                Started_On__c = System.now(),
                Completed_On__c = System.now()
            );
        } else if (progress.Status__c != 'Completed') {
            // Update existing progress to completed
            progress.Status__c = 'Completed';
            progress.Completed_On__c = System.now();
            
            if (progress.Started_On__c == null) {
                progress.Started_On__c = System.now();
            }
        }
        
        upsert progress;
        
        return progress;
    }
    
    /**
     * Upsert a progress record and mark it as In Progress
     * If record exists and not completed: keep existing status
     * If not: insert new record with In Progress status
     * @param enrollmentId The enrollment ID
     * @param lessonId The lesson ID
     * @return The upserted Progress__c record
     */
    public static Progress__c upsertStartedProgress(Id enrollmentId, Id lessonId) {
        // First, get the contact from the enrollment
        Enrollment__c enrollment = [
            SELECT Id, Contact__c
            FROM Enrollment__c
            WHERE Id = :enrollmentId
            LIMIT 1
        ];
        
        // Find existing progress record
        Progress__c progress = getProgress(enrollmentId, lessonId);
        
        if (progress == null) {
            // Create new progress record as In Progress
            progress = new Progress__c(
                Enrollment__c = enrollmentId,
                Lesson__c = lessonId,
                Contact__c = enrollment.Contact__c,
                Status__c = 'In Progress',
                Started_On__c = System.now()
            );
            insert progress;
        } else if (progress.Status__c == 'Not Started') {
            // Update to In Progress only if it was Not Started
            progress.Status__c = 'In Progress';
            if (progress.Started_On__c == null) {
                progress.Started_On__c = System.now();
            }
            update progress;
        }
        // If already In Progress or Completed, don't change it
        
        return progress;
    }
    
    /**
     * Get all lessons for a module
     * @param moduleId The module ID
     * @return List of Lesson__c records
     */
    public static List<Lesson__c> getLessonsForModule(Id moduleId) {
        return [
            SELECT Id
            FROM Lesson__c
            WHERE Module__c = :moduleId
        ];
    }
    
    /**
     * Count completed progress records for specific lessons in an enrollment
     * @param enrollmentId The enrollment ID
     * @param lessonIds Set of lesson IDs to check
     * @return Count of completed progress records
     */
    public static Integer countCompletedProgress(Id enrollmentId, Set<Id> lessonIds) {
        return [
            SELECT COUNT()
            FROM Progress__c
            WHERE Enrollment__c = :enrollmentId
            AND Lesson__c IN :lessonIds
            AND Status__c = 'Completed'
        ];
    }
}