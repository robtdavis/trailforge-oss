/**
 * Test class for EnrollmentWizardController
 * Tests contact retrieval, search, and bulk enrollment functionality
 */
@IsTest
private class EnrollmentWizardController_Test {

    // ========================================================================
    // TEST DATA SETUP
    // ========================================================================

    @TestSetup
    static void setupTestData() {
        // Create test Account
        Account testAccount = new Account(Name = 'Test Enrollment Account');
        insert testAccount;
        
        // Create multiple contacts for the account
        List<Contact> contacts = new List<Contact>();
        for (Integer i = 0; i < 10; i++) {
            contacts.add(new Contact(
                FirstName = 'Test',
                LastName = 'Contact ' + i,
                Email = 'test.contact' + i + '@example.com',
                Title = 'Test Title ' + i,
                AccountId = testAccount.Id
            ));
        }
        insert contacts;
        
        // Create a second account with contacts for search testing
        Account testAccount2 = new Account(Name = 'Secondary Account');
        insert testAccount2;
        
        Contact searchContact = new Contact(
            FirstName = 'Unique',
            LastName = 'Searchable',
            Email = 'unique.searchable@example.com',
            AccountId = testAccount2.Id
        );
        insert searchContact;
        
        // Create test Course
        Course__c testCourse = new Course__c(
            Name = 'Test Enrollment Course',
            Description__c = 'A test course for enrollment wizard',
            Active__c = true,
            Archived__c = false,
            Difficulty__c = 'Beginner'
        );
        insert testCourse;
        
        // Create an archived course for testing
        Course__c archivedCourse = new Course__c(
            Name = 'Archived Course',
            Active__c = false,
            Archived__c = true
        );
        insert archivedCourse;
    }

    // ========================================================================
    // CONTACT RETRIEVAL TESTS
    // ========================================================================

    @IsTest
    static void testGetContactsByAccount_Success() {
        Account testAccount = [SELECT Id FROM Account WHERE Name = 'Test Enrollment Account' LIMIT 1];
        
        Test.startTest();
        List<Contact> contacts = EnrollmentWizardController.getContactsByAccount(testAccount.Id, 200);
        Test.stopTest();
        
        System.assertEquals(10, contacts.size(), 'Should return all 10 contacts');
        // Verify ordering
        System.assert(contacts[0].Name <= contacts[1].Name, 'Contacts should be ordered by name');
    }

    @IsTest
    static void testGetContactsByAccount_WithLimit() {
        Account testAccount = [SELECT Id FROM Account WHERE Name = 'Test Enrollment Account' LIMIT 1];
        
        Test.startTest();
        List<Contact> contacts = EnrollmentWizardController.getContactsByAccount(testAccount.Id, 5);
        Test.stopTest();
        
        System.assertEquals(5, contacts.size(), 'Should return only 5 contacts due to limit');
    }

    @IsTest
    static void testGetContactsByAccount_NullAccountId() {
        Test.startTest();
        List<Contact> contacts = EnrollmentWizardController.getContactsByAccount(null, 200);
        Test.stopTest();
        
        System.assertEquals(0, contacts.size(), 'Should return empty list for null account');
    }

    @IsTest
    static void testGetContactCountForAccount() {
        Account testAccount = [SELECT Id FROM Account WHERE Name = 'Test Enrollment Account' LIMIT 1];
        
        Test.startTest();
        Integer count = EnrollmentWizardController.getContactCountForAccount(testAccount.Id);
        Test.stopTest();
        
        System.assertEquals(10, count, 'Should return correct contact count');
    }

    @IsTest
    static void testGetContactCountForAccount_NullAccountId() {
        Test.startTest();
        Integer count = EnrollmentWizardController.getContactCountForAccount(null);
        Test.stopTest();
        
        System.assertEquals(0, count, 'Should return 0 for null account');
    }

    // ========================================================================
    // GLOBAL SEARCH TESTS
    // ========================================================================

    @IsTest
    static void testSearchContactsGlobal_WithResults() {
        Test.startTest();
        // SOSL requires Test.setFixedSearchResults in test context
        Contact searchContact = [SELECT Id FROM Contact WHERE FirstName = 'Unique' LIMIT 1];
        Test.setFixedSearchResults(new List<Id>{ searchContact.Id });
        
        List<Contact> contacts = EnrollmentWizardController.searchContactsGlobal('Unique', 50);
        Test.stopTest();
        
        System.assert(contacts.size() >= 1, 'Should find at least one contact');
    }

    @IsTest
    static void testSearchContactsGlobal_FallbackToSOQL() {
        // Don't set fixed search results to trigger SOQL fallback
        Test.startTest();
        List<Contact> contacts = EnrollmentWizardController.searchContactsGlobal('Searchable', 50);
        Test.stopTest();
        
        // SOQL LIKE should find the contact by name
        System.assert(contacts.size() >= 1, 'SOQL fallback should find contact by name');
    }

