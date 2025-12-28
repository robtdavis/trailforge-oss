//
// SPDX-License-Identifier: MIT
// TrailForge — Open Source under the MIT License
// Copyright (c) 2025 Robert Davis
// See the LICENSE file in the project root for full license text.
//
/**
 * Test data factory for quiz-related entities
 * Provides helper methods to create test data for quiz submission and review flows
 */
@IsTest
public class QuizTestDataFactory {
    
    /**
     * Bundle DTO containing all quiz-related test data
     */
    public class QuizBundle {
        public Contact learner;
        public Course__c course;
        public Module__c module;
        public Lesson__c lesson;
        public Quiz__c quiz;
        public List<Quiz_Question__c> questions;
        public Map<Id, List<Quiz_Answer_Option__c>> optionsByQuestion;
        public Enrollment__c enrollment;
        
        public QuizBundle() {
            this.questions = new List<Quiz_Question__c>();
            this.optionsByQuestion = new Map<Id, List<Quiz_Answer_Option__c>>();
        }
    }
    
    /**
     * Creates a contact for testing
     */
    public static Contact createContact() {
        return createContact('Test', 'Learner', 'testlearner@trailforge.test');
    }
    
    /**
     * Creates a contact with specified details
     */
    public static Contact createContact(String firstName, String lastName, String email) {
        Contact c = new Contact(
            FirstName = firstName,
            LastName = lastName,
            Email = email
        );
        insert c;
        return c;
    }
    
    /**
     * Creates a complete quiz bundle with course, module, lesson, quiz, questions, and options
     * @param learner The contact to associate with enrollment
     * @return QuizBundle containing all created records
     */
    public static QuizBundle createQuizBundle(Contact learner) {
        return createQuizBundle(learner, 3, 3);
    }
    
    /**
     * Creates a complete quiz bundle with specified number of questions and options
     * @param learner The contact to associate with enrollment
     * @param numQuestions Number of questions to create
     * @param numOptionsPerQuestion Number of options per question (first will be correct)
     * @return QuizBundle containing all created records
     */
    public static QuizBundle createQuizBundle(Contact learner, Integer numQuestions, Integer numOptionsPerQuestion) {
        QuizBundle bundle = new QuizBundle();
        bundle.learner = learner;
        
        // Create Course
        bundle.course = new Course__c(
            Name = 'Test Course',
            Passing_Score__c = 70,
            Archived__c = false
        );
        insert bundle.course;
        
        // Create Module
        bundle.module = new Module__c(
            Name = 'Test Module',
            Course__c = bundle.course.Id,
            Archived__c = false
        );
        insert bundle.module;
        
        // Create Lesson
        bundle.lesson = new Lesson__c(
            Name = 'Test Lesson',
            Module__c = bundle.module.Id,
            Content_Body__c = 'Test lesson content',
            Archived__c = false
        );
        insert bundle.lesson;
        
        // Create Quiz
        bundle.quiz = new Quiz__c(
            Name = 'Test Quiz',
            Lesson__c = bundle.lesson.Id,
            Course__c = bundle.course.Id,
            Passing_Score__c = 70,
            Max_Score__c = numQuestions,
            Active__c = true,
            Archived__c = false,
            Allow_Retakes__c = true,
            Max_Attempts__c = 3,
            Instructions__c = 'Answer all questions'
        );
        insert bundle.quiz;
        
        // Update lesson to reference quiz
        bundle.lesson.Quiz__c = bundle.quiz.Id;
        update bundle.lesson;
        
        // Create Questions
        for (Integer i = 1; i <= numQuestions; i++) {
            Quiz_Question__c q = new Quiz_Question__c(
                Quiz__c = bundle.quiz.Id,
                Question_Text__c = 'Question ' + i + '?',
                Question_Type__c = 'MultipleChoice',
                Points__c = 1,
                Required__c = true,
                Sort_Order__c = i
            );
            bundle.questions.add(q);
        }
        insert bundle.questions;
        
        // Create Answer Options
        for (Quiz_Question__c question : bundle.questions) {
            List<Quiz_Answer_Option__c> options = new List<Quiz_Answer_Option__c>();
            
            for (Integer i = 1; i <= numOptionsPerQuestion; i++) {
                Quiz_Answer_Option__c opt = new Quiz_Answer_Option__c(
                    Quiz_Question__c = question.Id,
                    Answer_Text__c = 'Option ' + i,
                    Is_Correct__c = (i == 1), // First option is correct
                    Sort_Order__c = i,
                    Is_Active__c = true
                );
                options.add(opt);
            }
            
            insert options;
            bundle.optionsByQuestion.put(question.Id, options);
        }
        
        // Create Enrollment
        bundle.enrollment = new Enrollment__c(
            Contact__c = learner.Id,
            Course__c = bundle.course.Id,
            Status__c = 'In Progress',
            Progress_Percentage__c = 50,
            Quiz_Passed__c = false
        );
        insert bundle.enrollment;
        
        return bundle;
    }
    
