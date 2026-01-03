//
// SPDX-License-Identifier: MIT
// TrailForge — Open Source under the MIT License
// Copyright (c) 2025 Robert Davis
// See the LICENSE file in the project root for full license text.
//
public with sharing class EnrollmentService {

    // ========================================================================
    // QUIZ RESULT RECORDING
    // ========================================================================

    /**
     * Apply quiz result to enrollment (called from QuizService)
     * Updates Quiz_Passed__c and Quiz_Score__c fields
     * Triggers completion gating logic if quiz passed and progress >= 90%
     * 
     * @param enrollmentId The enrollment to update
     * @param quizId The quiz that was completed (for logging)
     * @param scorePercent The percentage score (0-100)
     * @param passed Whether the quiz was passed
     */
    public static void applyQuizResultToEnrollment(
        Id enrollmentId, 
        Id quizId, 
        Decimal scorePercent, 
        Boolean passed
    ) {
        if (enrollmentId == null) {
            Logger.logInfo('EnrollmentService', 'applyQuizResultToEnrollment',
                'Enrollment ID is null - skipping quiz result application');
            return;
        }
        
        try {
            // Query enrollment with current progress
            List<Enrollment__c> enrollments = [
                SELECT Id, Contact__c, Course__c, Status__c, 
                       Progress_Percentage__c, Quiz_Passed__c, Quiz_Score__c, Completion_Date__c
                FROM Enrollment__c
                WHERE Id = :enrollmentId
                LIMIT 1
            ];
            
            if (enrollments.isEmpty()) {
                Logger.logInfo('EnrollmentService', 'applyQuizResultToEnrollment',
                    'Enrollment not found: ' + enrollmentId);
                return;
            }
            
            Enrollment__c enrollment = enrollments[0];
            
            // Update quiz fields
            enrollment.Quiz_Passed__c = passed;
            enrollment.Quiz_Score__c = scorePercent;
            
            // Apply completion gating logic (quiz passed + progress >= 90% = complete)
            applyQuizCompletionRule(enrollment);
            
            update enrollment;
            
            Logger.logInfo('EnrollmentService', 'applyQuizResultToEnrollment',
                'Quiz result applied to enrollment ' + enrollmentId + 
                ': Score=' + scorePercent + '%, Passed=' + passed + 
                ', New Status=' + enrollment.Status__c);
                
        } catch (Exception e) {
            Logger.logError('EnrollmentService', 'applyQuizResultToEnrollment', e, 1);
            // Don't rethrow - quiz grading already succeeded, enrollment update is secondary
        }
    }

    /**
     * Record a quiz result for an enrollment
     * Creates a Quiz_Attempt__c record and updates enrollment quiz fields
     * May promote enrollment to Completed if quiz passed and content complete
     */
    @AuraEnabled
    public static EnrollmentResultDTO recordQuizResult(Id enrollmentId, Decimal score) {
        // Validate input
        if (enrollmentId == null) {
            throw new AuraHandledException('Enrollment ID is required');
        }
        if (score == null || score < 0 || score > 100) {
            throw new AuraHandledException('Score must be between 0 and 100');
        }

        // Query Enrollment + Course
        List<Enrollment__c> enrollments = [
            SELECT Id, 
                   Contact__c, 
                   Course__c, 
                   Course__r.Passing_Score__c,
                   Progress_Percentage__c, 
                   Status__c, 
                   Quiz_Score__c, 
                   Quiz_Passed__c,
                   Completion_Date__c
            FROM Enrollment__c
            WHERE Id = :enrollmentId
            LIMIT 1
        ];

        if (enrollments.isEmpty()) {
            throw new AuraHandledException('Enrollment not found');
        }

        Enrollment__c enrollment = enrollments[0];

        // Determine passing score (default to 70 if not set on Course)
        Decimal passingScore = enrollment.Course__r.Passing_Score__c != null 
            ? enrollment.Course__r.Passing_Score__c 
            : 70.0;

        Boolean passed = score >= passingScore;

        // Create Quiz_Attempt__c record
        Quiz_Attempt__c attempt = new Quiz_Attempt__c(
            Contact__c = enrollment.Contact__c,
            Enrollment__c = enrollment.Id,
            Course__c = enrollment.Course__c,
            Score__c = score,
            Passed__c = passed,
            Completed_Date__c = System.now()
        );
        insert attempt;

        // Update Enrollment quiz fields
        enrollment.Quiz_Score__c = score;
        enrollment.Quiz_Passed__c = passed;

        // Apply gating rule for completion
        applyQuizCompletionRule(enrollment);

        update enrollment;

        // Return DTO
        return buildEnrollmentResultDTO(enrollment);
    }

    /**
     * Apply quiz gating rule: enrollment can only be fully complete
     * if quiz is passed AND content progress is sufficient
     * Uses shared completion rule helper for consistency with recalculation
     */
    private static void applyQuizCompletionRule(Enrollment__c enrollment) {
        // Delegate to shared helper for consistent completion logic
        if (shouldMarkAsComplete(enrollment, enrollment.Progress_Percentage__c)) {
            enrollment.Progress_Percentage__c = 100;
            enrollment.Status__c = 'Completed';
            
            // Set completion date if not already set
            if (enrollment.Completion_Date__c == null) {
                enrollment.Completion_Date__c = Date.today();
            }
        }
        // If quiz passed but content not sufficient, leave progress as-is
        // If quiz failed, leave Status__c and Progress_Percentage__c unchanged
    }

    /**
     * Shared quiz completion rule (Option B - Fudge Model):
     * Learner is considered complete if:
     *   - Quiz passed (Quiz_Passed__c == true), AND
     *   - Content progress >= 90%
     * 
     * This prevents "un-completing" enrollments when recalculation runs
     * after quiz submission has already promoted them to Completed.
     * 
     * @param enr Enrollment with Quiz_Passed__c field loaded
     * @param contentPercent Current calculated content progress (0-100)
     * @return true if enrollment should be marked as 100% Completed
     */
    @TestVisible
    private static Boolean shouldMarkAsComplete(Enrollment__c enr, Decimal contentPercent) {
        if (enr == null || enr.Quiz_Passed__c != true) {
            return false;
        }
        
        // Fudge factor: 90% content + quiz passed = fully complete
        return contentPercent != null && contentPercent >= 90;
    }

    /**
     * Build DTO for enrollment result
     */
    private static EnrollmentResultDTO buildEnrollmentResultDTO(Enrollment__c enrollment) {
        EnrollmentResultDTO dto = new EnrollmentResultDTO();
        dto.enrollmentId = enrollment.Id;
        dto.status = enrollment.Status__c;
        dto.progressPercentage = enrollment.Progress_Percentage__c != null 
            ? enrollment.Progress_Percentage__c 
            : 0;
        dto.quizScore = enrollment.Quiz_Score__c;
        dto.quizPassed = enrollment.Quiz_Passed__c != null 
            ? enrollment.Quiz_Passed__c 
            : false;
        return dto;
    }

    // ========================================================================
    // PROGRESS RECALCULATION
    // ========================================================================

    /**
     * Transaction-level recursion guard to prevent infinite recalculation loops.
     * Cleared in finally block to ensure fresh state for subsequent transactions.
     * 
     * Use case: Progress__c trigger → recalc → Enrollment update → 
     *           (potential) Enrollment trigger → recalc (prevented)
     */
    @TestVisible
    private static Set<Id> processingEnrollmentIds = new Set<Id>();

    /**
     * Recalculate progress for a single enrollment
     * Delegates to bulk method for consistency and recursion safety
     */
    public static void recalculateEnrollmentProgress(Id enrollmentId) {
        if (enrollmentId == null) {
            return;
        }
        
        // Delegate to bulk method for consistent recursion guard behavior
        Set<Id> ids = new Set<Id>{ enrollmentId };
        recalculateEnrollmentProgressBulk(ids);
    }

    /**
     * Recalculate progress for multiple enrollments in a single transaction
     * Governor-safe: Uses 3 SOQL queries and 1 DML statement regardless of enrollment count
     * 
     * @param enrollmentIds Set of Enrollment IDs to recalculate
     */
    public static void recalculateEnrollmentProgressBulk(Set<Id> enrollmentIds) {
        if (enrollmentIds == null || enrollmentIds.isEmpty()) {
            return;
        }

        // Remove already-processing enrollments to prevent recursion
        Set<Id> idsToProcess = new Set<Id>(enrollmentIds);
        idsToProcess.removeAll(processingEnrollmentIds);

        if (idsToProcess.isEmpty()) {
            return;
        }

        // Mark as processing
        processingEnrollmentIds.addAll(idsToProcess);

        try {
            // Query 1: Load all enrollments (with quiz fields)
            List<Enrollment__c> enrollmentList = 
                EnrollmentDAO.getEnrollmentsByIds(idsToProcess);

            if (enrollmentList.isEmpty()) {
                return;
            }

            Map<Id, Enrollment__c> enrollmentsById = 
                new Map<Id, Enrollment__c>(enrollmentList);

            // Extract course IDs
            Set<Id> courseIds = new Set<Id>();
            for (Enrollment__c enr : enrollmentsById.values()) {
                if (enr.Course__c != null) {
                    courseIds.add(enr.Course__c);
                }
            }

            // Query 2: Load all lessons grouped by course
            Map<Id, List<Lesson__c>> lessonsByCourse = 
                EnrollmentDAO.getLessonsByCourseIds(courseIds);

            // Query 3: Load all progress records grouped by enrollment
            Map<Id, List<Progress__c>> progressByEnrollment = 
                EnrollmentDAO.getProgressByEnrollmentIds(idsToProcess);

            // Calculate progress for each enrollment
            List<Enrollment__c> toUpdate = new List<Enrollment__c>();

            for (Id enrollmentId : idsToProcess) {
                Enrollment__c enr = enrollmentsById.get(enrollmentId);
                if (enr == null) {
                    continue;
                }

                List<Lesson__c> lessons = 
                    lessonsByCourse.containsKey(enr.Course__c)
                    ? lessonsByCourse.get(enr.Course__c)
                    : new List<Lesson__c>();

                List<Progress__c> progressList = 
                    progressByEnrollment.containsKey(enrollmentId)
                    ? progressByEnrollment.get(enrollmentId)
                    : new List<Progress__c>();

                Decimal newPercent = calculateProgressPercent(lessons, progressList);
                
                // Apply completion rule: if quiz passed + content >= 90%, promote to 100%
                if (shouldMarkAsComplete(enr, newPercent) && newPercent < 100) {
                    newPercent = 100;
                }
                
                String newStatus = deriveStatus(enr, newPercent);

                Boolean changed = false;

                if (enr.Progress_Percentage__c != newPercent) {
                    enr.Progress_Percentage__c = newPercent;
                    changed = true;
                }
                if (enr.Status__c != newStatus) {
                    enr.Status__c = newStatus;
                    changed = true;
                    
                    // Set Completion_Date__c when status changes to Completed
                    if (newStatus == 'Completed' && enr.Completion_Date__c == null) {
                        enr.Completion_Date__c = Date.today();
                    }
                }

                if (changed) {
                    toUpdate.add(enr);
                }
            }

            // DML: Update all changed enrollments in one statement
            if (!toUpdate.isEmpty()) {
                try {
                    update toUpdate;
                } catch (DmlException e) {
                    // Log error with structured context
                    Logger.logError(
                        'EnrollmentService',
                        'recalculateEnrollmentProgressBulk',
                        e,
                        toUpdate.size()
                    );
                    // Don't rethrow - silent failure is acceptable for progress recalc
                }
            }

        } finally {
            // Always clear processing set to prevent memory leaks
            processingEnrollmentIds.removeAll(idsToProcess);
        }
    }

    /**
     * Calculate progress percentage based on completed lessons
     * 
     * @param lessons All lessons for the course
     * @param progressList Progress records for this enrollment
     * @return Percentage (0-100) with 2 decimal precision
     */
    @TestVisible
    private static Decimal calculateProgressPercent(
        List<Lesson__c> lessons,
        List<Progress__c> progressList
    ) {
        if (lessons == null || lessons.isEmpty()) {
            return 0;
        }

        Set<Id> completedLessonIds = new Set<Id>();
        for (Progress__c p : progressList) {
            if (p.Status__c == 'Completed' && p.Lesson__c != null) {
                completedLessonIds.add(p.Lesson__c);
            }
        }

        Integer total = lessons.size();
        Integer completed = 0;
        for (Lesson__c lesson : lessons) {
            if (completedLessonIds.contains(lesson.Id)) {
                completed++;
            }
        }

        if (total == 0) {
            return 0;
        }

        Decimal percent = 
            (Decimal.valueOf(completed) / Decimal.valueOf(total)) * 100;
        return percent.setScale(2);
    }

    /**
     * Derive enrollment status based on progress percentage and quiz results
     * Uses shared completion rule to prevent "un-completing" enrollments
     * 
     * Option B (Fudge Model): If quiz passed + content >= 90%, treat as complete
     * This ensures consistency with applyQuizCompletionRule
     * 
     * @param enr Enrollment record (must include Quiz_Passed__c, Progress_Percentage__c)
     * @param newPercent Newly calculated progress percentage
     * @return Status picklist value: 'Not Started', 'In Progress', or 'Completed'
     */
    @TestVisible
    private static String deriveStatus(Enrollment__c enr, Decimal newPercent) {
        if (newPercent == null || newPercent == 0) {
            return 'Not Started';
        }

        // Mark as Completed if:
        // 1. Progress is 100% (all content complete), OR
        // 2. Quiz passed + content >= 90% (fudge model), OR
        // 3. Already completed with quiz passed + >= 90% (prevent downgrade)
        if (newPercent >= 100 ||
            shouldMarkAsComplete(enr, newPercent) || 
            (enr.Status__c == 'Completed' && enr.Quiz_Passed__c == true && newPercent >= 90)) {
            return 'Completed';
        }
        
        return 'In Progress';
    }

    // ========================================================================
    // DTO CLASSES
    // ========================================================================

    public class EnrollmentResultDTO {
        @AuraEnabled public Id enrollmentId;
        @AuraEnabled public String status;
        @AuraEnabled public Decimal progressPercentage;
        @AuraEnabled public Decimal quizScore;
        @AuraEnabled public Boolean quizPassed;
    }
}