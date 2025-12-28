//
// SPDX-License-Identifier: MIT
// TrailForge — Open Source under the MIT License
// Copyright (c) 2025 Robert Davis
// See the LICENSE file in the project root for full license text.
//
/**
 * @description Test class for QuizAdminController
 * Tests CRUD operations for Quiz Builder admin UI
 * 
 * @author TrailForge Team
 * @date 2025-11-25
 */
@isTest
private class QuizAdminController_Test {
    
    @TestSetup
    static void setupTestData() {
        // Create Course
        Course__c course = new Course__c(
            Name = 'Admin Quiz Test Course',
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
            Name = 'Test Lesson for Quiz Builder',
            Module__c = module.Id,
            Content_Body__c = 'Test content',
            Archived__c = false
        );
        insert lesson;
        
        // Create Contact for attempts test
        Contact learner = new Contact(
            FirstName = 'Quiz',
            LastName = 'Learner',
            Email = 'quizlearner@test.com'
        );
        insert learner;
    }
    
    /**
     * Test creating a new quiz
     */
    @isTest
    static void testCreateQuiz() {
        Lesson__c lesson = [SELECT Id FROM Lesson__c LIMIT 1];
        
        QuizAdminController.QuizDetailDTO dto = new QuizAdminController.QuizDetailDTO();
        dto.name = 'New Test Quiz';
        dto.level = 'Lesson';
        dto.lessonId = String.valueOf(lesson.Id);
        dto.isActive = false;
        dto.isArchived = false;
        dto.passingScore = 80;
        dto.allowRetakes = true;
        dto.sortOrder = 1;
        dto.instructions = 'Complete all questions';
        dto.questions = new List<QuizAdminController.QuestionDTO>();
        
        Test.startTest();
        String quizIdStr = QuizAdminController.saveQuiz(JSON.serialize(dto));
        Test.stopTest();
        
        System.assertNotEquals(null, quizIdStr, 'Quiz should be created');
        
        Quiz__c quiz = [
            SELECT Id, Name, Level__c, Lesson__c, Active__c, Passing_Score__c
            FROM Quiz__c
            WHERE Id = :quizIdStr
        ];
        
        System.assertEquals('New Test Quiz', quiz.Name);
        System.assertEquals('Lesson', quiz.Level__c);
        System.assertEquals(lesson.Id, quiz.Lesson__c);
        System.assertEquals(false, quiz.Active__c);
        System.assertEquals(80, quiz.Passing_Score__c);
    }
    
    /**
     * Test getting all quizzes
     */
    @isTest
    static void testGetAllQuizzes() {
        Lesson__c lesson = [SELECT Id FROM Lesson__c LIMIT 1];
        
        // Create test quiz
        Quiz__c quiz = new Quiz__c(
            Name = 'List Test Quiz',
            Level__c = 'Lesson',
            Lesson__c = lesson.Id,
            Active__c = true,
            Archived__c = false,
            Passing_Score__c = 70
        );
        insert quiz;
        
        Test.startTest();
        List<QuizAdminController.QuizListItemDTO> quizzes = QuizAdminController.getAllQuizzes();
        Test.stopTest();
        
        System.assertEquals(1, quizzes.size(), 'Should return 1 quiz');
        System.assertEquals(quiz.Id, quizzes[0].quizId);
        System.assertEquals('List Test Quiz', quizzes[0].name);
        System.assertEquals('Lesson', quizzes[0].level);
        System.assertEquals(true, quizzes[0].isActive);
    }
    
