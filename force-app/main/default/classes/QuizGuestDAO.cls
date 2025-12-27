/**
 * @description Guest-accessible Data Access Object for quiz-related objects
 * Runs WITHOUT SHARING to allow guest users to access quiz data.
 * Mirrors QuizDAO methods but without sharing enforcement.
 * 
 * @author TrailForge Team
 * @date 2025-12-24
 */
public without sharing class QuizGuestDAO {
    
    /**
     * @description Retrieves the quiz for a specific lesson (guest-safe)
     * Only returns quizzes where Level__c = 'Lesson' and Lesson__c matches
     * This ensures quizzes only appear at their designated level
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
            return quizzes[0];
        }
        
        return null;
    }
    
    /**
     * @description Retrieves active module-level quiz (guest-safe)
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
        
        return quizzes.isEmpty() ? null : quizzes[0];
    }
    
    /**
     * @description Retrieves the active course-level quiz (guest-safe)
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
        
        return quizzes.isEmpty() ? null : quizzes[0];
    }
    
    /**
     * @description Retrieves active lesson-level quizzes for multiple lessons (bulk-safe, guest-safe)
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
            if (!result.containsKey(quiz.Lesson__c)) {
                result.put(quiz.Lesson__c, quiz.Id);
            }
        }
        
        return result;
    }
    
    /**
     * @description Retrieves active module-level quizzes for multiple modules (bulk-safe, guest-safe)
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
            if (!result.containsKey(quiz.Module__c)) {
                result.put(quiz.Module__c, quiz);
            }
        }
        
        return result;
    }
    
    /**
     * @description Get questions with answer options for a quiz (guest-safe)
     */
    public static List<Quiz_Question__c> getQuestionsWithOptions(Id quizId) {
        if (quizId == null) {
            return new List<Quiz_Question__c>();
        }
        
        return [
            SELECT Id, Question_Text__c, Question_Type__c, Points__c, Required__c, Sort_Order__c, Explanation__c,
                   (SELECT Id, Answer_Text__c, Sort_Order__c
                    FROM Answer_Options__r
                    WHERE (Is_Active__c = true OR Is_Active__c = null)
                    ORDER BY Sort_Order__c NULLS LAST)
            FROM Quiz_Question__c
            WHERE Quiz__c = :quizId
            ORDER BY Sort_Order__c NULLS LAST
        ];
    }
    
    /**
     * @description Get latest attempt for a quiz (guest-safe)
     */
    public static Quiz_Attempt__c getLatestAttemptForQuiz(Id quizId, Id contactId, Id enrollmentId) {
        if (quizId == null || contactId == null) {
            return null;
        }
        
        String query = 'SELECT Id, Quiz__c, Contact__c, Enrollment__c, Attempt_Number__c, ' +
                       'Score__c, Passed__c, Completed_On__c, Status__c ' +
                       'FROM Quiz_Attempt__c ' +
                       'WHERE Quiz__c = :quizId AND Contact__c = :contactId';
        
        if (enrollmentId != null) {
            query += ' AND Enrollment__c = :enrollmentId';
        }
        
        query += ' ORDER BY CreatedDate DESC LIMIT 1';
        
        List<Quiz_Attempt__c> attempts = Database.query(query);
        return attempts.isEmpty() ? null : attempts[0];
    }
    
    /**
     * @description Count attempts for a quiz (guest-safe)
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
    
    // ========================================================================
    // QUIZ SUBMISSION METHODS (FOR GRADING)
    // ========================================================================
    
    /**
     * @description Retrieves quiz with course relationship for grading (guest-safe)
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
     * @description Get questions with answer options INCLUDING Is_Correct__c for server-side grading (guest-safe)
     * This method should ONLY be used for server-side grading, never for sending data to client
     * @param quizId The ID of the quiz
     * @return List of Quiz_Question__c with answer options
     */
    public static List<Quiz_Question__c> getQuestionsWithOptionsForGrading(Id quizId) {
        if (quizId == null) {
            return new List<Quiz_Question__c>();
        }
        
        return [
            SELECT Id, Name, Question_Text__c, Question_Type__c, Points__c,
                   Required__c, Sort_Order__c,
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
     * @description Inserts a Quiz_Attempt__c record (guest-safe)
     * @param attempt The Quiz_Attempt__c record to insert
     * @return The inserted Quiz_Attempt__c with Id populated
     */
    public static Quiz_Attempt__c insertAttempt(Quiz_Attempt__c attempt) {
        insert attempt;
        return attempt;
    }
    
    /**
     * @description Updates a Quiz_Attempt__c record (guest-safe)
     * @param attempt The Quiz_Attempt__c record to update
     */
    public static void updateAttempt(Quiz_Attempt__c attempt) {
        update attempt;
    }
    
    /**
     * @description Inserts Quiz_Response__c records in bulk (guest-safe)
     * @param responses List of Quiz_Response__c records to insert
     */
    public static void insertResponses(List<Quiz_Response__c> responses) {
        if (responses != null && !responses.isEmpty()) {
            insert responses;
        }
    }
}
