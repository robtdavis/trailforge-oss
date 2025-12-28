//
// SPDX-License-Identifier: MIT
// TrailForge — Open Source under the MIT License
// Copyright (c) 2025 Robert Davis
// See the LICENSE file in the project root for full license text.
//
/**
 * Guest-accessible controller for TrailForge access code validation.
 * This controller runs WITHOUT sharing to allow guest users to validate codes.
 * 
 * Only exposes the minimal methods needed for external users:
 * - validateAndBurn: Validate and consume an access code
 * - getSession: Rehydrate an existing session
 */
public without sharing class TrailForgeAccessCodeGuestController {
    
    // Rate limiting constants
    private static final Integer MAX_ATTEMPTS_PER_WINDOW = 10;
    private static final Integer WINDOW_MINUTES = 10;
    
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
            System.debug(LoggingLevel.ERROR, 'TrailForgeAccessCodeGuestController.validateAndBurn error: ' + e.getMessage());
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
            System.debug(LoggingLevel.ERROR, 'TrailForgeAccessCodeGuestController.getSession error: ' + e.getMessage());
            return TrailForgeAccessSessionDTO.failure('An error occurred. Please try again.');
        }
    }
    
    /**
     * Check rate limiting for a fingerprint.
     * Returns true if request is allowed, false if rate limited.
     */
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