    /**
     * Creates a quiz submission request with all correct answers
     */
    public static QuizService.QuizSubmissionRequestDTO createSubmissionWithCorrectAnswers(QuizBundle bundle) {
        QuizService.QuizSubmissionRequestDTO request = new QuizService.QuizSubmissionRequestDTO();
        request.quizId = bundle.quiz.Id;
        request.lessonId = bundle.lesson.Id;
        request.enrollmentId = bundle.enrollment.Id;
        request.contactId = bundle.learner.Id;
        
        for (Quiz_Question__c question : bundle.questions) {
            QuizService.SubmittedAnswerDTO answer = new QuizService.SubmittedAnswerDTO();
            answer.questionId = question.Id;
            
            // Select first option (which is correct)
            List<Quiz_Answer_Option__c> options = bundle.optionsByQuestion.get(question.Id);
            answer.selectedOptionIds.add(options[0].Id);
            
            request.answers.add(answer);
        }
        
        return request;
    }
    
    /**
     * Creates a quiz submission request with all incorrect answers
     */
    public static QuizService.QuizSubmissionRequestDTO createSubmissionWithIncorrectAnswers(QuizBundle bundle) {
        QuizService.QuizSubmissionRequestDTO request = new QuizService.QuizSubmissionRequestDTO();
        request.quizId = bundle.quiz.Id;
        request.lessonId = bundle.lesson.Id;
        request.enrollmentId = bundle.enrollment.Id;
        request.contactId = bundle.learner.Id;
        
        for (Quiz_Question__c question : bundle.questions) {
            QuizService.SubmittedAnswerDTO answer = new QuizService.SubmittedAnswerDTO();
            answer.questionId = question.Id;
            
            // Select second option (which is incorrect)
            List<Quiz_Answer_Option__c> options = bundle.optionsByQuestion.get(question.Id);
            if (options.size() > 1) {
                answer.selectedOptionIds.add(options[1].Id);
            }
            
            request.answers.add(answer);
        }
        
        return request;
    }
    
    /**
     * Creates a quiz submission request with mixed answers
     * @param numCorrect Number of correct answers (remaining will be incorrect)
     */
    public static QuizService.QuizSubmissionRequestDTO createSubmissionWithMixedAnswers(
        QuizBundle bundle, 
        Integer numCorrect
    ) {
        QuizService.QuizSubmissionRequestDTO request = new QuizService.QuizSubmissionRequestDTO();
        request.quizId = bundle.quiz.Id;
        request.lessonId = bundle.lesson.Id;
        request.enrollmentId = bundle.enrollment.Id;
        request.contactId = bundle.learner.Id;
        
        Integer correctCount = 0;
        
        for (Quiz_Question__c question : bundle.questions) {
            QuizService.SubmittedAnswerDTO answer = new QuizService.SubmittedAnswerDTO();
            answer.questionId = question.Id;
            
            List<Quiz_Answer_Option__c> options = bundle.optionsByQuestion.get(question.Id);
            
            // Select correct answer if still under numCorrect, otherwise incorrect
            if (correctCount < numCorrect) {
                answer.selectedOptionIds.add(options[0].Id); // Correct
                correctCount++;
            } else if (options.size() > 1) {
                answer.selectedOptionIds.add(options[1].Id); // Incorrect
            }
            
            request.answers.add(answer);
        }
        
        return request;
    }
    
    /**
     * Retrieves the correct option for a question
     */
    public static Quiz_Answer_Option__c getCorrectOption(QuizBundle bundle, Id questionId) {
        List<Quiz_Answer_Option__c> options = bundle.optionsByQuestion.get(questionId);
        for (Quiz_Answer_Option__c opt : options) {
            if (opt.Is_Correct__c) {
                return opt;
            }
        }
        return null;
    }
    
    /**
     * Retrieves an incorrect option for a question
     */
    public static Quiz_Answer_Option__c getIncorrectOption(QuizBundle bundle, Id questionId) {
        List<Quiz_Answer_Option__c> options = bundle.optionsByQuestion.get(questionId);
        for (Quiz_Answer_Option__c opt : options) {
            if (!opt.Is_Correct__c) {
                return opt;
            }
        }
        return null;
    }
}