/**
 * Guest-accessible version of ContentRenderingService.
 * Runs WITHOUT SHARING to allow guest users to access Lesson content.
 * 
 * Content rendering and sanitization service for TrailForge lessons
 * Prevents XSS attacks by sanitizing HTML content
 * Validates external URLs against whitelist
 */
public without sharing class ContentRenderingGuestService {
    
    /**
     * Get sanitized lesson content safe for display in LWC
     * 
     * @param lessonId ID of the lesson to render
     * @return Sanitized content DTO
     */
    @AuraEnabled
    public static ContentRenderingService.ContentDTO getSanitizedContent(Id lessonId) {
        if (lessonId == null) {
            throw new AuraHandledException('Lesson ID is required');
        }
        
        try {
            // Query lesson with content fields
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
            
            ContentRenderingService.ContentDTO dto = new ContentRenderingService.ContentDTO();
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
                dto.sanitizedContent = contentBody;
                dto.isMarkdown = true;
            } else if (lesson.Content_Type__c == 'URL' || lesson.Content_Type__c == 'Video') {
                dto.externalUrl = validateAndSanitizeUrl(lesson.External_URL__c);
                dto.isExternal = true;
            } else {
                dto.sanitizedContent = contentBody;
            }
            
            return dto;
            
        } catch (QueryException e) {
            throw new AuraHandledException('Lesson not found');
        } catch (Exception e) {
            System.debug('Error in getSanitizedContent: ' + e.getMessage() + ' - ' + e.getStackTraceString());
            throw new AuraHandledException('Error loading lesson content: ' + e.getMessage());
        }
    }
    
    /**
     * Sanitize HTML content to prevent XSS attacks
     */
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
     */
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
            throw new AuraHandledException('URL domain not allowed: ' + domain);
        }
        
        return url;
    }
    
    /**
     * Extract domain from URL
     */
    private static String extractDomain(String url) {
        String urlWithoutProtocol = url.replaceFirst('(?i)^https?://', '');
        
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
        
        if (domain.startsWithIgnoreCase('www.')) {
            domain = domain.substring(4);
        }
        
        return domain.toLowerCase();
    }
    
    /**
     * Check if domain is in the allowed whitelist
     */
    private static Boolean isAllowedDomain(String domain) {
        List<Allowed_Content_Domain__mdt> allowedDomains = [
            SELECT Domain__c
            FROM Allowed_Content_Domain__mdt
            WHERE Active__c = true
        ];
        
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
}
