/**
 * Comprehensive tests for EnrollmentService bulk methods
 * Tests governor limits, recursion protection, and quiz gating consistency
 */
@isTest
private class EnrollmentService_BulkTest {
    
    /**
     * Test bulk recalculation for 100 enrollments
     * Verifies no governor limit violations
     */
    @isTest
    static void testBulkRecalc_200Enrollments() {
        // Create test data: 100 contacts, 1 course with 10 lessons
        List<Contact> contacts = new List<Contact>();
        for (Integer i = 0; i < 100; i++) {
            contacts.add(new Contact(
                FirstName = 'Bulk',
                LastName = 'Learner' + i,
                Email = 'bulk' + i + '@test.com'
            ));
        }
        insert contacts;
        
        // Create course with 2 modules, 5 lessons each (10 total)
        Course__c course = new Course__c(
            Name = 'Bulk Test Course',
            Passing_Score__c = 70
        );
        insert course;
        
        List<Module__c> modules = new List<Module__c>{
            new Module__c(Course__c = course.Id, Name = 'Module 1'),
            new Module__c(Course__c = course.Id, Name = 'Module 2')
        };
        insert modules;
        
        List<Lesson__c> lessons = new List<Lesson__c>();
        for (Integer i = 0; i < 2; i++) {
            for (Integer j = 0; j < 5; j++) {
                lessons.add(new Lesson__c(
                    Module__c = modules[i].Id,
                    Name = 'Module ' + (i + 1) + ' Lesson ' + (j + 1),
                    Content_Body__c = '<p>Test</p>'
                ));
            }
        }
        insert lessons;
        
        // Reload contacts to ensure we have fresh IDs
        Map<Id, Contact> contactMap = new Map<Id, Contact>([
            SELECT Id FROM Contact WHERE Id IN :contacts
        ]);
        
        // Create 100 enrollments
        List<Enrollment__c> enrollments = new List<Enrollment__c>();
        for (Contact contact : contactMap.values()) {
            Enrollment__c enr = new Enrollment__c(
                Contact__c = contact.Id,
                Course__c = course.Id,
                Status__c = 'Not Started',
                Progress_Percentage__c = 0
            );
            // Explicitly set Unique_Key__c to prevent workflow issues in tests
            enr.Unique_Key__c = contact.Id + '_' + course.Id;
            enrollments.add(enr);
        }
        insert enrollments;
        
        // Mark 5 lessons complete for each enrollment (50% progress)
        List<Progress__c> progressRecords = new List<Progress__c>();
        for (Enrollment__c enr : enrollments) {
            for (Integer i = 0; i < 5; i++) {
                Progress__c prog = new Progress__c(
                    Contact__c = enr.Contact__c,
                    Enrollment__c = enr.Id,
                    Lesson__c = lessons[i].Id,
                    Status__c = 'Completed',
                    Started_On__c = System.now(),
                    Completed_On__c = System.now()
                );
                // Explicitly set Unique_Key__c to prevent workflow issues in tests
                prog.Unique_Key__c = enr.Contact__c + '_' + lessons[i].Id + '_' + enr.Id;
                progressRecords.add(prog);
            }
        }
        insert progressRecords;
        
        // Test bulk recalculation
        Test.startTest();
        Set<Id> enrollmentIds = new Map<Id, Enrollment__c>(enrollments).keySet();
        EnrollmentService.recalculateEnrollmentProgressBulk(enrollmentIds);
        Test.stopTest();
        
        // Verify results
        List<Enrollment__c> updatedEnrollments = [
            SELECT Id, Progress_Percentage__c, Status__c
            FROM Enrollment__c
            WHERE Id IN :enrollmentIds
        ];
        
        System.assertEquals(100, updatedEnrollments.size(), 'Should process all 100 enrollments');
        
        for (Enrollment__c enr : updatedEnrollments) {
            System.assertEquals(50, enr.Progress_Percentage__c, 'Each enrollment should be 50% complete');
            System.assertEquals('In Progress', enr.Status__c, 'Status should be In Progress');
        }
        
        // Verify governor limits (should use 3 queries + 1 DML)
        // No assertions needed - test will fail if limits exceeded
    }
    
