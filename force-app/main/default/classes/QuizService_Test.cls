/**
 * @description Test class for QuizService
 * Tests quiz loading, grading, and enrollment integration
 * 
 * @author TrailForge Team
 * @date 2025-11-25
 */
@isTest
private class QuizService_Test {
    
    /**
     * Setup test data: Course, Module, Lesson, Quiz, Questions, Answer Options
     */
    @TestSetup
    static void setupTestData() {
        // Create Contact
        Contact learner = new Contact(
            FirstName = 'Test',
            LastName = 'Learner',
            Email = 'testlearner@trailforge.test'
        );
        insert learner;
        
        // Create Course
        Course__c course = new Course__c(
            Name = 'Wave 4 Quiz Test Course',
            Passing_Score__c = 70,
            Archived__c = false
        );
        insert course;
        
        // Create Module
        Module__c module = new Module__c(
            Name = 'Test Module',
            Course__c = course.Id,
            Archived__c = false
        );
        insert module;
        
        // Create Lesson
        Lesson__c lesson = new Lesson__c(
            Name = 'Test Lesson with Quiz',
            Module__c = module.Id,
            Content_Body__c = 'Test lesson content',
            Archived__c = false
        );
        insert lesson;
        
        // Create Enrollment
        Enrollment__c enrollment = new Enrollment__c(
            Contact__c = learner.Id,
            Course__c = course.Id,
            Status__c = 'In Progress',
            Progress_Percentage__c = 95, // Above 90% threshold for completion gating
            Quiz_Passed__c = false
        );
        insert enrollment;
        
        // Create Quiz
        Quiz__c quiz = new Quiz__c(
            Name = 'Test Quiz',
            Lesson__c = lesson.Id,
            Passing_Score__c = 70,
            Active__c = true,
            Archived__c = false,
            Allow_Retakes__c = true,
            Max_Attempts__c = 3,
            Instructions__c = 'Answer all questions to the best of your ability'
        );
        insert quiz;
        
        // Create Questions
        List<Quiz_Question__c> questions = new List<Quiz_Question__c>{
            new Quiz_Question__c(
                Quiz__c = quiz.Id,
                Question_Text__c = 'What is 2 + 2?',
                Question_Type__c = 'MultipleChoice',
                Points__c = 1,
                Required__c = true,
                Sort_Order__c = 1
            ),
            new Quiz_Question__c(
                Quiz__c = quiz.Id,
                Question_Text__c = 'What is the capital of France?',
                Question_Type__c = 'MultipleChoice',
                Points__c = 1,
                Required__c = true,
                Sort_Order__c = 2
            ),
            new Quiz_Question__c(
                Quiz__c = quiz.Id,
                Question_Text__c = 'Salesforce uses what programming language?',
                Question_Type__c = 'MultipleChoice',
                Points__c = 1,
                Required__c = true,
                Sort_Order__c = 3
            )
        };
        insert questions;
        
        // Create Answer Options for Question 1 (2 + 2)
        insert new List<Quiz_Answer_Option__c>{
            new Quiz_Answer_Option__c(
                Quiz_Question__c = questions[0].Id,
                Answer_Text__c = '3',
                Is_Correct__c = false,
                Sort_Order__c = 1,
                Is_Active__c = true
            ),
            new Quiz_Answer_Option__c(
                Quiz_Question__c = questions[0].Id,
                Answer_Text__c = '4',
                Is_Correct__c = true,
                Sort_Order__c = 2,
                Is_Active__c = true
            ),
            new Quiz_Answer_Option__c(
                Quiz_Question__c = questions[0].Id,
                Answer_Text__c = '5',
                Is_Correct__c = false,
                Sort_Order__c = 3,
                Is_Active__c = true
            )
        };
        
        // Create Answer Options for Question 2 (Capital of France)
        insert new List<Quiz_Answer_Option__c>{
            new Quiz_Answer_Option__c(
                Quiz_Question__c = questions[1].Id,
                Answer_Text__c = 'London',
                Is_Correct__c = false,
                Sort_Order__c = 1,
                Is_Active__c = true
            ),
            new Quiz_Answer_Option__c(
                Quiz_Question__c = questions[1].Id,
                Answer_Text__c = 'Paris',
                Is_Correct__c = true,
                Sort_Order__c = 2,
                Is_Active__c = true
            ),
            new Quiz_Answer_Option__c(
                Quiz_Question__c = questions[1].Id,
                Answer_Text__c = 'Berlin',
                Is_Correct__c = false,
                Sort_Order__c = 3,
                Is_Active__c = true
            )
        };
        
        // Create Answer Options for Question 3 (Salesforce language)
        insert new List<Quiz_Answer_Option__c>{
            new Quiz_Answer_Option__c(
                Quiz_Question__c = questions[2].Id,
                Answer_Text__c = 'Java',
                Is_Correct__c = false,
                Sort_Order__c = 1,
                Is_Active__c = true
            ),
            new Quiz_Answer_Option__c(
                Quiz_Question__c = questions[2].Id,
                Answer_Text__c = 'Apex',
                Is_Correct__c = true,
                Sort_Order__c = 2,
                Is_Active__c = true
            ),
            new Quiz_Answer_Option__c(
                Quiz_Question__c = questions[2].Id,
                Answer_Text__c = 'Python',
                Is_Correct__c = false,
                Sort_Order__c = 3,
                Is_Active__c = true
            )
        };
    }
    
