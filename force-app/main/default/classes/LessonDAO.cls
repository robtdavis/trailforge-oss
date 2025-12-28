//
// SPDX-License-Identifier: MIT
// TrailForge — Open Source under the MIT License
// Copyright (c) 2025 Robert Davis
// See the LICENSE file in the project root for full license text.
//
/**
 * @description Data Access Object for Lesson__c
 * All SOQL for lessons lives here
 * 
 * @author TrailForge Team
 * @date 2025-11-27
 */
public with sharing class LessonDAO {
    
    /**
     * @description Retrieves a lesson with its associated quiz (if any)
     * @param lessonId The ID of the lesson
     * @return Lesson__c record with Quiz__c lookup populated
     */
    public static Lesson__c getLessonWithQuiz(Id lessonId) {
        if (lessonId == null) {
            return null;
        }
        
        List<Lesson__c> lessons = [
            SELECT Id, Name, Module__c, Content_Body__c, Content_Type__c,
                   External_URL__c, Order__c, Archived__c,
                   Quiz__c, Quiz__r.Name, Quiz__r.Passing_Score__c,
                   Quiz__r.Active__c, Quiz__r.Archived__c
            FROM Lesson__c
            WHERE Id = :lessonId
            LIMIT 1
        ];
        
        return lessons.isEmpty() ? null : lessons[0];
    }
    
    /**
     * @description Retrieves lessons for a module with quiz lookups
     * @param moduleId The ID of the module
     * @return List of Lesson__c records with Quiz__c lookups
     */
    public static List<Lesson__c> getLessonsForModuleWithQuiz(Id moduleId) {
        if (moduleId == null) {
            return new List<Lesson__c>();
        }
        
        return [
            SELECT Id, Name, Module__c, Content_Body__c, Content_Type__c,
                   External_URL__c, Order__c, Archived__c,
                   Quiz__c, Quiz__r.Name, Quiz__r.Passing_Score__c,
                   Quiz__r.Active__c, Quiz__r.Archived__c
            FROM Lesson__c
            WHERE Module__c = :moduleId
              AND Archived__c = false
            ORDER BY Order__c NULLS LAST, Name
        ];
    }
    
    /**
     * @description Retrieves lessons for multiple modules with quiz lookups (bulk-safe)
     * @param moduleIds Set of module IDs
     * @return List of Lesson__c records with Quiz__c lookups
     */
    public static List<Lesson__c> getLessonsForModulesWithQuiz(Set<Id> moduleIds) {
        if (moduleIds == null || moduleIds.isEmpty()) {
            return new List<Lesson__c>();
        }
        
        return [
            SELECT Id, Name, Module__c, Content_Body__c, Content_Type__c,
                   External_URL__c, Order__c, Archived__c,
                   Quiz__c, Quiz__r.Name, Quiz__r.Passing_Score__c,
                   Quiz__r.Active__c, Quiz__r.Archived__c
            FROM Lesson__c
            WHERE Module__c IN :moduleIds
              AND Archived__c = false
            ORDER BY Module__c, Order__c NULLS LAST, Name
        ];
    }
}