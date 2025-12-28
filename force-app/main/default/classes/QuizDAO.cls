//
// SPDX-License-Identifier: MIT
// TrailForge — Open Source under the MIT License
// Copyright (c) 2025 Robert Davis
// See the LICENSE file in the project root for full license text.
//
/**
 * @description Data Access Object for quiz-related objects
 * Provides bulk-safe query methods for Quiz__c, Quiz_Question__c, Quiz_Answer_Option__c,
 * Quiz_Attempt__c, and Quiz_Response__c
 * 
 * @author TrailForge Team
 * @date 2025-11-25
 */
public with sharing class QuizDAO {
    
    /**
     * @description Retrieves the quiz for a specific lesson
     * Only returns quizzes where Level__c = 'Lesson' and Lesson__c matches
     * This ensures quizzes only appear at their designated level
     * @param lessonId The ID of the lesson
     * @return The Quiz__c record for this lesson, or null if none exists
     */
    public static Quiz__c getActiveQuizForLesson(Id lessonId) {
        if (lessonId == null) {
            return null;
        }
        
        // Only get quizzes where Level = 'Lesson' and Lesson__c points to this lesson
        List<Quiz__c> quizzes = [
            SELECT Id, Name, Lesson__c, Passing_Score__c, Max_Score__c, 
                   Allow_Retakes__c, Active__c, Archived__c, Instructions__c,
                   Time_Limit_Minutes__c, Shuffle_Questions__c, Max_Attempts__c,
                   Modal_Size__c, Level__c, Mode__c
            FROM Quiz__c
            WHERE Lesson__c = :lessonId
              AND Level__c = 'Lesson'
              AND (Archived__c = false OR Archived__c = null)
              AND (Active__c = true OR Active__c = null)
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];
        
        if (!quizzes.isEmpty()) {
            System.debug('QuizDAO: Found lesson-level quiz ' + quizzes[0].Id + ' for lesson ' + lessonId);
            return quizzes[0];
        }
        
        System.debug('QuizDAO: No lesson-level quiz found for lesson ' + lessonId);
        return null;
    }
    
    /**
     * @description Retrieves active module-level quizzes for a module
     * @param moduleId The ID of the module
     * @return The active Quiz__c record, or null if none exists
     */
    public static Quiz__c getActiveModuleQuiz(Id moduleId) {
        if (moduleId == null) {
            return null;
        }
        
        List<Quiz__c> quizzes = [
            SELECT Id, Name, Module__c, Passing_Score__c, Max_Score__c,
                   Allow_Retakes__c, Active__c, Archived__c, Instructions__c,
                   Time_Limit_Minutes__c, Shuffle_Questions__c, Max_Attempts__c,
                   Modal_Size__c, Level__c, Mode__c
            FROM Quiz__c
            WHERE Module__c = :moduleId
              AND Level__c = 'Module'
              AND (Active__c = true OR Active__c = null)
              AND (Archived__c = false OR Archived__c = null)
            ORDER BY Sort_Order__c NULLS LAST
            LIMIT 1
        ];
        
        if (!quizzes.isEmpty()) {
            System.debug('QuizDAO: Found module quiz ' + quizzes[0].Id + ' for module ' + moduleId);
        }
        
        return quizzes.isEmpty() ? null : quizzes[0];
    }
    
    /**
     * @description Retrieves active module-level quizzes for multiple modules (bulk-safe)
     * @param moduleIds Set of module IDs
     * @return Map of module ID to Quiz__c record
     */
    public static Map<Id, Quiz__c> getActiveModuleQuizzes(Set<Id> moduleIds) {
        if (moduleIds == null || moduleIds.isEmpty()) {
            return new Map<Id, Quiz__c>();
        }
        
        List<Quiz__c> quizzes = [
            SELECT Id, Name, Module__c, Passing_Score__c, Max_Score__c,
                   Allow_Retakes__c, Active__c, Archived__c, Instructions__c,
                   Time_Limit_Minutes__c, Shuffle_Questions__c, Max_Attempts__c,
                   Modal_Size__c, Level__c, Mode__c
            FROM Quiz__c
            WHERE Module__c IN :moduleIds
              AND Level__c = 'Module'
              AND (Active__c = true OR Active__c = null)
              AND (Archived__c = false OR Archived__c = null)
            ORDER BY Sort_Order__c NULLS LAST
        ];
        
        Map<Id, Quiz__c> result = new Map<Id, Quiz__c>();
        for (Quiz__c quiz : quizzes) {
            // Only keep first quiz per module (if multiple exist)
            if (!result.containsKey(quiz.Module__c)) {
                result.put(quiz.Module__c, quiz);
            }
        }
        
        System.debug('QuizDAO: Found ' + result.size() + ' module quizzes for ' + moduleIds.size() + ' modules');
        return result;
    }
    
    /**
     * @description Retrieves active lesson-level quizzes for multiple lessons (bulk-safe)
     * Uses the Quiz__c.Lesson__c relationship to find quizzes assigned to lessons
     * @param lessonIds Set of lesson IDs
     * @return Map of lesson ID to quiz ID
     */
    public static Map<Id, Id> getActiveLessonQuizzes(Set<Id> lessonIds) {
        if (lessonIds == null || lessonIds.isEmpty()) {
            return new Map<Id, Id>();
        }
        
        List<Quiz__c> quizzes = [
            SELECT Id, Lesson__c
            FROM Quiz__c
            WHERE Lesson__c IN :lessonIds
              AND Level__c = 'Lesson'
              AND (Active__c = true OR Active__c = null)
              AND (Archived__c = false OR Archived__c = null)
            ORDER BY CreatedDate DESC
        ];
        
        Map<Id, Id> result = new Map<Id, Id>();
        for (Quiz__c quiz : quizzes) {
            // Only keep first quiz per lesson (if multiple exist)
            if (!result.containsKey(quiz.Lesson__c)) {
                result.put(quiz.Lesson__c, quiz.Id);
            }
        }
        
        System.debug('QuizDAO: Found ' + result.size() + ' lesson quizzes for ' + lessonIds.size() + ' lessons');
        return result;
    }
    
    /**
     * @description Retrieves the active course-level quiz
     * @param courseId The ID of the course
     * @return The active Quiz__c record, or null if none exists
     */
    public static Quiz__c getActiveCourseQuiz(Id courseId) {
        if (courseId == null) {
            return null;
        }
        
        List<Quiz__c> quizzes = [
            SELECT Id, Name, Course__c, Passing_Score__c, Max_Score__c,
                   Allow_Retakes__c, Active__c, Archived__c, Instructions__c,
                   Time_Limit_Minutes__c, Shuffle_Questions__c, Max_Attempts__c,
                   Modal_Size__c, Level__c, Mode__c
            FROM Quiz__c
            WHERE Course__c = :courseId
              AND Level__c = 'Course'
              AND (Active__c = true OR Active__c = null)
              AND (Archived__c = false OR Archived__c = null)
            ORDER BY Sort_Order__c NULLS LAST
            LIMIT 1
        ];
        
        if (!quizzes.isEmpty()) {
            System.debug('QuizDAO: Found course quiz ' + quizzes[0].Id + ' for course ' + courseId);
        }
        
        return quizzes.isEmpty() ? null : quizzes[0];
    }
    
    /**
     * @description Retrieves all active questions and answer options for a quiz
     * Uses a parent-child SOQL query for efficiency
     * @param quizId The ID of the quiz
     * @return List of Quiz_Question__c records with child Answer_Options__r
     */
    public static List<Quiz_Question__c> getQuestionsWithOptions(Id quizId) {
        if (quizId == null) {
            return new List<Quiz_Question__c>();
        }
        
        return [
            SELECT Id, Name, Question_Text__c, Question_Type__c, Points__c,
                   Required__c, Sort_Order__c, Explanation__c,
                   (SELECT Id, Name, Answer_Text__c, Is_Correct__c, Sort_Order__c, Is_Active__c
                    FROM Answer_Options__r
                    WHERE Is_Active__c = true
                    ORDER BY Sort_Order__c NULLS LAST, Name)
            FROM Quiz_Question__c
            WHERE Quiz__c = :quizId
            ORDER BY Sort_Order__c NULLS LAST, Name
        ];
    }
    
    /**
     * @description Retrieves the latest quiz attempt for a specific learner and quiz
     * @param quizId The ID of the quiz
     * @param contactId The ID of the contact (learner)
     * @param enrollmentId The ID of the enrollment (optional)
     * @return The most recent Quiz_Attempt__c record, or null if none exists
     */
    public static Quiz_Attempt__c getLatestAttemptForQuiz(Id quizId, Id contactId, Id enrollmentId) {
        if (quizId == null || contactId == null) {
            return null;
        }
        
        String whereClause = 'Quiz__c = :quizId AND Contact__c = :contactId';
        
        // Build query dynamically based on whether enrollmentId is provided
        List<Quiz_Attempt__c> attempts;
        if (enrollmentId != null) {
            attempts = [
                SELECT Id, Name, Quiz__c, Contact__c, Enrollment__c, Attempt_Number__c,
                       Score__c, Score_Percent__c, Passed__c, Started_On__c, 
                       Completed_On__c, Status__c
                FROM Quiz_Attempt__c
                WHERE Quiz__c = :quizId
                  AND Contact__c = :contactId
                  AND Enrollment__c = :enrollmentId
                ORDER BY Attempt_Number__c DESC NULLS LAST, CreatedDate DESC
                LIMIT 1
            ];
        } else {
            attempts = [
                SELECT Id, Name, Quiz__c, Contact__c, Enrollment__c, Attempt_Number__c,
                       Score__c, Score_Percent__c, Passed__c, Started_On__c,
                       Completed_On__c, Status__c
                FROM Quiz_Attempt__c
                WHERE Quiz__c = :quizId
                  AND Contact__c = :contactId
                ORDER BY Attempt_Number__c DESC NULLS LAST, CreatedDate DESC
                LIMIT 1
            ];
        }
        
        return attempts.isEmpty() ? null : attempts[0];
    }
    
    /**
     * @description Retrieves all attempts for a quiz by a specific learner (bulk-safe)
     * @param quizId The ID of the quiz
     * @param contactId The ID of the contact
     * @return List of Quiz_Attempt__c records ordered by attempt number
     */
    public static List<Quiz_Attempt__c> getAttemptsForQuiz(Id quizId, Id contactId) {
        if (quizId == null || contactId == null) {
            return new List<Quiz_Attempt__c>();
        }
        
        return [
            SELECT Id, Name, Quiz__c, Contact__c, Enrollment__c, Attempt_Number__c,
                   Score__c, Score_Percent__c, Passed__c, Started_On__c,
                   Completed_On__c, Status__c
            FROM Quiz_Attempt__c
            WHERE Quiz__c = :quizId
              AND Contact__c = :contactId
            ORDER BY Attempt_Number__c DESC NULLS LAST, CreatedDate DESC
        ];
    }
    
    /**
     * @description Retrieves responses for a quiz attempt with question and option details
     * @param attemptId The ID of the quiz attempt
     * @return List of Quiz_Response__c records with relationships
     */
    public static List<Quiz_Response__c> getResponsesForAttempt(Id attemptId) {
        if (attemptId == null) {
            return new List<Quiz_Response__c>();
        }
        
        return [
            SELECT Id, Name, Quiz_Attempt__c, Quiz_Question__c, Quiz_Answer_Option__c,
                   Is_Correct__c, Points_Earned__c,
                   Quiz_Question__r.Question_Text__c, Quiz_Question__r.Question_Type__c,
                   Quiz_Answer_Option__r.Answer_Text__c, Quiz_Answer_Option__r.Is_Correct__c
            FROM Quiz_Response__c
            WHERE Quiz_Attempt__c = :attemptId
            ORDER BY CreatedDate
        ];
    }
    
    /**
     * @description Counts the number of attempts for a quiz by a learner
     * @param quizId The ID of the quiz
     * @param contactId The ID of the contact
     * @return The count of attempts
     */
    public static Integer countAttempts(Id quizId, Id contactId) {
        if (quizId == null || contactId == null) {
            return 0;
        }
        
        return [
            SELECT COUNT()
            FROM Quiz_Attempt__c
            WHERE Quiz__c = :quizId
              AND Contact__c = :contactId
        ];
    }
    
    /**
     * @description Retrieves quiz with course relationship for grading
     * @param quizId The ID of the quiz
     * @return Quiz__c record with course information
     */
    public static Quiz__c getQuizWithCourse(Id quizId) {
        if (quizId == null) {
            return null;
        }
        
        List<Quiz__c> quizzes = [
            SELECT Id, Name, Passing_Score__c, Max_Score__c, Allow_Retakes__c, Max_Attempts__c,
                   Course__c, Lesson__c, Lesson__r.Module__r.Course__c
            FROM Quiz__c
            WHERE Id = :quizId
            LIMIT 1
        ];
        
        return quizzes.isEmpty() ? null : quizzes[0];
    }
    
    /**
     * @description Inserts a Quiz_Attempt__c record
     * @param attempt The Quiz_Attempt__c record to insert
     * @return The inserted Quiz_Attempt__c with Id populated
     */
    public static Quiz_Attempt__c insertAttempt(Quiz_Attempt__c attempt) {
        insert attempt;
        return attempt;
    }
    
    /**
     * @description Updates a Quiz_Attempt__c record
     * @param attempt The Quiz_Attempt__c record to update
     */
    public static void updateAttempt(Quiz_Attempt__c attempt) {
        update attempt;
    }
    
    /**
     * @description Inserts Quiz_Response__c records in bulk
     * @param responses List of Quiz_Response__c records to insert
     */
    public static void insertResponses(List<Quiz_Response__c> responses) {
        if (responses != null && !responses.isEmpty()) {
            insert responses;
        }
    }
    
    /**
     * @description Retrieves the most recent quiz attempt for a quiz/contact combination
     * @param quizId The ID of the quiz
     * @param enrollmentId The ID of the enrollment (optional)
     * @param contactId The ID of the contact
     * @return The most recent Quiz_Attempt__c or null if none exists
     */
    public static Quiz_Attempt__c getLastAttemptForQuiz(Id quizId, Id enrollmentId, Id contactId) {
        if (quizId == null || contactId == null) {
            return null;
        }
        
        String queryString = 
            'SELECT Id, Quiz__c, Enrollment__c, Contact__c, Course__c, ' +
            'Score__c, Score_Percent__c, Passed__c, Attempt_Number__c, ' +
            'Completed_On__c, Status__c, ' +
            'Quiz__r.Max_Score__c, Quiz__r.Passing_Score__c ' +
            'FROM Quiz_Attempt__c ' +
            'WHERE Quiz__c = :quizId AND Contact__c = :contactId';
        
        if (enrollmentId != null) {
            queryString += ' AND Enrollment__c = :enrollmentId';
        }
        
        queryString += ' ORDER BY Completed_On__c DESC, CreatedDate DESC LIMIT 1';
        
        List<Quiz_Attempt__c> attempts = Database.query(queryString);
        
        return attempts.isEmpty() ? null : attempts[0];
    }
    
    /**
     * @description Retrieves a quiz attempt with all related information for review
     * @param attemptId The ID of the quiz attempt
     * @return Quiz_Attempt__c with relationships or null if not found
     */
    public static Quiz_Attempt__c getAttemptWithRelationships(Id attemptId) {
        if (attemptId == null) {
            return null;
        }
        
        List<Quiz_Attempt__c> attempts = [
            SELECT Id, Quiz__c, Enrollment__c, Contact__c, Course__c,
                   Score__c, Score_Percent__c, Passed__c, Attempt_Number__c,
                   Completed_On__c, Status__c,
                   Quiz__r.Id, Quiz__r.Name, Quiz__r.Max_Score__c, Quiz__r.Passing_Score__c,
                   Quiz__r.Lesson__c, Quiz__r.Lesson__r.Name
            FROM Quiz_Attempt__c
            WHERE Id = :attemptId
            LIMIT 1
        ];
        
        return attempts.isEmpty() ? null : attempts[0];
    }
}