    /**
     * Test loading quiz context for a lesson
     */
    @isTest
    static void testGetLessonQuizContext() {
        // Query test data
        Lesson__c lesson = [SELECT Id FROM Lesson__c LIMIT 1];
        Contact learner = [SELECT Id FROM Contact LIMIT 1];
        Enrollment__c enrollment = [SELECT Id FROM Enrollment__c LIMIT 1];
        
        Test.startTest();
        
        QuizService.QuizContextDTO context = QuizService.getLessonQuizContext(
            lesson.Id, 
            learner.Id, 
            enrollment.Id
        );
        
        Test.stopTest();
        
        // Assertions
        System.assertNotEquals(null, context, 'Quiz context should not be null');
        System.assertNotEquals(null, context.quizId, 'Quiz ID should be populated');
        System.assertEquals(70, context.passingScore, 'Passing score should be 70');
        System.assertEquals(true, context.allowRetakes, 'Retakes should be allowed');
        System.assertEquals(3, context.maxAttempts, 'Max attempts should be 3');
        System.assertEquals(3, context.questions.size(), 'Should have 3 questions');
        
        // Verify questions have options
        for (QuizService.QuestionDTO q : context.questions) {
            System.assertNotEquals(null, q.questionText, 'Question text should be populated');
            System.assertEquals(1, q.points, 'Each question worth 1 point');
            System.assertEquals(3, q.options.size(), 'Each question should have 3 options');
            
            // Verify options don't expose Is_Correct__c (security)
            for (QuizService.AnswerOptionDTO opt : q.options) {
                System.assertNotEquals(null, opt.answerText, 'Option text should be populated');
                System.assertNotEquals(null, opt.optionId, 'Option ID should be populated');
            }
        }
    }
    
    /**
     * Test submitting quiz with all correct answers (passing)
     */
    @isTest
    static void testSubmitQuizAttempt_AllCorrect() {
        // Query test data
        Quiz__c quiz = [SELECT Id FROM Quiz__c LIMIT 1];
        Contact learner = [SELECT Id FROM Contact LIMIT 1];
        Enrollment__c enrollment = [SELECT Id FROM Enrollment__c LIMIT 1];
        
        List<Quiz_Question__c> questions = [
            SELECT Id, (SELECT Id, Is_Correct__c FROM Answer_Options__r WHERE Is_Active__c = true)
            FROM Quiz_Question__c
            WHERE Quiz__c = :quiz.Id
            ORDER BY Sort_Order__c
        ];
        
        // Build submission with all correct answers
        List<QuizService.ResponseDTO> responses = new List<QuizService.ResponseDTO>();
        for (Quiz_Question__c q : questions) {
            Quiz_Answer_Option__c correctOption = null;
            for (Quiz_Answer_Option__c opt : q.Answer_Options__r) {
                if (opt.Is_Correct__c) {
                    correctOption = opt;
                    break;
                }
            }
            
            QuizService.ResponseDTO resp = new QuizService.ResponseDTO();
            resp.questionId = q.Id;
            resp.selectedOptionId = correctOption.Id;
            responses.add(resp);
        }
        
        QuizService.QuizSubmissionDTO submission = new QuizService.QuizSubmissionDTO();
        submission.quizId = quiz.Id;
        submission.contactId = learner.Id;
        submission.enrollmentId = enrollment.Id;
        submission.responses = responses;
        
        Test.startTest();
        
        QuizService.GradingResultDTO result = QuizService.submitQuizAttemptLegacy(
            JSON.serialize(submission)
        );
        
        Test.stopTest();
        
        // Assertions
        System.assertNotEquals(null, result, 'Grading result should not be null');
        System.assertEquals(100, result.scorePercent, 'Score should be 100%');
        System.assertEquals(true, result.passed, 'Quiz should be passed');
        System.assertEquals(1, result.attemptNumber, 'Should be attempt #1');
        System.assertNotEquals(null, result.attemptId, 'Attempt ID should be populated');
        
        // Verify Quiz_Attempt__c created
        Quiz_Attempt__c attempt = [
            SELECT Id, Score__c, Score_Percent__c, Passed__c, Status__c, Attempt_Number__c
            FROM Quiz_Attempt__c
            WHERE Id = :result.attemptId
        ];
        System.assertEquals(3, attempt.Score__c, 'Score should be 3 points');
        System.assertEquals(100, attempt.Score_Percent__c, 'Score percent should be 100');
        System.assertEquals(true, attempt.Passed__c, 'Attempt should be passed');
        System.assertEquals('Completed', attempt.Status__c, 'Status should be Completed');
        
        // Verify Quiz_Response__c records created
        List<Quiz_Response__c> quizResponses = [
            SELECT Id, Is_Correct__c, Points_Earned__c
            FROM Quiz_Response__c
            WHERE Quiz_Attempt__c = :result.attemptId
        ];
        System.assertEquals(3, quizResponses.size(), 'Should have 3 responses');
        for (Quiz_Response__c resp : quizResponses) {
            System.assertEquals(true, resp.Is_Correct__c, 'All responses should be correct');
            System.assertEquals(1, resp.Points_Earned__c, 'Each response earns 1 point');
        }
        
        // Verify Enrollment updated (quiz passed + progress >= 90% = Completed)
        Enrollment__c updatedEnrollment = [
            SELECT Id, Quiz_Passed__c, Quiz_Score__c, Status__c, Progress_Percentage__c
            FROM Enrollment__c
            WHERE Id = :enrollment.Id
        ];
        System.assertEquals(true, updatedEnrollment.Quiz_Passed__c, 'Enrollment quiz should be marked passed');
        System.assertEquals(100, updatedEnrollment.Quiz_Score__c, 'Enrollment quiz score should be 100');
        System.assertEquals('Completed', updatedEnrollment.Status__c, 'Enrollment should be Completed (95% progress + quiz passed)');
    }
    
