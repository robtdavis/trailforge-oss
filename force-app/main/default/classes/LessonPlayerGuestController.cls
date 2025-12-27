/**
 * Guest-accessible controller for Lesson Player functionality.
 * Runs WITHOUT SHARING to allow guest users to access Course, Lesson, and Progress data.
 * 
 * This is a thin wrapper that delegates to the main LessonPlayerController logic
 * but runs without sharing for Experience Cloud guest users.
 */
public without sharing class LessonPlayerGuestController {
    
    // ========================================================================
    // LESSON CONTEXT LOADING
    // ========================================================================
    
    @AuraEnabled(cacheable=false)
    public static LessonPlayerController.LessonContextDTO getLessonContext(Id courseId, Id contactId) {
        try {
            if (courseId == null || contactId == null) {
                throw new AuraHandledException('Course and Contact are required');
            }
            
            // Step 1: Find or create enrollment
            Enrollment__c enrollment = findOrCreateEnrollment(courseId, contactId);
            
            // Step 2: Load modules for course
            List<Module__c> modules = [
                SELECT Id, Name
                FROM Module__c
                WHERE Course__c = :courseId
                  AND Archived__c = false
                ORDER BY Name
            ];
            
            if (modules.isEmpty()) {
                return buildEmptyContext(enrollment);
            }
            
            // Step 3: Load lessons for all modules
            Set<Id> moduleIds = new Map<Id, Module__c>(modules).keySet();
            List<Lesson__c> lessons = [
                SELECT Id, Name, Module__c, Content_Body__c, Quiz__c, Show_Complete_Button__c
                FROM Lesson__c
                WHERE Module__c IN :moduleIds
                  AND Archived__c = false
                ORDER BY Name
            ];
            
            // Step 4: Load progress records
            Set<Id> lessonIds = new Map<Id, Lesson__c>(lessons).keySet();
            List<Progress__c> progressRecords = [
                SELECT Id, Lesson__c, Status__c
                FROM Progress__c
                WHERE Enrollment__c = :enrollment.Id
                  AND Lesson__c IN :lessonIds
            ];
            
            // Step 5: Build progress map
            Map<Id, Progress__c> progressByLesson = new Map<Id, Progress__c>();
            for (Progress__c progress : progressRecords) {
                progressByLesson.put(progress.Lesson__c, progress);
            }
            
            // Step 6: Group lessons by module
            Map<Id, List<Lesson__c>> lessonsByModule = new Map<Id, List<Lesson__c>>();
            for (Lesson__c lesson : lessons) {
                if (!lessonsByModule.containsKey(lesson.Module__c)) {
                    lessonsByModule.put(lesson.Module__c, new List<Lesson__c>());
                }
                lessonsByModule.get(lesson.Module__c).add(lesson);
            }
            
            // Step 7: Build DTO structure
            return buildContextDTO(enrollment, modules, lessonsByModule, progressByLesson);
            
        } catch (Exception e) {
            System.debug('Error in getLessonContext: ' + e.getMessage() + ' - ' + e.getStackTraceString());
            throw new AuraHandledException('Error loading lesson context: ' + e.getMessage());
        }
    }
    
    // ========================================================================
    // PROGRESS TRACKING
    // ========================================================================
    
    @AuraEnabled
    public static LessonPlayerController.LessonContextDTO markLessonComplete(Id enrollmentId, Id lessonId) {
        try {
            if (enrollmentId == null || lessonId == null) {
                throw new AuraHandledException('Enrollment and Lesson are required');
            }
            
            // Get enrollment details
            Enrollment__c enrollment = [
                SELECT Id, Contact__c, Course__c
                FROM Enrollment__c
                WHERE Id = :enrollmentId
                LIMIT 1
            ];
            
            // Find or create progress record
            List<Progress__c> existingProgress = [
                SELECT Id, Status__c
                FROM Progress__c
                WHERE Enrollment__c = :enrollmentId
                  AND Lesson__c = :lessonId
                LIMIT 1
            ];
            
            Progress__c progress;
            if (existingProgress.isEmpty()) {
                progress = new Progress__c(
                    Enrollment__c = enrollmentId,
                    Lesson__c = lessonId,
                    Status__c = 'Completed'
                );
                insert progress;
            } else {
                progress = existingProgress[0];
                progress.Status__c = 'Completed';
                update progress;
            }
            
            // Recalculate enrollment progress
            EnrollmentService.recalculateEnrollmentProgress(enrollmentId);
            
            // Return updated context
            return getLessonContext(enrollment.Course__c, enrollment.Contact__c);
            
        } catch (Exception e) {
            System.debug('Error in markLessonComplete: ' + e.getMessage() + ' - ' + e.getStackTraceString());
            throw new AuraHandledException('Error marking lesson complete: ' + e.getMessage());
        }
    }
    
    // ========================================================================
    // QUIZ COMPLETION
    // ========================================================================

    @AuraEnabled
    public static EnrollmentService.EnrollmentResultDTO completeQuiz(Id enrollmentId, Decimal score) {
        return EnrollmentService.recordQuizResult(enrollmentId, score);
    }
    
    // ========================================================================
    // PRIVATE HELPERS
    // ========================================================================
    
    private static Enrollment__c findOrCreateEnrollment(Id courseId, Id contactId) {
        List<Enrollment__c> enrollments = [
            SELECT Id, Contact__c, Course__c, Course__r.Name, Status__c, Progress_Percentage__c
            FROM Enrollment__c
            WHERE Course__c = :courseId
              AND Contact__c = :contactId
            LIMIT 1
        ];
        
        if (!enrollments.isEmpty()) {
            return enrollments[0];
        }
        
        Enrollment__c enrollment = new Enrollment__c(
            Contact__c = contactId,
            Course__c = courseId,
            Status__c = 'Not Started',
            Progress_Percentage__c = 0
        );
        insert enrollment;
        
        // Re-query to get Course__r.Name
        return [
            SELECT Id, Contact__c, Course__c, Course__r.Name, Status__c, Progress_Percentage__c
            FROM Enrollment__c
            WHERE Id = :enrollment.Id
            LIMIT 1
        ];
    }
    
    private static LessonPlayerController.LessonContextDTO buildEmptyContext(Enrollment__c enrollment) {
        LessonPlayerController.LessonContextDTO context = new LessonPlayerController.LessonContextDTO();
        context.enrollmentId = enrollment.Id;
        context.courseId = enrollment.Course__c;
        context.courseName = enrollment.Course__r.Name;
        context.modules = new List<LessonPlayerController.ModuleDTO>();
        return context;
    }
    
    private static LessonPlayerController.LessonContextDTO buildContextDTO(
        Enrollment__c enrollment,
        List<Module__c> modules,
        Map<Id, List<Lesson__c>> lessonsByModule,
        Map<Id, Progress__c> progressByLesson
    ) {
        LessonPlayerController.LessonContextDTO context = new LessonPlayerController.LessonContextDTO();
        context.enrollmentId = enrollment.Id;
        context.courseId = enrollment.Course__c;
        context.courseName = enrollment.Course__r.Name;
        context.modules = new List<LessonPlayerController.ModuleDTO>();
        
        // Load course-level quiz using guest-safe DAO
        Quiz__c courseQuiz = QuizGuestDAO.getActiveCourseQuiz(enrollment.Course__c);
        if (courseQuiz != null) {
            context.courseQuizId = courseQuiz.Id;
        }
        
        // Load module-level quizzes in bulk using guest-safe DAO
        Set<Id> moduleIds = new Map<Id, Module__c>(modules).keySet();
        Map<Id, Quiz__c> moduleQuizzes = QuizGuestDAO.getActiveModuleQuizzes(moduleIds);
        
        // Collect all lesson IDs and build a map for lesson-level quizzes
        Set<Id> allLessonIds = new Set<Id>();
        for (List<Lesson__c> lessonList : lessonsByModule.values()) {
            for (Lesson__c lesson : lessonList) {
                allLessonIds.add(lesson.Id);
            }
        }
        
        // Load lesson-level quizzes in bulk using guest-safe DAO
        Map<Id, Id> lessonToQuizMap = QuizGuestDAO.getActiveLessonQuizzes(allLessonIds);
        
        for (Module__c module : modules) {
            LessonPlayerController.ModuleDTO moduleDTO = new LessonPlayerController.ModuleDTO();
            moduleDTO.moduleId = module.Id;
            moduleDTO.moduleName = module.Name;
            moduleDTO.lessons = new List<LessonPlayerController.LessonDTO>();
            
            // Set module-level quiz ID if exists
            Quiz__c moduleQuiz = moduleQuizzes.get(module.Id);
            if (moduleQuiz != null) {
                moduleDTO.moduleQuizId = moduleQuiz.Id;
            }
            
            List<Lesson__c> moduleLessons = lessonsByModule.get(module.Id);
            if (moduleLessons != null) {
                for (Lesson__c lesson : moduleLessons) {
                    LessonPlayerController.LessonDTO lessonDTO = new LessonPlayerController.LessonDTO();
                    lessonDTO.lessonId = lesson.Id;
                    lessonDTO.lessonName = lesson.Name;
                    lessonDTO.content = lesson.Content_Body__c;
                    
                    // Only use quizzes with Level='Lesson' from the reverse lookup
                    // This respects the Level__c field on Quiz__c
                    if (lessonToQuizMap.containsKey(lesson.Id)) {
                        lessonDTO.quizId = lessonToQuizMap.get(lesson.Id);
                    }
                    
                    lessonDTO.showCompleteButton = lesson.Show_Complete_Button__c != false;
                    
                    Progress__c progress = progressByLesson.get(lesson.Id);
                    lessonDTO.status = progress != null ? progress.Status__c : 'Not Started';
                    
                    moduleDTO.lessons.add(lessonDTO);
                }
            }
            
            context.modules.add(moduleDTO);
        }
        
        return context;
    }
}
