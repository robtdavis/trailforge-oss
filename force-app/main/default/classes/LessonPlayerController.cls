/**
 * Controller for Lesson Player LWC
 * Thin orchestration layer - all SOQL delegated to EnrollmentDAO
 */
public with sharing class LessonPlayerController {
    
    // ========================================================================
    // LEARNER SELECTION
    // ========================================================================
    
    @AuraEnabled(cacheable=true)
    public static List<SelectOptionDTO> getLearnerOptions(String searchTerm) {
        try {
            List<Contact> contacts = EnrollmentDAO.searchContacts(searchTerm, 25);
            
            List<SelectOptionDTO> options = new List<SelectOptionDTO>();
            for (Contact contact : contacts) {
                SelectOptionDTO option = new SelectOptionDTO();
                option.value = contact.Id;
                option.label = contact.Name + (contact.Email != null ? ' (' + contact.Email + ')' : '');
                option.description = contact.Email;
                options.add(option);
            }
            
            return options;
            
        } catch (Exception e) {
            throw new AuraHandledException('Error searching for learners: ' + e.getMessage());
        }
    }
    
    // ========================================================================
    // LESSON CONTEXT LOADING
    // ========================================================================
    
    @AuraEnabled(cacheable=false)
    public static LessonContextDTO getLessonContext(Id courseId, Id contactId) {
        try {
            if (courseId == null || contactId == null) {
                throw new AuraHandledException('Course and Contact are required');
            }
            
            // Step 1: Find or create enrollment
            Enrollment__c enrollment = findOrCreateEnrollment(courseId, contactId);
            
            // Step 2: Load modules for course
            List<Module__c> modules = EnrollmentDAO.getModulesForCourse(courseId);
            
            if (modules.isEmpty()) {
                return buildEmptyContext(enrollment);
            }
            
            // Step 3: Load lessons for all modules
            Set<Id> moduleIds = new Map<Id, Module__c>(modules).keySet();
            List<Lesson__c> lessons = EnrollmentDAO.getLessonsForModules(moduleIds);
            
            // Step 4: Load progress records
            Set<Id> lessonIds = new Map<Id, Lesson__c>(lessons).keySet();
            List<Progress__c> progressRecords = EnrollmentDAO.getProgressForEnrollmentAndLessons(
                enrollment.Id,
                lessonIds
            );
            
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
            throw new AuraHandledException('Error loading lesson context: ' + e.getMessage());
        }
    }
    
    // ========================================================================
    // QUIZ COMPLETION
    // ========================================================================

    /**
     * Record a quiz result for an enrollment
     * Delegates to EnrollmentService.recordQuizResult
     */
    @AuraEnabled
    public static EnrollmentService.EnrollmentResultDTO completeQuiz(Id enrollmentId, Decimal score) {
        return EnrollmentService.recordQuizResult(enrollmentId, score);
    }

    // ========================================================================
    // PROGRESS TRACKING
    // ========================================================================
    
    // Mark lesson complete - EnrollmentService will enforce quiz gating rules
    @AuraEnabled
    public static LessonContextDTO markLessonComplete(Id enrollmentId, Id lessonId) {
        try {
            if (enrollmentId == null || lessonId == null) {
                throw new AuraHandledException('Enrollment and Lesson are required');
            }
            
            // Get enrollment details
            Enrollment__c enrollment = EnrollmentDAO.getEnrollmentWithContactAndCourse(enrollmentId);
            
            // Find or create progress record using findProgress + upsert pattern
            // This approach prevents duplicate Progress records when Unique_Key__c constraint is deployed
            Progress__c progress = EnrollmentDAO.findProgress(
                enrollmentId,
                lessonId
            );
            
            if (progress == null) {
                // Create new progress record
                progress = new Progress__c(
                    Contact__c = enrollment.Contact__c,
                    Lesson__c = lessonId,
                    Enrollment__c = enrollmentId,
                    Status__c = 'Completed',
                    Started_On__c = System.now(),
                    Completed_On__c = System.now()
                );
            } else if (progress.Status__c != 'Completed') {
                // Update existing progress to completed
                progress.Status__c = 'Completed';
                progress.Completed_On__c = System.now();
                
                if (progress.Started_On__c == null) {
                    progress.Started_On__c = System.now();
                }
            }
            
            // Upsert handles both insert and update cases
            upsert progress;
            
            // Recalculate enrollment progress
            EnrollmentService.recalculateEnrollmentProgress(enrollmentId);
            
            // Return updated context
            return getLessonContext(enrollment.Course__c, enrollment.Contact__c);
            
        } catch (Exception e) {
            throw new AuraHandledException('Error marking lesson complete: ' + e.getMessage());
        }
    }
    
    // ========================================================================
    // PRIVATE HELPERS
    // ========================================================================
    
    private static Enrollment__c findOrCreateEnrollment(Id courseId, Id contactId) {
        Enrollment__c enrollment = EnrollmentDAO.findEnrollment(courseId, contactId);
        
        if (enrollment == null) {
            enrollment = new Enrollment__c(
                Contact__c = contactId,
                Course__c = courseId,
                Status__c = 'Not Started',
                Progress_Percentage__c = 0
            );
            
            insert enrollment;
            
            // Re-query to get Course__r.Name
            enrollment = EnrollmentDAO.getEnrollmentById(enrollment.Id);
        }
        
        return enrollment;
    }
    
    private static LessonContextDTO buildEmptyContext(Enrollment__c enrollment) {
        LessonContextDTO context = new LessonContextDTO();
        context.enrollmentId = enrollment.Id;
        context.courseId = enrollment.Course__c;
        context.courseName = enrollment.Course__r.Name;
        context.modules = new List<ModuleDTO>();
        return context;
    }
    
    private static LessonContextDTO buildContextDTO(
        Enrollment__c enrollment,
        List<Module__c> modules,
        Map<Id, List<Lesson__c>> lessonsByModule,
        Map<Id, Progress__c> progressByLesson
    ) {
        LessonContextDTO context = new LessonContextDTO();
        context.enrollmentId = enrollment.Id;
        context.courseId = enrollment.Course__c;
        context.courseName = enrollment.Course__r.Name;
        context.modules = new List<ModuleDTO>();
        
        // Load course-level quiz
        Quiz__c courseQuiz = QuizDAO.getActiveCourseQuiz(enrollment.Course__c);
        if (courseQuiz != null) {
            context.courseQuizId = courseQuiz.Id;
        }
        
        // Load module-level quizzes in bulk
        Set<Id> moduleIds = new Map<Id, Module__c>(modules).keySet();
        Map<Id, Quiz__c> moduleQuizzes = QuizDAO.getActiveModuleQuizzes(moduleIds);
        
        // Collect all lesson IDs and build a map for lesson-level quizzes
        Set<Id> allLessonIds = new Set<Id>();
        for (List<Lesson__c> lessonList : lessonsByModule.values()) {
            for (Lesson__c lesson : lessonList) {
                allLessonIds.add(lesson.Id);
            }
        }
        
        // Load lesson-level quizzes in bulk (quizzes where Quiz__c.Lesson__c points to these lessons)
        Map<Id, Id> lessonToQuizMap = QuizDAO.getActiveLessonQuizzes(allLessonIds);
        
        for (Module__c module : modules) {
            ModuleDTO moduleDTO = new ModuleDTO();
            moduleDTO.moduleId = module.Id;
            moduleDTO.moduleName = module.Name;
            moduleDTO.lessons = new List<LessonDTO>();
            
            // Set module-level quiz ID if exists
            Quiz__c moduleQuiz = moduleQuizzes.get(module.Id);
            if (moduleQuiz != null) {
                moduleDTO.moduleQuizId = moduleQuiz.Id;
            }
            
            List<Lesson__c> moduleLessons = lessonsByModule.get(module.Id);
            if (moduleLessons != null) {
                for (Lesson__c lesson : moduleLessons) {
                    LessonDTO lessonDTO = new LessonDTO();
                    lessonDTO.lessonId = lesson.Id;
                    lessonDTO.lessonName = lesson.Name;
                    lessonDTO.content = lesson.Content_Body__c;
                    
                    // Only use quizzes with Level='Lesson' from the reverse lookup
                    // This respects the Level__c field on Quiz__c
                    if (lessonToQuizMap.containsKey(lesson.Id)) {
                        lessonDTO.quizId = lessonToQuizMap.get(lesson.Id);
                    }
                    
                    lessonDTO.showCompleteButton = lesson.Show_Complete_Button__c != false; // Default to true if null
                    
                    Progress__c progress = progressByLesson.get(lesson.Id);
                    lessonDTO.status = progress != null ? progress.Status__c : 'Not Started';
                    
                    moduleDTO.lessons.add(lessonDTO);
                }
            }
            
            context.modules.add(moduleDTO);
        }
        
        return context;
    }
    
    // ========================================================================
    // DTO CLASSES
    // ========================================================================
    
    public class SelectOptionDTO {
        @AuraEnabled public Id value;
        @AuraEnabled public String label;
        @AuraEnabled public String description;
    }
    
    public class LessonContextDTO {
        @AuraEnabled public Id enrollmentId;
        @AuraEnabled public Id courseId;
        @AuraEnabled public String courseName;
        @AuraEnabled public Id courseQuizId;  // Course-level quiz ID
        @AuraEnabled public List<ModuleDTO> modules;
    }
    
    public class ModuleDTO {
        @AuraEnabled public Id moduleId;
        @AuraEnabled public String moduleName;
        @AuraEnabled public Id moduleQuizId;  // Module-level quiz ID
        @AuraEnabled public List<LessonDTO> lessons;
    }
    
    public class LessonDTO {
        @AuraEnabled public Id lessonId;
        @AuraEnabled public String lessonName;
        @AuraEnabled public String status;
        @AuraEnabled public String content;
        @AuraEnabled public Id quizId;  // Quiz__c lookup from Lesson__c
        @AuraEnabled public Boolean showCompleteButton;
    }
}