    /**
     * Test getting quiz details with questions and options
     */
    @isTest
    static void testGetQuizDetails() {
        Lesson__c lesson = [SELECT Id FROM Lesson__c LIMIT 1];
        
        // Create quiz
        Quiz__c quiz = new Quiz__c(
            Name = 'Detail Test Quiz',
            Level__c = 'Lesson',
            Lesson__c = lesson.Id,
            Active__c = true,
            Passing_Score__c = 75
        );
        insert quiz;
        
        // Create questions
        List<Quiz_Question__c> questions = new List<Quiz_Question__c>{
            new Quiz_Question__c(
                Quiz__c = quiz.Id,
                Question_Text__c = 'What is 2+2?',
                Question_Type__c = 'MultipleChoice',
                Points__c = 1,
                Required__c = true,
                Sort_Order__c = 1
            ),
            new Quiz_Question__c(
                Quiz__c = quiz.Id,
                Question_Text__c = 'What is Salesforce?',
                Question_Type__c = 'MultipleChoice',
                Points__c = 1,
                Required__c = true,
                Sort_Order__c = 2
            )
        };
        insert questions;
        
        // Create answer options
        List<Quiz_Answer_Option__c> options = new List<Quiz_Answer_Option__c>{
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
                Quiz_Question__c = questions[1].Id,
                Answer_Text__c = 'A CRM platform',
                Is_Correct__c = true,
                Sort_Order__c = 1,
                Is_Active__c = true
            )
        };
        insert options;
        
        Test.startTest();
        QuizAdminController.QuizDetailDTO dto = QuizAdminController.getQuizDetails(String.valueOf(quiz.Id));
        Test.stopTest();
        
