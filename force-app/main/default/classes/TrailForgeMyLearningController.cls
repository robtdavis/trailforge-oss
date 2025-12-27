public with sharing class TrailForgeMyLearningController {
    
    @AuraEnabled(cacheable=false)
    public static List<EnrollmentDTO> getEnrollmentsForContact(Id contactId) {
        try {
            // Validate contactId
            if (contactId == null) {
                throw new AuraHandledException('Contact ID is required.');
            }
            
            // Query enrollments for this contact
            List<Enrollment__c> enrollments = [
                SELECT Id,
                       Course__c,
                       Course__r.Name,
                       Course__r.Description__c,
                       Course__r.Thumbnail_URL__c,
                       Status__c,
                       Progress_Percentage__c
                FROM Enrollment__c
                WHERE Contact__c = :contactId
                ORDER BY CreatedDate DESC
            ];
            
            // Map to DTOs
            List<EnrollmentDTO> dtos = new List<EnrollmentDTO>();
            for (Enrollment__c enrollment : enrollments) {
                EnrollmentDTO dto = new EnrollmentDTO();
                dto.enrollmentId = enrollment.Id;
                dto.courseId = enrollment.Course__c;
                dto.courseName = enrollment.Course__r.Name;
                dto.courseDescription = enrollment.Course__r.Description__c;
                dto.thumbnailUrl = enrollment.Course__r.Thumbnail_URL__c;
                dto.status = enrollment.Status__c;
                dto.progressPercentage = enrollment.Progress_Percentage__c != null 
                    ? enrollment.Progress_Percentage__c 
                    : 0;
                dtos.add(dto);
            }
            
            return dtos;
            
        } catch (Exception e) {
            throw new AuraHandledException('Error retrieving enrollments: ' + e.getMessage());
        }
    }
    
    @AuraEnabled(cacheable=true)
    public static List<EnrollmentDTO> getMyEnrollments() {
        try {
            // Get current user's email
            String userEmail = UserInfo.getUserEmail();
            
            // Find the Contact associated with this user
            List<Contact> contacts = [
                SELECT Id 
                FROM Contact 
                WHERE Email = :userEmail 
                LIMIT 1
            ];
            
            // If no contact found, return empty list
            if (contacts.isEmpty()) {
                return new List<EnrollmentDTO>();
            }
            
            Id contactId = contacts[0].Id;
            
            // Query enrollments for this contact
            List<Enrollment__c> enrollments = [
                SELECT Id,
                       Course__c,
                       Course__r.Name,
                       Course__r.Description__c,
                       Course__r.Thumbnail_URL__c,
                       Status__c,
                       Progress_Percentage__c,
                       Quiz_Passed__c,
                       Quiz_Score__c
                FROM Enrollment__c
                WHERE Contact__c = :contactId
                ORDER BY CreatedDate DESC
            ];
            
            // Map to DTOs
            List<EnrollmentDTO> dtos = new List<EnrollmentDTO>();
            for (Enrollment__c enrollment : enrollments) {
                EnrollmentDTO dto = new EnrollmentDTO();
                dto.enrollmentId = enrollment.Id;
                dto.courseId = enrollment.Course__c;
                dto.courseName = enrollment.Course__r.Name;
                dto.courseDescription = enrollment.Course__r.Description__c;
                dto.thumbnailUrl = enrollment.Course__r.Thumbnail_URL__c;
                dto.status = enrollment.Status__c;
                dto.progressPercentage = enrollment.Progress_Percentage__c != null 
                    ? enrollment.Progress_Percentage__c 
                    : 0;
                dtos.add(dto);
            }
            
            return dtos;
            
        } catch (Exception e) {
            throw new AuraHandledException('Error retrieving enrollments: ' + e.getMessage());
        }
    }
    
    public class EnrollmentDTO {
        @AuraEnabled public Id enrollmentId;
        @AuraEnabled public Id courseId;
        @AuraEnabled public String courseName;
        @AuraEnabled public String courseDescription;
        @AuraEnabled public String thumbnailUrl;
        @AuraEnabled public String status;
        @AuraEnabled public Decimal progressPercentage;
    }
}