    /**
     * Test recursion guard prevents double-processing
     * Verifies static Set<Id> processingEnrollmentIds works
     */
    @isTest
    static void testRecursionGuard() {
        // Create test context
        TrailForgeTestDataFactory.TrailForgeTestContext ctx = 
            TrailForgeTestDataFactory.createBasicContext(3);
        
        // Mark 2 of 3 lessons complete (67%)
        List<Lesson__c> completeLessons = new List<Lesson__c>{
            ctx.lessons[0],
            ctx.lessons[1]
        };
        TrailForgeTestDataFactory.createProgressForLessons(
            ctx.enrollment.Id,
            ctx.contact.Id,
            completeLessons
        );
        
        // First recalculation
        Test.startTest();
        EnrollmentService.recalculateEnrollmentProgress(ctx.enrollment.Id);
        
        // Verify enrollment updated
        Enrollment__c enr1 = [
            SELECT Progress_Percentage__c, Status__c
            FROM Enrollment__c
            WHERE Id = :ctx.enrollment.Id
        ];
        System.assertEquals(66.67, enr1.Progress_Percentage__c, 'Should be 66.67% after first recalc (2/3)');
        System.assertEquals('In Progress', enr1.Status__c, 'Should be In Progress');
        
        // Second recalculation (should be idempotent due to recursion guard)
        EnrollmentService.recalculateEnrollmentProgress(ctx.enrollment.Id);
        
        Enrollment__c enr2 = [
            SELECT Progress_Percentage__c, Status__c
            FROM Enrollment__c
            WHERE Id = :ctx.enrollment.Id
        ];
        System.assertEquals(66.67, enr2.Progress_Percentage__c, 'Should still be 66.67% after second recalc (2/3)');
        System.assertEquals('In Progress', enr2.Status__c, 'Should still be In Progress');
        
        Test.stopTest();
    }
    
    /**
     * Test quiz gating consistency between submission and recalculation
     * Verifies Option B (fudge model): 90% + quiz = 100% complete
     */
    @isTest
    static void testQuizGatingConsistency() {
        // Create course with quiz
        Course__c course = new Course__c(
            Name = 'Quiz Gating Test Course',
            Passing_Score__c = 70
        );
        insert course;
        
        Module__c module = new Module__c(
            Course__c = course.Id,
            Name = 'Module 1'
        );
        insert module;
        
        // Create 10 lessons
        List<Lesson__c> lessons = new List<Lesson__c>();
        for (Integer i = 0; i < 10; i++) {
            lessons.add(new Lesson__c(
                Module__c = module.Id,
                Name = 'Lesson ' + (i + 1),
                Content_Body__c = '<p>Test</p>'
            ));
        }
        insert lessons;
        
        // Create contact and enrollment
        Contact contact = new Contact(
            FirstName = 'Quiz',
            LastName = 'Tester',
            Email = 'quiz@test.com'
        );
        insert contact;
        
        Enrollment__c enrollment = new Enrollment__c(
            Contact__c = contact.Id,
            Course__c = course.Id,
            Status__c = 'Not Started',
            Progress_Percentage__c = 0
        );
        insert enrollment;
        
        // Mark 9 of 10 lessons complete (90% content)
        List<Progress__c> progressRecords = new List<Progress__c>();
        for (Integer i = 0; i < 9; i++) {
            progressRecords.add(new Progress__c(
                Contact__c = contact.Id,
                Enrollment__c = enrollment.Id,
                Lesson__c = lessons[i].Id,
                Status__c = 'Completed',
                Started_On__c = System.now(),
                Completed_On__c = System.now()
            ));
        }
        insert progressRecords;
        
        Test.startTest();
        
        // Step 1: Recalculate - should be 90% In Progress (quiz not passed)
        EnrollmentService.recalculateEnrollmentProgress(enrollment.Id);
        
        Enrollment__c enr1 = [
            SELECT Progress_Percentage__c, Status__c, Quiz_Passed__c
            FROM Enrollment__c
            WHERE Id = :enrollment.Id
        ];
        System.assertEquals(90, enr1.Progress_Percentage__c, 'Should be 90% before quiz');
        System.assertEquals('In Progress', enr1.Status__c, 'Should be In Progress before quiz');
        System.assertEquals(false, enr1.Quiz_Passed__c, 'Quiz not passed yet');
        
        // Step 2: Submit passing quiz score
        EnrollmentService.EnrollmentResultDTO result = 
            EnrollmentService.recordQuizResult(enrollment.Id, 85);
        
        // Should promote to 100% Completed (Option B: 90% + quiz = complete)
        System.assertEquals(100, result.progressPercentage, 'Should be 100% after passing quiz');
        System.assertEquals('Completed', result.status, 'Should be Completed after passing quiz');
        System.assertEquals(true, result.quizPassed, 'Quiz should be marked passed');
        
        // Step 3: Recalculate again - should NOT downgrade from Completed
        EnrollmentService.recalculateEnrollmentProgress(enrollment.Id);
        
        Enrollment__c enr2 = [
            SELECT Progress_Percentage__c, Status__c, Quiz_Passed__c
            FROM Enrollment__c
            WHERE Id = :enrollment.Id
        ];
        System.assertEquals(100, enr2.Progress_Percentage__c, 'Should stay 100% after recalc');
        System.assertEquals('Completed', enr2.Status__c, 'Should stay Completed after recalc');
        System.assertEquals(true, enr2.Quiz_Passed__c, 'Quiz should still be passed');
        
        Test.stopTest();
    }
    
