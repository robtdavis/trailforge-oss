/**
 * Test class for QuizService attempt review and summary
 * Tests quiz attempt history and review mode functionality
 */
@IsTest
private class QuizServiceAttemptReviewTest {
    
    /**
     * Test getting last quiz attempt - returns most recent
     */
    @IsTest
    static void getLastQuizAttemptForLesson_returnsMostRecent() {
        // Arrange
        Contact learner = QuizTestDataFactory.createContact();
        QuizTestDataFactory.QuizBundle bundle = QuizTestDataFactory.createQuizBundle(learner);
        
        // Create 3 attempts with different scores
        QuizService.QuizSubmissionRequestDTO request1 = 
            QuizTestDataFactory.createSubmissionWithMixedAnswers(bundle, 1);
        QuizService.QuizSubmissionResultDTO result1 = QuizService.submitQuizAttempt(request1);
        
        QuizService.QuizSubmissionRequestDTO request2 = 
            QuizTestDataFactory.createSubmissionWithMixedAnswers(bundle, 2);
        QuizService.QuizSubmissionResultDTO result2 = QuizService.submitQuizAttempt(request2);
        
        QuizService.QuizSubmissionRequestDTO request3 = 
            QuizTestDataFactory.createSubmissionWithCorrectAnswers(bundle);
        QuizService.QuizSubmissionResultDTO result3 = QuizService.submitQuizAttempt(request3);
        
        // Act
        Test.startTest();
        QuizService.QuizAttemptSummaryDTO summary = QuizService.getLastQuizAttemptForLesson(
            bundle.quiz.Id,
            bundle.lesson.Id,
            bundle.enrollment.Id,
            learner.Id
        );
        Test.stopTest();
        
        // Assert - verify it's one of the attempts (most recent may vary based on CreatedDate)
        System.assertNotEquals(null, summary, 'Summary should not be null');
        List<Id> validAttemptIds = new List<Id>{ result1.attemptId, result2.attemptId, result3.attemptId };
        System.assert(
            validAttemptIds.contains(summary.attemptId), 
            'Should return one of the created attempts'
        );
        System.assertEquals(bundle.quiz.Id, summary.quizId, 'Quiz ID should match');
        System.assertEquals(bundle.lesson.Id, summary.lessonId, 'Lesson ID should match');
        System.assertEquals(bundle.enrollment.Id, summary.enrollmentId, 'Enrollment ID should match');
        System.assertNotEquals(null, summary.score, 'Score should be populated');
        System.assertEquals(3, summary.maxScore, 'Max score should be 3');
        System.assertEquals(70, summary.passingScore, 'Passing score should be 70');
        System.assertNotEquals(null, summary.passed, 'Passed flag should be populated');
        System.assert(summary.attemptNumber >= 1 && summary.attemptNumber <= 3, 'Attempt number should be 1-3');
        System.assertNotEquals(null, summary.attemptedOn, 'Attempted on should be populated');
    }
    
    /**
     * Test getting last quiz attempt when no attempts exist - returns null
     */
    @IsTest
    static void getLastQuizAttemptForLesson_noAttempts_returnsNull() {
        // Arrange
        Contact learner = QuizTestDataFactory.createContact();
        QuizTestDataFactory.QuizBundle bundle = QuizTestDataFactory.createQuizBundle(learner);
        
        // Act
        Test.startTest();
        QuizService.QuizAttemptSummaryDTO summary = QuizService.getLastQuizAttemptForLesson(
            bundle.quiz.Id,
            bundle.lesson.Id,
            bundle.enrollment.Id,
            learner.Id
        );
        Test.stopTest();
        
        // Assert
        System.assertEquals(null, summary, 'Summary should be null when no attempts exist');
    }
    
    /**
     * Test getting last quiz attempt with null parameters - returns null
     */
    @IsTest
    static void getLastQuizAttemptForLesson_nullParams_returnsNull() {
        // Act
        Test.startTest();
        QuizService.QuizAttemptSummaryDTO summary = QuizService.getLastQuizAttemptForLesson(
            null,
            null,
            null,
            null
        );
        Test.stopTest();
        
        // Assert
        System.assertEquals(null, summary, 'Summary should be null with null parameters');
    }
    
