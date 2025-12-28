//
// SPDX-License-Identifier: MIT
// TrailForge — Open Source under the MIT License
// Copyright (c) 2025 Robert Davis
// See the LICENSE file in the project root for full license text.
//
public with sharing class TrailForgeTestDataFactory {

    public class TrailForgeTestContext {
        public User user;
        public Contact contact;
        public Course__c course;
        public List<Module__c> modules;
        public List<Lesson__c> lessons;
        public Enrollment__c enrollment;
    }

    public static TrailForgeTestContext createBasicContext(Integer lessonCount) {
        if (lessonCount == null || lessonCount <= 0) {
            lessonCount = 3;
        }

        TrailForgeTestContext ctx = new TrailForgeTestContext();
        ctx.modules = new List<Module__c>();
        ctx.lessons = new List<Lesson__c>();

        // 1) User
        ctx.user = createTestUser();

        // 2) Contact linked by email (used by MyLearning controller)
        ctx.contact = new Contact(
            LastName = 'TrailForge Tester',
            Email    = ctx.user.Email
        );
        insert ctx.contact;

        // 3) Course
        ctx.course = new Course__c(
            Name             = 'Test Course',
            Description__c   = 'Test Course Description',
            Thumbnail_URL__c = 'https://example.com/test-thumbnail.png'
        );
        insert ctx.course;

        // 4) Module
        Module__c module = new Module__c(
            Name      = 'Test Module',
            Course__c = ctx.course.Id
        );
        insert module;
        ctx.modules.add(module);

        // 5) Lessons
        List<Lesson__c> lessonsToInsert = new List<Lesson__c>();
        for (Integer i = 1; i <= lessonCount; i++) {
            lessonsToInsert.add(new Lesson__c(
                Name       = 'Lesson ' + i,
                Module__c  = module.Id,
                Content_Body__c = 'Test content for lesson ' + i
            ));
        }
        insert lessonsToInsert;
        ctx.lessons.addAll(lessonsToInsert);

        // 6) Enrollment
        ctx.enrollment = new Enrollment__c(
            Contact__c              = ctx.contact.Id,
            Course__c               = ctx.course.Id,
            Status__c               = 'Not Started',
            Progress_Percentage__c  = 0
        );
        insert ctx.enrollment;

        return ctx;
    }

    public static List<Progress__c> createProgressForLessons(
        Id enrollmentId,
        Id contactId,
        List<Lesson__c> lessons
    ) {
        List<Progress__c> toInsert = new List<Progress__c>();
        for (Lesson__c lesson : lessons) {
            toInsert.add(new Progress__c(
                Enrollment__c   = enrollmentId,
                Contact__c      = contactId,
                Lesson__c       = lesson.Id,
                Status__c       = 'Completed',
                Started_On__c   = System.now(),
                Completed_On__c = System.now()
            ));
        }
        insert toInsert;
        return toInsert;
    }

    private static User createTestUser() {
        Profile p = [
            SELECT Id
            FROM Profile
            WHERE Name = 'Standard User'
            LIMIT 1
        ];

        User u = new User(
            FirstName         = 'TrailForge',
            LastName          = 'Tester',
            Email             = 'trailforge.tester.' + System.currentTimeMillis() + '@example.com',
            Username          = 'trailforge.tester.' + System.currentTimeMillis() + '@example.com',
            Alias             = 'tftst',
            TimeZoneSidKey    = 'America/Los_Angeles',
            LocaleSidKey      = 'en_US',
            EmailEncodingKey  = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            ProfileId         = p.Id
        );
        insert u;
        return u;
    }
}