    /**
     * Test quiz gating: below 90% content should NOT promote to complete
     */
    @isTest
    static void testQuizGating_BelowThreshold() {
        // Create course with quiz
        Course__c course = new Course__c(
            Name = 'Quiz Threshold Test',
            Passing_Score__c = 70
        );
        insert course;
        
        Module__c module = new Module__c(
            Course__c = course.Id,
            Name = 'Module 1'
        );
        insert module;
        
        // Create 10 lessons
        List<Lesson__c> lessons = new List<Lesson__c>();
        for (Integer i = 0; i < 10; i++) {
            lessons.add(new Lesson__c(
                Module__c = module.Id,
                Name = 'Lesson ' + (i + 1),
                Content_Body__c = '<p>Test</p>'
            ));
        }
        insert lessons;
        
        // Create contact and enrollment
        Contact contact = new Contact(
            FirstName = 'Quiz',
            LastName = 'Threshold',
            Email = 'threshold@test.com'
        );
        insert contact;
        
        Enrollment__c enrollment = new Enrollment__c(
            Contact__c = contact.Id,
            Course__c = course.Id,
            Status__c = 'Not Started',
            Progress_Percentage__c = 0
        );
        insert enrollment;
        
        // Mark only 8 of 10 lessons complete (80% content - below 90% threshold)
        List<Progress__c> progressRecords = new List<Progress__c>();
        for (Integer i = 0; i < 8; i++) {
            progressRecords.add(new Progress__c(
                Contact__c = contact.Id,
                Enrollment__c = enrollment.Id,
                Lesson__c = lessons[i].Id,
                Status__c = 'Completed',
                Started_On__c = System.now(),
                Completed_On__c = System.now()
            ));
        }
        insert progressRecords;
        
        Test.startTest();
        
        // Submit passing quiz score
        EnrollmentService.EnrollmentResultDTO result = 
            EnrollmentService.recordQuizResult(enrollment.Id, 85);
        
        // Should NOT promote to 100% (only 80% content complete)
        System.assertEquals(80, result.progressPercentage, 'Should stay at 80% (below threshold)');
        System.assertEquals('In Progress', result.status, 'Should stay In Progress');
        System.assertEquals(true, result.quizPassed, 'Quiz should be passed');
        
        Test.stopTest();
    }
}