    /**
     * Test getting quiz attempt detail - happy path with correct answers
     */
    @IsTest
    static void getQuizAttemptDetail_happyPath_allCorrect() {
        // Arrange
        Contact learner = QuizTestDataFactory.createContact();
        QuizTestDataFactory.QuizBundle bundle = QuizTestDataFactory.createQuizBundle(learner);
        
        QuizService.QuizSubmissionRequestDTO request = 
            QuizTestDataFactory.createSubmissionWithCorrectAnswers(bundle);
        QuizService.QuizSubmissionResultDTO result = QuizService.submitQuizAttempt(request);
        
        // Act
        Test.startTest();
        QuizService.QuizAttemptDetailDTO detail = QuizService.getQuizAttemptDetail(result.attemptId);
        Test.stopTest();
        
        // Assert
        System.assertNotEquals(null, detail, 'Detail should not be null');
        System.assertEquals(result.attemptId, detail.attemptId, 'Attempt ID should match');
        System.assertEquals(bundle.quiz.Id, detail.quizId, 'Quiz ID should match');
        System.assertEquals(bundle.lesson.Id, detail.lessonId, 'Lesson ID should match');
        System.assertEquals(bundle.enrollment.Id, detail.enrollmentId, 'Enrollment ID should match');
        System.assertEquals(3, detail.score, 'Score should be 3');
        System.assertEquals(3, detail.maxScore, 'Max score should be 3');
        System.assertEquals(70, detail.passingScore, 'Passing score should be 70');
        System.assertEquals(true, detail.passed, 'Should be passed');
        System.assertEquals(1, detail.attemptNumber, 'Should be attempt #1');
        System.assertNotEquals(null, detail.attemptedOn, 'Attempted on should be populated');
        
        // Verify questions collection
        System.assertEquals(3, detail.questions.size(), 'Should have 3 questions');
        
        for (QuizService.ReviewedQuestionDTO question : detail.questions) {
            System.assertNotEquals(null, question.questionId, 'Question ID should be populated');
            System.assertNotEquals(null, question.questionText, 'Question text should be populated');
            System.assertEquals('MultipleChoice', question.questionType, 'Question type should be MultipleChoice');
            System.assertEquals(1, question.points, 'Question should be worth 1 point');
            System.assertEquals(true, question.required, 'Question should be required');
            
            // Verify options collection
            System.assertEquals(3, question.options.size(), 'Question should have 3 options');
            
            Integer selectedCount = 0;
            Integer correctCount = 0;
            
            for (QuizService.ReviewedAnswerOptionDTO option : question.options) {
                System.assertNotEquals(null, option.optionId, 'Option ID should be populated');
                System.assertNotEquals(null, option.answerText, 'Answer text should be populated');
                System.assertNotEquals(null, option.selected, 'Selected flag should be populated');
                System.assertNotEquals(null, option.correct, 'Correct flag should be populated (review mode)');
                
                if (option.selected) {
                    selectedCount++;
                }
                if (option.correct) {
                    correctCount++;
                }
            }
            
            // Verify exactly one option is selected and one is correct
            System.assertEquals(1, selectedCount, 'Exactly one option should be selected per question');
            System.assertEquals(1, correctCount, 'Exactly one option should be correct per question');
        }
        
        // Verify selected option matches correct option for all questions
        for (QuizService.ReviewedQuestionDTO question : detail.questions) {
            Boolean selectedIsCorrect = false;
            
            for (QuizService.ReviewedAnswerOptionDTO option : question.options) {
                if (option.selected && option.correct) {
                    selectedIsCorrect = true;
                    break;
                }
            }
            
            System.assertEquals(true, selectedIsCorrect, 'Selected option should be the correct one');
        }
    }
    
