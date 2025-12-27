// Test QuizAdminController.saveQuiz
Lesson__c lesson = [SELECT Id FROM Lesson__c LIMIT 1];

QuizAdminController.QuizDetailDTO dto = new QuizAdminController.QuizDetailDTO();
dto.name = 'Debug Test Quiz';
dto.level = 'Lesson';
dto.lessonId = String.valueOf(lesson.Id);
dto.isActive = true;
dto.passingScore = 70;
dto.questions = new List<QuizAdminController.QuestionDTO>();

try {
    String quizId = QuizAdminController.saveQuiz(JSON.serialize(dto));
    System.debug('SUCCESS: Created quiz with ID: ' + quizId);
} catch (Exception e) {
    System.debug('ERROR: ' + e.getTypeName() + ': ' + e.getMessage());
    System.debug('Stack: ' + e.getStackTraceString());
}