    @IsTest
    static void testSearchContactsGlobal_ShortSearchTerm() {
        Test.startTest();
        List<Contact> contacts = EnrollmentWizardController.searchContactsGlobal('a', 50);
        Test.stopTest();
        
        System.assertEquals(0, contacts.size(), 'Should return empty for search term < 2 chars');
    }

    @IsTest
    static void testSearchContactsGlobal_EmptySearchTerm() {
        Test.startTest();
        List<Contact> contacts = EnrollmentWizardController.searchContactsGlobal('', 50);
        Test.stopTest();
        
        System.assertEquals(0, contacts.size(), 'Should return empty for blank search term');
    }

    @IsTest
    static void testSearchContactsGlobal_NullSearchTerm() {
        Test.startTest();
        List<Contact> contacts = EnrollmentWizardController.searchContactsGlobal(null, 50);
        Test.stopTest();
        
        System.assertEquals(0, contacts.size(), 'Should return empty for null search term');
    }

    // ========================================================================
    // COURSE SEARCH TESTS
    // ========================================================================

    @IsTest
    static void testSearchCourses_WithSearchTerm() {
        Test.startTest();
        List<Course__c> courses = EnrollmentWizardController.searchCourses('Enrollment', 25);
        Test.stopTest();
        
        System.assertEquals(1, courses.size(), 'Should find the test course');
        System.assertEquals('Test Enrollment Course', courses[0].Name);
    }

    @IsTest
    static void testSearchCourses_NoSearchTerm() {
        Test.startTest();
        List<Course__c> courses = EnrollmentWizardController.searchCourses('', 25);
        Test.stopTest();
        
        // Should return active non-archived courses
        System.assert(courses.size() >= 1, 'Should return active courses');
        for (Course__c c : courses) {
            System.assertEquals('Test Enrollment Course', c.Name, 'Should not include archived course');
        }
    }

    @IsTest
    static void testSearchCourses_NoResults() {
        Test.startTest();
        List<Course__c> courses = EnrollmentWizardController.searchCourses('NonExistentCourse123', 25);
        Test.stopTest();
        
        System.assertEquals(0, courses.size(), 'Should return empty for no matches');
    }

    @IsTest
    static void testGetCourseById_Success() {
        Course__c testCourse = [SELECT Id FROM Course__c WHERE Name = 'Test Enrollment Course' LIMIT 1];
        
        Test.startTest();
        Course__c result = EnrollmentWizardController.getCourseById(testCourse.Id);
        Test.stopTest();
        
        System.assertNotEquals(null, result, 'Should return the course');
        System.assertEquals('Test Enrollment Course', result.Name);
    }

    @IsTest
    static void testGetCourseById_NullId() {
        Test.startTest();
        Course__c result = EnrollmentWizardController.getCourseById(null);
        Test.stopTest();
        
        System.assertEquals(null, result, 'Should return null for null ID');
    }

    // ========================================================================
    // ENROLLMENT TESTS
    // ========================================================================

    @IsTest
    static void testEnrollContacts_Success() {
        Course__c testCourse = [SELECT Id FROM Course__c WHERE Name = 'Test Enrollment Course' LIMIT 1];
        List<Contact> contacts = [SELECT Id FROM Contact WHERE Account.Name = 'Test Enrollment Account' LIMIT 3];
        List<Id> contactIds = new List<Id>();
        for (Contact c : contacts) {
            contactIds.add(c.Id);
        }
        
        Test.startTest();
        EnrollmentWizardController.BulkEnrollmentResultDTO result = 
            EnrollmentWizardController.enrollContacts(testCourse.Id, contactIds);
        Test.stopTest();
        
        System.assertEquals(true, result.success, 'Enrollment should succeed');
        System.assertEquals(3, result.createdCount, 'Should create 3 enrollments');
        System.assertEquals(0, result.skippedCount, 'Should skip 0 enrollments');
        System.assertEquals(0, result.failedCount, 'Should fail 0 enrollments');
        System.assertEquals('Test Enrollment Course', result.courseName);
        
        // Verify enrollments were created
        List<Enrollment__c> enrollments = [
            SELECT Id, Contact__c, Course__c, Status__c
            FROM Enrollment__c
            WHERE Course__c = :testCourse.Id
        ];
        System.assertEquals(3, enrollments.size(), 'Should have 3 enrollment records');
    }

