/**
 * Test class for QuizService submission flow
 * Tests quiz context loading and attempt submission
 */
@IsTest
private class QuizServiceSubmissionTest {
    
    /**
     * Test loading quiz context for a lesson - happy path
     * Verifies that context is loaded correctly without exposing Is_Correct__c
     */
    @IsTest
    static void getLessonQuizContext_happyPath() {
        // Arrange
        Contact learner = QuizTestDataFactory.createContact();
        QuizTestDataFactory.QuizBundle bundle = QuizTestDataFactory.createQuizBundle(learner);
        
        // Act
        Test.startTest();
        QuizService.QuizContextDTO context = QuizService.getLessonQuizContext(
            bundle.lesson.Id,
            learner.Id,
            bundle.enrollment.Id
        );
        Test.stopTest();
        
        // Assert
        System.assertNotEquals(null, context, 'Quiz context should not be null');
        System.assertEquals(bundle.quiz.Id, context.quizId, 'Quiz ID should match');
        System.assertEquals(bundle.lesson.Id, context.lessonId, 'Lesson ID should match');
        System.assertEquals('Test Quiz', context.quizName, 'Quiz name should match');
        System.assertEquals(70, context.passingScore, 'Passing score should be 70');
        System.assertEquals(3, context.maxScore, 'Max score should be 3');
        System.assertEquals(true, context.allowRetakes, 'Retakes should be allowed');
        System.assertEquals(3, context.maxAttempts, 'Max attempts should be 3');
        System.assertEquals(3, context.questions.size(), 'Should have 3 questions');
        
        // Verify questions have options and DON'T expose Is_Correct__c
        for (QuizService.QuestionDTO question : context.questions) {
            System.assertNotEquals(null, question.questionText, 'Question text should be populated');
            System.assertEquals(1, question.points, 'Question should be worth 1 point');
            System.assertEquals(3, question.options.size(), 'Question should have 3 options');
            System.assertEquals(true, question.required, 'Question should be required');
            
            // Verify options don't expose Is_Correct__c (security check)
            for (QuizService.AnswerOptionDTO option : question.options) {
                System.assertNotEquals(null, option.answerText, 'Option text should be populated');
                System.assertNotEquals(null, option.optionId, 'Option ID should be populated');
                // No field for Is_Correct__c should be accessible in AnswerOptionDTO
            }
        }
    }
    
    /**
     * Test loading quiz context for lesson with no quiz
     */
    @IsTest
    static void getLessonQuizContext_noQuiz_returnsNull() {
        // Arrange
        Contact learner = QuizTestDataFactory.createContact();
        
        Course__c course = new Course__c(
            Name = 'Test Course',
            Archived__c = false
        );
        insert course;
        
        Module__c module = new Module__c(
            Name = 'Test Module',
            Course__c = course.Id,
            Archived__c = false
        );
        insert module;
        
        Lesson__c lessonWithoutQuiz = new Lesson__c(
            Name = 'Lesson Without Quiz',
            Module__c = module.Id,
            Content_Body__c = 'Content',
            Archived__c = false
        );
        insert lessonWithoutQuiz;
        
        // Act
        Test.startTest();
        QuizService.QuizContextDTO context = QuizService.getLessonQuizContext(
            lessonWithoutQuiz.Id,
            learner.Id,
            null
        );
        Test.stopTest();
        
        // Assert
        System.assertEquals(null, context, 'Context should be null for lesson without quiz');
    }
    
