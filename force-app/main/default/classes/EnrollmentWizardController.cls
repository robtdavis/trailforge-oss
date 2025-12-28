//
// SPDX-License-Identifier: MIT
// TrailForge — Open Source under the MIT License
// Copyright (c) 2025 Robert Davis
// See the LICENSE file in the project root for full license text.
//
/**
 * Controller for the Enrollment Wizard LWC
 * Provides methods to search contacts, courses, and bulk create enrollments
 * 
 * Usage:
 *   - Add trailforgeEnrollmentWizard LWC to a Lightning App Page
 *   - Required permissions: Contact (Read), Account (Read), Course__c (Read), Enrollment__c (Create/Read)
 */
public with sharing class EnrollmentWizardController {

    // ========================================================================
    // CONTACT RETRIEVAL
    // ========================================================================

    /**
     * Get contacts for a specific Account
     * Limited to prevent loading entire org's contacts
     * 
     * @param accountId The Account ID to get contacts for
     * @param limitSize Maximum number of contacts to return (default 200)
     * @return List of Contact records with Id, Name, Email, Title, AccountId
     */
    @AuraEnabled(cacheable=true)
    public static List<Contact> getContactsByAccount(Id accountId, Integer limitSize) {
        if (accountId == null) {
            return new List<Contact>();
        }
        
        Integer queryLimit = (limitSize != null && limitSize > 0) ? limitSize : 200;
        // Cap at 500 to prevent excessive data transfer
        if (queryLimit > 500) {
            queryLimit = 500;
        }
        
        return [
            SELECT Id, Name, Email, Title, AccountId
            FROM Contact
            WHERE AccountId = :accountId
            ORDER BY Name ASC
            LIMIT :queryLimit
        ];
    }

    /**
     * Get total count of contacts for an Account
     * Used to display "Showing X of Y" message
     * 
     * @param accountId The Account ID to count contacts for
     * @return Total number of contacts for the account
     */
    @AuraEnabled(cacheable=true)
    public static Integer getContactCountForAccount(Id accountId) {
        if (accountId == null) {
            return 0;
        }
        
        return [SELECT COUNT() FROM Contact WHERE AccountId = :accountId];
    }

    /**
     * Search contacts globally using SOSL
     * Falls back to SOQL LIKE if SOSL returns no results
     * 
     * @param searchTerm The search term (minimum 2 characters)
     * @param limitSize Maximum number of contacts to return (default 50)
     * @return List of Contact records matching the search
     */
    @AuraEnabled
    public static List<Contact> searchContactsGlobal(String searchTerm, Integer limitSize) {
        if (String.isBlank(searchTerm) || searchTerm.trim().length() < 2) {
            return new List<Contact>();
        }
        
        Integer queryLimit = (limitSize != null && limitSize > 0) ? limitSize : 50;
        if (queryLimit > 100) {
            queryLimit = 100;
        }
        
        String sanitizedTerm = String.escapeSingleQuotes(searchTerm.trim());
        
        // Try SOSL first for better fuzzy matching
        List<List<SObject>> soslResults = [
            FIND :sanitizedTerm IN ALL FIELDS
            RETURNING Contact(Id, Name, Email, Title, AccountId, Account.Name 
                             ORDER BY Name ASC LIMIT :queryLimit)
        ];
        
        List<Contact> contacts = (List<Contact>) soslResults[0];
        
        // Fall back to SOQL LIKE if SOSL returns nothing
        if (contacts.isEmpty()) {
            String likePattern = '%' + sanitizedTerm + '%';
            contacts = [
                SELECT Id, Name, Email, Title, AccountId, Account.Name
                FROM Contact
                WHERE Name LIKE :likePattern
                   OR Email LIKE :likePattern
                ORDER BY Name ASC
                LIMIT :queryLimit
            ];
        }
        
        return contacts;
    }

    // ========================================================================
    // COURSE RETRIEVAL
    // ========================================================================

    /**
     * Search courses by name
     * Returns active, non-archived courses only
     * 
     * @param searchTerm The search term
     * @param limitSize Maximum number of courses to return (default 25)
     * @return List of Course__c records matching the search
     */
    @AuraEnabled(cacheable=true)
    public static List<Course__c> searchCourses(String searchTerm, Integer limitSize) {
        Integer queryLimit = (limitSize != null && limitSize > 0) ? limitSize : 25;
        
        if (String.isBlank(searchTerm)) {
            // Return recent active courses if no search term
            return [
                SELECT Id, Name, Description__c, Difficulty__c, Estimated_Duration__c
                FROM Course__c
                WHERE Active__c = true
                  AND Archived__c = false
                ORDER BY Name ASC
                LIMIT :queryLimit
            ];
        }
        
        String likePattern = '%' + String.escapeSingleQuotes(searchTerm.trim()) + '%';
        
        return [
            SELECT Id, Name, Description__c, Difficulty__c, Estimated_Duration__c
            FROM Course__c
            WHERE Name LIKE :likePattern
              AND Active__c = true
              AND Archived__c = false
            ORDER BY Name ASC
            LIMIT :queryLimit
        ];
    }

    /**
     * Get a single course by ID
     * 
     * @param courseId The Course ID
     * @return Course__c record or null if not found
     */
    @AuraEnabled(cacheable=true)
    public static Course__c getCourseById(Id courseId) {
        if (courseId == null) {
            return null;
        }
        
        List<Course__c> courses = [
            SELECT Id, Name, Description__c, Difficulty__c, Estimated_Duration__c
            FROM Course__c
            WHERE Id = :courseId
            LIMIT 1
        ];
        
        return courses.isEmpty() ? null : courses[0];
    }

    // ========================================================================
    // ENROLLMENT CREATION
    // ========================================================================

    /**
     * Bulk enroll contacts into a course
     * Implements dedupe logic to skip contacts already enrolled
     * Uses Unique_Key__c field for duplicate detection
     * 
     * @param courseId The Course to enroll contacts in
     * @param contactIds List of Contact IDs to enroll
     * @return BulkEnrollmentResultDTO with counts and per-contact results
     */
    @AuraEnabled
    public static BulkEnrollmentResultDTO enrollContacts(Id courseId, List<Id> contactIds) {
        BulkEnrollmentResultDTO result = new BulkEnrollmentResultDTO();
        result.createdCount = 0;
        result.skippedCount = 0;
        result.failedCount = 0;
        result.contactResults = new List<ContactEnrollmentResult>();
        
        // Validate inputs
        if (courseId == null) {
            throw new AuraHandledException('Course ID is required');
        }
        if (contactIds == null || contactIds.isEmpty()) {
            throw new AuraHandledException('At least one Contact is required');
        }
        
        // Remove nulls and duplicates from contact list
        Set<Id> uniqueContactIds = new Set<Id>();
        for (Id cId : contactIds) {
            if (cId != null) {
                uniqueContactIds.add(cId);
            }
        }
        
        if (uniqueContactIds.isEmpty()) {
            throw new AuraHandledException('No valid Contact IDs provided');
        }
        
        // Verify course exists and is active
        List<Course__c> courses = [
            SELECT Id, Name, Active__c, Archived__c
            FROM Course__c
            WHERE Id = :courseId
            LIMIT 1
        ];
        
        if (courses.isEmpty()) {
            throw new AuraHandledException('Course not found');
        }
        
        Course__c course = courses[0];
        if (course.Archived__c == true) {
            throw new AuraHandledException('Cannot enroll in an archived course');
        }
        
        // Get contact names for result details
        Map<Id, Contact> contactsMap = new Map<Id, Contact>([
            SELECT Id, Name, AccountId
            FROM Contact
            WHERE Id IN :uniqueContactIds
        ]);
        
        // Find existing enrollments for these contacts in this course
        Set<Id> alreadyEnrolledContactIds = new Set<Id>();
        for (Enrollment__c existing : [
            SELECT Id, Contact__c
            FROM Enrollment__c
            WHERE Course__c = :courseId
              AND Contact__c IN :uniqueContactIds
        ]) {
            alreadyEnrolledContactIds.add(existing.Contact__c);
        }
        
        // Build list of new enrollments to create
        List<Enrollment__c> enrollmentsToCreate = new List<Enrollment__c>();
        
        for (Id contactId : uniqueContactIds) {
            Contact c = contactsMap.get(contactId);
            ContactEnrollmentResult contactResult = new ContactEnrollmentResult();
            contactResult.contactId = contactId;
            contactResult.contactName = c != null ? c.Name : 'Unknown';
            
            if (alreadyEnrolledContactIds.contains(contactId)) {
                // Already enrolled - skip
                contactResult.status = 'Skipped';
                contactResult.message = 'Already enrolled';
                result.skippedCount++;
            } else {
                // Create new enrollment
                Enrollment__c enrollment = new Enrollment__c();
                enrollment.Contact__c = contactId;
                enrollment.Course__c = courseId;
                enrollment.Status__c = 'Not Started';
                enrollment.Progress_Percentage__c = 0;
                enrollment.Enrollment_Date__c = Date.today();
                // Unique_Key__c is set by workflow/flow, but we can set it here too
                enrollment.Unique_Key__c = String.valueOf(contactId) + '_' + String.valueOf(courseId);
                
                enrollmentsToCreate.add(enrollment);
                contactResult.status = 'Pending';
            }
            
            result.contactResults.add(contactResult);
        }
        
        // Insert new enrollments
        if (!enrollmentsToCreate.isEmpty()) {
            try {
                // Apply field-level security before DML
                SObjectAccessDecision securityDecision = Security.stripInaccessible(
                    AccessType.CREATABLE, 
                    enrollmentsToCreate
                );
                List<Enrollment__c> sanitizedEnrollments = (List<Enrollment__c>) securityDecision.getRecords();
                
                // Check if security stripped required fields (Contact__c or Course__c)
                // If so, mark those records as failed
                Set<String> strippedFields = securityDecision.getRemovedFields().get('Enrollment__c');
                if (strippedFields != null && (strippedFields.contains('Contact__c') || strippedFields.contains('Course__c'))) {
                    // Critical fields were stripped - fail all pending enrollments
                    for (ContactEnrollmentResult cr : result.contactResults) {
                        if (cr.status == 'Pending') {
                            cr.status = 'Failed';
                            cr.message = 'Insufficient field-level access to create enrollment';
                            result.failedCount++;
                        }
                    }
                    result.success = false;
                    result.courseName = course.Name;
                    return result;
                }
                
                // Use Database.insert to handle partial failures gracefully
                Database.SaveResult[] saveResults = Database.insert(sanitizedEnrollments, false);
                
                // Map results back to contact results
                Integer insertIndex = 0;
                for (ContactEnrollmentResult cr : result.contactResults) {
                    if (cr.status == 'Pending') {
                        Database.SaveResult sr = saveResults[insertIndex];
                        if (sr.isSuccess()) {
                            cr.status = 'Created';
                            cr.enrollmentId = sr.getId();
                            result.createdCount++;
                        } else {
                            cr.status = 'Failed';
                            cr.message = sr.getErrors()[0].getMessage();
                            result.failedCount++;
                        }
                        insertIndex++;
                    }
                }
                
            } catch (Exception e) {
                throw new AuraHandledException('Error creating enrollments: ' + e.getMessage());
            }
        }
        
        result.courseName = course.Name;
        result.success = result.failedCount == 0;
        
        return result;
    }

    // ========================================================================
    // DTO CLASSES
    // ========================================================================

    /**
     * Result DTO for bulk enrollment operation
     */
    public class BulkEnrollmentResultDTO {
        @AuraEnabled public Boolean success;
        @AuraEnabled public Integer createdCount;
        @AuraEnabled public Integer skippedCount;
        @AuraEnabled public Integer failedCount;
        @AuraEnabled public String courseName;
        @AuraEnabled public List<ContactEnrollmentResult> contactResults;
    }

    /**
     * Per-contact result for enrollment operation
     */
    public class ContactEnrollmentResult {
        @AuraEnabled public Id contactId;
        @AuraEnabled public String contactName;
        @AuraEnabled public String status; // 'Created', 'Skipped', 'Failed'
        @AuraEnabled public String message;
        @AuraEnabled public Id enrollmentId;
    }
}
