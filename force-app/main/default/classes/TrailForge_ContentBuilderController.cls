//
// SPDX-License-Identifier: MIT
// TrailForge — Open Source under the MIT License
// Copyright (c) 2025 Robert Davis
// See the LICENSE file in the project root for full license text.
//
/**
 * @description Controller for TrailForge Content Builder Admin
 * Handles creation of Course, Module, and Lesson records in a single transaction
 */
public with sharing class TrailForge_ContentBuilderController {
    
    /**
     * @description DTO for Course creation input
     */
    public class CourseDTO {
        @AuraEnabled public String name { get; set; }
        @AuraEnabled public String description { get; set; }
        @AuraEnabled public Boolean active { get; set; }
        @AuraEnabled public List<ModuleDTO> modules { get; set; }
        
        public CourseDTO() {
            this.modules = new List<ModuleDTO>();
            this.active = true;
        }
    }
    
    /**
     * @description DTO for Module creation input
     */
    public class ModuleDTO {
        @AuraEnabled public String name { get; set; }
        @AuraEnabled public Integer orderNumber { get; set; }
        @AuraEnabled public String summary { get; set; }
        @AuraEnabled public List<LessonDTO> lessons { get; set; }
        
        public ModuleDTO() {
            this.lessons = new List<LessonDTO>();
        }
    }
    
    /**
     * @description DTO for Lesson creation input
     */
    public class LessonDTO {
        @AuraEnabled public String name { get; set; }
        @AuraEnabled public Integer orderNumber { get; set; }
        @AuraEnabled public String contentType { get; set; }
        @AuraEnabled public Id quizId { get; set; }
        @AuraEnabled public String content { get; set; }
        
        public LessonDTO() {
            // Default constructor
        }
    }
    
    /**
     * @description DTO for the result of content creation
     */
    public class ContentCreationResultDTO {
        @AuraEnabled public Id courseId { get; set; }
        @AuraEnabled public List<Id> moduleIds { get; set; }
        @AuraEnabled public List<Id> lessonIds { get; set; }
        @AuraEnabled public Boolean success { get; set; }
        @AuraEnabled public String message { get; set; }
        
        public ContentCreationResultDTO() {
            this.moduleIds = new List<Id>();
            this.lessonIds = new List<Id>();
            this.success = false;
        }
    }
    
    /**
     * @description DTO for existing quiz lookup
     */
    public class QuizOptionDTO {
        @AuraEnabled public Id quizId { get; set; }
        @AuraEnabled public String name { get; set; }
        @AuraEnabled public String assignedTo { get; set; }
        
        public QuizOptionDTO() {
            // Default constructor
        }
    }
    
    /**
     * @description Creates a complete course structure with modules and lessons
     * @param courseJson JSON string representing CourseDTO
     * @return ContentCreationResultDTO with created record IDs
     */
    @AuraEnabled
    public static ContentCreationResultDTO createCourseContent(String courseJson) {
        ContentCreationResultDTO result = new ContentCreationResultDTO();
        Savepoint sp = Database.setSavepoint();
        
        try {
            CourseDTO courseData = (CourseDTO) JSON.deserialize(courseJson, CourseDTO.class);
            
            // Validate required fields
            if (String.isBlank(courseData.name)) {
                throw new AuraHandledException('Course name is required');
            }
            
            // Create Course
            Course__c course = new Course__c(
                Name = courseData.name,
                Description__c = courseData.description,
                Active__c = courseData.active != null ? courseData.active : true
            );
            insert course;
            result.courseId = course.Id;
            
            // Create Modules if any
            if (courseData.modules != null && !courseData.modules.isEmpty()) {
                List<Module__c> modulesToInsert = new List<Module__c>();
                
                for (ModuleDTO moduleData : courseData.modules) {
                    if (String.isBlank(moduleData.name)) {
                        throw new AuraHandledException('Module name is required');
                    }
                    
                    Module__c mod = new Module__c(
                        Name = moduleData.name,
                        Course__c = course.Id,
                        Order__c = moduleData.orderNumber,
                        Summary__c = moduleData.summary
                    );
                    modulesToInsert.add(mod);
                }
                
                insert modulesToInsert;
                
                // Map modules for lesson creation
                Map<Integer, Id> moduleIndexToId = new Map<Integer, Id>();
                for (Integer i = 0; i < modulesToInsert.size(); i++) {
                    moduleIndexToId.put(i, modulesToInsert[i].Id);
                    result.moduleIds.add(modulesToInsert[i].Id);
                }
                
                // Create Lessons for each Module
                List<Lesson__c> lessonsToInsert = new List<Lesson__c>();
                
                for (Integer moduleIndex = 0; moduleIndex < courseData.modules.size(); moduleIndex++) {
                    ModuleDTO moduleData = courseData.modules[moduleIndex];
                    Id moduleId = moduleIndexToId.get(moduleIndex);
                    
                    if (moduleData.lessons != null) {
                        for (LessonDTO lessonData : moduleData.lessons) {
                            if (String.isBlank(lessonData.name)) {
                                throw new AuraHandledException('Lesson name is required');
                            }
                            
                            Lesson__c lesson = new Lesson__c(
                                Name = lessonData.name,
                                Module__c = moduleId,
                                Order__c = lessonData.orderNumber,
                                Content_Type__c = lessonData.contentType,
                                Quiz__c = lessonData.quizId,
                                Content_Body__c = lessonData.content
                            );
                            lessonsToInsert.add(lesson);
                        }
                    }
                }
                
                if (!lessonsToInsert.isEmpty()) {
                    insert lessonsToInsert;
                    for (Lesson__c lesson : lessonsToInsert) {
                        result.lessonIds.add(lesson.Id);
                    }
                }
            }
            
            result.success = true;
            result.message = 'Course content created successfully';
            
        } catch (AuraHandledException e) {
            Database.rollback(sp);
            result.success = false;
            result.message = e.getMessage();
            throw e;
        } catch (Exception e) {
            Database.rollback(sp);
            result.success = false;
            result.message = 'Error creating content: ' + e.getMessage();
            throw new AuraHandledException(result.message);
        }
        
        return result;
    }
    
    /**
     * @description Gets available quizzes for lesson assignment
     * @return List of QuizOptionDTO for quiz selection
     */
    @AuraEnabled(cacheable=true)
    public static List<QuizOptionDTO> getAvailableQuizzes() {
        List<QuizOptionDTO> options = new List<QuizOptionDTO>();
        
        List<Quiz__c> quizzes = [
            SELECT Id, Name, Lesson__r.Name, Course__r.Name
            FROM Quiz__c
            WHERE Active__c = true
            AND Archived__c = false
            ORDER BY Name ASC
            LIMIT 200
        ];
        
        for (Quiz__c quiz : quizzes) {
            QuizOptionDTO option = new QuizOptionDTO();
            option.quizId = quiz.Id;
            option.name = quiz.Name;
            
            if (quiz.Lesson__r != null && quiz.Lesson__r.Name != null) {
                option.assignedTo = 'Lesson: ' + quiz.Lesson__r.Name;
            } else if (quiz.Course__r != null && quiz.Course__r.Name != null) {
                option.assignedTo = 'Course: ' + quiz.Course__r.Name;
            } else {
                option.assignedTo = 'Unassigned';
            }
            
            options.add(option);
        }
        
        return options;
    }
    
    /**
     * @description Updates a lesson to assign a quiz
     * @param lessonId The lesson to update
     * @param quizId The quiz to assign
     * @return true if successful
     */
    @AuraEnabled
    public static Boolean assignQuizToLesson(Id lessonId, Id quizId) {
        try {
            Lesson__c lesson = new Lesson__c(
                Id = lessonId,
                Quiz__c = quizId
            );
            update lesson;
            return true;
        } catch (Exception e) {
            throw new AuraHandledException('Error assigning quiz: ' + e.getMessage());
        }
    }
}
