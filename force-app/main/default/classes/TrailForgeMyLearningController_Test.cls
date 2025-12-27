@IsTest
private class TrailForgeMyLearningController_Test {

    private static User createMyLearningUser() {
        Profile p = [
            SELECT Id
            FROM Profile
            WHERE Name = 'Standard User'
            LIMIT 1
        ];

        User u = new User(
            FirstName         = 'MyLearning',
            LastName          = 'User',
            Email             = 'mylearning.user.' + System.currentTimeMillis() + '@example.com',
            Username          = 'mylearning.user.' + System.currentTimeMillis() + '@example.com',
            Alias             = 'mlusr',
            TimeZoneSidKey    = 'America/Los_Angeles',
            LocaleSidKey      = 'en_US',
            EmailEncodingKey  = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            ProfileId         = p.Id
        );
        insert u;
        return u;
    }

    @IsTest
    static void getMyEnrollments_returnsEnrollmentsForCurrentUser() {
        // Get current running user's email
        String currentUserEmail = UserInfo.getUserEmail();
        
        // Create contact with current user's email
        Contact c = new Contact(
            LastName = 'MyLearning Contact',
            Email    = currentUserEmail
        );
        insert c;

        Course__c course = new Course__c(
            Name             = 'MyLearning Course',
            Description__c   = 'Course for MyLearning tests',
            Thumbnail_URL__c = 'https://example.com/mylearning.png'
        );
        insert course;

        Enrollment__c enrollment = new Enrollment__c(
            Contact__c             = c.Id,
            Course__c              = course.Id,
            Status__c              = 'In Progress',
            Progress_Percentage__c = 42
        );
        insert enrollment;

        List<TrailForgeMyLearningController.EnrollmentDTO> result;

        // Call the method - it will use UserInfo.getUserEmail() internally
        Test.startTest();
        result = TrailForgeMyLearningController.getMyEnrollments();
        Test.stopTest();

        System.assertEquals(1, result.size(), 'Should return one enrollment for this user');
        TrailForgeMyLearningController.EnrollmentDTO dto = result[0];

        System.assertEquals(enrollment.Id, dto.enrollmentId, 'Enrollment Id should match');
        System.assertEquals(course.Id, dto.courseId, 'Course Id should match');
        System.assertEquals('MyLearning Course', dto.courseName, 'Course name should match');
        System.assertEquals('Course for MyLearning tests', dto.courseDescription,
            'Description should match');
        System.assertEquals(42, dto.progressPercentage, 'Progress should match');
        System.assertEquals('In Progress', dto.status, 'Status should match');
    }
}