    @IsTest
    static void testEnrollContacts_DedupeSkipsExisting() {
        Course__c testCourse = [SELECT Id FROM Course__c WHERE Name = 'Test Enrollment Course' LIMIT 1];
        List<Contact> contacts = [SELECT Id FROM Contact WHERE Account.Name = 'Test Enrollment Account' LIMIT 3];
        
        // Pre-create enrollment for first contact
        Enrollment__c existingEnrollment = new Enrollment__c(
            Contact__c = contacts[0].Id,
            Course__c = testCourse.Id,
            Status__c = 'In Progress',
            Unique_Key__c = String.valueOf(contacts[0].Id) + '_' + String.valueOf(testCourse.Id)
        );
        insert existingEnrollment;
        
        List<Id> contactIds = new List<Id>();
        for (Contact c : contacts) {
            contactIds.add(c.Id);
        }
        
        Test.startTest();
        EnrollmentWizardController.BulkEnrollmentResultDTO result = 
            EnrollmentWizardController.enrollContacts(testCourse.Id, contactIds);
        Test.stopTest();
        
        System.assertEquals(true, result.success, 'Enrollment should succeed');
        System.assertEquals(2, result.createdCount, 'Should create 2 new enrollments');
        System.assertEquals(1, result.skippedCount, 'Should skip 1 existing enrollment');
        
        // Verify per-contact results
        Integer createdCount = 0;
        Integer skippedCount = 0;
        for (EnrollmentWizardController.ContactEnrollmentResult cr : result.contactResults) {
            if (cr.status == 'Created') createdCount++;
            if (cr.status == 'Skipped') skippedCount++;
        }
        System.assertEquals(2, createdCount, 'Should have 2 created results');
        System.assertEquals(1, skippedCount, 'Should have 1 skipped result');
    }

    @IsTest
    static void testEnrollContacts_RunTwiceNoDuplicates() {
        Course__c testCourse = [SELECT Id FROM Course__c WHERE Name = 'Test Enrollment Course' LIMIT 1];
        List<Contact> contacts = [SELECT Id FROM Contact WHERE Account.Name = 'Test Enrollment Account' LIMIT 3];
        List<Id> contactIds = new List<Id>();
        for (Contact c : contacts) {
            contactIds.add(c.Id);
        }
        
        Test.startTest();
        // First run - should create all
        EnrollmentWizardController.BulkEnrollmentResultDTO result1 = 
            EnrollmentWizardController.enrollContacts(testCourse.Id, contactIds);
        
        // Second run - should skip all
        EnrollmentWizardController.BulkEnrollmentResultDTO result2 = 
            EnrollmentWizardController.enrollContacts(testCourse.Id, contactIds);
        Test.stopTest();
        
        System.assertEquals(3, result1.createdCount, 'First run should create 3');
        System.assertEquals(0, result1.skippedCount, 'First run should skip 0');
        
        System.assertEquals(0, result2.createdCount, 'Second run should create 0');
        System.assertEquals(3, result2.skippedCount, 'Second run should skip all 3');
        
        // Verify only 3 enrollments exist
        Integer totalEnrollments = [SELECT COUNT() FROM Enrollment__c WHERE Course__c = :testCourse.Id];
        System.assertEquals(3, totalEnrollments, 'Should still have only 3 enrollments');
    }

    @IsTest
    static void testEnrollContacts_NullCourseId() {
        List<Contact> contacts = [SELECT Id FROM Contact LIMIT 1];
        List<Id> contactIds = new List<Id>{ contacts[0].Id };
        
        Test.startTest();
        Boolean exceptionThrown = false;
        try {
            EnrollmentWizardController.enrollContacts(null, contactIds);
        } catch (AuraHandledException e) {
            exceptionThrown = true;
        }
        Test.stopTest();
        
        System.assert(exceptionThrown, 'Should throw exception for null course');
    }

    @IsTest
    static void testEnrollContacts_EmptyContactList() {
        Course__c testCourse = [SELECT Id FROM Course__c WHERE Name = 'Test Enrollment Course' LIMIT 1];
        
        Test.startTest();
        Boolean exceptionThrown = false;
        try {
            EnrollmentWizardController.enrollContacts(testCourse.Id, new List<Id>());
        } catch (AuraHandledException e) {
            exceptionThrown = true;
        }
        Test.stopTest();
        
        System.assert(exceptionThrown, 'Should throw exception for empty contacts');
    }

    @IsTest
    static void testEnrollContacts_NullContactList() {
        Course__c testCourse = [SELECT Id FROM Course__c WHERE Name = 'Test Enrollment Course' LIMIT 1];
        
        Test.startTest();
        Boolean exceptionThrown = false;
        try {
            EnrollmentWizardController.enrollContacts(testCourse.Id, null);
        } catch (AuraHandledException e) {
            exceptionThrown = true;
        }
        Test.stopTest();
        
        System.assert(exceptionThrown, 'Should throw exception for null contacts');
    }

