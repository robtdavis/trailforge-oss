@IsTest
private class LessonPlayerController_Test {

    @IsTest
    static void getLessonContext_returnsModulesAndLessons() {
        TrailForgeTestDataFactory.TrailForgeTestContext ctx =
            TrailForgeTestDataFactory.createBasicContext(3);

        Test.startTest();
        LessonPlayerController.LessonContextDTO context =
            LessonPlayerController.getLessonContext(ctx.course.Id, ctx.contact.Id);
        Test.stopTest();

        System.assertNotEquals(null, context, 'Context should not be null');
        System.assertEquals(ctx.enrollment.Id, context.enrollmentId, 'Enrollment Id should match');
        System.assertEquals(ctx.course.Id, context.courseId, 'Course Id should match');
        System.assertEquals('Test Course', context.courseName, 'Course name should match');

        System.assertEquals(1, context.modules.size(), 'There should be one module');
        System.assertEquals(3, context.modules[0].lessons.size(), 'There should be three lessons');

        for (LessonPlayerController.LessonDTO ldto : context.modules[0].lessons) {
            System.assertEquals('Not Started', ldto.status, 'Initial status should be Not Started');
            System.assertNotEquals(null, ldto.content, 'Content should be populated');
        }
    }

    @IsTest
    static void markLessonComplete_createsProgressAndUpdatesStatus() {
        TrailForgeTestDataFactory.TrailForgeTestContext ctx =
            TrailForgeTestDataFactory.createBasicContext(2);

        Lesson__c firstLesson = ctx.lessons[0];

        Test.startTest();
        LessonPlayerController.LessonContextDTO context =
            LessonPlayerController.markLessonComplete(ctx.enrollment.Id, firstLesson.Id);
        Test.stopTest();

        // Progress record exists
        List<Progress__c> progress = [
            SELECT Enrollment__c, Lesson__c, Status__c
            FROM Progress__c
            WHERE Enrollment__c = :ctx.enrollment.Id
              AND Lesson__c = :firstLesson.Id
        ];
        System.assertEquals(1, progress.size(), 'One progress record should exist');
        System.assertEquals('Completed', progress[0].Status__c,
            'Progress should be Completed');

        // Enrollment is updated
        Enrollment__c updatedEnr = [
            SELECT Status__c, Progress_Percentage__c
            FROM Enrollment__c
            WHERE Id = :ctx.enrollment.Id
        ];
        System.assertEquals('In Progress', updatedEnr.Status__c,
            'Status should be In Progress after first lesson completion');

        // Returned DTO reflects updated status for that lesson
        Boolean foundCompleted = false;
        for (LessonPlayerController.ModuleDTO mdto : context.modules) {
            for (LessonPlayerController.LessonDTO ldto : mdto.lessons) {
                if (ldto.lessonId == firstLesson.Id) {
                    System.assertEquals('Completed', ldto.status,
                        'DTO should show Completed for the finished lesson');
                    foundCompleted = true;
                }
            }
        }
        System.assertEquals(true, foundCompleted,
            'Completed lesson should be present in context DTO');
    }
}