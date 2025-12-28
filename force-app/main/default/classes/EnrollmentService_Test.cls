//
// SPDX-License-Identifier: MIT
// TrailForge — Open Source under the MIT License
// Copyright (c) 2025 Robert Davis
// See the LICENSE file in the project root for full license text.
//
@IsTest
private class EnrollmentService_Test {

    @IsTest
    static void recalc_setsNotStartedWhenNoProgress() {
        TrailForgeTestDataFactory.TrailForgeTestContext ctx =
            TrailForgeTestDataFactory.createBasicContext(3);

        Test.startTest();
        EnrollmentService.recalculateEnrollmentProgress(ctx.enrollment.Id);
        Test.stopTest();

        Enrollment__c updatedEnr = [
            SELECT Status__c, Progress_Percentage__c
            FROM Enrollment__c
            WHERE Id = :ctx.enrollment.Id
        ];

        System.assertEquals(0, updatedEnr.Progress_Percentage__c,
            'Progress should be 0 with no lessons completed');
        System.assertEquals('Not Started', updatedEnr.Status__c,
            'Status should be Not Started');
    }

    @IsTest
    static void recalc_setsInProgressWhenSomeLessonsCompleted() {
        TrailForgeTestDataFactory.TrailForgeTestContext ctx =
            TrailForgeTestDataFactory.createBasicContext(3);

        // Mark 1 of 3 lessons as completed
        List<Lesson__c> subset = new List<Lesson__c>{ ctx.lessons[0] };
        TrailForgeTestDataFactory.createProgressForLessons(
            ctx.enrollment.Id,
            ctx.contact.Id,
            subset
        );

        Test.startTest();
        EnrollmentService.recalculateEnrollmentProgress(ctx.enrollment.Id);
        Test.stopTest();

        Enrollment__c updatedEnr = [
            SELECT Status__c, Progress_Percentage__c
            FROM Enrollment__c
            WHERE Id = :ctx.enrollment.Id
        ];

        System.assertEquals(33.33, updatedEnr.Progress_Percentage__c,
            '1 of 3 completed should be about 33.33%');
        System.assertEquals('In Progress', updatedEnr.Status__c,
            'Status should be In Progress when some lessons are done');
    }

    @IsTest
    static void recalc_setsCompletedWhenAllLessonsCompleted() {
        TrailForgeTestDataFactory.TrailForgeTestContext ctx =
            TrailForgeTestDataFactory.createBasicContext(3);

        // Mark all lessons as completed
        TrailForgeTestDataFactory.createProgressForLessons(
            ctx.enrollment.Id,
            ctx.contact.Id,
            ctx.lessons
        );

        Test.startTest();
        EnrollmentService.recalculateEnrollmentProgress(ctx.enrollment.Id);
        Test.stopTest();

        Enrollment__c updatedEnr = [
            SELECT Status__c, Progress_Percentage__c
            FROM Enrollment__c
            WHERE Id = :ctx.enrollment.Id
        ];

        System.assertEquals(100, updatedEnr.Progress_Percentage__c,
            'All lessons completed should be 100%');
        System.assertEquals('Completed', updatedEnr.Status__c,
            'Status should be Completed when all lessons are done');
    }
}