    @IsTest
    static void testEnrollContacts_ArchivedCourse() {
        Course__c archivedCourse = [SELECT Id FROM Course__c WHERE Name = 'Archived Course' LIMIT 1];
        List<Contact> contacts = [SELECT Id FROM Contact LIMIT 1];
        List<Id> contactIds = new List<Id>{ contacts[0].Id };
        
        Test.startTest();
        Boolean exceptionThrown = false;
        try {
            EnrollmentWizardController.enrollContacts(archivedCourse.Id, contactIds);
        } catch (AuraHandledException e) {
            exceptionThrown = true;
        }
        Test.stopTest();
        
        System.assert(exceptionThrown, 'Should throw exception for archived course');
    }

    @IsTest
    static void testEnrollContacts_NonExistentCourse() {
        // Use a fake ID
        Id fakeCourseId = Course__c.SObjectType.getDescribe().getKeyPrefix() + '000000000001';
        List<Contact> contacts = [SELECT Id FROM Contact LIMIT 1];
        List<Id> contactIds = new List<Id>{ contacts[0].Id };
        
        Test.startTest();
        Boolean exceptionThrown = false;
        try {
            EnrollmentWizardController.enrollContacts(fakeCourseId, contactIds);
        } catch (AuraHandledException e) {
            exceptionThrown = true;
        }
        Test.stopTest();
        
        System.assert(exceptionThrown, 'Should throw exception for non-existent course');
    }

    @IsTest
    static void testEnrollContacts_SetsEnrollmentDate() {
        Course__c testCourse = [SELECT Id FROM Course__c WHERE Name = 'Test Enrollment Course' LIMIT 1];
        Account testAccount = [SELECT Id FROM Account WHERE Name = 'Test Enrollment Account' LIMIT 1];
        Contact testContact = [SELECT Id, AccountId FROM Contact WHERE AccountId = :testAccount.Id LIMIT 1];
        
        Test.startTest();
        EnrollmentWizardController.BulkEnrollmentResultDTO result = 
            EnrollmentWizardController.enrollContacts(testCourse.Id, new List<Id>{ testContact.Id });
        Test.stopTest();
        
        System.assertEquals(1, result.createdCount, 'Should create 1 enrollment');
        
        // Verify Enrollment Date was set
        Enrollment__c enrollment = [
            SELECT Enrollment_Date__c 
            FROM Enrollment__c 
            WHERE Contact__c = :testContact.Id AND Course__c = :testCourse.Id
            LIMIT 1
        ];
        System.assertEquals(Date.today(), enrollment.Enrollment_Date__c, 'Enrollment should have Enrollment Date set');
    }

    @IsTest
    static void testEnrollContacts_ContactResultsPopulated() {
        Course__c testCourse = [SELECT Id FROM Course__c WHERE Name = 'Test Enrollment Course' LIMIT 1];
        List<Contact> contacts = [SELECT Id, Name FROM Contact WHERE Account.Name = 'Test Enrollment Account' LIMIT 2];
        List<Id> contactIds = new List<Id>();
        for (Contact c : contacts) {
            contactIds.add(c.Id);
        }
        
        Test.startTest();
        EnrollmentWizardController.BulkEnrollmentResultDTO result = 
            EnrollmentWizardController.enrollContacts(testCourse.Id, contactIds);
        Test.stopTest();
        
        System.assertEquals(2, result.contactResults.size(), 'Should have 2 contact results');
        for (EnrollmentWizardController.ContactEnrollmentResult cr : result.contactResults) {
            System.assertNotEquals(null, cr.contactId, 'Contact ID should be set');
            System.assertNotEquals(null, cr.contactName, 'Contact name should be set');
            System.assertEquals('Created', cr.status, 'Status should be Created');
            System.assertNotEquals(null, cr.enrollmentId, 'Enrollment ID should be set');
        }
    }

    @IsTest
    static void testEnrollContacts_HandlesNullInContactIds() {
        Course__c testCourse = [SELECT Id FROM Course__c WHERE Name = 'Test Enrollment Course' LIMIT 1];
        Contact testContact = [SELECT Id FROM Contact LIMIT 1];
        
        // Include null in the list
        List<Id> contactIds = new List<Id>{ testContact.Id, null, testContact.Id };
        
        Test.startTest();
        EnrollmentWizardController.BulkEnrollmentResultDTO result = 
            EnrollmentWizardController.enrollContacts(testCourse.Id, contactIds);
        Test.stopTest();
        
        // Should dedupe and remove nulls, creating only 1
        System.assertEquals(1, result.createdCount, 'Should create 1 enrollment (deduped)');
    }
}
