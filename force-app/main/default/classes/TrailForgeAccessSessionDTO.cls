//
// SPDX-License-Identifier: MIT
// TrailForge — Open Source under the MIT License
// Copyright (c) 2025 Robert Davis
// See the LICENSE file in the project root for full license text.
//
/**
 * DTO for TrailForge access code session responses.
 * Used to communicate validation results and session state to LWC.
 */
public class TrailForgeAccessSessionDTO {
    @AuraEnabled public Boolean success;
    @AuraEnabled public String message;
    @AuraEnabled public Id contactId;
    @AuraEnabled public String contactName;
    @AuraEnabled public Id accessCodeId;
    @AuraEnabled public Datetime expiresOn;
    
    public TrailForgeAccessSessionDTO() {
        this.success = false;
    }
    
    /**
     * Create a success response
     */
    public static TrailForgeAccessSessionDTO success(
        Id contactId, 
        String contactName, 
        Id accessCodeId, 
        Datetime expiresOn
    ) {
        TrailForgeAccessSessionDTO dto = new TrailForgeAccessSessionDTO();
        dto.success = true;
        dto.message = 'Access granted';
        dto.contactId = contactId;
        dto.contactName = contactName;
        dto.accessCodeId = accessCodeId;
        dto.expiresOn = expiresOn;
        return dto;
    }
    
    /**
     * Create a failure response
     */
    public static TrailForgeAccessSessionDTO failure(String message) {
        TrailForgeAccessSessionDTO dto = new TrailForgeAccessSessionDTO();
        dto.success = false;
        dto.message = message;
        return dto;
    }
}
