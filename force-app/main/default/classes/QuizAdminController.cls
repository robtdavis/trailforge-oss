/**
 * @description Controller for Quiz Builder admin UI
 * Provides CRUD operations for Quiz__c, Quiz_Question__c, Quiz_Answer_Option__c
 * 
 * @author TrailForge Team
 * @date 2025-11-25
 */
public with sharing class QuizAdminController {
    
    // ========================================================================
    // DTO CLASSES
    // ========================================================================
    
    /**
     * Quiz DTO for admin UI
     */
    public class QuizDetailDTO {
        @AuraEnabled public String quizId;  // String to accept both IDs and temp IDs
        @AuraEnabled public String name;
        @AuraEnabled public String level; // 'Lesson' or 'Course'
        @AuraEnabled public String lessonId;
        @AuraEnabled public String lessonName;
        @AuraEnabled public String courseId;
        @AuraEnabled public String courseName;
        @AuraEnabled public Decimal passingScore;
        @AuraEnabled public Decimal maxScore;
        @AuraEnabled public Boolean allowRetakes;
        @AuraEnabled public Integer maxAttempts;
        @AuraEnabled public Integer sortOrder;
        @AuraEnabled public Boolean isActive;
        @AuraEnabled public Boolean isArchived;
        @AuraEnabled public String instructions;
        @AuraEnabled public List<QuestionDTO> questions;
    }
    
    /**
     * Question DTO for admin UI
     */
    public class QuestionDTO {
        @AuraEnabled public String questionId;  // String to accept both IDs and temp IDs
        @AuraEnabled public String quizId;
        @AuraEnabled public String questionText;
        @AuraEnabled public String questionType;
        @AuraEnabled public Decimal points;
        @AuraEnabled public Boolean required;
        @AuraEnabled public Integer sortOrder;
        @AuraEnabled public List<AnswerOptionDTO> options;
    }
    
    /**
     * Answer Option DTO for admin UI
     */
    public class AnswerOptionDTO {
        @AuraEnabled public String optionId;  // String to accept both IDs and temp IDs
        @AuraEnabled public String questionId;
        @AuraEnabled public String answerText;
        @AuraEnabled public Boolean isCorrect;
        @AuraEnabled public Boolean isActive;
        @AuraEnabled public Integer sortOrder;
    }
    
    /**
     * Simplified quiz DTO for list view
     */
    public class QuizListItemDTO {
        @AuraEnabled public Id quizId;
        @AuraEnabled public String name;
        @AuraEnabled public String level;
        @AuraEnabled public Id lessonId;
        @AuraEnabled public String lessonName;
        @AuraEnabled public Id courseId;
        @AuraEnabled public String courseName;
        @AuraEnabled public Boolean isActive;
        @AuraEnabled public Boolean isArchived;
        @AuraEnabled public Integer questionCount;
    }
    
    /**
     * Lookup result DTO for Course/Lesson search
     */
    public class LookupResultDTO {
        @AuraEnabled public Id value;
        @AuraEnabled public String label;
        @AuraEnabled public String sublabel;
    }
    
    // ========================================================================
    // QUERY METHODS
    // ========================================================================
    
    /**
     * Get all quizzes with basic info for list view
     */
    @AuraEnabled(cacheable=true)
    public static List<QuizListItemDTO> getAllQuizzes() {
        try {
            List<Quiz__c> quizzes = [
                SELECT Id, Name, Level__c, Lesson__c, Lesson__r.Name, Course__c, Course__r.Name,
                       Active__c, Archived__c,
                       (SELECT Id FROM Questions__r)
                FROM Quiz__c
                WHERE Archived__c = false
                ORDER BY Sort_Order__c NULLS LAST, Name
                LIMIT 200
            ];
            
            List<QuizListItemDTO> dtos = new List<QuizListItemDTO>();
            for (Quiz__c q : quizzes) {
                QuizListItemDTO dto = new QuizListItemDTO();
                dto.quizId = q.Id;
                dto.name = q.Name;
                dto.level = q.Level__c;
                dto.lessonId = q.Lesson__c;
                dto.lessonName = q.Lesson__c != null ? q.Lesson__r.Name : null;
                dto.courseId = q.Course__c;
                dto.courseName = q.Course__c != null ? q.Course__r.Name : null;
                dto.isActive = q.Active__c;
                dto.isArchived = q.Archived__c;
                dto.questionCount = q.Questions__r != null ? q.Questions__r.size() : 0;
                dtos.add(dto);
            }
            
            return dtos;
            
        } catch (Exception e) {
            Logger.logError('QuizAdminController', 'getAllQuizzes', e, 0);
            AuraHandledException auraEx = new AuraHandledException('Unable to load quizzes: ' + e.getMessage());
            auraEx.setMessage('Unable to load quizzes: ' + e.getMessage());
            throw auraEx;
        }
    }
    
    /**
     * Get full quiz details including questions and options
     */
    @AuraEnabled
    public static QuizDetailDTO getQuizDetails(String quizId) {
        try {
            if (String.isBlank(quizId)) {
                throw new IllegalArgumentException('Quiz ID is required');
            }
            
            Id quizIdValue = (Id) quizId;
            
            List<Quiz__c> quizzes = [
                SELECT Id, Name, Level__c, Lesson__c, Lesson__r.Name, Course__c, Course__r.Name,
                       Passing_Score__c, Max_Score__c, Allow_Retakes__c, Max_Attempts__c,
                       Sort_Order__c, Active__c, Archived__c, Instructions__c,
                       (SELECT Id, Quiz__c, Question_Text__c, Question_Type__c, Points__c, Required__c, Sort_Order__c
                        FROM Questions__r
                        ORDER BY Sort_Order__c NULLS LAST)
                FROM Quiz__c
                WHERE Id = :quizIdValue
                LIMIT 1
            ];
            
            if (quizzes.isEmpty()) {
                throw new IllegalArgumentException('Quiz not found: ' + quizId);
            }
            
            Quiz__c quiz = quizzes[0];
            
            // Get all questions IDs
            Set<Id> questionIds = new Set<Id>();
            for (Quiz_Question__c q : quiz.Questions__r) {
                questionIds.add(q.Id);
            }
            
            // Query options separately to avoid relationship depth limits
            Map<Id, List<Quiz_Answer_Option__c>> optionsByQuestion = new Map<Id, List<Quiz_Answer_Option__c>>();
            if (!questionIds.isEmpty()) {
                List<Quiz_Answer_Option__c> options = [
                    SELECT Id, Quiz_Question__c, Answer_Text__c, Is_Correct__c, Is_Active__c, Sort_Order__c
                    FROM Quiz_Answer_Option__c
                    WHERE Quiz_Question__c IN :questionIds
                    ORDER BY Sort_Order__c NULLS LAST
                ];
                
                for (Quiz_Answer_Option__c opt : options) {
                    if (!optionsByQuestion.containsKey(opt.Quiz_Question__c)) {
                        optionsByQuestion.put(opt.Quiz_Question__c, new List<Quiz_Answer_Option__c>());
                    }
                    optionsByQuestion.get(opt.Quiz_Question__c).add(opt);
                }
            }
            
            // Build DTO
            QuizDetailDTO dto = mapQuizToDTO(quiz, true);
            dto.questions = new List<QuestionDTO>();
            
            for (Quiz_Question__c q : quiz.Questions__r) {
                QuestionDTO qDto = mapQuestionToDTO(q);
                qDto.options = new List<AnswerOptionDTO>();
                
                if (optionsByQuestion.containsKey(q.Id)) {
                    for (Quiz_Answer_Option__c opt : optionsByQuestion.get(q.Id)) {
                        qDto.options.add(mapOptionToDTO(opt));
                    }
                }
                
                dto.questions.add(qDto);
            }
            
            return dto;
            
        } catch (Exception e) {
            Logger.logError('QuizAdminController', 'getQuizDetails', e, 0);
            AuraHandledException auraEx = new AuraHandledException('Unable to load quiz details: ' + e.getMessage());
            auraEx.setMessage('Unable to load quiz details: ' + e.getMessage());
            throw auraEx;
        }
    }
    
    // ========================================================================
    // SAVE METHODS
    // ========================================================================
    
    /**
     * Create or update quiz with questions and options
     */
    @AuraEnabled
    public static String saveQuiz(String quizJSON) {
        try {
            QuizDetailDTO dto = (QuizDetailDTO) JSON.deserialize(quizJSON, QuizDetailDTO.class);
            
            // Validate
            validateQuizDTO(dto);
            
            // Upsert quiz
            Quiz__c quiz = new Quiz__c();
            if (String.isNotBlank(dto.quizId)) {
                quiz.Id = (Id) dto.quizId;
            }
            quiz.Name = dto.name;
            quiz.Level__c = dto.level;
            quiz.Lesson__c = String.isNotBlank(dto.lessonId) ? (Id) dto.lessonId : null;
            quiz.Course__c = String.isNotBlank(dto.courseId) ? (Id) dto.courseId : null;
            quiz.Passing_Score__c = dto.passingScore;
            quiz.Max_Score__c = dto.maxScore;
            quiz.Allow_Retakes__c = dto.allowRetakes;
            quiz.Max_Attempts__c = dto.maxAttempts;
            quiz.Sort_Order__c = dto.sortOrder;
            quiz.Active__c = dto.isActive;
            quiz.Archived__c = dto.isArchived;
            quiz.Instructions__c = dto.instructions;
            
            upsert quiz;
            
            // Upsert questions if provided
            if (dto.questions != null && !dto.questions.isEmpty()) {
                saveQuestions(String.valueOf(quiz.Id), dto.questions);
            }
            
            // Return quiz Id
            return String.valueOf(quiz.Id);
            
        } catch (Exception e) {
            Logger.logError('QuizAdminController', 'saveQuiz', e, 0);
            AuraHandledException auraEx = new AuraHandledException('Unable to save quiz: ' + e.getMessage());
            auraEx.setMessage('Unable to save quiz: ' + e.getMessage());
            throw auraEx;
        }
    }
    
    /**
     * Save questions and their options
     */
    @AuraEnabled
    public static List<QuestionDTO> saveQuestions(String quizId, List<QuestionDTO> questionDTOs) {
        try {
            if (String.isBlank(quizId)) {
                throw new IllegalArgumentException('Quiz ID is required');
            }
            
            Id quizIdValue = (Id) quizId;
            
            List<Quiz_Question__c> questions = new List<Quiz_Question__c>();
            Map<String, List<AnswerOptionDTO>> optionsByTempId = new Map<String, List<AnswerOptionDTO>>();
            
            for (QuestionDTO qDto : questionDTOs) {
                Quiz_Question__c q = new Quiz_Question__c();
                if (String.isNotBlank(qDto.questionId)) {
                    try {
                        q.Id = (Id) qDto.questionId;
                    } catch (Exception e) {
                        // Ignore invalid temp IDs
                    }
                }
                q.Quiz__c = quizIdValue;
                q.Question_Text__c = qDto.questionText;
                q.Question_Type__c = qDto.questionType != null ? qDto.questionType : 'MultipleChoice';
                q.Points__c = qDto.points != null ? qDto.points : 1;
                q.Required__c = qDto.required != null ? qDto.required : true;
                q.Sort_Order__c = qDto.sortOrder;
                
                questions.add(q);
                
                // Store options for later (need question IDs first)
                if (qDto.options != null && !qDto.options.isEmpty()) {
                    String tempId = qDto.questionId != null ? qDto.questionId : 'temp_' + questions.size();
                    optionsByTempId.put(tempId, qDto.options);
                }
            }
            
            // Upsert questions
            upsert questions;
            
            // Now upsert options
            List<Quiz_Answer_Option__c> allOptions = new List<Quiz_Answer_Option__c>();
            for (Integer i = 0; i < questions.size(); i++) {
                Quiz_Question__c q = questions[i];
                String tempId = q.Id;
                
                // Check if we have options for this question
                if (optionsByTempId.containsKey(tempId) || 
                    optionsByTempId.containsKey('temp_' + (i + 1))) {
                    
                    List<AnswerOptionDTO> optDtos = optionsByTempId.containsKey(tempId) ? 
                        optionsByTempId.get(tempId) : optionsByTempId.get('temp_' + (i + 1));
                    
                    for (AnswerOptionDTO optDto : optDtos) {
                        Quiz_Answer_Option__c opt = new Quiz_Answer_Option__c();
                        if (String.isNotBlank(optDto.optionId)) {
                            try {
                                opt.Id = (Id) optDto.optionId;
                            } catch (Exception e) {
                                // Ignore invalid temp IDs
                            }
                        }
                        opt.Quiz_Question__c = q.Id;
                        opt.Answer_Text__c = optDto.answerText;
                        opt.Is_Correct__c = optDto.isCorrect;
                        opt.Is_Active__c = optDto.isActive != null ? optDto.isActive : true;
                        opt.Sort_Order__c = optDto.sortOrder;
                        
                        allOptions.add(opt);
                    }
                }
            }
            
            if (!allOptions.isEmpty()) {
                upsert allOptions;
            }
            
            // Return updated questions
            List<QuestionDTO> result = new List<QuestionDTO>();
            for (Quiz_Question__c q : questions) {
                result.add(mapQuestionToDTO(q));
            }
            
            return result;
            
        } catch (Exception e) {
            Logger.logError('QuizAdminController', 'saveQuestions', e, questionDTOs.size());
            throw new AuraHandledException('Unable to save questions: ' + e.getMessage());
        }
    }
    
    // ========================================================================
    // DELETE METHODS
    // ========================================================================
    
    /**
     * Delete a question and its options
     */
    @AuraEnabled
    public static void deleteQuestion(String questionId) {
        try {
            if (String.isBlank(questionId)) {
                throw new IllegalArgumentException('Question ID is required');
            }
            
            // Delete options first (will cascade via Master-Detail)
            delete new Quiz_Question__c(Id = (Id) questionId);
            
            Logger.logInfo('QuizAdminController', 'deleteQuestion', 
                'Deleted question: ' + questionId);
                
        } catch (Exception e) {
            Logger.logError('QuizAdminController', 'deleteQuestion', e, 0);
            AuraHandledException auraEx = new AuraHandledException('Unable to delete question: ' + e.getMessage());
            auraEx.setMessage('Unable to delete question: ' + e.getMessage());
            throw auraEx;
    }
        }
    
    /**
     * Delete an answer option
     */
    @AuraEnabled
    public static void deleteOption(String optionId) {
        try {
            if (String.isBlank(optionId)) {
                throw new IllegalArgumentException('Option ID is required');
            }
            
            delete new Quiz_Answer_Option__c(Id = (Id) optionId);
            
            Logger.logInfo('QuizAdminController', 'deleteOption', 
                'Deleted option: ' + optionId);
                
        } catch (Exception e) {
            Logger.logError('QuizAdminController', 'deleteOption', e, 0);
            AuraHandledException auraEx = new AuraHandledException('Unable to delete option: ' + e.getMessage());
            auraEx.setMessage('Unable to delete option: ' + e.getMessage());
            throw auraEx;
        }
    }
    
    /**
     * Archive a quiz (soft delete)
     */
    @AuraEnabled
    public static void archiveQuiz(String quizId, Boolean isArchived) {
        try {
            if (String.isBlank(quizId)) {
                throw new IllegalArgumentException('Quiz ID is required');
            }
            
            Id quizIdValue = (Id) quizId;
            
            // Check for active attempts
            Integer activeAttempts = [
                SELECT COUNT()
                FROM Quiz_Attempt__c
                WHERE Quiz__c = :quizIdValue
                AND Status__c = 'In Progress'
            ];
            
            if (activeAttempts > 0 && isArchived) {
                throw new IllegalArgumentException(
                    'Cannot archive quiz with ' + activeAttempts + ' active attempts. ' +
                    'Please wait for learners to complete their attempts.'
                );
            }
            
            Quiz__c quiz = new Quiz__c(
                Id = quizIdValue,
                Archived__c = isArchived,
                Active__c = !isArchived
            );
            update quiz;
            
            Logger.logInfo('QuizAdminController', 'archiveQuiz', 
                'Archived quiz: ' + quizId);
                
        } catch (Exception e) {
            Logger.logError('QuizAdminController', 'archiveQuiz', e, 0);
            AuraHandledException auraEx = new AuraHandledException('Unable to archive quiz: ' + e.getMessage());
            auraEx.setMessage('Unable to archive quiz: ' + e.getMessage());
            throw auraEx;
        }
    }
    
    // ========================================================================
    // FULL SAVE METHOD
    // ========================================================================
    
    /**
     * Save quiz with all questions and options in one transaction
     * @param quizJSON Serialized QuizDetailDTO with all questions and options
     * @return Id of the saved quiz
     */
    @AuraEnabled
    public static Id saveQuizFull(String quizJSON) {
        try {
            QuizDetailDTO dto = (QuizDetailDTO) JSON.deserialize(quizJSON, QuizDetailDTO.class);
            
            // Validate
            validateQuizDTO(dto);
            
            // Save quiz
            Quiz__c quiz = new Quiz__c();
            if (dto.quizId != null) {
                quiz.Id = dto.quizId;
            }
            quiz.Name = dto.name;
            quiz.Level__c = dto.level;
            quiz.Lesson__c = dto.lessonId;
            quiz.Course__c = dto.courseId;
            quiz.Passing_Score__c = dto.passingScore;
            quiz.Max_Score__c = dto.maxScore;
            quiz.Allow_Retakes__c = dto.allowRetakes != null ? dto.allowRetakes : false;
            quiz.Max_Attempts__c = dto.maxAttempts;
            quiz.Sort_Order__c = dto.sortOrder;
            quiz.Active__c = dto.isActive != null ? dto.isActive : false;
            quiz.Archived__c = dto.isArchived != null ? dto.isArchived : false;
            quiz.Instructions__c = dto.instructions;
            
            upsert quiz;
            
            // Save questions if provided
            if (dto.questions != null && !dto.questions.isEmpty()) {
                List<Quiz_Question__c> questions = new List<Quiz_Question__c>();
                List<Quiz_Answer_Option__c> allOptions = new List<Quiz_Answer_Option__c>();
                Map<Integer, List<AnswerOptionDTO>> optionsByIndex = new Map<Integer, List<AnswerOptionDTO>>();
                
                // Prepare questions
                for (Integer i = 0; i < dto.questions.size(); i++) {
                    QuestionDTO qDto = dto.questions[i];
                    Quiz_Question__c q = new Quiz_Question__c();
                    Boolean isExisting = false;
                    
                    // Only set Id if it exists and is a valid 15/18 char SF ID
                    if (qDto.questionId != null) {
                        String qIdStr = String.valueOf(qDto.questionId);
                        if (qIdStr.length() == 15 || qIdStr.length() == 18) {
                            try {
                                q.Id = (Id) qDto.questionId;
                                isExisting = true;
                            } catch (Exception e) {
                                // Invalid ID, skip setting it (not an existing question)
                            }
                        }
                    }
                    
                    // Only set Quiz__c for new questions (Master-Detail not writeable on update)
                    if (!isExisting) {
                        q.Quiz__c = quiz.Id;
                    }
                    q.Question_Text__c = qDto.questionText;
                    q.Question_Type__c = qDto.questionType != null ? qDto.questionType : 'MultipleChoice';
                    q.Points__c = qDto.points != null ? qDto.points : 1;
                    q.Required__c = qDto.required != null ? qDto.required : true;
                    q.Sort_Order__c = qDto.sortOrder;
                    
                    questions.add(q);
                    
                    // Store options by index
                    if (qDto.options != null && !qDto.options.isEmpty()) {
                        optionsByIndex.put(i, qDto.options);
                    }
                }
                
                // Upsert questions
                upsert questions;
                
                // Now prepare options with actual question IDs
                for (Integer i = 0; i < questions.size(); i++) {
                    Quiz_Question__c q = questions[i];
                    
                    if (optionsByIndex.containsKey(i)) {
                        for (AnswerOptionDTO optDto : optionsByIndex.get(i)) {
                            Quiz_Answer_Option__c opt = new Quiz_Answer_Option__c();
                            Boolean isExistingOption = false;
                            
                            // Only set Id if it exists and is a valid 15/18 char SF ID
                            if (optDto.optionId != null) {
                                String optIdStr = String.valueOf(optDto.optionId);
                                if (optIdStr.length() == 15 || optIdStr.length() == 18) {
                                    try {
                                        opt.Id = (Id) optDto.optionId;
                                        isExistingOption = true;
                                    } catch (Exception e) {
                                        // Invalid ID, skip setting it (not an existing option)
                                    }
                                }
                            }
                            
                            // Only set Quiz_Question__c for new options (Master-Detail not writeable on update)
                            if (!isExistingOption) {
                                opt.Quiz_Question__c = q.Id;
                            }
                            opt.Answer_Text__c = optDto.answerText;
                            opt.Is_Correct__c = optDto.isCorrect != null ? optDto.isCorrect : false;
                            opt.Is_Active__c = optDto.isActive != null ? optDto.isActive : true;
                            opt.Sort_Order__c = optDto.sortOrder;
                            
                            allOptions.add(opt);
                        }
                    }
                }
                
                // Upsert options
                if (!allOptions.isEmpty()) {
                    upsert allOptions;
                }
            }
            
            return String.valueOf(quiz.Id);
            
        } catch (Exception e) {
            Logger.logError('QuizAdminController', 'saveQuizFull', e, 0);
            AuraHandledException auraEx = new AuraHandledException('Unable to save quiz: ' + e.getMessage());
            auraEx.setMessage('Unable to save quiz: ' + e.getMessage());
            throw auraEx;
        }
    }
    
    // ========================================================================
    // LOOKUP METHODS
    // ========================================================================
    
    /**
     * Search for Courses or Lessons for lookup fields
     * @param searchTerm Search text
     * @param objectType 'Course' or 'Lesson'
     * @return List of matching records
     */
    @AuraEnabled(cacheable=true)
    public static List<LookupResultDTO> searchLookup(String searchTerm, String objectType) {
        try {
            List<LookupResultDTO> results = new List<LookupResultDTO>();
            String searchPattern = '%' + searchTerm + '%';
            
            if (objectType == 'Course') {
                List<Course__c> courses = [
                    SELECT Id, Name, Archived__c
                    FROM Course__c
                    WHERE Name LIKE :searchPattern
                    AND Archived__c = false
                    ORDER BY Name
                    LIMIT 20
                ];
                
                for (Course__c c : courses) {
                    LookupResultDTO dto = new LookupResultDTO();
                    dto.value = c.Id;
                    dto.label = c.Name;
                    dto.sublabel = 'Course';
                    results.add(dto);
                }
            } else if (objectType == 'Lesson') {
                List<Lesson__c> lessons = [
                    SELECT Id, Name, Module__r.Course__r.Name, Archived__c
                    FROM Lesson__c
                    WHERE Name LIKE :searchPattern
                    AND Archived__c = false
                    ORDER BY Name
                    LIMIT 20
                ];
                
                for (Lesson__c l : lessons) {
                    LookupResultDTO dto = new LookupResultDTO();
                    dto.value = l.Id;
                    dto.label = l.Name;
                    dto.sublabel = l.Module__r.Course__r.Name;
                    results.add(dto);
                }
            }
            
            return results;
            
        } catch (Exception e) {
            Logger.logError('QuizAdminController', 'searchLookup', e, 0);
            AuraHandledException auraEx = new AuraHandledException('Unable to search: ' + e.getMessage());
            auraEx.setMessage('Unable to search: ' + e.getMessage());
            throw auraEx;
        }
    }
    
    // ========================================================================
    // HELPER METHODS
    // ========================================================================
    
    /**
     * Map Quiz__c to QuizDetailDTO
     */
    private static QuizDetailDTO mapQuizToDTO(Quiz__c q, Boolean includeDetails) {
        QuizDetailDTO dto = new QuizDetailDTO();
        dto.quizId = q.Id;
        dto.name = q.Name;
        dto.level = q.Level__c;
        dto.lessonId = q.Lesson__c;
        dto.lessonName = q.Lesson__c != null ? q.Lesson__r.Name : null;
        dto.courseId = q.Course__c;
        dto.courseName = q.Course__c != null ? q.Course__r.Name : null;
        dto.passingScore = q.Passing_Score__c;
        dto.maxScore = q.Max_Score__c;
        dto.allowRetakes = q.Allow_Retakes__c;
        dto.maxAttempts = q.Max_Attempts__c != null ? Integer.valueOf(q.Max_Attempts__c) : null;
        dto.sortOrder = q.Sort_Order__c != null ? Integer.valueOf(q.Sort_Order__c) : null;
        dto.isActive = q.Active__c;
        dto.isArchived = q.Archived__c;
        dto.instructions = q.Instructions__c;
        
        return dto;
    }
    
    /**
     * Map Quiz_Question__c to QuestionDTO
     */
    private static QuestionDTO mapQuestionToDTO(Quiz_Question__c q) {
        QuestionDTO dto = new QuestionDTO();
        dto.questionId = q.Id;
        dto.quizId = q.Quiz__c;
        dto.questionText = q.Question_Text__c;
        dto.questionType = q.Question_Type__c;
        dto.points = q.Points__c;
        dto.required = q.Required__c;
        dto.sortOrder = q.Sort_Order__c != null ? Integer.valueOf(q.Sort_Order__c) : null;
        return dto;
    }
    
    /**
     * Map Quiz_Answer_Option__c to AnswerOptionDTO
     */
    private static AnswerOptionDTO mapOptionToDTO(Quiz_Answer_Option__c opt) {
        AnswerOptionDTO dto = new AnswerOptionDTO();
        dto.optionId = opt.Id;
        dto.questionId = opt.Quiz_Question__c;
        dto.answerText = opt.Answer_Text__c;
        dto.isCorrect = opt.Is_Correct__c;
        dto.isActive = opt.Is_Active__c;
        dto.sortOrder = opt.Sort_Order__c != null ? Integer.valueOf(opt.Sort_Order__c) : null;
        return dto;
    }
    
    /**
     * Validate Quiz DTO before save
     */
    private static void validateQuizDTO(QuizDetailDTO dto) {
        if (String.isBlank(dto.name)) {
            throw new IllegalArgumentException('Quiz name is required');
        }
        
        if (String.isBlank(dto.level)) {
            throw new IllegalArgumentException('Quiz level is required');
        }
        
        if (dto.level == 'Lesson' && String.isBlank(dto.lessonId)) {
            throw new IllegalArgumentException('Lesson is required for lesson-level quizzes');
        }
        
        if (dto.level == 'Course' && String.isBlank(dto.courseId)) {
            throw new IllegalArgumentException('Course is required for course-level quizzes');
        }
        
        // Validate questions if provided
        if (dto.questions != null && !dto.questions.isEmpty()) {
            for (QuestionDTO q : dto.questions) {
                if (String.isBlank(q.questionText)) {
                    throw new IllegalArgumentException('Question text is required');
                }
                
                // Validate at least one correct answer for MultipleChoice
                if (q.questionType == 'MultipleChoice' && q.options != null && !q.options.isEmpty()) {
                    Boolean hasCorrect = false;
                    for (AnswerOptionDTO opt : q.options) {
                        if (opt.isCorrect == true) {
                            hasCorrect = true;
                            break;
                        }
                    }
                    if (!hasCorrect) {
                        throw new IllegalArgumentException(
                            'Question "' + q.questionText + '" must have at least one correct answer'
                        );
                    }
                }
            }
        }
        
        // Validate active quiz has questions
        if (dto.isActive == true && (dto.questions == null || dto.questions.isEmpty())) {
            if (String.isNotBlank(dto.quizId)) {
                // Check existing questions
                Integer questionCount = [
                    SELECT COUNT()
                    FROM Quiz_Question__c
                    WHERE Quiz__c = :(Id)dto.quizId
                ];
                if (questionCount == 0) {
                    throw new IllegalArgumentException('Cannot activate quiz without questions');
                }
            } else {
                throw new IllegalArgumentException('Cannot activate quiz without questions');
            }
        }
    }
}