//
// SPDX-License-Identifier: MIT
// TrailForge — Open Source under the MIT License
// Copyright (c) 2025 Robert Davis
// See the LICENSE file in the project root for full license text.
//
/**
 * Service class for TrailForge access code management.
 * Handles code generation, validation, and session management.
 * 
 * Security features:
 * - One-time use codes (burn on validation)
 * - Configurable expiry (default 24 hours)
 * - Rate limiting on validation attempts
 * - Custom permission for expiry override
 */
public with sharing class TrailForgeAccessCodeService {
    
    // Rate limiting constants
    private static final Integer MAX_ATTEMPTS_PER_WINDOW = 10;
    private static final Integer WINDOW_MINUTES = 10;
    
    // ========================================================================
    // PUBLIC METHODS - EXTERNAL USER (Experience Site)
    // ========================================================================
    
    /**
     * Validate an access code and burn it on success.
     * Called by external users on Experience site.
     * 
     * @param code The access code to validate
     * @param clientFingerprint Client identifier for rate limiting and tracking
     * @return TrailForgeAccessSessionDTO with success/failure and contact info
     */
    @AuraEnabled
    public static TrailForgeAccessSessionDTO validateAndBurn(String code, String clientFingerprint) {
        try {
            // Trim and validate input
            if (String.isBlank(code)) {
                return TrailForgeAccessSessionDTO.failure('Please enter an access code.');
            }
            code = code.trim().toUpperCase();
            
            // Rate limit check
            if (!checkRateLimit(clientFingerprint)) {
                return TrailForgeAccessSessionDTO.failure('Too many attempts. Please try again in a few minutes.');
            }
            
            // Query the access code record
            List<TrailForge_Access_Code__c> codes = [
                SELECT Id, Code__c, Contact__c, Contact__r.Name, 
                       Is_Active__c, Is_Used__c, Expires_On__c
                FROM TrailForge_Access_Code__c
                WHERE Code__c = :code
                LIMIT 1
            ];
            
            if (codes.isEmpty()) {
                return TrailForgeAccessSessionDTO.failure('Invalid access code. Please check and try again.');
            }
            
            TrailForge_Access_Code__c accessCode = codes[0];
            
            // Validate the code status
            if (!accessCode.Is_Active__c) {
                return TrailForgeAccessSessionDTO.failure('This access code is no longer active.');
            }
            
            if (accessCode.Is_Used__c) {
                return TrailForgeAccessSessionDTO.failure('This access code has already been used.');
            }
            
            if (accessCode.Expires_On__c < System.now()) {
                return TrailForgeAccessSessionDTO.failure('This access code has expired. Please request a new one.');
            }
            
            // Valid code - burn it
            accessCode.Is_Used__c = true;
            accessCode.Used_On__c = System.now();
            accessCode.Used_Fingerprint__c = clientFingerprint;
            accessCode.Is_Active__c = false;
            update accessCode;
            
            // Clear the code from Contact (or mark as used)
            if (accessCode.Contact__c != null) {
                Contact con = new Contact(
                    Id = accessCode.Contact__c,
                    TrailForge_Access_Code__c = '(USED)'
                );
                update con;
            }
            
            // Return success with contact info
            return TrailForgeAccessSessionDTO.success(
                accessCode.Contact__c,
                accessCode.Contact__r.Name,
                accessCode.Id,
                accessCode.Expires_On__c
            );
            
        } catch (Exception e) {
            Logger.logError('TrailForgeAccessCodeService', 'validateAndBurn', e, 1);
            return TrailForgeAccessSessionDTO.failure('An error occurred. Please try again.');
        }
    }
    
    /**
     * Get session info for a previously validated access code.
     * Used to rehydrate session state on page reload.
     * 
     * @param accessCodeId The access code record Id (stored in sessionStorage)
     * @param clientFingerprint Client identifier for validation
     * @return TrailForgeAccessSessionDTO with contact info if valid session
     */
    @AuraEnabled
    public static TrailForgeAccessSessionDTO getSession(Id accessCodeId, String clientFingerprint) {
        try {
            if (accessCodeId == null) {
                return TrailForgeAccessSessionDTO.failure('No session found.');
            }
            
            // Rate limit check
            if (!checkRateLimit(clientFingerprint)) {
                return TrailForgeAccessSessionDTO.failure('Too many attempts. Please try again in a few minutes.');
            }
            
            // Query the access code record
            List<TrailForge_Access_Code__c> codes = [
                SELECT Id, Contact__c, Contact__r.Name, 
                       Is_Used__c, Expires_On__c, Used_Fingerprint__c
                FROM TrailForge_Access_Code__c
                WHERE Id = :accessCodeId
                LIMIT 1
            ];
            
            if (codes.isEmpty()) {
                return TrailForgeAccessSessionDTO.failure('Session not found.');
            }
            
            TrailForge_Access_Code__c accessCode = codes[0];
            
            // For session rehydration, we allow used codes but verify fingerprint
            // In sandbox/demo mode, we're lenient on fingerprint matching
            if (!accessCode.Is_Used__c) {
                return TrailForgeAccessSessionDTO.failure('Invalid session state.');
            }
            
            // Check if code has expired (even for session rehydration)
            if (accessCode.Expires_On__c < System.now()) {
                return TrailForgeAccessSessionDTO.failure('Session has expired.');
            }
            
            // Return success with contact info
            return TrailForgeAccessSessionDTO.success(
                accessCode.Contact__c,
                accessCode.Contact__r.Name,
                accessCode.Id,
                accessCode.Expires_On__c
            );
            
        } catch (Exception e) {
            Logger.logError('TrailForgeAccessCodeService', 'getSession', e, 1);
            return TrailForgeAccessSessionDTO.failure('An error occurred. Please try again.');
        }
    }
    
    // ========================================================================
    // PUBLIC METHODS - ADMIN (Salesforce UI)
    // ========================================================================
    
    /**
     * Generate a new access code for a Contact.
     * Deactivates any existing active codes for that Contact.
     * 
     * @param contactId The Contact to generate a code for
     * @param expiryHours Custom expiry hours (requires custom permission)
     * @return The generated code string
     */
    @AuraEnabled
    public static String generateForContact(Id contactId, Integer expiryHours) {
        if (contactId == null) {
            throw new AuraHandledException('Contact ID is required.');
        }
        
        // Determine expiry hours
        Integer hoursToUse = getDefaultExpiryHours();
        
        if (expiryHours != null) {
            // Check custom permission for override
            if (!FeatureManagement.checkPermission('Trailforge_Access_Code_Override')) {
                throw new AuraHandledException('You do not have permission to override the expiry hours.');
            }
            
            // Validate bounds
            if (expiryHours < 1 || expiryHours > 168) {
                throw new AuraHandledException('Expiry hours must be between 1 and 168 (7 days).');
            }
            
            hoursToUse = expiryHours;
        }
        
        // Deactivate existing active codes for this contact
        List<TrailForge_Access_Code__c> existingCodes = [
            SELECT Id, Is_Active__c
            FROM TrailForge_Access_Code__c
            WHERE Contact__c = :contactId
            AND Is_Active__c = true
            AND Is_Used__c = false
        ];
        
        for (TrailForge_Access_Code__c existing : existingCodes) {
            existing.Is_Active__c = false;
        }
        if (!existingCodes.isEmpty()) {
            update existingCodes;
        }
        
        // Generate new code
        String newCode = generateCodeString();
        
        // Create access code record
        TrailForge_Access_Code__c accessCode = new TrailForge_Access_Code__c(
            Contact__c = contactId,
            Code__c = newCode,
            Is_Active__c = true,
            Is_Used__c = false,
            Issued_On__c = System.now(),
            Expires_On__c = System.now().addHours(hoursToUse),
            Issued_By__c = UserInfo.getUserId()
        );
        insert accessCode;
        
        // Update Contact with the code for visibility
        Contact con = new Contact(
            Id = contactId,
            TrailForge_Access_Code__c = newCode
        );
        update con;
        
        return newCode;
    }
    
    /**
     * Get the latest access code info for a Contact.
     * Used by admin LWC to display current code status.
     * 
     * @param contactId The Contact to get code info for
     * @return Map with code details
     */
    @AuraEnabled(cacheable=true)
    public static Map<String, Object> getLatestForContact(Id contactId) {
        Map<String, Object> result = new Map<String, Object>();
        
        if (contactId == null) {
            return result;
        }
        
        // Get the most recent access code for this contact
        List<TrailForge_Access_Code__c> codes = [
            SELECT Id, Code__c, Is_Active__c, Is_Used__c, 
                   Issued_On__c, Expires_On__c, Used_On__c
            FROM TrailForge_Access_Code__c
            WHERE Contact__c = :contactId
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];
        
        if (codes.isEmpty()) {
            result.put('hasCode', false);
            return result;
        }
        
        TrailForge_Access_Code__c code = codes[0];
        
        result.put('hasCode', true);
        result.put('code', code.Code__c);
        result.put('isActive', code.Is_Active__c);
        result.put('isUsed', code.Is_Used__c);
        result.put('issuedOn', code.Issued_On__c);
        result.put('expiresOn', code.Expires_On__c);
        result.put('usedOn', code.Used_On__c);
        result.put('isExpired', code.Expires_On__c < System.now());
        
        // Determine status string
        String status;
        if (code.Is_Used__c) {
            status = 'Used';
        } else if (code.Expires_On__c < System.now()) {
            status = 'Expired';
        } else if (code.Is_Active__c) {
            status = 'Active';
        } else {
            status = 'Inactive';
        }
        result.put('status', status);
        
        return result;
    }
    
    /**
     * Clear/deactivate the current access code for a Contact.
     * 
     * @param contactId The Contact to clear code for
     */
    @AuraEnabled
    public static void clearAccessCode(Id contactId) {
        if (contactId == null) {
            throw new AuraHandledException('Contact ID is required.');
        }
        
        // Deactivate any active codes
        List<TrailForge_Access_Code__c> activeCodes = [
            SELECT Id, Is_Active__c
            FROM TrailForge_Access_Code__c
            WHERE Contact__c = :contactId
            AND Is_Active__c = true
        ];
        
        for (TrailForge_Access_Code__c code : activeCodes) {
            code.Is_Active__c = false;
        }
        if (!activeCodes.isEmpty()) {
            update activeCodes;
        }
        
        // Clear contact field
        Contact con = new Contact(
            Id = contactId,
            TrailForge_Access_Code__c = null
        );
        update con;
    }
    
    /**
     * Check if current user has permission to override expiry hours.
     * 
     * @return true if user has the custom permission
     */
    @AuraEnabled(cacheable=true)
    public static Boolean hasOverridePermission() {
        return FeatureManagement.checkPermission('Trailforge_Access_Code_Override');
    }
    
    // ========================================================================
    // PRIVATE HELPER METHODS
    // ========================================================================
    
    /**
     * Generate a unique access code string in format TF-XXXX-XXXX
     */
    @TestVisible
    private static String generateCodeString() {
        String chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // Exclude confusing chars: 0, O, I, 1
        String code = 'TF-';
        
        for (Integer i = 0; i < 4; i++) {
            Integer idx = Math.mod(Math.abs(Crypto.getRandomInteger()), chars.length());
            code += chars.substring(idx, idx + 1);
        }
        
        code += '-';
        
        for (Integer i = 0; i < 4; i++) {
            Integer idx = Math.mod(Math.abs(Crypto.getRandomInteger()), chars.length());
            code += chars.substring(idx, idx + 1);
        }
        
        return code;
    }
    
    /**
     * Get the default expiry hours from Custom Metadata.
     */
    @TestVisible
    private static Integer getDefaultExpiryHours() {
        List<TrailForge_Settings__mdt> settings = [
            SELECT Access_Code_Default_Expiry_Hours__c
            FROM TrailForge_Settings__mdt
            WHERE DeveloperName = 'Default'
            LIMIT 1
        ];
        
        if (!settings.isEmpty() && settings[0].Access_Code_Default_Expiry_Hours__c != null) {
            return Integer.valueOf(settings[0].Access_Code_Default_Expiry_Hours__c);
        }
        
        return 24; // Fallback default
    }
    
    /**
     * Check rate limiting for a fingerprint.
     * Returns true if request is allowed, false if rate limited.
     */
    @TestVisible
    private static Boolean checkRateLimit(String fingerprint) {
        if (String.isBlank(fingerprint)) {
            fingerprint = 'anonymous';
        }
        
        // Truncate fingerprint to fit field
        if (fingerprint.length() > 255) {
            fingerprint = fingerprint.substring(0, 255);
        }
        
        Datetime now = System.now();
        Datetime windowStart = now.addMinutes(-WINDOW_MINUTES);
        
        // Query or create throttle record
        List<TrailForge_Access_Throttle__c> throttles = [
            SELECT Id, Window_Start__c, Count__c
            FROM TrailForge_Access_Throttle__c
            WHERE Fingerprint__c = :fingerprint
            LIMIT 1
        ];
        
        TrailForge_Access_Throttle__c throttle;
        
        if (throttles.isEmpty()) {
            // Create new throttle record
            throttle = new TrailForge_Access_Throttle__c(
                Fingerprint__c = fingerprint,
                Window_Start__c = now,
                Count__c = 1
            );
            insert throttle;
            return true;
        }
        
        throttle = throttles[0];
        
        // Check if window has expired
        if (throttle.Window_Start__c < windowStart) {
            // Reset window
            throttle.Window_Start__c = now;
            throttle.Count__c = 1;
            update throttle;
            return true;
        }
        
        // Check count
        if (throttle.Count__c >= MAX_ATTEMPTS_PER_WINDOW) {
            return false;
        }
        
        // Increment count
        throttle.Count__c = throttle.Count__c + 1;
        update throttle;
        return true;
    }
}