        System.assertEquals(String.valueOf(quiz.Id), dto.quizId);
        System.assertEquals('Detail Test Quiz', dto.name);
        System.assertEquals(2, dto.questions.size(), 'Should have 2 questions');
        System.assertEquals('What is 2+2?', dto.questions[0].questionText);
        System.assertEquals(2, dto.questions[0].options.size(), 'First question should have 2 options');
        System.assertEquals(1, dto.questions[1].options.size(), 'Second question should have 1 option');
        System.assertEquals(true, dto.questions[0].options[1].isCorrect, 'Option "4" should be correct');
    }
    
    /**
     * Test full quiz save with questions and options
     */
    @isTest
    static void testSaveQuizFull() {
        Lesson__c lesson = [SELECT Id FROM Lesson__c LIMIT 1];
        
        // Build quiz DTO
        QuizAdminController.QuizDetailDTO dto = new QuizAdminController.QuizDetailDTO();
        dto.name = 'Full Save Test Quiz';
        dto.level = 'Lesson';
        dto.lessonId = lesson.Id;
        dto.isActive = true;
        dto.isArchived = false;
        dto.passingScore = 70;
        dto.allowRetakes = true;
        dto.sortOrder = 1;
        dto.instructions = 'Answer all questions';
        
        // Add questions
        dto.questions = new List<QuizAdminController.QuestionDTO>();
        
        QuizAdminController.QuestionDTO q1 = new QuizAdminController.QuestionDTO();
        q1.questionId = 'temp-q1'; // Temp ID for new question
        q1.questionText = 'What is the capital of France?';
        q1.questionType = 'MultipleChoice';
        q1.points = 1;
        q1.required = true;
        q1.sortOrder = 1;
        
        // Add answer options
        q1.options = new List<QuizAdminController.AnswerOptionDTO>();
        
        QuizAdminController.AnswerOptionDTO opt1 = new QuizAdminController.AnswerOptionDTO();
        opt1.optionId = 'temp-opt1';
        opt1.answerText = 'London';
        opt1.isCorrect = false;
        opt1.sortOrder = 1;
        opt1.isActive = true;
        q1.options.add(opt1);
        
        QuizAdminController.AnswerOptionDTO opt2 = new QuizAdminController.AnswerOptionDTO();
        opt2.optionId = 'temp-opt2';
        opt2.answerText = 'Paris';
        opt2.isCorrect = true;
        opt2.sortOrder = 2;
        opt2.isActive = true;
        q1.options.add(opt2);
        
        dto.questions.add(q1);
        
        Test.startTest();
        Id quizId = QuizAdminController.saveQuizFull(JSON.serialize(dto));
        Test.stopTest();
        
        System.assertNotEquals(null, quizId, 'Quiz should be created');
        
        // Verify quiz
        Quiz__c quiz = [SELECT Id, Name, Active__c FROM Quiz__c WHERE Id = :quizId];
        System.assertEquals('Full Save Test Quiz', quiz.Name);
        System.assertEquals(true, quiz.Active__c);
        
        // Verify questions
        List<Quiz_Question__c> questions = [
            SELECT Id, Question_Text__c, 
                   (SELECT Id, Answer_Text__c, Is_Correct__c FROM Answer_Options__r ORDER BY Sort_Order__c)
            FROM Quiz_Question__c
            WHERE Quiz__c = :quizId
        ];
        
        System.assertEquals(1, questions.size(), 'Should have 1 question');
        System.assertEquals('What is the capital of France?', questions[0].Question_Text__c);
        System.assertEquals(2, questions[0].Answer_Options__r.size(), 'Question should have 2 options');
        System.assertEquals('London', questions[0].Answer_Options__r[0].Answer_Text__c);
        System.assertEquals(false, questions[0].Answer_Options__r[0].Is_Correct__c);
        System.assertEquals('Paris', questions[0].Answer_Options__r[1].Answer_Text__c);
        System.assertEquals(true, questions[0].Answer_Options__r[1].Is_Correct__c);
    }
    
    /**
     * Test updating existing quiz
     */
    @isTest
    static void testUpdateQuiz() {
        Lesson__c lesson = [SELECT Id FROM Lesson__c LIMIT 1];
        
        // Create initial quiz
        Quiz__c quiz = new Quiz__c(
            Name = 'Original Name',
            Level__c = 'Lesson',
            Lesson__c = lesson.Id,
            Active__c = false,
            Passing_Score__c = 60
        );
        insert quiz;
        
        // Create question
        Quiz_Question__c question = new Quiz_Question__c(
            Quiz__c = quiz.Id,
            Question_Text__c = 'Original Question',
            Question_Type__c = 'MultipleChoice',
            Points__c = 1
        );
        insert question;
        
        // Create option
        Quiz_Answer_Option__c option = new Quiz_Answer_Option__c(
            Quiz_Question__c = question.Id,
            Answer_Text__c = 'Original Answer',
            Is_Correct__c = true,
            Is_Active__c = true
        );
        insert option;
        
        // Build update DTO
        QuizAdminController.QuizDetailDTO dto = new QuizAdminController.QuizDetailDTO();
        dto.quizId = String.valueOf(quiz.Id);
        dto.name = 'Updated Name';
        dto.level = 'Lesson';
        dto.lessonId = String.valueOf(lesson.Id);
        dto.isActive = true;
        dto.passingScore = 80;
        dto.allowRetakes = false;
        
        dto.questions = new List<QuizAdminController.QuestionDTO>();
        
        QuizAdminController.QuestionDTO q1 = new QuizAdminController.QuestionDTO();
        q1.questionId = String.valueOf(question.Id);
        q1.questionText = 'Updated Question';
        q1.questionType = 'MultipleChoice';
        q1.points = 2;
        q1.required = true;
        
        q1.options = new List<QuizAdminController.AnswerOptionDTO>();
        
        QuizAdminController.AnswerOptionDTO opt1 = new QuizAdminController.AnswerOptionDTO();
        opt1.optionId = String.valueOf(option.Id);
        opt1.answerText = 'Updated Answer';
        opt1.isCorrect = true;
        opt1.isActive = true;
        q1.options.add(opt1);
        
        dto.questions.add(q1);
        
        Test.startTest();
        String updatedQuizId = QuizAdminController.saveQuizFull(JSON.serialize(dto));
        Test.stopTest();
        
        System.assertEquals(String.valueOf(quiz.Id), updatedQuizId, 'Should update existing quiz');
        
        // Verify updates
        Quiz__c updatedQuiz = [SELECT Name, Active__c, Passing_Score__c, Allow_Retakes__c FROM Quiz__c WHERE Id = :quiz.Id];
        System.assertEquals('Updated Name', updatedQuiz.Name);
        System.assertEquals(true, updatedQuiz.Active__c);
        System.assertEquals(80, updatedQuiz.Passing_Score__c);
        System.assertEquals(false, updatedQuiz.Allow_Retakes__c);
        
        Quiz_Question__c updatedQuestion = [SELECT Question_Text__c, Points__c FROM Quiz_Question__c WHERE Id = :question.Id];
        System.assertEquals('Updated Question', updatedQuestion.Question_Text__c);
        System.assertEquals(2, updatedQuestion.Points__c);
        
        Quiz_Answer_Option__c updatedOption = [SELECT Answer_Text__c FROM Quiz_Answer_Option__c WHERE Id = :option.Id];
        System.assertEquals('Updated Answer', updatedOption.Answer_Text__c);
    }
    
    /**
     * Test deleting question
     */
    @isTest
    static void testDeleteQuestion() {
        Lesson__c lesson = [SELECT Id FROM Lesson__c LIMIT 1];
        
        Quiz__c quiz = new Quiz__c(
            Name = 'Delete Test Quiz',
            Level__c = 'Lesson',
            Lesson__c = lesson.Id,
            Passing_Score__c = 70
        );
        insert quiz;
        
        Quiz_Question__c question = new Quiz_Question__c(
            Quiz__c = quiz.Id,
            Question_Text__c = 'To be deleted',
            Question_Type__c = 'MultipleChoice'
        );
        insert question;
        
        Quiz_Answer_Option__c option = new Quiz_Answer_Option__c(
            Quiz_Question__c = question.Id,
            Answer_Text__c = 'Option',
            Is_Correct__c = true,
            Is_Active__c = true
        );
        insert option;
        
        Test.startTest();
        QuizAdminController.deleteQuestion(question.Id);
        Test.stopTest();
        
        // Verify question deleted
        List<Quiz_Question__c> questions = [SELECT Id FROM Quiz_Question__c WHERE Id = :question.Id];
        System.assertEquals(0, questions.size(), 'Question should be deleted');
        
        // Verify options cascaded delete (Master-Detail)
        List<Quiz_Answer_Option__c> options = [SELECT Id FROM Quiz_Answer_Option__c WHERE Id = :option.Id];
        System.assertEquals(0, options.size(), 'Options should be cascade deleted');
    }
    
    /**
     * Test deleting answer option
     */
    @isTest
    static void testDeleteOption() {
        Lesson__c lesson = [SELECT Id FROM Lesson__c LIMIT 1];
        
        Quiz__c quiz = new Quiz__c(
            Name = 'Delete Option Test Quiz',
            Level__c = 'Lesson',
            Lesson__c = lesson.Id,
            Passing_Score__c = 70
        );
        insert quiz;
        
        Quiz_Question__c question = new Quiz_Question__c(
            Quiz__c = quiz.Id,
            Question_Text__c = 'Test Question',
            Question_Type__c = 'MultipleChoice'
        );
        insert question;
        
        Quiz_Answer_Option__c option = new Quiz_Answer_Option__c(
            Quiz_Question__c = question.Id,
            Answer_Text__c = 'To be deleted',
            Is_Correct__c = false,
            Is_Active__c = true
        );
        insert option;
        
        Test.startTest();
        QuizAdminController.deleteOption(option.Id);
        Test.stopTest();
        
        List<Quiz_Answer_Option__c> options = [SELECT Id FROM Quiz_Answer_Option__c WHERE Id = :option.Id];
        System.assertEquals(0, options.size(), 'Option should be deleted');
    }
    
    /**
     * Test archiving quiz without active attempts
     */
    @isTest
    static void testArchiveQuiz_NoActiveAttempts() {
        Lesson__c lesson = [SELECT Id FROM Lesson__c LIMIT 1];
        
        Quiz__c quiz = new Quiz__c(
            Name = 'Archive Test Quiz',
            Level__c = 'Lesson',
            Lesson__c = lesson.Id,
            Active__c = true,
            Archived__c = false,
            Passing_Score__c = 70
        );
        insert quiz;
        
        Test.startTest();
        QuizAdminController.archiveQuiz(quiz.Id, true);
        Test.stopTest();
        
        Quiz__c archivedQuiz = [SELECT Archived__c, Active__c FROM Quiz__c WHERE Id = :quiz.Id];
        System.assertEquals(true, archivedQuiz.Archived__c, 'Quiz should be archived');
        System.assertEquals(false, archivedQuiz.Active__c, 'Archived quiz should not be active');
    }
    
    /**
     * Test archiving quiz with active attempts (should fail without force)
     */
    @isTest
    static void testArchiveQuiz_WithActiveAttempts() {
        Lesson__c lesson = [SELECT Id FROM Lesson__c LIMIT 1];
        Contact learner = [SELECT Id FROM Contact LIMIT 1];
        Course__c course = [SELECT Id FROM Course__c LIMIT 1];
        
        Quiz__c quiz = new Quiz__c(
            Name = 'Active Attempt Quiz',
            Level__c = 'Lesson',
            Lesson__c = lesson.Id,
            Active__c = true,
            Passing_Score__c = 70
        );
        insert quiz;
        
        // Create active attempt
        Quiz_Attempt__c attempt = new Quiz_Attempt__c(
            Quiz__c = quiz.Id,
            Contact__c = learner.Id,
            Course__c = course.Id,
            Status__c = 'In Progress',
            Score__c = 0
        );
        insert attempt;
        
        Test.startTest();
        
        Boolean exceptionThrown = false;
        try {
            QuizAdminController.archiveQuiz(quiz.Id, true);
        } catch (AuraHandledException e) {
            exceptionThrown = true;
            System.assert(e.getMessage().contains('active attempt'), 'Error should mention active attempts');
        }
        
        System.assertEquals(true, exceptionThrown, 'Should throw exception for active attempts');
        
        // Complete the attempt, then archive should succeed
        attempt.Status__c = 'Completed';
        update attempt;
        QuizAdminController.archiveQuiz(quiz.Id, true);

        
        
        Test.stopTest();
        
        Quiz__c archivedQuiz = [SELECT Archived__c FROM Quiz__c WHERE Id = :quiz.Id];
        System.assertEquals(true, archivedQuiz.Archived__c, 'Quiz should be archived after completing attempts');
    }
    
    /**
     * Test validation: Course-level quiz must have courseId
     */
    @isTest
    static void testValidation_CourseLevelRequiresCourse() {
        QuizAdminController.QuizDetailDTO dto = new QuizAdminController.QuizDetailDTO();
        dto.name = 'Invalid Course Quiz';
        dto.level = 'Course';
        dto.courseId = null; // Missing course
        dto.isActive = true;
        dto.passingScore = 70;
        dto.questions = new List<QuizAdminController.QuestionDTO>();
        
        Test.startTest();
        
        Boolean exceptionThrown = false;
        try {
            QuizAdminController.saveQuiz(JSON.serialize(dto));
        } catch (AuraHandledException e) {
            exceptionThrown = true;
            System.assert(e.getMessage().contains('Course is required'), 'Error should mention course requirement');
        }
        
        Test.stopTest();
        
        System.assertEquals(true, exceptionThrown, 'Should throw exception for missing course');
    }
    
    /**
     * Test validation: MultipleChoice question must have correct answer
     */
    @isTest
    static void testValidation_RequireCorrectAnswer() {
        Lesson__c lesson = [SELECT Id FROM Lesson__c LIMIT 1];
        
        QuizAdminController.QuizDetailDTO dto = new QuizAdminController.QuizDetailDTO();
        dto.name = 'No Correct Answer Quiz';
        dto.level = 'Lesson';
        dto.lessonId = String.valueOf(lesson.Id);
        dto.isActive = true;
        dto.passingScore = 70;
        
        dto.questions = new List<QuizAdminController.QuestionDTO>();
        
        QuizAdminController.QuestionDTO q1 = new QuizAdminController.QuestionDTO();
        q1.questionId = 'temp-q1';
        q1.questionText = 'Question without correct answer';
        q1.questionType = 'MultipleChoice';
        q1.points = 1;
        
        q1.options = new List<QuizAdminController.AnswerOptionDTO>();
        
        QuizAdminController.AnswerOptionDTO opt1 = new QuizAdminController.AnswerOptionDTO();
        opt1.optionId = 'temp-opt1';
        opt1.answerText = 'Wrong answer 1';
        opt1.isCorrect = false;
        opt1.isActive = true;
        q1.options.add(opt1);
        
        QuizAdminController.AnswerOptionDTO opt2 = new QuizAdminController.AnswerOptionDTO();
        opt2.optionId = 'temp-opt2';
        opt2.answerText = 'Wrong answer 2';
        opt2.isCorrect = false; // No correct answer!
        opt2.isActive = true;
        q1.options.add(opt2);
        
        dto.questions.add(q1);
        
        Test.startTest();
        
        Boolean exceptionThrown = false;
        try {
            QuizAdminController.saveQuizFull(JSON.serialize(dto));
        } catch (AuraHandledException e) {
            exceptionThrown = true;
            System.assert(e.getMessage().contains('correct answer'), 'Error should mention correct answer requirement');
        }
        
        Test.stopTest();
        
        System.assertEquals(true, exceptionThrown, 'Should throw exception for missing correct answer');
    }
    
    /**
     * Test Course lookup search
     */
    @isTest
    static void testSearchLookup_Course() {
        Test.startTest();
        List<QuizAdminController.LookupResultDTO> results = 
            QuizAdminController.searchLookup('Admin', 'Course');
        Test.stopTest();
        
        System.assertEquals(1, results.size(), 'Should find 1 course');
        System.assertEquals('Admin Quiz Test Course', results[0].label);
    }
    
    /**
     * Test Lesson lookup search
     */
    @isTest
    static void testSearchLookup_Lesson() {
        Test.startTest();
        List<QuizAdminController.LookupResultDTO> results = 
            QuizAdminController.searchLookup('Builder', 'Lesson');
        Test.stopTest();
        
        System.assertEquals(1, results.size(), 'Should find 1 lesson');
        System.assert(results[0].label.contains('Test Lesson for Quiz Builder'), 'Label should contain lesson name');
    }
    
    /**
     * Test bulk operations don't exceed governor limits
     */
    @isTest
    static void testBulkOperations_NoGovernorLimits() {
        Lesson__c lesson = [SELECT Id FROM Lesson__c LIMIT 1];
        
        // Build quiz with 20 questions, each with 4 options (80 total options)
        QuizAdminController.QuizDetailDTO dto = new QuizAdminController.QuizDetailDTO();
        dto.name = 'Bulk Test Quiz';
        dto.level = 'Lesson';
        dto.lessonId = String.valueOf(lesson.Id);
        dto.isActive = false;
        dto.passingScore = 70;
        
        dto.questions = new List<QuizAdminController.QuestionDTO>();
        
        for (Integer i = 0; i < 20; i++) {
            QuizAdminController.QuestionDTO q = new QuizAdminController.QuestionDTO();
            q.questionId = 'temp-q' + i;
            q.questionText = 'Question ' + i;
            q.questionType = 'MultipleChoice';
            q.points = 1;
            q.required = true;
            
            q.options = new List<QuizAdminController.AnswerOptionDTO>();
            
            for (Integer j = 0; j < 4; j++) {
                QuizAdminController.AnswerOptionDTO opt = new QuizAdminController.AnswerOptionDTO();
                opt.optionId = 'temp-opt' + i + '-' + j;
                opt.answerText = 'Option ' + j;
                opt.isCorrect = (j == 0); // First option is correct
                opt.isActive = true;
                q.options.add(opt);
            }
            
            dto.questions.add(q);
        }
        
        Test.startTest();
        String quizId = QuizAdminController.saveQuizFull(JSON.serialize(dto));
        Test.stopTest();
        
        // Verify all questions and options created
        List<Quiz_Question__c> questions = [
            SELECT Id, (SELECT Id FROM Answer_Options__r)
            FROM Quiz_Question__c
            WHERE Quiz__c = :quizId
        ];
        
        System.assertEquals(20, questions.size(), 'Should have 20 questions');
        
        Integer totalOptions = 0;
        for (Quiz_Question__c q : questions) {
            totalOptions += q.Answer_Options__r.size();
        }
        
        System.assertEquals(80, totalOptions, 'Should have 80 total options');
        
        // Verify no governor limit violations (test would fail if exceeded)
        System.assert(Limits.getQueries() < Limits.getLimitQueries(), 'Should not exceed SOQL limit');
        System.assert(Limits.getDMLStatements() < Limits.getLimitDMLStatements(), 'Should not exceed DML limit');
    }
}