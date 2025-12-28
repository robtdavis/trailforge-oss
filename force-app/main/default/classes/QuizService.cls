//
// SPDX-License-Identifier: MIT
// TrailForge — Open Source under the MIT License
// Copyright (c) 2025 Robert Davis
// See the LICENSE file in the project root for full license text.
//
/**
 * @description Service layer for quiz functionality
 * Orchestrates quiz loading, attempt creation, and grading
 * Integrates with H2_EnrollmentService for completion gating
 * 
 * @author TrailForge Team
 * @date 2025-11-25
 * @version 1.1 - Fixed lessonId validation for course-level quizzes
 */
public with sharing class QuizService {
    
    /**
     * @description DTO for quiz context (quiz metadata + questions + latest attempt)
     */
    public class QuizContextDTO {
        @AuraEnabled public Id quizId { get; set; }
        @AuraEnabled public Id lessonId { get; set; }
        @AuraEnabled public Id moduleId { get; set; }
        @AuraEnabled public Id courseId { get; set; }
        @AuraEnabled public String quizName { get; set; }
        @AuraEnabled public Decimal passingScore { get; set; }
        @AuraEnabled public Decimal maxScore { get; set; }
        @AuraEnabled public Boolean allowRetakes { get; set; }
        @AuraEnabled public String instructions { get; set; }
        @AuraEnabled public Integer timeLimit { get; set; }
        @AuraEnabled public String modalSize { get; set; }
        @AuraEnabled public String mode { get; set; } // 'Training' or 'Exam'
        @AuraEnabled public List<QuestionDTO> questions { get; set; }
        @AuraEnabled public AttemptDTO latestAttempt { get; set; }
        @AuraEnabled public Integer attemptCount { get; set; }
        @AuraEnabled public Integer maxAttempts { get; set; }
        
        public QuizContextDTO() {
            this.questions = new List<QuestionDTO>();
            this.modalSize = 'large'; // Default quiz modal size
            this.mode = 'Exam'; // Default mode
        }
    }
    
    /**
     * @description DTO for a quiz question
     */
    public class QuestionDTO {
        @AuraEnabled public Id questionId { get; set; }
        @AuraEnabled public String questionText { get; set; }
        @AuraEnabled public String questionType { get; set; }
        @AuraEnabled public Decimal points { get; set; }
        @AuraEnabled public Boolean required { get; set; }
        @AuraEnabled public String explanation { get; set; } // Shown in Training mode after answering
        @AuraEnabled public List<AnswerOptionDTO> options { get; set; }
        
        public QuestionDTO() {
            this.options = new List<AnswerOptionDTO>();
        }
    }
    
    /**
     * @description DTO for an answer option
     */
    public class AnswerOptionDTO {
        @AuraEnabled public Id optionId { get; set; }
        @AuraEnabled public String answerText { get; set; }
        // Note: Do NOT expose Is_Correct__c to the LWC (security)
        
        public AnswerOptionDTO() {}
    }
    
    /**
     * @description DTO for a quiz attempt
     */
    public class AttemptDTO {
        @AuraEnabled public Id attemptId { get; set; }
        @AuraEnabled public Integer attemptNumber { get; set; }
        @AuraEnabled public Decimal score { get; set; }
        @AuraEnabled public Decimal scorePercent { get; set; }
        @AuraEnabled public Boolean passed { get; set; }
        @AuraEnabled public DateTime completedOn { get; set; }
        @AuraEnabled public String status { get; set; }
        
        public AttemptDTO() {}
    }
    
    /**
     * @description DTO for quiz submission request
     */
    public class QuizSubmissionRequestDTO {
        @AuraEnabled public Id quizId { get; set; }
        @AuraEnabled public Id lessonId { get; set; }
        @AuraEnabled public Id enrollmentId { get; set; }
        @AuraEnabled public Id contactId { get; set; }
        @AuraEnabled public List<SubmittedAnswerDTO> answers { get; set; }
        
        public QuizSubmissionRequestDTO() {
            this.answers = new List<SubmittedAnswerDTO>();
        }
    }
    
    /**
     * @description DTO for a submitted answer
     */
    public class SubmittedAnswerDTO {
        @AuraEnabled public Id questionId { get; set; }
        @AuraEnabled public List<Id> selectedOptionIds { get; set; }
        
        public SubmittedAnswerDTO() {
            this.selectedOptionIds = new List<Id>();
        }
    }
    
    /**
     * @description DTO for quiz submission result
     */
    public class QuizSubmissionResultDTO {
        @AuraEnabled public Id quizId { get; set; }
        @AuraEnabled public Id lessonId { get; set; }
        @AuraEnabled public Id enrollmentId { get; set; }
        @AuraEnabled public Id attemptId { get; set; }
        @AuraEnabled public Decimal score { get; set; }
        @AuraEnabled public Decimal maxScore { get; set; }
        @AuraEnabled public Decimal passingScore { get; set; }
        @AuraEnabled public Boolean passed { get; set; }
        @AuraEnabled public Integer attemptNumber { get; set; }
        @AuraEnabled public String message { get; set; }
        
        public QuizSubmissionResultDTO() {}
    }
    
    /**
     * @description DTO for quiz attempt summary (lightweight version for listing)
     */
    public class QuizAttemptSummaryDTO {
        @AuraEnabled public Id attemptId { get; set; }
        @AuraEnabled public Id quizId { get; set; }
        @AuraEnabled public Id lessonId { get; set; }
        @AuraEnabled public Id enrollmentId { get; set; }
        @AuraEnabled public Decimal score { get; set; }
        @AuraEnabled public Decimal maxScore { get; set; }
        @AuraEnabled public Decimal passingScore { get; set; }
        @AuraEnabled public Boolean passed { get; set; }
        @AuraEnabled public Integer attemptNumber { get; set; }
        @AuraEnabled public Datetime attemptedOn { get; set; }
        
        public QuizAttemptSummaryDTO() {}
    }
    
    /**
     * @description DTO for quiz attempt detail with answers for review mode
     */
    public class QuizAttemptDetailDTO {
        @AuraEnabled public Id attemptId { get; set; }
        @AuraEnabled public Id quizId { get; set; }
        @AuraEnabled public Id lessonId { get; set; }
        @AuraEnabled public Id enrollmentId { get; set; }
        @AuraEnabled public Decimal score { get; set; }
        @AuraEnabled public Decimal maxScore { get; set; }
        @AuraEnabled public Decimal passingScore { get; set; }
        @AuraEnabled public Boolean passed { get; set; }
        @AuraEnabled public Integer attemptNumber { get; set; }
        @AuraEnabled public Datetime attemptedOn { get; set; }
        @AuraEnabled public List<ReviewedQuestionDTO> questions { get; set; }
        
        public QuizAttemptDetailDTO() {
            this.questions = new List<ReviewedQuestionDTO>();
        }
    }
    
    /**
     * @description DTO for a question in review mode
     */
    public class ReviewedQuestionDTO {
        @AuraEnabled public Id questionId { get; set; }
        @AuraEnabled public String questionText { get; set; }
        @AuraEnabled public String questionType { get; set; }
        @AuraEnabled public Decimal points { get; set; }
        @AuraEnabled public Boolean required { get; set; }
        @AuraEnabled public List<ReviewedAnswerOptionDTO> options { get; set; }
        
        public ReviewedQuestionDTO() {
            this.options = new List<ReviewedAnswerOptionDTO>();
        }
    }
    
    /**
     * @description DTO for an answer option in review mode (includes selected and correct flags)
     */
    public class ReviewedAnswerOptionDTO {
        @AuraEnabled public Id optionId { get; set; }
        @AuraEnabled public String answerText { get; set; }
        @AuraEnabled public Boolean selected { get; set; }
        @AuraEnabled public Boolean correct { get; set; }
        
        public ReviewedAnswerOptionDTO() {}
    }
    
    /**
     * @description DTO for quiz submission (DEPRECATED - use QuizSubmissionRequestDTO)
     */
    public class QuizSubmissionDTO {
        @AuraEnabled public Id quizId { get; set; }
        @AuraEnabled public Id contactId { get; set; }
        @AuraEnabled public Id enrollmentId { get; set; }
        @AuraEnabled public List<ResponseDTO> responses { get; set; }
        
        public QuizSubmissionDTO() {
            this.responses = new List<ResponseDTO>();
        }
    }
    
    /**
     * @description DTO for a single response
     */
    public class ResponseDTO {
        @AuraEnabled public Id questionId { get; set; }
        @AuraEnabled public Id selectedOptionId { get; set; }
        
        public ResponseDTO() {}
    }
    
    /**
     * @description DTO for grading result
     */
    public class GradingResultDTO {
        @AuraEnabled public Id attemptId { get; set; }
        @AuraEnabled public Decimal score { get; set; }
        @AuraEnabled public Decimal scorePercent { get; set; }
        @AuraEnabled public Boolean passed { get; set; }
        @AuraEnabled public Integer attemptNumber { get; set; }
        @AuraEnabled public String message { get; set; }
        
        public GradingResultDTO() {}
    }
    
    /**
     * @description Retrieves quiz data for UI display (for standalone quiz player)
     * @param quizId The ID of the quiz
     * @param contactId The ID of the learner
     * @param enrollmentId The ID of the enrollment (optional)
     * @return QuizContextDTO with quiz metadata, questions, and latest attempt
     */
    @AuraEnabled(cacheable=true)
    public static QuizContextDTO getQuizForUi(Id quizId, Id contactId, Id enrollmentId) {
        try {
            // Query the quiz directly
            List<Quiz__c> quizzes = [
                SELECT Id, Name, Lesson__c, Passing_Score__c, Max_Score__c,
                       Allow_Retakes__c, Active__c, Archived__c, Instructions__c,
                       Time_Limit_Minutes__c, Shuffle_Questions__c, Max_Attempts__c
                FROM Quiz__c
                WHERE Id = :quizId
                LIMIT 1
            ];
            
            if (quizzes.isEmpty()) {
                return null;
            }
            
            Quiz__c quiz = quizzes[0];
            
            // Build context DTO
            QuizContextDTO context = new QuizContextDTO();
            context.quizId = quiz.Id;
            context.lessonId = quiz.Lesson__c; // Include lessonId for navigation
            context.quizName = quiz.Name;
            context.passingScore = quiz.Passing_Score__c != null ? quiz.Passing_Score__c : 70;
            context.maxScore = quiz.Max_Score__c;
            context.allowRetakes = quiz.Allow_Retakes__c != null ? quiz.Allow_Retakes__c : true;
            context.instructions = quiz.Instructions__c;
            context.timeLimit = quiz.Time_Limit_Minutes__c != null ? Integer.valueOf(quiz.Time_Limit_Minutes__c) : null;
            context.maxAttempts = quiz.Max_Attempts__c != null ? Integer.valueOf(quiz.Max_Attempts__c) : 0;
            
            // Load questions and answer options (delegate to DAO)
            List<Quiz_Question__c> questions = QuizDAO.getQuestionsWithOptions(quiz.Id);
            Decimal calculatedMaxScore = 0;
            
            for (Quiz_Question__c question : questions) {
                QuestionDTO qDTO = new QuestionDTO();
                qDTO.questionId = question.Id;
                qDTO.questionText = question.Question_Text__c;
                qDTO.questionType = question.Question_Type__c;
                qDTO.points = question.Points__c != null ? question.Points__c : 1;
                qDTO.required = question.Required__c != null ? question.Required__c : true;
                
                calculatedMaxScore += qDTO.points;
                
                // Load answer options (DO NOT include Is_Correct__c for security)
                for (Quiz_Answer_Option__c option : question.Answer_Options__r) {
                    AnswerOptionDTO aDTO = new AnswerOptionDTO();
                    aDTO.optionId = option.Id;
                    aDTO.answerText = option.Answer_Text__c;
                    qDTO.options.add(aDTO);
                }
                
                context.questions.add(qDTO);
            }
            
            // If Max_Score__c not set on quiz, use calculated value
            if (context.maxScore == null) {
                context.maxScore = calculatedMaxScore;
            }
            
            // Load latest attempt if exists (delegate to DAO)
            Quiz_Attempt__c latestAttempt = QuizDAO.getLatestAttemptForQuiz(quiz.Id, contactId, enrollmentId);
            if (latestAttempt != null) {
                context.latestAttempt = mapAttemptToDTO(latestAttempt);
            }
            
            // Count total attempts (delegate to DAO)
            context.attemptCount = QuizDAO.countAttempts(quiz.Id, contactId);
            
            return context;
            
        } catch (Exception e) {
            Logger.logError('QuizService', 'getQuizForUi', e, 0);
            throw new AuraHandledException('Unable to load quiz: ' + e.getMessage());
        }
    }
    
    /**
     * @description Retrieves quiz context for a lesson (cacheable for performance)
     * @param lessonId The ID of the lesson
     * @param contactId The ID of the learner
     * @param enrollmentId The ID of the enrollment (optional)
     * @return QuizContextDTO with quiz metadata, questions, and latest attempt
     */
    @AuraEnabled(cacheable=true)
    public static QuizContextDTO getLessonQuizContext(Id lessonId, Id contactId, Id enrollmentId) {
        try {
            System.debug('QuizService.getLessonQuizContext called for lesson: ' + lessonId);
            
            // Query the active quiz for this lesson
            Quiz__c quiz = QuizDAO.getActiveQuizForLesson(lessonId);
            
            if (quiz == null) {
                System.debug('QUIZ CTX for lesson ' + lessonId + ' = null (no quiz found)');
                return null; // No quiz for this lesson
            }
            
            System.debug('QuizService: Building context for quiz ' + quiz.Id);
            
            // Build context DTO
            QuizContextDTO context = new QuizContextDTO();
            context.quizId = quiz.Id;
            context.lessonId = lessonId; // Include lessonId for navigation
            context.quizName = quiz.Name;
            context.passingScore = quiz.Passing_Score__c != null ? quiz.Passing_Score__c : 70;
            context.maxScore = quiz.Max_Score__c;
            context.allowRetakes = quiz.Allow_Retakes__c != null ? quiz.Allow_Retakes__c : true;
            context.instructions = quiz.Instructions__c;
            context.timeLimit = quiz.Time_Limit_Minutes__c != null ? Integer.valueOf(quiz.Time_Limit_Minutes__c) : null;
            context.maxAttempts = quiz.Max_Attempts__c != null ? Integer.valueOf(quiz.Max_Attempts__c) : 0;
            context.modalSize = String.isNotBlank(quiz.Modal_Size__c) ? quiz.Modal_Size__c : 'large';
            
            // Load questions and answer options
            List<Quiz_Question__c> questions = QuizDAO.getQuestionsWithOptions(quiz.Id);
            Decimal calculatedMaxScore = 0;
            
            for (Quiz_Question__c question : questions) {
                QuestionDTO qDTO = new QuestionDTO();
                qDTO.questionId = question.Id;
                qDTO.questionText = question.Question_Text__c;
                qDTO.questionType = question.Question_Type__c;
                qDTO.points = question.Points__c != null ? question.Points__c : 1;
                qDTO.required = question.Required__c != null ? question.Required__c : true;
                
                calculatedMaxScore += qDTO.points;
                
                // Load answer options (DO NOT include Is_Correct__c for security)
                for (Quiz_Answer_Option__c option : question.Answer_Options__r) {
                    AnswerOptionDTO aDTO = new AnswerOptionDTO();
                    aDTO.optionId = option.Id;
                    aDTO.answerText = option.Answer_Text__c;
                    qDTO.options.add(aDTO);
                }
                
                context.questions.add(qDTO);
            }
            
            // If Max_Score__c not set on quiz, use calculated value
            if (context.maxScore == null) {
                context.maxScore = calculatedMaxScore;
            }
            
            // Load latest attempt if exists (optional - don't fail if this errors)
            try {
                Quiz_Attempt__c latestAttempt = QuizDAO.getLatestAttemptForQuiz(quiz.Id, contactId, enrollmentId);
                if (latestAttempt != null) {
                    context.latestAttempt = mapAttemptToDTO(latestAttempt);
                }
            } catch (Exception attemptEx) {
                System.debug('Warning: Could not load latest attempt: ' + attemptEx.getMessage());
                // Continue - this is optional data
            }
            
            // Count total attempts (optional - don't fail if this errors)
            try {
                context.attemptCount = QuizDAO.countAttempts(quiz.Id, contactId);
            } catch (Exception countEx) {
                System.debug('Warning: Could not count attempts: ' + countEx.getMessage());
                context.attemptCount = 0; // Default to 0
            }
            
            // Debug: Log what we're returning
            System.debug('QUIZ CTX for lesson ' + lessonId + ' = ' + JSON.serialize(context));
            
            return context;
            
        } catch (Exception e) {
            System.debug('QUIZ CTX ERROR for lesson ' + lessonId + ': ' + e.getMessage());
            Logger.logError('QuizService', 'getLessonQuizContext', e, 0);
            throw new AuraHandledException('Unable to load quiz: ' + e.getMessage());
        }
    }
    
    /**
     * @description Loads quiz context for a module-level quiz
     * @param moduleId The ID of the module
     * @param contactId The ID of the learner
     * @param enrollmentId The ID of the enrollment (optional)
     * @return QuizContextDTO with quiz metadata, questions, and latest attempt
     */
    @AuraEnabled(cacheable=true)
    public static QuizContextDTO getModuleQuizContext(Id moduleId, Id contactId, Id enrollmentId) {
        try {
            System.debug('QuizService.getModuleQuizContext called for module: ' + moduleId);
            
            // Query the active module-level quiz
            Quiz__c quiz = QuizDAO.getActiveModuleQuiz(moduleId);
            
            if (quiz == null) {
                System.debug('MODULE QUIZ CTX for module ' + moduleId + ' = null (no quiz found)');
                return null;
            }
            
            System.debug('QuizService: Building context for module quiz ' + quiz.Id);
            
            return buildQuizContextDTO(quiz, null, moduleId, contactId, enrollmentId);
            
        } catch (Exception e) {
            System.debug('MODULE QUIZ CTX ERROR for module ' + moduleId + ': ' + e.getMessage());
            Logger.logError('QuizService', 'getModuleQuizContext', e, 0);
            throw new AuraHandledException('Unable to load module quiz: ' + e.getMessage());
        }
    }
    
    /**
     * @description Loads quiz context for a course-level quiz
     * @param courseId The ID of the course
     * @param contactId The ID of the learner
     * @param enrollmentId The ID of the enrollment (optional)
     * @return QuizContextDTO with quiz metadata, questions, and latest attempt
     */
    @AuraEnabled(cacheable=true)
    public static QuizContextDTO getCourseQuizContext(Id courseId, Id contactId, Id enrollmentId) {
        try {
            System.debug('QuizService.getCourseQuizContext called for course: ' + courseId);
            
            // Query the active course-level quiz
            Quiz__c quiz = QuizDAO.getActiveCourseQuiz(courseId);
            
            if (quiz == null) {
                System.debug('COURSE QUIZ CTX for course ' + courseId + ' = null (no quiz found)');
                return null;
            }
            
            System.debug('QuizService: Building context for course quiz ' + quiz.Id);
            
            return buildQuizContextDTO(quiz, null, null, contactId, enrollmentId);
            
        } catch (Exception e) {
            System.debug('COURSE QUIZ CTX ERROR for course ' + courseId + ': ' + e.getMessage());
            Logger.logError('QuizService', 'getCourseQuizContext', e, 0);
            throw new AuraHandledException('Unable to load course quiz: ' + e.getMessage());
        }
    }
    
    /**
     * @description Helper to build QuizContextDTO from a Quiz__c record
     * @param quiz The Quiz__c record
     * @param lessonId Optional lesson ID (for lesson-level quizzes)
     * @param moduleId Optional module ID (for module-level quizzes)
     * @param contactId The learner's contact ID
     * @param enrollmentId Optional enrollment ID
     * @return Fully populated QuizContextDTO
     */
    private static QuizContextDTO buildQuizContextDTO(Quiz__c quiz, Id lessonId, Id moduleId, Id contactId, Id enrollmentId) {
        QuizContextDTO context = new QuizContextDTO();
        context.quizId = quiz.Id;
        context.lessonId = lessonId;
        context.moduleId = moduleId;
        context.quizName = quiz.Name;
        context.passingScore = quiz.Passing_Score__c != null ? quiz.Passing_Score__c : 70;
        context.maxScore = quiz.Max_Score__c;
        context.allowRetakes = quiz.Allow_Retakes__c != null ? quiz.Allow_Retakes__c : true;
        context.instructions = quiz.Instructions__c;
        context.timeLimit = quiz.Time_Limit_Minutes__c != null ? Integer.valueOf(quiz.Time_Limit_Minutes__c) : null;
        context.maxAttempts = quiz.Max_Attempts__c != null ? Integer.valueOf(quiz.Max_Attempts__c) : 0;
        context.modalSize = String.isNotBlank(quiz.Modal_Size__c) ? quiz.Modal_Size__c : 'large';
        context.mode = String.isNotBlank(quiz.Mode__c) ? quiz.Mode__c : 'Exam';
        
        // Load questions and answer options
        List<Quiz_Question__c> questions = QuizDAO.getQuestionsWithOptions(quiz.Id);
        Decimal calculatedMaxScore = 0;
        
        for (Quiz_Question__c question : questions) {
            QuestionDTO qDTO = new QuestionDTO();
            qDTO.questionId = question.Id;
            qDTO.questionText = question.Question_Text__c;
            qDTO.questionType = question.Question_Type__c;
            qDTO.points = question.Points__c != null ? question.Points__c : 1;
            qDTO.required = question.Required__c != null ? question.Required__c : true;
            qDTO.explanation = question.Explanation__c;
            
            calculatedMaxScore += qDTO.points;
            
            // Load answer options (DO NOT include Is_Correct__c for security)
            for (Quiz_Answer_Option__c option : question.Answer_Options__r) {
                AnswerOptionDTO aDTO = new AnswerOptionDTO();
                aDTO.optionId = option.Id;
                aDTO.answerText = option.Answer_Text__c;
                qDTO.options.add(aDTO);
            }
            
            context.questions.add(qDTO);
        }
        
        // If Max_Score__c not set on quiz, use calculated value
        if (context.maxScore == null) {
            context.maxScore = calculatedMaxScore;
        }
        
        // Load latest attempt if exists
        try {
            Quiz_Attempt__c latestAttempt = QuizDAO.getLatestAttemptForQuiz(quiz.Id, contactId, enrollmentId);
            if (latestAttempt != null) {
                context.latestAttempt = mapAttemptToDTO(latestAttempt);
            }
        } catch (Exception attemptEx) {
            System.debug('Warning: Could not load latest attempt: ' + attemptEx.getMessage());
        }
        
        // Count total attempts
        try {
            context.attemptCount = QuizDAO.countAttempts(quiz.Id, contactId);
        } catch (Exception countEx) {
            System.debug('Warning: Could not count attempts: ' + countEx.getMessage());
            context.attemptCount = 0;
        }
        
        return context;
    }
    
    /**
     * @description Submits a quiz attempt using a DTO - convenience overload
     * @param request QuizSubmissionRequestDTO containing all submission data
     * @return QuizSubmissionResultDTO with score, pass/fail, and attempt details
     */
    public static QuizSubmissionResultDTO submitQuizAttempt(QuizSubmissionRequestDTO request) {
        return submitQuizAttempt(
            request.quizId,
            request.lessonId,
            request.contactId,
            request.enrollmentId,
            request.answers
        );
    }
    
    /**
     * @description Submits a quiz attempt and grades it
     * @param quizId ID of the quiz
     * @param lessonId ID of the lesson (optional for course-level quizzes)
     * @param contactId ID of the contact/learner
     * @param enrollmentId ID of the enrollment
     * @param answers List of submitted answers
     * @return QuizSubmissionResultDTO with score, pass/fail, and attempt details
     */
    @AuraEnabled
    public static QuizSubmissionResultDTO submitQuizAttempt(
        Id quizId, 
        Id lessonId, 
        Id contactId, 
        Id enrollmentId, 
        List<SubmittedAnswerDTO> answers
    ) {
        try {
            System.debug('=== submitQuizAttempt START ===');
            System.debug('quizId: ' + quizId);
            System.debug('lessonId: ' + lessonId);
            System.debug('contactId: ' + contactId);
            System.debug('enrollmentId: ' + enrollmentId);
            System.debug('answers: ' + JSON.serialize(answers));
            
            // Validate required fields
            if (quizId == null) {
                throw new IllegalArgumentException('Quiz ID is required');
            }
            if (contactId == null) {
                throw new IllegalArgumentException('Contact ID is required');
            }
            // lessonId is optional - course-level quizzes don't have a lesson
            
            System.debug('Loading quiz with course relationship...');
            // Load quiz with course relationship via DAO
            Quiz__c quiz = QuizDAO.getQuizWithCourse(quizId);
            System.debug('Quiz loaded: ' + quiz);
            
            if (quiz == null) {
                throw new IllegalArgumentException('Quiz not found: ' + quizId);
            }
            
            System.debug('Loading questions with options...');
            // Load questions with answer options via DAO
            List<Quiz_Question__c> questions = QuizDAO.getQuestionsWithOptions(quizId);
            System.debug('Questions loaded: ' + questions.size());
            
            // Build maps for grading
            Map<Id, Quiz_Question__c> questionMap = new Map<Id, Quiz_Question__c>();
            Map<Id, Quiz_Answer_Option__c> optionMap = new Map<Id, Quiz_Answer_Option__c>();
            
            System.debug('Building question and option maps...');
            for (Quiz_Question__c q : questions) {
                questionMap.put(q.Id, q);
                System.debug('Question: ' + q.Id + ', Answer_Options__r: ' + q.Answer_Options__r);
                if (q.Answer_Options__r != null) {
                    for (Quiz_Answer_Option__c opt : q.Answer_Options__r) {
                        optionMap.put(opt.Id, opt);
                    }
                }
            }
            System.debug('Question map size: ' + questionMap.size());
            System.debug('Option map size: ' + optionMap.size());
            
            System.debug('Checking attempt limits...');
            // Check attempt limits via DAO
            Integer attemptCount = QuizDAO.countAttempts(quizId, contactId);
            System.debug('Attempt count: ' + attemptCount);
            
            Integer maxAttempts = quiz.Max_Attempts__c != null ? Integer.valueOf(quiz.Max_Attempts__c) : 0;
            
            if (maxAttempts > 0 && attemptCount >= maxAttempts) {
                throw new IllegalArgumentException('Maximum attempts (' + maxAttempts + ') reached for this quiz');
            }
            
            // Determine Course ID (required field on Quiz_Attempt__c)
            Id courseId = null;
            if (quiz.Course__c != null) {
                courseId = quiz.Course__c;
            } else if (quiz.Lesson__r != null && quiz.Lesson__r.Module__r != null && quiz.Lesson__r.Module__r.Course__c != null) {
                courseId = quiz.Lesson__r.Module__r.Course__c;
            }
            
            if (courseId == null) {
                throw new IllegalArgumentException('Cannot determine course for quiz attempt');
            }
            
            // Create Quiz_Attempt__c record
            Quiz_Attempt__c attempt = new Quiz_Attempt__c();
            attempt.Quiz__c = quizId;
            attempt.Contact__c = contactId;
            attempt.Enrollment__c = enrollmentId;
            attempt.Course__c = courseId;
            attempt.Score__c = 0; // Will be updated after grading
            attempt.Attempt_Number__c = attemptCount + 1;
            attempt.Started_On__c = DateTime.now();
            attempt.Completed_On__c = DateTime.now();
            attempt.Status__c = 'Completed';
            
            // Insert via DAO
            attempt = QuizDAO.insertAttempt(attempt);
            
            // Grade responses and build Quiz_Response__c records
            List<Quiz_Response__c> responses = new List<Quiz_Response__c>();
            Decimal totalScore = 0;
            Decimal maxScore = 0;
            
            for (SubmittedAnswerDTO answer : answers) {
                Quiz_Question__c question = questionMap.get(answer.questionId);
                if (question == null) {
                    continue; // Skip invalid question
                }
                
                Decimal questionPoints = question.Points__c != null ? question.Points__c : 1;
                maxScore += questionPoints;
                
                // For now, handle single-select (take first selectedOptionId)
                // Future: support multiple-select by checking all selected options
                if (answer.selectedOptionIds != null && !answer.selectedOptionIds.isEmpty()) {
                    Id selectedOptionId = answer.selectedOptionIds[0];
                    Quiz_Answer_Option__c selectedOption = optionMap.get(selectedOptionId);
                    
                    if (selectedOption != null) {
                        Boolean isCorrect = selectedOption.Is_Correct__c;
                        Decimal pointsEarned = isCorrect ? questionPoints : 0;
                        totalScore += pointsEarned;
                        
                        Quiz_Response__c response = new Quiz_Response__c();
                        response.Quiz_Attempt__c = attempt.Id;
                        response.Quiz_Question__c = answer.questionId;
                        response.Quiz_Answer_Option__c = selectedOptionId;
                        response.Is_Correct__c = isCorrect;
                        response.Points_Earned__c = pointsEarned;
                        
                        responses.add(response);
                    }
                }
            }
            
            // Insert responses via DAO
            QuizDAO.insertResponses(responses);
            
            // Calculate score percentage and pass/fail
            Decimal scorePercent = maxScore > 0 ? (totalScore / maxScore * 100) : 0;
            Decimal passingScore = quiz.Passing_Score__c != null ? quiz.Passing_Score__c : 70;
            Boolean passed = scorePercent >= passingScore;
            
            // Update attempt with final scores
            attempt.Score__c = totalScore;
            attempt.Score_Percent__c = scorePercent;
            attempt.Passed__c = passed;
            QuizDAO.updateAttempt(attempt);
            
            // Log result
            Logger.logInfo('QuizService', 'submitQuizAttempt',
                'Quiz attempt graded: Attempt ' + attempt.Attempt_Number__c + 
                ', Score: ' + scorePercent + '%, Passed: ' + passed);
            
            // If passed and enrollment exists, update enrollment
            if (passed && enrollmentId != null) {
                try {
                    EnrollmentService.applyQuizResultToEnrollment(
                        enrollmentId, 
                        quizId, 
                        scorePercent, 
                        passed
                    );
                } catch (Exception enrollmentEx) {
                    // Don't fail the quiz submission if enrollment update fails
                    Logger.logError('QuizService', 'submitQuizAttempt - enrollment update', enrollmentEx, 0);
                }
            }
            
            // Build result DTO
            QuizSubmissionResultDTO result = new QuizSubmissionResultDTO();
            result.quizId = quizId;
            result.lessonId = lessonId;
            result.enrollmentId = enrollmentId;
            result.attemptId = attempt.Id;
            result.score = totalScore;
            result.maxScore = maxScore;
            result.passingScore = passingScore;
            result.passed = passed;
            result.attemptNumber = Integer.valueOf(attempt.Attempt_Number__c);
            result.message = passed ? 
                'Congratulations! You passed with ' + scorePercent.setScale(1) + '%' :
                'You scored ' + scorePercent.setScale(1) + '%. Passing score is ' + passingScore.setScale(0) + '%';
            
            return result;
            
        } catch (Exception e) {
            Logger.logError('QuizService', 'submitQuizAttempt', e, 0);
            System.debug('=== EXCEPTION in submitQuizAttempt ===');
            System.debug('Type: ' + e.getTypeName());
            System.debug('Message: ' + e.getMessage());
            System.debug('Stack trace: ' + e.getStackTraceString());
            System.debug('Line number: ' + e.getLineNumber());
            throw new AuraHandledException('Unable to submit quiz: ' + e.getMessage() + ' (Line ' + e.getLineNumber() + ')');
        }
    }
    
    /**
     * @description Submits a quiz attempt and grades it (DEPRECATED - for backward compatibility)
     * @param submissionJSON JSON string of QuizSubmissionDTO
     * @return GradingResultDTO with score, pass/fail, and attempt details
     */
    @AuraEnabled
    public static GradingResultDTO submitQuizAttemptLegacy(String submissionJSON) {
        try {
            // Deserialize submission
            QuizSubmissionDTO submission = (QuizSubmissionDTO) JSON.deserialize(
                submissionJSON, QuizSubmissionDTO.class);
            
            if (submission.quizId == null || submission.contactId == null) {
                throw new IllegalArgumentException('Quiz ID and Contact ID are required');
            }
            
            // Load quiz and questions with correct answers
            Quiz__c quiz = [
                SELECT Id, Name, Passing_Score__c, Max_Score__c, Allow_Retakes__c, Max_Attempts__c,
                       Course__c, Lesson__c, Lesson__r.Module__r.Course__c
                FROM Quiz__c
                WHERE Id = :submission.quizId
                LIMIT 1
            ];
            
            List<Quiz_Question__c> questions = QuizDAO.getQuestionsWithOptions(submission.quizId);
            
            // Build map of questionId -> question for grading
            Map<Id, Quiz_Question__c> questionMap = new Map<Id, Quiz_Question__c>();
            Map<Id, Quiz_Answer_Option__c> optionMap = new Map<Id, Quiz_Answer_Option__c>();
            
            for (Quiz_Question__c q : questions) {
                questionMap.put(q.Id, q);
                for (Quiz_Answer_Option__c opt : q.Answer_Options__r) {
                    optionMap.put(opt.Id, opt);
                }
            }
            
            // Check attempt limits
            Integer attemptCount = QuizDAO.countAttempts(submission.quizId, submission.contactId);
            Integer maxAttempts = quiz.Max_Attempts__c != null ? Integer.valueOf(quiz.Max_Attempts__c) : 0;
            
            if (maxAttempts > 0 && attemptCount >= maxAttempts) {
                throw new IllegalArgumentException('Maximum attempts (' + maxAttempts + ') reached for this quiz');
            }
            
            // Create quiz attempt record
            // Determine Course: either from quiz.Course__c or from lesson's module's course
            Id courseId = quiz.Course__c != null ? quiz.Course__c : 
                          (quiz.Lesson__c != null && quiz.Lesson__r.Module__r.Course__c != null ? 
                           quiz.Lesson__r.Module__r.Course__c : null);
            
            Quiz_Attempt__c attempt = new Quiz_Attempt__c();
            attempt.Quiz__c = submission.quizId;
            attempt.Contact__c = submission.contactId;
            attempt.Enrollment__c = submission.enrollmentId;
            attempt.Course__c = courseId; // Required field
            attempt.Score__c = 0; // Required field - will be updated after grading
            attempt.Attempt_Number__c = attemptCount + 1;
            attempt.Started_On__c = DateTime.now();
            attempt.Completed_On__c = DateTime.now();
            attempt.Status__c = 'Completed';
            
            insert attempt;
            
            // Grade responses and create Quiz_Response__c records
            List<Quiz_Response__c> responses = new List<Quiz_Response__c>();
            Decimal totalScore = 0;
            Decimal maxScore = 0;
            
            for (ResponseDTO resp : submission.responses) {
                Quiz_Question__c question = questionMap.get(resp.questionId);
                Quiz_Answer_Option__c selectedOption = optionMap.get(resp.selectedOptionId);
                
                if (question == null || selectedOption == null) {
                    continue; // Skip invalid responses
                }
                
                Decimal questionPoints = question.Points__c != null ? question.Points__c : 1;
                maxScore += questionPoints;
                
                Boolean isCorrect = selectedOption.Is_Correct__c;
                Decimal pointsEarned = isCorrect ? questionPoints : 0;
                totalScore += pointsEarned;
                
                Quiz_Response__c response = new Quiz_Response__c();
                response.Quiz_Attempt__c = attempt.Id;
                response.Quiz_Question__c = resp.questionId;
                response.Quiz_Answer_Option__c = resp.selectedOptionId;
                response.Is_Correct__c = isCorrect;
                response.Points_Earned__c = pointsEarned;
                
                responses.add(response);
            }
            
            // Bulk insert responses
            if (!responses.isEmpty()) {
                insert responses;
            }
            
            // Calculate score percentage
            Decimal scorePercent = maxScore > 0 ? (totalScore / maxScore * 100) : 0;
            Decimal passingScore = quiz.Passing_Score__c != null ? quiz.Passing_Score__c : 70;
            Boolean passed = scorePercent >= passingScore;
            
            // Update attempt with scores
            attempt.Score__c = totalScore;
            attempt.Score_Percent__c = scorePercent;
            attempt.Passed__c = passed;
            update attempt;
            
            // Log grading result
            Logger.logInfo('QuizService', 'submitQuizAttempt',
                'Quiz attempt graded: Attempt ' + attempt.Attempt_Number__c + 
                ', Score: ' + scorePercent + '%, Passed: ' + passed);
            
            // If passed and enrollment exists, update enrollment
            if (passed && submission.enrollmentId != null) {
                EnrollmentService.applyQuizResultToEnrollment(
                    submission.enrollmentId, 
                    submission.quizId, 
                    scorePercent, 
                    passed
                );
            }
            
            // Build result DTO
            GradingResultDTO result = new GradingResultDTO();
            result.attemptId = attempt.Id;
            result.score = totalScore;
            result.scorePercent = scorePercent;
            result.passed = passed;
            result.attemptNumber = Integer.valueOf(attempt.Attempt_Number__c);
            result.message = passed ? 
                'Congratulations! You passed with ' + scorePercent.intValue() + '%' :
                'You scored ' + scorePercent.intValue() + '%. Passing score is ' + passingScore.intValue() + '%';
            
            return result;
            
        } catch (Exception e) {
            Logger.logError('QuizService', 'submitQuizAttempt', e, 0);
            AuraHandledException auraEx = new AuraHandledException('Unable to submit quiz: ' + e.getMessage());
            auraEx.setMessage('Unable to submit quiz: ' + e.getMessage());
            throw auraEx;
        }
    }
    
    /**
     * @description Helper method to map Quiz_Attempt__c to AttemptDTO
     */
    private static AttemptDTO mapAttemptToDTO(Quiz_Attempt__c attempt) {
        AttemptDTO dto = new AttemptDTO();
        dto.attemptId = attempt.Id;
        dto.attemptNumber = attempt.Attempt_Number__c != null ? Integer.valueOf(attempt.Attempt_Number__c) : 0;
        dto.score = attempt.Score__c;
        dto.scorePercent = attempt.Score_Percent__c;
        dto.passed = attempt.Passed__c;
        dto.completedOn = attempt.Completed_On__c;
        dto.status = attempt.Status__c;
        return dto;
    }
    
    /**
     * @description Retrieves the last quiz attempt for a lesson
     * @param quizId The ID of the quiz
     * @param lessonId The ID of the lesson
     * @param enrollmentId The ID of the enrollment (optional)
     * @param contactId The ID of the contact
     * @return QuizAttemptSummaryDTO with summary of last attempt, or null if none exists
     */
    @AuraEnabled(cacheable=true)
    public static QuizAttemptSummaryDTO getLastQuizAttemptForLesson(Id quizId, Id lessonId, Id enrollmentId, Id contactId) {
        try {
            if (quizId == null || contactId == null) {
                return null;
            }
            
            // Get last attempt via DAO
            Quiz_Attempt__c attempt = QuizDAO.getLastAttemptForQuiz(quizId, enrollmentId, contactId);
            
            if (attempt == null) {
                return null;
            }
            
            // Map to summary DTO
            QuizAttemptSummaryDTO summary = new QuizAttemptSummaryDTO();
            summary.attemptId = attempt.Id;
            summary.quizId = attempt.Quiz__c;
            summary.lessonId = lessonId;
            summary.enrollmentId = attempt.Enrollment__c;
            summary.score = attempt.Score__c;
            summary.maxScore = attempt.Quiz__r.Max_Score__c;
            summary.passingScore = attempt.Quiz__r.Passing_Score__c != null ? attempt.Quiz__r.Passing_Score__c : 70;
            summary.passed = attempt.Passed__c;
            summary.attemptNumber = attempt.Attempt_Number__c != null ? Integer.valueOf(attempt.Attempt_Number__c) : 0;
            summary.attemptedOn = attempt.Completed_On__c;
            
            return summary;
            
        } catch (Exception e) {
            Logger.logError('QuizService', 'getLastQuizAttemptForLesson', e, 0);
            throw new AuraHandledException('Unable to load quiz attempt summary: ' + e.getMessage());
        }
    }
    
    /**
     * @description Retrieves detailed quiz attempt with all answers for review mode
     * @param attemptId The ID of the quiz attempt
     * @return QuizAttemptDetailDTO with full attempt details and answers, or null if not found
     */
    @AuraEnabled(cacheable=true)
    public static QuizAttemptDetailDTO getQuizAttemptDetail(Id attemptId) {
        try {
            if (attemptId == null) {
                return null;
            }
            
            // Load attempt with relationships via DAO
            Quiz_Attempt__c attempt = QuizDAO.getAttemptWithRelationships(attemptId);
            
            if (attempt == null) {
                return null;
            }
            
            // Build detail DTO
            QuizAttemptDetailDTO detail = new QuizAttemptDetailDTO();
            detail.attemptId = attempt.Id;
            detail.quizId = attempt.Quiz__c;
            detail.lessonId = attempt.Quiz__r.Lesson__c;
            detail.enrollmentId = attempt.Enrollment__c;
            detail.score = attempt.Score__c;
            detail.maxScore = attempt.Quiz__r.Max_Score__c;
            detail.passingScore = attempt.Quiz__r.Passing_Score__c != null ? attempt.Quiz__r.Passing_Score__c : 70;
            detail.passed = attempt.Passed__c;
            detail.attemptNumber = attempt.Attempt_Number__c != null ? Integer.valueOf(attempt.Attempt_Number__c) : 0;
            detail.attemptedOn = attempt.Completed_On__c;
            
            // Load responses via DAO
            List<Quiz_Response__c> responses = QuizDAO.getResponsesForAttempt(attemptId);
            
            // Build map of questionId -> selected option IDs
            Map<Id, Set<Id>> selectedOptionsByQuestion = new Map<Id, Set<Id>>();
            for (Quiz_Response__c response : responses) {
                if (!selectedOptionsByQuestion.containsKey(response.Quiz_Question__c)) {
                    selectedOptionsByQuestion.put(response.Quiz_Question__c, new Set<Id>());
                }
                selectedOptionsByQuestion.get(response.Quiz_Question__c).add(response.Quiz_Answer_Option__c);
            }
            
            // Load all questions with options for this quiz
            List<Quiz_Question__c> questions = QuizDAO.getQuestionsWithOptions(attempt.Quiz__c);
            
            // Build reviewed questions
            for (Quiz_Question__c question : questions) {
                ReviewedQuestionDTO rqDTO = new ReviewedQuestionDTO();
                rqDTO.questionId = question.Id;
                rqDTO.questionText = question.Question_Text__c;
                rqDTO.questionType = question.Question_Type__c;
                rqDTO.points = question.Points__c != null ? question.Points__c : 1;
                rqDTO.required = question.Required__c != null ? question.Required__c : true;
                
                Set<Id> selectedOptions = selectedOptionsByQuestion.get(question.Id);
                if (selectedOptions == null) {
                    selectedOptions = new Set<Id>();
                }
                
                // Build reviewed answer options
                for (Quiz_Answer_Option__c option : question.Answer_Options__r) {
                    ReviewedAnswerOptionDTO raDTO = new ReviewedAnswerOptionDTO();
                    raDTO.optionId = option.Id;
                    raDTO.answerText = option.Answer_Text__c;
                    raDTO.selected = selectedOptions.contains(option.Id);
                    raDTO.correct = option.Is_Correct__c; // OK to expose in review mode
                    
                    rqDTO.options.add(raDTO);
                }
                
                detail.questions.add(rqDTO);
            }
            
            return detail;
            
        } catch (Exception e) {
            Logger.logError('QuizService', 'getQuizAttemptDetail', e, 0);
            throw new AuraHandledException('Unable to load quiz attempt details: ' + e.getMessage());
        }
    }
}