//
// SPDX-License-Identifier: MIT
// TrailForge — Open Source under the MIT License
// Copyright (c) 2025 Robert Davis
// See the LICENSE file in the project root for full license text.
//
public with sharing class EnrollmentDAO {

    // ========================================================================
    // EXISTING METHODS (for EnrollmentService compatibility)
    // ========================================================================

    public static Enrollment__c getEnrollmentWithContactAndCourse(Id enrollmentId) {
        if (enrollmentId == null) return null;

        return [
            SELECT Id, Contact__c, Course__c, Progress_Percentage__c, Status__c, Quiz_Passed__c, Quiz_Score__c
            FROM Enrollment__c
            WHERE Id = :enrollmentId
            LIMIT 1
        ];
    }

    public static List<Lesson__c> getLessonsForCourse(Id courseId) {
        if (courseId == null) return new List<Lesson__c>();

        return [
            SELECT Id
            FROM Lesson__c
            WHERE Module__r.Course__c = :courseId
              AND Archived__c = false
              AND Module__r.Archived__c = false
        ];
    }

    public static List<Progress__c> getProgressForContactAndLessons(Id contactId, Set<Id> lessonIds) {
        if (contactId == null || lessonIds.isEmpty()) {
            return new List<Progress__c>();
        }

        return [
            SELECT Id, Lesson__c, Status__c
            FROM Progress__c
            WHERE Contact__c = :contactId
              AND Lesson__c IN :lessonIds
        ];
    }

    // ========================================================================
    // BULK PROCESSING METHODS (for EnrollmentService bulk recalculation)
    // ========================================================================

    /**
     * Get multiple enrollments by IDs in a single query
     * Used by bulk recalculation to avoid N+1 queries
     * 
     * @param enrollmentIds Set of Enrollment IDs
     * @return List of Enrollments with all fields needed for progress calculation
     */
    public static List<Enrollment__c> getEnrollmentsByIds(Set<Id> enrollmentIds) {
        if (enrollmentIds == null || enrollmentIds.isEmpty()) {
            return new List<Enrollment__c>();
        }

        return [
            SELECT Id, 
                   Contact__c, 
                   Course__c, 
                   Progress_Percentage__c, 
                   Status__c, 
                   Quiz_Passed__c, 
                   Quiz_Score__c,
                   Completion_Date__c
            FROM Enrollment__c
            WHERE Id IN :enrollmentIds
        ];
    }

    /**
     * Get all lessons for multiple courses, grouped by course ID
     * Single query to support bulk enrollment recalculation
     * 
     * @param courseIds Set of Course IDs
     * @return Map of Course ID → List of Lessons for that course
     */
    public static Map<Id, List<Lesson__c>> getLessonsByCourseIds(Set<Id> courseIds) {
        if (courseIds == null || courseIds.isEmpty()) {
            return new Map<Id, List<Lesson__c>>();
        }

        Map<Id, List<Lesson__c>> result = new Map<Id, List<Lesson__c>>();

        for (Lesson__c lesson : [
            SELECT Id, Module__r.Course__c
            FROM Lesson__c
            WHERE Module__r.Course__c IN :courseIds
              AND Archived__c = false
              AND Module__r.Archived__c = false
        ]) {
            Id courseId = lesson.Module__r.Course__c;
            if (!result.containsKey(courseId)) {
                result.put(courseId, new List<Lesson__c>());
            }
            result.get(courseId).add(lesson);
        }

        return result;
    }

    /**
     * Get all progress records for multiple enrollments, grouped by enrollment ID
     * Single query to support bulk enrollment recalculation
     * 
     * @param enrollmentIds Set of Enrollment IDs
     * @return Map of Enrollment ID → List of Progress records for that enrollment
     */
    public static Map<Id, List<Progress__c>> getProgressByEnrollmentIds(Set<Id> enrollmentIds) {
        if (enrollmentIds == null || enrollmentIds.isEmpty()) {
            return new Map<Id, List<Progress__c>>();
        }

        Map<Id, List<Progress__c>> result = new Map<Id, List<Progress__c>>();

        for (Progress__c progress : [
            SELECT Id, Enrollment__c, Lesson__c, Status__c
            FROM Progress__c
            WHERE Enrollment__c IN :enrollmentIds
        ]) {
            Id enrollmentId = progress.Enrollment__c;
            if (!result.containsKey(enrollmentId)) {
                result.put(enrollmentId, new List<Progress__c>());
            }
            result.get(enrollmentId).add(progress);
        }

        return result;
    }

    // ========================================================================
    // LESSON PLAYER METHODS
    // ========================================================================

    /**
     * Search for Contact records by name or email
     * Returns limited results suitable for a lookup/search UI
     */
    public static List<Contact> searchContacts(String searchTerm, Integer maxResults) {
        if (String.isBlank(searchTerm)) {
            return new List<Contact>();
        }

        Integer limitValue = maxResults != null ? maxResults : 25;
        String searchPattern = '%' + String.escapeSingleQuotes(searchTerm) + '%';

        return [
            SELECT Id, Name, Email
            FROM Contact
            WHERE Name LIKE :searchPattern 
               OR Email LIKE :searchPattern
            ORDER BY Name
            LIMIT :limitValue
        ];
    }

    /**
     * Find existing enrollment for a specific Contact and Course
     * Returns null if not found
     */
    public static Enrollment__c findEnrollment(Id courseId, Id contactId) {
        if (courseId == null || contactId == null) {
            return null;
        }

        List<Enrollment__c> enrollments = [
            SELECT Id, 
                   Contact__c, 
                   Course__c, 
                   Course__r.Name, 
                   Status__c, 
                   Progress_Percentage__c,
                   Quiz_Passed__c,
                   Quiz_Score__c
            FROM Enrollment__c
            WHERE Course__c = :courseId 
              AND Contact__c = :contactId
            LIMIT 1
        ];

        return enrollments.isEmpty() ? null : enrollments[0];
    }

    /**
     * Get full enrollment details by Id
     * Includes Course name for display
     */
    public static Enrollment__c getEnrollmentById(Id enrollmentId) {
        if (enrollmentId == null) {
            return null;
        }

        return [
            SELECT Id, 
                   Contact__c, 
                   Course__c, 
                   Course__r.Name, 
                   Status__c, 
                   Progress_Percentage__c,
                   Quiz_Passed__c,
                   Quiz_Score__c
            FROM Enrollment__c
            WHERE Id = :enrollmentId
            LIMIT 1
        ];
    }

    /**
     * Get all modules for a course, ordered by name
     */
    public static List<Module__c> getModulesForCourse(Id courseId) {
        if (courseId == null) {
            return new List<Module__c>();
        }

        return [
            SELECT Id, Name
            FROM Module__c
            WHERE Course__c = :courseId
              AND Archived__c = false
            ORDER BY Name
        ];
    }

    /**
     * Get all lessons for a set of modules, ordered by name
     */
    public static List<Lesson__c> getLessonsForModules(Set<Id> moduleIds) {
        if (moduleIds == null || moduleIds.isEmpty()) {
            return new List<Lesson__c>();
        }

        return [
            SELECT Id, Name, Module__c, Content_Body__c, Quiz__c, Show_Complete_Button__c
            FROM Lesson__c
            WHERE Module__c IN :moduleIds
              AND Archived__c = false
            ORDER BY Name
        ];
    }

    /**
     * Get progress records for an enrollment across specific lessons
     * Always scoped to a specific enrollment for data integrity
     */
    public static List<Progress__c> getProgressForEnrollmentAndLessons(
        Id enrollmentId,
        Set<Id> lessonIds
    ) {
        if (enrollmentId == null || lessonIds == null || lessonIds.isEmpty()) {
            return new List<Progress__c>();
        }

        return [
            SELECT Id, Lesson__c, Status__c, Enrollment__c, Started_On__c, Completed_On__c
            FROM Progress__c
            WHERE Enrollment__c = :enrollmentId
              AND Lesson__c IN :lessonIds
        ];
    }

    /**
     * Find existing progress record for a specific enrollment and lesson
     * Returns null if not found
     */
    public static Progress__c findProgress(Id enrollmentId, Id lessonId) {
        if (enrollmentId == null || lessonId == null) {
            return null;
        }

        List<Progress__c> progressRecords = [
            SELECT Id, Status__c, Started_On__c, Completed_On__c
            FROM Progress__c
            WHERE Enrollment__c = :enrollmentId
              AND Lesson__c = :lessonId
            LIMIT 1
        ];

        return progressRecords.isEmpty() ? null : progressRecords[0];
    }
}