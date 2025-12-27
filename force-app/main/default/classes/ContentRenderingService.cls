/**
 * Content rendering and sanitization service for TrailForge lessons
 * Prevents XSS attacks by sanitizing HTML content
 * Validates external URLs against whitelist
 */
public with sharing class ContentRenderingService {
    
    /**
     * Get sanitized lesson content safe for display in LWC
     * 
     * @param lessonId ID of the lesson to render
     * @return Sanitized content DTO
     */
    @AuraEnabled
    public static ContentDTO getSanitizedContent(Id lessonId) {
        if (lessonId == null) {
            throw new AuraHandledException('Lesson ID is required');
        }
        
        try {
            // Query lesson with content fields
            // Note: Content__c is the main field used by ContentBuilder, Content_Body__c is legacy
            Lesson__c lesson = [
                SELECT Id, 
                       Name,
                       Content_Type__c, 
                       Content__c,
                       Content_Body__c, 
                       External_URL__c,
                       Modal_Size__c,
                       Show_Complete_Button__c
                FROM Lesson__c
                WHERE Id = :lessonId
                LIMIT 1
            ];
            
            ContentDTO dto = new ContentDTO();
            dto.lessonId = lesson.Id;
            dto.lessonName = lesson.Name;
            dto.contentType = lesson.Content_Type__c;
            dto.modalSize = String.isNotBlank(lesson.Modal_Size__c) ? lesson.Modal_Size__c : 'medium';
            dto.showCompleteButton = lesson.Show_Complete_Button__c;
            
            // Use Content__c if populated, fall back to Content_Body__c for backward compatibility
            String contentBody = String.isNotBlank(lesson.Content__c) 
                ? lesson.Content__c 
                : lesson.Content_Body__c;
            
            // Route to appropriate handler based on content type
            if (lesson.Content_Type__c == 'HTML') {
                dto.sanitizedContent = sanitizeHtml(contentBody);
                dto.isHtml = true;
            } else if (lesson.Content_Type__c == 'Markdown') {
                // Future: Convert markdown to HTML
                dto.sanitizedContent = contentBody;
                dto.isMarkdown = true;
            } else if (lesson.Content_Type__c == 'URL' || lesson.Content_Type__c == 'Video') {
                dto.externalUrl = validateAndSanitizeUrl(lesson.External_URL__c);
                dto.isExternal = true;
            } else {
                // Plain text or unknown type
                dto.sanitizedContent = contentBody;
            }
            
            return dto;
            
        } catch (QueryException e) {
            throw new AuraHandledException('Lesson not found');
        } catch (Exception e) {
            Logger.logError('ContentRenderingService', 'getSanitizedContent', e, 1);
            throw new AuraHandledException('Error loading lesson content: ' + e.getMessage());
        }
    }
    
    /**
     * Sanitize HTML content to prevent XSS attacks
     * Removes dangerous tags, attributes, and protocols
     * 
     * @param htmlContent Raw HTML content
     * @return Sanitized HTML safe for display
     */
    @TestVisible
    private static String sanitizeHtml(String htmlContent) {
        if (String.isBlank(htmlContent)) {
            return '';
        }
        
        String sanitized = htmlContent;
        
        // Remove <script> tags and content
        sanitized = sanitized.replaceAll('(?i)<script[^>]*>.*?</script>', '');
        
        // Remove <iframe> tags (prevent clickjacking)
        sanitized = sanitized.replaceAll('(?i)<iframe[^>]*>.*?</iframe>', '');
        
        // Remove <object> and <embed> tags
        sanitized = sanitized.replaceAll('(?i)<object[^>]*>.*?</object>', '');
        sanitized = sanitized.replaceAll('(?i)<embed[^>]*>', '');
        
        // Remove inline event handlers (onclick, onerror, onload, etc.)
        sanitized = sanitized.replaceAll('(?i)\\s*on\\w+\\s*=\\s*["\'][^"\']*["\']', '');
        
        // Remove javascript: protocol from hrefs and srcs
        sanitized = sanitized.replaceAll('(?i)javascript:', '');
        
        // Remove data: protocol (can be used for XSS)
        sanitized = sanitized.replaceAll('(?i)data:', '');
        
        // Remove vbscript: protocol
        sanitized = sanitized.replaceAll('(?i)vbscript:', '');
        
        return sanitized;
    }
    
    /**
     * Validate and sanitize external URLs
     * Checks URL against whitelist of allowed domains
     * 
     * @param url External URL to validate
     * @return Sanitized URL if valid
     * @throws AuraHandledException if URL is invalid or not whitelisted
     */
    @TestVisible
    private static String validateAndSanitizeUrl(String url) {
        if (String.isBlank(url)) {
            return null;
        }
        
        // Basic URL validation
        if (!url.startsWithIgnoreCase('http://') && !url.startsWithIgnoreCase('https://')) {
            throw new AuraHandledException('URL must use HTTP or HTTPS protocol');
        }
        
        // Extract domain from URL
        String domain = extractDomain(url);
        
        // Check against whitelist
        if (!isAllowedDomain(domain)) {
            Logger.logInfo(
                'ContentRenderingService',
                'validateAndSanitizeUrl',
                'Blocked non-whitelisted domain: ' + domain
            );
            throw new AuraHandledException('URL domain not allowed: ' + domain);
        }
        
        return url;
    }
    
    /**
     * Extract domain from URL
     * 
     * @param url Full URL
     * @return Domain portion (e.g., "youtube.com")
     */
    private static String extractDomain(String url) {
        // Remove protocol
        String urlWithoutProtocol = url.replaceFirst('(?i)^https?://', '');
        
        // Extract domain (everything before first / or ?)
        Integer slashPos = urlWithoutProtocol.indexOf('/');
        Integer queryPos = urlWithoutProtocol.indexOf('?');
        
        Integer endPos = urlWithoutProtocol.length();
        if (slashPos > 0) {
            endPos = Math.min(endPos, slashPos);
        }
        if (queryPos > 0) {
            endPos = Math.min(endPos, queryPos);
        }
        
        String domain = urlWithoutProtocol.substring(0, endPos);
        
        // Remove www. prefix
        if (domain.startsWithIgnoreCase('www.')) {
            domain = domain.substring(4);
        }
        
        return domain.toLowerCase();
    }
    
    /**
     * Check if domain is in the allowed whitelist
     * Reads from Allowed_Content_Domain__mdt for admin configurability
     * Falls back to minimal safe defaults if CMDT is empty
     * 
     * @param domain Domain to check
     * @return true if allowed
     */
    private static Boolean isAllowedDomain(String domain) {
        // Query Custom Metadata for allowed domains
        List<Allowed_Content_Domain__mdt> allowedDomains = [
            SELECT Domain__c
            FROM Allowed_Content_Domain__mdt
            WHERE Active__c = true
        ];
        
        // Build set of allowed domains from CMDT
        Set<String> allowedDomainSet = new Set<String>();
        for (Allowed_Content_Domain__mdt cmd : allowedDomains) {
            if (String.isNotBlank(cmd.Domain__c)) {
                allowedDomainSet.add(cmd.Domain__c.toLowerCase());
            }
        }
        
        // Fallback: If CMDT is empty, use minimal safe defaults
        if (allowedDomainSet.isEmpty()) {
            allowedDomainSet = new Set<String>{
                'salesforce.com',
                'force.com'
            };
        }
        
        return allowedDomainSet.contains(domain);
    }
    
    // ========================================================================
    // DTO CLASSES
    // ========================================================================
    
    public class ContentDTO {
        @AuraEnabled public Id lessonId;
        @AuraEnabled public String lessonName;
        @AuraEnabled public String contentType;
        @AuraEnabled public String sanitizedContent;
        @AuraEnabled public String externalUrl;
        @AuraEnabled public String modalSize;
        @AuraEnabled public Boolean isHtml;
        @AuraEnabled public Boolean isMarkdown;
        @AuraEnabled public Boolean isExternal;
        @AuraEnabled public Boolean showCompleteButton;
        
        public ContentDTO() {
            this.isHtml = false;
            this.isMarkdown = false;
            this.isExternal = false;
            this.modalSize = 'medium';
            this.showCompleteButton = true; // Default to showing button
        }
    }
}