    /**
     * Test submitting quiz with all correct answers - should pass
     */
    @IsTest
    static void submitQuizAttempt_happyPath_allCorrect() {
        // Arrange
        Contact learner = QuizTestDataFactory.createContact();
        QuizTestDataFactory.QuizBundle bundle = QuizTestDataFactory.createQuizBundle(learner);
        
        QuizService.QuizSubmissionRequestDTO request = 
            QuizTestDataFactory.createSubmissionWithCorrectAnswers(bundle);
        
        // Act
        Test.startTest();
        QuizService.QuizSubmissionResultDTO result = QuizService.submitQuizAttempt(request);
        Test.stopTest();
        
        // Assert
        System.assertNotEquals(null, result, 'Result should not be null');
        System.assertEquals(3, result.score, 'Score should be 3 points');
        System.assertEquals(3, result.maxScore, 'Max score should be 3');
        Decimal scorePercent = (result.score / result.maxScore) * 100;
        System.assertEquals(100, scorePercent, 'Score percent should be 100%');
        System.assertEquals(true, result.passed, 'Quiz should be passed');
        System.assertEquals(1, result.attemptNumber, 'Should be attempt #1');
        System.assertNotEquals(null, result.attemptId, 'Attempt ID should be populated');
        System.assert(result.message.contains('Congratulations'), 'Message should indicate success');
        
        // Verify Quiz_Attempt__c record was created correctly
        List<Quiz_Attempt__c> attempts = [
            SELECT Id, Score__c, Score_Percent__c, Passed__c, Status__c, 
                   Attempt_Number__c, Contact__c, Enrollment__c, Quiz__c, Course__c
            FROM Quiz_Attempt__c
            WHERE Id = :result.attemptId
        ];
        
        System.assertEquals(1, attempts.size(), 'Should have created 1 attempt');
        Quiz_Attempt__c attempt = attempts[0];
        System.assertEquals(3, attempt.Score__c, 'Attempt score should be 3');
        System.assertEquals(100, attempt.Score_Percent__c, 'Attempt score percent should be 100');
        System.assertEquals(true, attempt.Passed__c, 'Attempt should be marked passed');
        System.assertEquals('Completed', attempt.Status__c, 'Attempt status should be Completed');
        System.assertEquals(1, attempt.Attempt_Number__c, 'Attempt number should be 1');
        System.assertEquals(learner.Id, attempt.Contact__c, 'Contact should match');
        System.assertEquals(bundle.enrollment.Id, attempt.Enrollment__c, 'Enrollment should match');
        System.assertEquals(bundle.quiz.Id, attempt.Quiz__c, 'Quiz should match');
        System.assertEquals(bundle.course.Id, attempt.Course__c, 'Course should match');
        
        // Verify Quiz_Response__c records were created
        List<Quiz_Response__c> responses = [
            SELECT Id, Quiz_Question__c, Quiz_Answer_Option__c, Is_Correct__c, Points_Earned__c
            FROM Quiz_Response__c
            WHERE Quiz_Attempt__c = :result.attemptId
        ];
        
        System.assertEquals(3, responses.size(), 'Should have created 3 responses');
        for (Quiz_Response__c response : responses) {
            System.assertEquals(true, response.Is_Correct__c, 'All responses should be correct');
            System.assertEquals(1, response.Points_Earned__c, 'Each response should earn 1 point');
        }
    }
    
    /**
     * Test submitting quiz with incorrect answer - should fail
     */
    @IsTest
    static void submitQuizAttempt_happyPath_incorrectAnswer() {
        // Arrange
        Contact learner = QuizTestDataFactory.createContact();
        QuizTestDataFactory.QuizBundle bundle = QuizTestDataFactory.createQuizBundle(learner);
        
        QuizService.QuizSubmissionRequestDTO request = 
            QuizTestDataFactory.createSubmissionWithIncorrectAnswers(bundle);
        
        // Act
        Test.startTest();
        QuizService.QuizSubmissionResultDTO result = QuizService.submitQuizAttempt(request);
        Test.stopTest();
        
        // Assert
        System.assertNotEquals(null, result, 'Result should not be null');
        System.assertEquals(0, result.score, 'Score should be 0 points');
        Decimal scorePercent = (result.score / result.maxScore) * 100;
        System.assertEquals(0, scorePercent, 'Score percent should be 0%');
        System.assertEquals(false, result.passed, 'Quiz should not be passed');
        System.assertEquals(1, result.attemptNumber, 'Should be attempt #1');
        System.assert(result.message.contains('70%'), 'Message should mention passing score');
        
        // Verify Quiz_Attempt__c record
        Quiz_Attempt__c attempt = [
            SELECT Id, Score__c, Passed__c, Status__c
            FROM Quiz_Attempt__c
            WHERE Id = :result.attemptId
        ];
        
        System.assertEquals(0, attempt.Score__c, 'Attempt score should be 0');
        System.assertEquals(false, attempt.Passed__c, 'Attempt should not be passed');
        System.assertEquals('Completed', attempt.Status__c, 'Attempt should still be completed');
        
        // Verify Quiz_Response__c records
        List<Quiz_Response__c> responses = [
            SELECT Id, Is_Correct__c, Points_Earned__c
            FROM Quiz_Response__c
            WHERE Quiz_Attempt__c = :result.attemptId
        ];
        
        System.assertEquals(3, responses.size(), 'Should have 3 responses');
        for (Quiz_Response__c response : responses) {
            System.assertEquals(false, response.Is_Correct__c, 'All responses should be incorrect');
            System.assertEquals(0, response.Points_Earned__c, 'Each response should earn 0 points');
        }
    }
    
