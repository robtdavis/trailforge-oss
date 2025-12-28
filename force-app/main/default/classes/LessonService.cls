//
// SPDX-License-Identifier: MIT
// TrailForge — Open Source under the MIT License
// Copyright (c) 2025 Robert Davis
// See the LICENSE file in the project root for full license text.
//
/**
 * @description Service layer for Lesson operations
 * LWC-facing facade that delegates all SOQL to LessonDAO
 * 
 * @author TrailForge Team
 * @date 2025-11-27
 */
public with sharing class LessonService {
    
    /**
     * @description DTO for lesson data sent to LWC
     */
    public class LessonDTO {
        @AuraEnabled public Id lessonId { get; set; }
        @AuraEnabled public String lessonName { get; set; }
        @AuraEnabled public String contentBody { get; set; }
        @AuraEnabled public String contentType { get; set; }
        @AuraEnabled public String externalUrl { get; set; }
        @AuraEnabled public Id quizId { get; set; }
        @AuraEnabled public String quizName { get; set; }
        @AuraEnabled public Boolean hasQuiz { get; set; }
        
        public LessonDTO() {
            this.hasQuiz = false;
        }
    }
    
    /**
     * @description Retrieves lesson data including quiz lookup for UI display
     * @param lessonId The ID of the lesson
     * @return LessonDTO with lesson and quiz data
     */
    @AuraEnabled(cacheable=true)
    public static LessonDTO getLessonForUi(Id lessonId) {
        try {
            // Delegate SOQL to DAO
            Lesson__c lesson = LessonDAO.getLessonWithQuiz(lessonId);
            
            if (lesson == null) {
                throw new AuraHandledException('Lesson not found: ' + lessonId);
            }
            
            // Build DTO
            LessonDTO dto = new LessonDTO();
            dto.lessonId = lesson.Id;
            dto.lessonName = lesson.Name;
            dto.contentBody = lesson.Content_Body__c;
            dto.contentType = lesson.Content_Type__c;
            dto.externalUrl = lesson.External_URL__c;
            
            // Check if lesson has an active quiz
            if (lesson.Quiz__c != null && 
                lesson.Quiz__r.Active__c == true && 
                lesson.Quiz__r.Archived__c == false) {
                dto.quizId = lesson.Quiz__c;
                dto.quizName = lesson.Quiz__r.Name;
                dto.hasQuiz = true;
            }
            
            return dto;
            
        } catch (Exception e) {
            Logger.logError('LessonService', 'getLessonForUi', e, 0);
            throw new AuraHandledException('Unable to load lesson: ' + e.getMessage());
        }
    }
}