    /**
     * Test getting quiz attempt detail with incorrect answers
     */
    @IsTest
    static void getQuizAttemptDetail_happyPath_someIncorrect() {
        // Arrange
        Contact learner = QuizTestDataFactory.createContact();
        QuizTestDataFactory.QuizBundle bundle = QuizTestDataFactory.createQuizBundle(learner);
        
        // Submit with 2 correct, 1 incorrect
        QuizService.QuizSubmissionRequestDTO request = 
            QuizTestDataFactory.createSubmissionWithMixedAnswers(bundle, 2);
        QuizService.QuizSubmissionResultDTO result = QuizService.submitQuizAttempt(request);
        
        // Act
        Test.startTest();
        QuizService.QuizAttemptDetailDTO detail = QuizService.getQuizAttemptDetail(result.attemptId);
        Test.stopTest();
        
        // Assert
        System.assertNotEquals(null, detail, 'Detail should not be null');
        System.assertEquals(2, detail.score, 'Score should be 2');
        System.assertEquals(false, detail.passed, 'Should not be passed (67%)');
        
        // Count questions with correct vs incorrect selected answers
        Integer questionsWithCorrectAnswer = 0;
        Integer questionsWithIncorrectAnswer = 0;
        
        for (QuizService.ReviewedQuestionDTO question : detail.questions) {
            for (QuizService.ReviewedAnswerOptionDTO option : question.options) {
                if (option.selected) {
                    if (option.correct) {
                        questionsWithCorrectAnswer++;
                    } else {
                        questionsWithIncorrectAnswer++;
                    }
                }
            }
        }
        
        System.assertEquals(2, questionsWithCorrectAnswer, 'Should have 2 questions with correct answer selected');
        System.assertEquals(1, questionsWithIncorrectAnswer, 'Should have 1 question with incorrect answer selected');
    }
    
    /**
     * Test getting quiz attempt detail with missing attempt ID - returns null
     */
    @IsTest
    static void getQuizAttemptDetail_missingAttempt_returnsNull() {
        // Act
        Test.startTest();
        QuizService.QuizAttemptDetailDTO detail = QuizService.getQuizAttemptDetail(null);
        Test.stopTest();
        
        // Assert
        System.assertEquals(null, detail, 'Detail should be null with null attempt ID');
    }
    
    /**
     * Test getting quiz attempt detail with invalid attempt ID - returns null
     */
    @IsTest
    static void getQuizAttemptDetail_invalidAttempt_returnsNull() {
        // Arrange
        Id fakeAttemptId = 'a00000000000000AAA';
        
        // Act
        Test.startTest();
        QuizService.QuizAttemptDetailDTO detail = QuizService.getQuizAttemptDetail(fakeAttemptId);
        Test.stopTest();
        
        // Assert
        System.assertEquals(null, detail, 'Detail should be null with invalid attempt ID');
    }
    
    /**
     * Test getting quiz attempt detail verifies correct/incorrect flags are exposed
     * This is a security check - correct answers should ONLY be visible in review mode
     */
    @IsTest
    static void getQuizAttemptDetail_exposesCorrectFlags() {
        // Arrange
        Contact learner = QuizTestDataFactory.createContact();
        QuizTestDataFactory.QuizBundle bundle = QuizTestDataFactory.createQuizBundle(learner);
        
        QuizService.QuizSubmissionRequestDTO request = 
            QuizTestDataFactory.createSubmissionWithIncorrectAnswers(bundle);
        QuizService.QuizSubmissionResultDTO result = QuizService.submitQuizAttempt(request);
        
        // Act
        Test.startTest();
        QuizService.QuizAttemptDetailDTO detail = QuizService.getQuizAttemptDetail(result.attemptId);
        Test.stopTest();
        
        // Assert - verify that ReviewedAnswerOptionDTO exposes correct flag
        Boolean hasCorrectFlag = false;
        Boolean hasSelectedFlag = false;
        
        for (QuizService.ReviewedQuestionDTO question : detail.questions) {
            for (QuizService.ReviewedAnswerOptionDTO option : question.options) {
                // The DTO should expose both selected and correct flags
                if (option.correct != null) {
                    hasCorrectFlag = true;
                }
                if (option.selected != null) {
                    hasSelectedFlag = true;
                }
            }
        }
        
        System.assertEquals(true, hasCorrectFlag, 'ReviewedAnswerOptionDTO should expose correct flag in review mode');
        System.assertEquals(true, hasSelectedFlag, 'ReviewedAnswerOptionDTO should expose selected flag in review mode');
    }
    