    /**
     * Test submitting quiz with some wrong answers (failing)
     */
    @isTest
    static void testSubmitQuizAttempt_Failed() {
        // Query test data
        Quiz__c quiz = [SELECT Id FROM Quiz__c LIMIT 1];
        Contact learner = [SELECT Id FROM Contact LIMIT 1];
        Enrollment__c enrollment = [SELECT Id FROM Enrollment__c LIMIT 1];
        
        List<Quiz_Question__c> questions = [
            SELECT Id, (SELECT Id, Is_Correct__c FROM Answer_Options__r WHERE Is_Active__c = true ORDER BY Sort_Order__c)
            FROM Quiz_Question__c
            WHERE Quiz__c = :quiz.Id
            ORDER BY Sort_Order__c
        ];
        
        // Build submission with only 1 correct answer (33% = fail)
        List<QuizService.ResponseDTO> responses = new List<QuizService.ResponseDTO>();
        Integer questionIndex = 0;
        for (Quiz_Question__c q : questions) {
            QuizService.ResponseDTO resp = new QuizService.ResponseDTO();
            resp.questionId = q.Id;
            
            // First question correct, rest incorrect
            if (questionIndex == 0) {
                for (Quiz_Answer_Option__c opt : q.Answer_Options__r) {
                    if (opt.Is_Correct__c) {
                        resp.selectedOptionId = opt.Id;
                        break;
                    }
                }
            } else {
                // Select first incorrect option
                for (Quiz_Answer_Option__c opt : q.Answer_Options__r) {
                    if (!opt.Is_Correct__c) {
                        resp.selectedOptionId = opt.Id;
                        break;
                    }
                }
            }
            
            responses.add(resp);
            questionIndex++;
        }
        
        QuizService.QuizSubmissionDTO submission = new QuizService.QuizSubmissionDTO();
        submission.quizId = quiz.Id;
        submission.contactId = learner.Id;
        submission.enrollmentId = enrollment.Id;
        submission.responses = responses;
        
        Test.startTest();
        
        QuizService.GradingResultDTO result = QuizService.submitQuizAttemptLegacy(
            JSON.serialize(submission)
        );
        
        Test.stopTest();
        
        // Assertions
        System.assertNotEquals(null, result, 'Grading result should not be null');
        System.assertEquals(33, Math.round(result.scorePercent), 'Score should be ~33%');
        System.assertEquals(false, result.passed, 'Quiz should not be passed');
        
        // Verify enrollment NOT marked as complete (quiz failed)
        Enrollment__c updatedEnrollment = [
            SELECT Id, Quiz_Passed__c, Status__c
            FROM Enrollment__c
            WHERE Id = :enrollment.Id
        ];
        System.assertEquals(false, updatedEnrollment.Quiz_Passed__c, 'Enrollment quiz should not be passed');
        System.assertNotEquals('Completed', updatedEnrollment.Status__c, 'Enrollment should not be Completed');
    }
    