    /**
     * Test submitting quiz with partial correct answers
     */
    @IsTest
    static void submitQuizAttempt_partiallyCorrect() {
        // Arrange
        Contact learner = QuizTestDataFactory.createContact();
        QuizTestDataFactory.QuizBundle bundle = QuizTestDataFactory.createQuizBundle(learner);
        
        // Create submission with 2 out of 3 correct (66% - below 70% passing)
        QuizService.QuizSubmissionRequestDTO request = 
            QuizTestDataFactory.createSubmissionWithMixedAnswers(bundle, 2);
        
        // Act
        Test.startTest();
        QuizService.QuizSubmissionResultDTO result = QuizService.submitQuizAttempt(request);
        Test.stopTest();
        
        // Assert
        System.assertEquals(2, result.score, 'Score should be 2 points');
        Decimal scorePercent = (result.score / result.maxScore) * 100;
        System.assertEquals(67, Math.round(scorePercent), 'Score percent should be ~67%');
        System.assertEquals(false, result.passed, 'Quiz should not be passed (below 70%)');
    }
    
    /**
     * Test submitting quiz with invalid quiz ID - should throw exception
     */
    @IsTest
    static void submitQuizAttempt_invalidQuiz_throwsException() {
        // Arrange
        Contact learner = QuizTestDataFactory.createContact();
        
        QuizService.QuizSubmissionRequestDTO request = new QuizService.QuizSubmissionRequestDTO();
        request.quizId = 'a00000000000000AAA'; // Fake ID
        request.lessonId = 'a01000000000000AAA';
        request.contactId = learner.Id;
        request.enrollmentId = null;
        
        // Act & Assert
        Test.startTest();
        try {
            QuizService.QuizSubmissionResultDTO result = QuizService.submitQuizAttempt(request);
            System.assert(false, 'Should have thrown AuraHandledException');
        } catch (Exception e) {
            // Accept any exception type since AuraHandledException wraps the original
            System.assert(true, 'Exception was thrown as expected');
        }
        Test.stopTest();
        
        // Verify no attempts or responses were created
        List<Quiz_Attempt__c> attempts = [SELECT Id FROM Quiz_Attempt__c];
        System.assertEquals(0, attempts.size(), 'No attempts should be created');
        
        List<Quiz_Response__c> responses = [SELECT Id FROM Quiz_Response__c];
        System.assertEquals(0, responses.size(), 'No responses should be created');
    }
    
    /**
     * Test submitting quiz with missing required field - should throw exception
     */
    @IsTest
    static void submitQuizAttempt_missingContactId_throwsException() {
        // Arrange
        Contact learner = QuizTestDataFactory.createContact();
        QuizTestDataFactory.QuizBundle bundle = QuizTestDataFactory.createQuizBundle(learner);
        
        QuizService.QuizSubmissionRequestDTO request = new QuizService.QuizSubmissionRequestDTO();
        request.quizId = bundle.quiz.Id;
        request.lessonId = bundle.lesson.Id;
        request.contactId = null; // Missing required field
        request.enrollmentId = bundle.enrollment.Id;
        
        // Act & Assert
        Test.startTest();
        try {
            QuizService.QuizSubmissionResultDTO result = QuizService.submitQuizAttempt(request);
            System.assert(false, 'Should have thrown AuraHandledException');
        } catch (Exception e) {
            // Accept any exception type since validation may occur at different layers
            System.assert(true, 'Exception was thrown as expected');
        }
        Test.stopTest();
    }
    