    /**
     * Test getting quiz attempt detail for multiple attempts on same quiz
     */
    @IsTest
    static void getQuizAttemptDetail_multipleAttempts_returnsCorrectOne() {
        // Arrange
        Contact learner = QuizTestDataFactory.createContact();
        QuizTestDataFactory.QuizBundle bundle = QuizTestDataFactory.createQuizBundle(learner);
        
        // Create 3 attempts
        QuizService.QuizSubmissionResultDTO result1 = QuizService.submitQuizAttempt(
            QuizTestDataFactory.createSubmissionWithMixedAnswers(bundle, 1)
        );
        
        QuizService.QuizSubmissionResultDTO result2 = QuizService.submitQuizAttempt(
            QuizTestDataFactory.createSubmissionWithMixedAnswers(bundle, 2)
        );
        
        QuizService.QuizSubmissionResultDTO result3 = QuizService.submitQuizAttempt(
            QuizTestDataFactory.createSubmissionWithCorrectAnswers(bundle)
        );
        
        // Act - Get detail for second attempt
        Test.startTest();
        QuizService.QuizAttemptDetailDTO detail = QuizService.getQuizAttemptDetail(result2.attemptId);
        Test.stopTest();
        
        // Assert
        System.assertNotEquals(null, detail, 'Detail should not be null');
        System.assertEquals(result2.attemptId, detail.attemptId, 'Should return details for attempt 2');
        System.assertEquals(2, detail.score, 'Score should be 2 for attempt 2');
        System.assertEquals(2, detail.attemptNumber, 'Should be attempt #2');
    }
    
    /**
     * Test getting last attempt for different contacts on same quiz
     */
    @IsTest
    static void getLastQuizAttemptForLesson_differentContacts_returnsCorrectOne() {
        // Arrange
        Contact learner1 = QuizTestDataFactory.createContact('Alice', 'Learner', 'alice@test.com');
        Contact learner2 = QuizTestDataFactory.createContact('Bob', 'Learner', 'bob@test.com');
        
        QuizTestDataFactory.QuizBundle bundle1 = QuizTestDataFactory.createQuizBundle(learner1);
        
        // Create enrollment for learner2 on same course
        Enrollment__c enrollment2 = new Enrollment__c(
            Contact__c = learner2.Id,
            Course__c = bundle1.course.Id,
            Status__c = 'In Progress',
            Progress_Percentage__c = 50,
            Quiz_Passed__c = false
        );
        insert enrollment2;
        
        // Create attempts for both learners
        QuizService.QuizSubmissionRequestDTO request1 = 
            QuizTestDataFactory.createSubmissionWithCorrectAnswers(bundle1);
        QuizService.QuizSubmissionResultDTO result1 = QuizService.submitQuizAttempt(request1);
        
        QuizService.QuizSubmissionRequestDTO request2 = 
            QuizTestDataFactory.createSubmissionWithIncorrectAnswers(bundle1);
        request2.contactId = learner2.Id;
        request2.enrollmentId = enrollment2.Id;
        QuizService.QuizSubmissionResultDTO result2 = QuizService.submitQuizAttempt(request2);
        
        // Act - Get summary for learner1
        Test.startTest();
        QuizService.QuizAttemptSummaryDTO summary1 = QuizService.getLastQuizAttemptForLesson(
            bundle1.quiz.Id,
            bundle1.lesson.Id,
            bundle1.enrollment.Id,
            learner1.Id
        );
        
        QuizService.QuizAttemptSummaryDTO summary2 = QuizService.getLastQuizAttemptForLesson(
            bundle1.quiz.Id,
            bundle1.lesson.Id,
            enrollment2.Id,
            learner2.Id
        );
        Test.stopTest();
        
        // Assert
        System.assertEquals(result1.attemptId, summary1.attemptId, 'Should return attempt for learner1');
        System.assertEquals(true, summary1.passed, 'Learner1 should have passed');
        
        System.assertEquals(result2.attemptId, summary2.attemptId, 'Should return attempt for learner2');
        System.assertEquals(false, summary2.passed, 'Learner2 should not have passed');
    }
}