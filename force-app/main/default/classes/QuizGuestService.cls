/**
 * @description Guest-accessible service for quiz functionality.
 * Runs WITHOUT SHARING to allow guest users to access quiz data.
 * Delegates to QuizGuestDAO which also runs without sharing.
 * 
 * @author TrailForge Team
 * @date 2025-12-24
 */
public without sharing class QuizGuestService {
    
    /**
     * @description Retrieves quiz context for a lesson (for guest users)
     * @param lessonId The ID of the lesson
     * @param contactId The ID of the learner
     * @param enrollmentId The ID of the enrollment (optional)
     * @return QuizService.QuizContextDTO with quiz metadata, questions, and latest attempt
     */
    @AuraEnabled(cacheable=true)
    public static QuizService.QuizContextDTO getLessonQuizContext(Id lessonId, Id contactId, Id enrollmentId) {
        try {
            System.debug('QuizGuestService.getLessonQuizContext called for lesson: ' + lessonId);
            
            // Query the active quiz for this lesson using guest-safe DAO
            Quiz__c quiz = QuizGuestDAO.getActiveQuizForLesson(lessonId);
            
            if (quiz == null) {
                System.debug('QUIZ CTX (guest) for lesson ' + lessonId + ' = null (no quiz found)');
                return null;
            }
            
            System.debug('QuizGuestService: Building context for quiz ' + quiz.Id);
            
            return buildQuizContextDTO(quiz, lessonId, null, contactId, enrollmentId);
            
        } catch (Exception e) {
            System.debug('QUIZ CTX ERROR (guest) for lesson ' + lessonId + ': ' + e.getMessage());
            throw new AuraHandledException('Unable to load quiz: ' + e.getMessage());
        }
    }
    
    /**
     * @description Loads quiz context for a module-level quiz (for guest users)
     * @param moduleId The ID of the module
     * @param contactId The ID of the learner
     * @param enrollmentId The ID of the enrollment (optional)
     * @return QuizService.QuizContextDTO with quiz metadata, questions, and latest attempt
     */
    @AuraEnabled(cacheable=true)
    public static QuizService.QuizContextDTO getModuleQuizContext(Id moduleId, Id contactId, Id enrollmentId) {
        try {
            System.debug('QuizGuestService.getModuleQuizContext called for module: ' + moduleId);
            
            // Query the active module-level quiz using guest-safe DAO
            Quiz__c quiz = QuizGuestDAO.getActiveModuleQuiz(moduleId);
            
            if (quiz == null) {
                System.debug('MODULE QUIZ CTX (guest) for module ' + moduleId + ' = null (no quiz found)');
                return null;
            }
            
            System.debug('QuizGuestService: Building context for module quiz ' + quiz.Id);
            
            return buildQuizContextDTO(quiz, null, moduleId, contactId, enrollmentId);
            
        } catch (Exception e) {
            System.debug('MODULE QUIZ CTX ERROR (guest) for module ' + moduleId + ': ' + e.getMessage());
            throw new AuraHandledException('Unable to load module quiz: ' + e.getMessage());
        }
    }
    
    /**
     * @description Loads quiz context for a course-level quiz (for guest users)
     * @param courseId The ID of the course
     * @param contactId The ID of the learner
     * @param enrollmentId The ID of the enrollment (optional)
     * @return QuizService.QuizContextDTO with quiz metadata, questions, and latest attempt
     */
    @AuraEnabled(cacheable=true)
    public static QuizService.QuizContextDTO getCourseQuizContext(Id courseId, Id contactId, Id enrollmentId) {
        try {
            System.debug('QuizGuestService.getCourseQuizContext called for course: ' + courseId);
            
            // Query the active course-level quiz using guest-safe DAO
            Quiz__c quiz = QuizGuestDAO.getActiveCourseQuiz(courseId);
            
            if (quiz == null) {
                System.debug('COURSE QUIZ CTX (guest) for course ' + courseId + ' = null (no quiz found)');
                return null;
            }
            
            System.debug('QuizGuestService: Building context for course quiz ' + quiz.Id);
            
            return buildQuizContextDTO(quiz, null, null, contactId, enrollmentId);
            
        } catch (Exception e) {
            System.debug('COURSE QUIZ CTX ERROR (guest) for course ' + courseId + ': ' + e.getMessage());
            throw new AuraHandledException('Unable to load course quiz: ' + e.getMessage());
        }
    }
    
    /**
     * @description Retrieves quiz data for UI display (for standalone quiz player - guest-safe)
     * @param quizId The ID of the quiz
     * @param contactId The ID of the learner
     * @param enrollmentId The ID of the enrollment (optional)
     * @return QuizContextDTO with quiz metadata, questions, and latest attempt
     */
    @AuraEnabled(cacheable=true)
    public static QuizService.QuizContextDTO getQuizForUi(Id quizId, Id contactId, Id enrollmentId) {
        try {
            // Query the quiz directly using without sharing context
            List<Quiz__c> quizzes = [
                SELECT Id, Name, Lesson__c, Passing_Score__c, Max_Score__c,
                       Allow_Retakes__c, Active__c, Archived__c, Instructions__c,
                       Time_Limit_Minutes__c, Shuffle_Questions__c, Max_Attempts__c,
                       Modal_Size__c
                FROM Quiz__c
                WHERE Id = :quizId
                LIMIT 1
            ];
            
            if (quizzes.isEmpty()) {
                return null;
            }
            
            Quiz__c quiz = quizzes[0];
            
            return buildQuizContextDTO(quiz, quiz.Lesson__c, null, contactId, enrollmentId);
            
        } catch (Exception e) {
            System.debug('QUIZ FOR UI ERROR (guest) for quiz ' + quizId + ': ' + e.getMessage());
            throw new AuraHandledException('Unable to load quiz: ' + e.getMessage());
        }
    }
    
    /**
     * @description Helper to build QuizService.QuizContextDTO from a Quiz__c record
     */
    private static QuizService.QuizContextDTO buildQuizContextDTO(Quiz__c quiz, Id lessonId, Id moduleId, Id contactId, Id enrollmentId) {
        QuizService.QuizContextDTO context = new QuizService.QuizContextDTO();
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
        
        // Load questions and answer options using guest-safe DAO
        List<Quiz_Question__c> questions = QuizGuestDAO.getQuestionsWithOptions(quiz.Id);
        Decimal calculatedMaxScore = 0;
        
        for (Quiz_Question__c question : questions) {
            QuizService.QuestionDTO qDTO = new QuizService.QuestionDTO();
            qDTO.questionId = question.Id;
            qDTO.questionText = question.Question_Text__c;
            qDTO.questionType = question.Question_Type__c;
            qDTO.points = question.Points__c != null ? question.Points__c : 1;
            qDTO.required = question.Required__c != null ? question.Required__c : true;
            qDTO.explanation = question.Explanation__c;
            
            calculatedMaxScore += qDTO.points;
            
            // Load answer options (DO NOT include Is_Correct__c for security)
            for (Quiz_Answer_Option__c option : question.Answer_Options__r) {
                QuizService.AnswerOptionDTO aDTO = new QuizService.AnswerOptionDTO();
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
        
        // Load latest attempt if exists using guest-safe DAO
        try {
            Quiz_Attempt__c latestAttempt = QuizGuestDAO.getLatestAttemptForQuiz(quiz.Id, contactId, enrollmentId);
            if (latestAttempt != null) {
                context.latestAttempt = new QuizService.AttemptDTO();
                context.latestAttempt.attemptId = latestAttempt.Id;
                context.latestAttempt.attemptNumber = latestAttempt.Attempt_Number__c != null ? Integer.valueOf(latestAttempt.Attempt_Number__c) : 1;
                context.latestAttempt.score = latestAttempt.Score__c;
                context.latestAttempt.passed = latestAttempt.Passed__c;
                context.latestAttempt.completedOn = latestAttempt.Completed_On__c;
                context.latestAttempt.status = latestAttempt.Status__c;
            }
        } catch (Exception attemptEx) {
            System.debug('Warning (guest): Could not load latest attempt: ' + attemptEx.getMessage());
        }
        
        // Count total attempts using guest-safe DAO
        try {
            context.attemptCount = QuizGuestDAO.countAttempts(quiz.Id, contactId);
        } catch (Exception countEx) {
            System.debug('Warning (guest): Could not count attempts: ' + countEx.getMessage());
            context.attemptCount = 0;
        }
        
        return context;
    }
    
    // ========================================================================
    // QUIZ SUBMISSION (GUEST-SAFE)
    // ========================================================================
    
    /**
     * @description Submits a quiz attempt and grades it (for guest users)
     * This runs without sharing to allow guest users to submit quiz attempts
     * @param request QuizSubmissionRequestDTO containing quiz submission data
     * @return QuizSubmissionResultDTO with score, pass/fail, and attempt details
     */
    @AuraEnabled
    public static QuizService.QuizSubmissionResultDTO submitQuizAttempt(QuizService.QuizSubmissionRequestDTO request) {
        return submitQuizAttemptInternal(
            request.quizId,
            request.lessonId,
            request.contactId,
            request.enrollmentId,
            request.answers
        );
    }
    
    /**
     * @description Internal implementation of quiz submission (guest-safe)
     */
    private static QuizService.QuizSubmissionResultDTO submitQuizAttemptInternal(
        Id quizId, 
        Id lessonId, 
        Id contactId, 
        Id enrollmentId, 
        List<QuizService.SubmittedAnswerDTO> answers
    ) {
        try {
            System.debug('=== QuizGuestService.submitQuizAttempt START ===');
            System.debug('quizId: ' + quizId);
            System.debug('lessonId: ' + lessonId);
            System.debug('contactId: ' + contactId);
            System.debug('enrollmentId: ' + enrollmentId);
            
            // Validate required fields
            if (quizId == null) {
                throw new AuraHandledException('Quiz ID is required');
            }
            if (contactId == null) {
                throw new AuraHandledException('Contact ID is required');
            }
            
            // Load quiz with course relationship via guest-safe DAO
            Quiz__c quiz = QuizGuestDAO.getQuizWithCourse(quizId);
            
            if (quiz == null) {
                throw new AuraHandledException('Quiz not found: ' + quizId);
            }
            
            // Load questions with answer options (including Is_Correct__c for grading) via guest-safe DAO
            List<Quiz_Question__c> questions = QuizGuestDAO.getQuestionsWithOptionsForGrading(quizId);
            
            // Build maps for grading
            Map<Id, Quiz_Question__c> questionMap = new Map<Id, Quiz_Question__c>();
            Map<Id, Quiz_Answer_Option__c> optionMap = new Map<Id, Quiz_Answer_Option__c>();
            
            for (Quiz_Question__c q : questions) {
                questionMap.put(q.Id, q);
                if (q.Answer_Options__r != null) {
                    for (Quiz_Answer_Option__c opt : q.Answer_Options__r) {
                        optionMap.put(opt.Id, opt);
                    }
                }
            }
            
            // Check attempt limits via guest-safe DAO
            Integer attemptCount = QuizGuestDAO.countAttempts(quizId, contactId);
            Integer maxAttempts = quiz.Max_Attempts__c != null ? Integer.valueOf(quiz.Max_Attempts__c) : 0;
            
            if (maxAttempts > 0 && attemptCount >= maxAttempts) {
                throw new AuraHandledException('Maximum attempts (' + maxAttempts + ') reached for this quiz');
            }
            
            // Determine Course ID (required field on Quiz_Attempt__c)
            Id courseId = null;
            if (quiz.Course__c != null) {
                courseId = quiz.Course__c;
            } else if (quiz.Lesson__r != null && quiz.Lesson__r.Module__r != null && quiz.Lesson__r.Module__r.Course__c != null) {
                courseId = quiz.Lesson__r.Module__r.Course__c;
            }
            
            if (courseId == null) {
                throw new AuraHandledException('Cannot determine course for quiz attempt');
            }
            
            // Create Quiz_Attempt__c record
            Quiz_Attempt__c attempt = new Quiz_Attempt__c();
            attempt.Quiz__c = quizId;
            attempt.Contact__c = contactId;
            attempt.Enrollment__c = enrollmentId;
            attempt.Course__c = courseId;
            attempt.Score__c = 0;
            attempt.Attempt_Number__c = attemptCount + 1;
            attempt.Started_On__c = DateTime.now();
            attempt.Completed_On__c = DateTime.now();
            attempt.Status__c = 'Completed';
            
            // Insert via guest-safe DAO
            attempt = QuizGuestDAO.insertAttempt(attempt);
            
            // Grade responses and build Quiz_Response__c records
            List<Quiz_Response__c> responses = new List<Quiz_Response__c>();
            Decimal totalScore = 0;
            Decimal maxScore = 0;
            
            for (QuizService.SubmittedAnswerDTO answer : answers) {
                Quiz_Question__c question = questionMap.get(answer.questionId);
                if (question == null) {
                    continue;
                }
                
                Decimal questionPoints = question.Points__c != null ? question.Points__c : 1;
                maxScore += questionPoints;
                
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
            
            // Insert responses via guest-safe DAO
            QuizGuestDAO.insertResponses(responses);
            
            // Calculate score percentage and pass/fail
            Decimal scorePercent = maxScore > 0 ? (totalScore / maxScore * 100) : 0;
            Decimal passingScore = quiz.Passing_Score__c != null ? quiz.Passing_Score__c : 70;
            Boolean passed = scorePercent >= passingScore;
            
            // Update attempt with final scores
            attempt.Score__c = totalScore;
            attempt.Score_Percent__c = scorePercent;
            attempt.Passed__c = passed;
            QuizGuestDAO.updateAttempt(attempt);
            
            System.debug('Quiz graded (guest): Score=' + totalScore + '/' + maxScore + ' (' + scorePercent + '%), Passed=' + passed);
            
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
                    System.debug('Warning: Enrollment update failed: ' + enrollmentEx.getMessage());
                }
            }
            
            // Build result DTO
            QuizService.QuizSubmissionResultDTO result = new QuizService.QuizSubmissionResultDTO();
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
            
        } catch (AuraHandledException ahe) {
            throw ahe;
        } catch (Exception e) {
            System.debug('Error in QuizGuestService.submitQuizAttempt: ' + e.getMessage() + ' - ' + e.getStackTraceString());
            throw new AuraHandledException('Unable to submit quiz: ' + e.getMessage());
        }
    }
}
