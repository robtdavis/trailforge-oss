@IsTest
private class EnrollmentRecalcInvoker_Test {

    @IsTest
    static void recalc_invokesServiceAndUpdatesProgress() {
        TrailForgeTestDataFactory.TrailForgeTestContext ctx =
            TrailForgeTestDataFactory.createBasicContext(2);

        // One lesson completed
        List<Lesson__c> subset = new List<Lesson__c>{ ctx.lessons[0] };
        TrailForgeTestDataFactory.createProgressForLessons(
            ctx.enrollment.Id,
            ctx.contact.Id,
            subset
        );

        Test.startTest();
        EnrollmentRecalcInvoker.recalc(new List<Id>{ ctx.enrollment.Id });
        Test.stopTest();

        Enrollment__c updatedEnr = [
            SELECT Status__c, Progress_Percentage__c
            FROM Enrollment__c
            WHERE Id = :ctx.enrollment.Id
        ];

        System.assertEquals('In Progress', updatedEnr.Status__c,
            'Status should be In Progress after partial completion');
        System.assertNotEquals(0, updatedEnr.Progress_Percentage__c,
            'Progress percentage should not be zero');
    }
}