    /**
     * Test submitting quiz when max attempts reached - should throw exception
     */
    @IsTest
    static void submitQuizAttempt_maxAttemptsReached_throwsException() {
        // Arrange
        Contact learner = QuizTestDataFactory.createContact();
        QuizTestDataFactory.QuizBundle bundle = QuizTestDataFactory.createQuizBundle(learner);
        
        // Submit quiz 3 times (max attempts)
        for (Integer i = 0; i < 3; i++) {
            QuizService.QuizSubmissionRequestDTO request = 
                QuizTestDataFactory.createSubmissionWithIncorrectAnswers(bundle);
            QuizService.submitQuizAttempt(request);
        }
        
        // Try to submit 4th attempt
        QuizService.QuizSubmissionRequestDTO request = 
            QuizTestDataFactory.createSubmissionWithCorrectAnswers(bundle);
        
        // Act & Assert
        Test.startTest();
        try {
            QuizService.QuizSubmissionResultDTO result = QuizService.submitQuizAttempt(request);
            System.assert(false, 'Should have thrown AuraHandledException for max attempts');
        } catch (Exception e) {
            // Accept any exception type
            System.assert(true, 'Exception was thrown as expected for max attempts');
        }
        Test.stopTest();
    }
    
    /**
     * Test submitting quiz without enrollment (informational quiz)
     */
    @IsTest
    static void submitQuizAttempt_noEnrollment_success() {
        // Arrange
        Contact learner = QuizTestDataFactory.createContact();
        QuizTestDataFactory.QuizBundle bundle = QuizTestDataFactory.createQuizBundle(learner);
        
        QuizService.QuizSubmissionRequestDTO request = 
            QuizTestDataFactory.createSubmissionWithCorrectAnswers(bundle);
        request.enrollmentId = null; // No enrollment
        
        // Act
        Test.startTest();
        QuizService.QuizSubmissionResultDTO result = QuizService.submitQuizAttempt(request);
        Test.stopTest();
        
        // Assert
        System.assertEquals(true, result.passed, 'Quiz should be passed');
        
        // Verify attempt created without enrollment
        Quiz_Attempt__c attempt = [
            SELECT Id, Enrollment__c
            FROM Quiz_Attempt__c
            WHERE Id = :result.attemptId
        ];
        
        System.assertEquals(null, attempt.Enrollment__c, 'Attempt should not have enrollment');
    }
    
    /**
     * Test legacy submission method for backward compatibility
     */
    @IsTest
    static void submitQuizAttemptLegacy_backwardCompatibility() {
        // Arrange
        Contact learner = QuizTestDataFactory.createContact();
        QuizTestDataFactory.QuizBundle bundle = QuizTestDataFactory.createQuizBundle(learner);
        
        // Build legacy submission format
        QuizService.QuizSubmissionDTO legacySubmission = new QuizService.QuizSubmissionDTO();
        legacySubmission.quizId = bundle.quiz.Id;
        legacySubmission.contactId = learner.Id;
        legacySubmission.enrollmentId = bundle.enrollment.Id;
        
        List<QuizService.ResponseDTO> responses = new List<QuizService.ResponseDTO>();
        for (Quiz_Question__c question : bundle.questions) {
            QuizService.ResponseDTO response = new QuizService.ResponseDTO();
            response.questionId = question.Id;
            response.selectedOptionId = bundle.optionsByQuestion.get(question.Id)[0].Id;
            responses.add(response);
        }
        legacySubmission.responses = responses;
        
        // Act
        Test.startTest();
        QuizService.GradingResultDTO result = QuizService.submitQuizAttemptLegacy(
            JSON.serialize(legacySubmission)
        );
        Test.stopTest();
        
        // Assert
        System.assertNotEquals(null, result, 'Legacy result should not be null');
        System.assertEquals(true, result.passed, 'Legacy submission should pass');
        System.assertEquals(100, result.scorePercent, 'Score should be 100%');
        
        // Verify attempt was created
        List<Quiz_Attempt__c> attempts = [SELECT Id FROM Quiz_Attempt__c];
        System.assertEquals(1, attempts.size(), 'Legacy submission should create attempt');
    }
}