    /**
     * Test multiple attempts and attempt counting
     */
    @isTest
    static void testMultipleAttempts() {
        // Query test data
        Quiz__c quiz = [SELECT Id FROM Quiz__c LIMIT 1];
        Contact learner = [SELECT Id FROM Contact LIMIT 1];
        Enrollment__c enrollment = [SELECT Id FROM Enrollment__c LIMIT 1];
        Lesson__c lesson = [SELECT Id FROM Lesson__c LIMIT 1];
        
        // First attempt - fail
        submitQuizWithAllWrongAnswers(quiz.Id, learner.Id, enrollment.Id);
        
        // Check attempt count
        Integer attemptCount1 = QuizDAO.countAttempts(quiz.Id, learner.Id);
        System.assertEquals(1, attemptCount1, 'Should have 1 attempt');
        
        Test.startTest();
        
        // Second attempt - fail
        submitQuizWithAllWrongAnswers(quiz.Id, learner.Id, enrollment.Id);
        
        // Third attempt - pass
        QuizService.QuizContextDTO context = QuizService.getLessonQuizContext(
            lesson.Id, learner.Id, enrollment.Id
        );
        
        Test.stopTest();
        
        // Verify attempt count
        System.assertEquals(2, context.attemptCount, 'Should have 2 attempts after test');
        System.assertNotEquals(null, context.latestAttempt, 'Latest attempt should be populated');
    }
    
    /**
     * Helper method to submit quiz with all wrong answers
     */
    private static void submitQuizWithAllWrongAnswers(Id quizId, Id contactId, Id enrollmentId) {
        List<Quiz_Question__c> questions = [
            SELECT Id, (SELECT Id, Is_Correct__c FROM Answer_Options__r WHERE Is_Active__c = true)
            FROM Quiz_Question__c
            WHERE Quiz__c = :quizId
            ORDER BY Sort_Order__c
        ];
        
        List<QuizService.ResponseDTO> responses = new List<QuizService.ResponseDTO>();
        for (Quiz_Question__c q : questions) {
            QuizService.ResponseDTO resp = new QuizService.ResponseDTO();
            resp.questionId = q.Id;
            
            // Select first incorrect option
            for (Quiz_Answer_Option__c opt : q.Answer_Options__r) {
                if (!opt.Is_Correct__c) {
                    resp.selectedOptionId = opt.Id;
                    break;
                }
            }
            
            responses.add(resp);
        }
        
        QuizService.QuizSubmissionDTO submission = new QuizService.QuizSubmissionDTO();
        submission.quizId = quizId;
        submission.contactId = contactId;
        submission.enrollmentId = enrollmentId;
        submission.responses = responses;
        
        QuizService.submitQuizAttemptLegacy(JSON.serialize(submission));
    }
    
    /**
     * Test quiz without enrollment (informational quiz)
     */
    @isTest
    static void testQuizWithoutEnrollment() {
        // Query test data
        Quiz__c quiz = [SELECT Id FROM Quiz__c LIMIT 1];
        Contact learner = [SELECT Id FROM Contact LIMIT 1];
        
        List<Quiz_Question__c> questions = [
            SELECT Id, (SELECT Id, Is_Correct__c FROM Answer_Options__r WHERE Is_Active__c = true)
            FROM Quiz_Question__c
            WHERE Quiz__c = :quiz.Id
            ORDER BY Sort_Order__c
        ];
        
        // Build submission with all correct answers but NO enrollment
        List<QuizService.ResponseDTO> responses = new List<QuizService.ResponseDTO>();
        for (Quiz_Question__c q : questions) {
            Quiz_Answer_Option__c correctOption = null;
            for (Quiz_Answer_Option__c opt : q.Answer_Options__r) {
                if (opt.Is_Correct__c) {
                    correctOption = opt;
                    break;
                }
            }
            
            QuizService.ResponseDTO resp = new QuizService.ResponseDTO();
            resp.questionId = q.Id;
            resp.selectedOptionId = correctOption.Id;
            responses.add(resp);
        }
        
        QuizService.QuizSubmissionDTO submission = new QuizService.QuizSubmissionDTO();
        submission.quizId = quiz.Id;
        submission.contactId = learner.Id;
        submission.enrollmentId = null; // No enrollment
        submission.responses = responses;
        
        Test.startTest();
        
        QuizService.GradingResultDTO result = QuizService.submitQuizAttemptLegacy(
            JSON.serialize(submission)
        );
        
        Test.stopTest();
        
        // Assertions
        System.assertEquals(true, result.passed, 'Quiz should be passed');
        
        // Verify Quiz_Attempt__c created without enrollment
        Quiz_Attempt__c attempt = [
            SELECT Id, Enrollment__c
            FROM Quiz_Attempt__c
            WHERE Id = :result.attemptId
        ];
        System.assertEquals(null, attempt.Enrollment__c, 'Attempt should not have enrollment');
    }
}