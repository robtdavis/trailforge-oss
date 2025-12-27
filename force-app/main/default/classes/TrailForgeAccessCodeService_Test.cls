/**
 * Test class for TrailForgeAccessCodeService.
 * Tests code generation, validation, rate limiting, and permission enforcement.
 */
@IsTest
private class TrailForgeAccessCodeService_Test {
    
    @TestSetup
    static void setup() {
        // Create test account and contact
        Account acc = new Account(Name = 'Test Account');
        insert acc;
        
        Contact con = new Contact(
            FirstName = 'Test',
            LastName = 'Learner',
            Email = 'test.learner@example.com',
            AccountId = acc.Id
        );
        insert con;
    }
    
    /**
     * Test generating a code with default expiry
     */
    @IsTest
    static void testGenerateForContact_DefaultExpiry() {
        Contact con = [SELECT Id FROM Contact LIMIT 1];
        
        Test.startTest();
        String code = TrailForgeAccessCodeService.generateForContact(con.Id, null);
        Test.stopTest();
        
        // Verify code format
        System.assertNotEquals(null, code, 'Code should be generated');
        System.assert(code.startsWith('TF-'), 'Code should start with TF-');
        System.assertEquals(12, code.length(), 'Code should be 12 characters (TF-XXXX-XXXX)');
        
        // Verify access code record was created
        TrailForge_Access_Code__c accessCode = [
            SELECT Id, Code__c, Contact__c, Is_Active__c, Is_Used__c, Expires_On__c
            FROM TrailForge_Access_Code__c
            WHERE Contact__c = :con.Id
            LIMIT 1
        ];
        
        System.assertEquals(code, accessCode.Code__c, 'Code should match');
        System.assertEquals(true, accessCode.Is_Active__c, 'Code should be active');
        System.assertEquals(false, accessCode.Is_Used__c, 'Code should not be used');
        System.assert(accessCode.Expires_On__c > System.now(), 'Code should expire in the future');
        
        // Verify contact field was updated
        Contact updatedCon = [SELECT TrailForge_Access_Code__c FROM Contact WHERE Id = :con.Id];
        System.assertEquals(code, updatedCon.TrailForge_Access_Code__c, 'Contact should have code');
    }
    
    /**
     * Test that override without permission is denied
     */
    @IsTest
    static void testGenerateForContact_OverrideDenied() {
        Contact con = [SELECT Id FROM Contact LIMIT 1];
        
        // Regular user without custom permission
        Test.startTest();
        try {
            String code = TrailForgeAccessCodeService.generateForContact(con.Id, 48);
            System.assert(false, 'Should have thrown exception');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('permission'), 'Should mention permission');
        }
        Test.stopTest();
    }
    
    /**
     * Test that override with invalid bounds is rejected
     */
    @IsTest
    static void testGenerateForContact_OverrideInvalidBounds() {
        Contact con = [SELECT Id FROM Contact LIMIT 1];
        
        // Create a user with the custom permission
        User testUser = createUserWithPermission();
        
        System.runAs(testUser) {
            Test.startTest();
            
            // Test hours too low
            try {
                String code = TrailForgeAccessCodeService.generateForContact(con.Id, 0);
                System.assert(false, 'Should have thrown exception for hours too low');
            } catch (AuraHandledException e) {
                System.assert(e.getMessage().contains('between 1 and 168'), 'Should mention valid range');
            }
            
            // Test hours too high
            try {
                String code = TrailForgeAccessCodeService.generateForContact(con.Id, 200);
                System.assert(false, 'Should have thrown exception for hours too high');
            } catch (AuraHandledException e) {
                System.assert(e.getMessage().contains('between 1 and 168'), 'Should mention valid range');
            }
            
            Test.stopTest();
        }
    }
    
    /**
     * Test that override is allowed with permission and valid bounds
     */
    @IsTest
    static void testGenerateForContact_OverrideAllowed() {
        Contact con = [SELECT Id FROM Contact LIMIT 1];
        
        // Create a user with the custom permission
        User testUser = createUserWithPermission();
        
        System.runAs(testUser) {
            Test.startTest();
            String code = TrailForgeAccessCodeService.generateForContact(con.Id, 72);
            Test.stopTest();
            
            System.assertNotEquals(null, code, 'Code should be generated');
            
            // Verify expiry is approximately 72 hours from now
            TrailForge_Access_Code__c accessCode = [
                SELECT Expires_On__c
                FROM TrailForge_Access_Code__c
                WHERE Contact__c = :con.Id
                AND Code__c = :code
                LIMIT 1
            ];
            
            Datetime expectedExpiry = System.now().addHours(72);
            // Allow 5 minute tolerance for test execution time
            System.assert(
                Math.abs(accessCode.Expires_On__c.getTime() - expectedExpiry.getTime()) < 300000,
                'Expiry should be approximately 72 hours from now'
            );
        }
    }
    
    /**
     * Test successful code validation and burning
     */
    @IsTest
    static void testValidateAndBurn_Success() {
        Contact con = [SELECT Id, Name FROM Contact LIMIT 1];
        
        // Generate a code first
        String code = TrailForgeAccessCodeService.generateForContact(con.Id, null);
        
        Test.startTest();
        TrailForgeAccessSessionDTO result = TrailForgeAccessCodeService.validateAndBurn(code, 'test-fingerprint');
        Test.stopTest();
        
        System.assertEquals(true, result.success, 'Validation should succeed');
        System.assertEquals(con.Id, result.contactId, 'Contact ID should match');
        System.assertNotEquals(null, result.accessCodeId, 'Access code ID should be returned');
        
        // Verify code was burned
        TrailForge_Access_Code__c accessCode = [
            SELECT Is_Active__c, Is_Used__c, Used_On__c, Used_Fingerprint__c
            FROM TrailForge_Access_Code__c
            WHERE Code__c = :code
        ];
        
        System.assertEquals(false, accessCode.Is_Active__c, 'Code should be inactive');
        System.assertEquals(true, accessCode.Is_Used__c, 'Code should be used');
        System.assertNotEquals(null, accessCode.Used_On__c, 'Used timestamp should be set');
        System.assertEquals('test-fingerprint', accessCode.Used_Fingerprint__c, 'Fingerprint should be recorded');
        
        // Verify contact field was updated
        Contact updatedCon = [SELECT TrailForge_Access_Code__c FROM Contact WHERE Id = :con.Id];
        System.assertEquals('(USED)', updatedCon.TrailForge_Access_Code__c, 'Contact code should show used');
    }
    
    /**
     * Test validation of expired code
     */
    @IsTest
    static void testValidateAndBurn_Expired() {
        Contact con = [SELECT Id FROM Contact LIMIT 1];
        
        // Create an expired code directly
        TrailForge_Access_Code__c expiredCode = new TrailForge_Access_Code__c(
            Contact__c = con.Id,
            Code__c = 'TF-EXPR-TEST',
            Is_Active__c = true,
            Is_Used__c = false,
            Issued_On__c = System.now().addDays(-2),
            Expires_On__c = System.now().addHours(-1) // Expired 1 hour ago
        );
        insert expiredCode;
        
        Test.startTest();
        TrailForgeAccessSessionDTO result = TrailForgeAccessCodeService.validateAndBurn('TF-EXPR-TEST', 'test-fingerprint');
        Test.stopTest();
        
        System.assertEquals(false, result.success, 'Validation should fail');
        System.assert(result.message.contains('expired'), 'Should mention expired');
    }
    
    /**
     * Test validation of already used code
     */
    @IsTest
    static void testValidateAndBurn_AlreadyUsed() {
        Contact con = [SELECT Id FROM Contact LIMIT 1];
        
        // Create a used code directly
        TrailForge_Access_Code__c usedCode = new TrailForge_Access_Code__c(
            Contact__c = con.Id,
            Code__c = 'TF-USED-TEST',
            Is_Active__c = false,
            Is_Used__c = true,
            Issued_On__c = System.now().addDays(-1),
            Expires_On__c = System.now().addHours(1),
            Used_On__c = System.now().addHours(-1)
        );
        insert usedCode;
        
        Test.startTest();
        TrailForgeAccessSessionDTO result = TrailForgeAccessCodeService.validateAndBurn('TF-USED-TEST', 'test-fingerprint');
        Test.stopTest();
        
        System.assertEquals(false, result.success, 'Validation should fail');
        System.assert(result.message.contains('already been used'), 'Should mention already used');
    }
    
    /**
     * Test validation of inactive code
     */
    @IsTest
    static void testValidateAndBurn_Inactive() {
        Contact con = [SELECT Id FROM Contact LIMIT 1];
        
        // Create an inactive code directly
        TrailForge_Access_Code__c inactiveCode = new TrailForge_Access_Code__c(
            Contact__c = con.Id,
            Code__c = 'TF-INAC-TEST',
            Is_Active__c = false,
            Is_Used__c = false,
            Issued_On__c = System.now(),
            Expires_On__c = System.now().addHours(24)
        );
        insert inactiveCode;
        
        Test.startTest();
        TrailForgeAccessSessionDTO result = TrailForgeAccessCodeService.validateAndBurn('TF-INAC-TEST', 'test-fingerprint');
        Test.stopTest();
        
        System.assertEquals(false, result.success, 'Validation should fail');
        System.assert(result.message.contains('no longer active'), 'Should mention not active');
    }
    
    /**
     * Test validation of invalid code
     */
    @IsTest
    static void testValidateAndBurn_InvalidCode() {
        Test.startTest();
        TrailForgeAccessSessionDTO result = TrailForgeAccessCodeService.validateAndBurn('TF-DOES-NOTEX', 'test-fingerprint');
        Test.stopTest();
        
        System.assertEquals(false, result.success, 'Validation should fail');
        System.assert(result.message.contains('Invalid'), 'Should mention invalid');
    }
    
    /**
     * Test rate limiting blocks excessive attempts
     */
    @IsTest
    static void testValidateAndBurn_RateLimited() {
        String fingerprint = 'rate-limit-test';
        
        Test.startTest();
        
        // Make 10 attempts (should all be allowed even though they fail)
        for (Integer i = 0; i < 10; i++) {
            TrailForgeAccessCodeService.validateAndBurn('TF-FAKE-' + String.valueOf(i).leftPad(4, '0'), fingerprint);
        }
        
        // 11th attempt should be rate limited
        TrailForgeAccessSessionDTO result = TrailForgeAccessCodeService.validateAndBurn('TF-FAKE-0010', fingerprint);
        
        Test.stopTest();
        
        System.assertEquals(false, result.success, 'Should be rate limited');
        System.assert(result.message.contains('Too many attempts'), 'Should mention rate limiting');
    }
    
    /**
     * Test session rehydration
     */
    @IsTest
    static void testGetSession_Success() {
        Contact con = [SELECT Id FROM Contact LIMIT 1];
        
        // Generate and validate a code
        String code = TrailForgeAccessCodeService.generateForContact(con.Id, null);
        TrailForgeAccessSessionDTO validateResult = TrailForgeAccessCodeService.validateAndBurn(code, 'test-fingerprint');
        
        Test.startTest();
        TrailForgeAccessSessionDTO sessionResult = TrailForgeAccessCodeService.getSession(
            validateResult.accessCodeId, 
            'test-fingerprint'
        );
        Test.stopTest();
        
        System.assertEquals(true, sessionResult.success, 'Session should be valid');
        System.assertEquals(con.Id, sessionResult.contactId, 'Contact ID should match');
    }
    
    /**
     * Test get latest code for contact
     */
    @IsTest
    static void testGetLatestForContact() {
        Contact con = [SELECT Id FROM Contact LIMIT 1];
        
        // Generate a code
        String code = TrailForgeAccessCodeService.generateForContact(con.Id, null);
        
        Test.startTest();
        Map<String, Object> result = TrailForgeAccessCodeService.getLatestForContact(con.Id);
        Test.stopTest();
        
        System.assertEquals(true, result.get('hasCode'), 'Should have a code');
        System.assertEquals(code, result.get('code'), 'Code should match');
        System.assertEquals('Active', result.get('status'), 'Status should be Active');
        System.assertEquals(true, result.get('isActive'), 'Should be active');
        System.assertEquals(false, result.get('isUsed'), 'Should not be used');
        System.assertEquals(false, result.get('isExpired'), 'Should not be expired');
    }
    
    /**
     * Test clear access code
     */
    @IsTest
    static void testClearAccessCode() {
        Contact con = [SELECT Id FROM Contact LIMIT 1];
        
        // Generate a code
        String code = TrailForgeAccessCodeService.generateForContact(con.Id, null);
        
        Test.startTest();
        TrailForgeAccessCodeService.clearAccessCode(con.Id);
        Test.stopTest();
        
        // Verify code was deactivated
        TrailForge_Access_Code__c accessCode = [
            SELECT Is_Active__c
            FROM TrailForge_Access_Code__c
            WHERE Code__c = :code
        ];
        System.assertEquals(false, accessCode.Is_Active__c, 'Code should be inactive');
        
        // Verify contact field was cleared
        Contact updatedCon = [SELECT TrailForge_Access_Code__c FROM Contact WHERE Id = :con.Id];
        System.assertEquals(null, updatedCon.TrailForge_Access_Code__c, 'Contact code should be null');
    }
    
    /**
     * Test generating a new code deactivates the old one
     */
    @IsTest
    static void testGenerateForContact_DeactivatesOldCode() {
        Contact con = [SELECT Id FROM Contact LIMIT 1];
        
        // Generate first code
        String code1 = TrailForgeAccessCodeService.generateForContact(con.Id, null);
        
        Test.startTest();
        // Generate second code
        String code2 = TrailForgeAccessCodeService.generateForContact(con.Id, null);
        Test.stopTest();
        
        System.assertNotEquals(code1, code2, 'Codes should be different');
        
        // Verify first code was deactivated
        TrailForge_Access_Code__c firstCode = [
            SELECT Is_Active__c
            FROM TrailForge_Access_Code__c
            WHERE Code__c = :code1
        ];
        System.assertEquals(false, firstCode.Is_Active__c, 'First code should be inactive');
        
        // Verify second code is active
        TrailForge_Access_Code__c secondCode = [
            SELECT Is_Active__c
            FROM TrailForge_Access_Code__c
            WHERE Code__c = :code2
        ];
        System.assertEquals(true, secondCode.Is_Active__c, 'Second code should be active');
    }
    
    /**
     * Test hasOverridePermission returns false for regular user
     */
    @IsTest
    static void testHasOverridePermission_False() {
        Test.startTest();
        Boolean hasPermission = TrailForgeAccessCodeService.hasOverridePermission();
        Test.stopTest();
        
        // Regular test context user shouldn't have the permission
        System.assertEquals(false, hasPermission, 'Regular user should not have permission');
    }
    
    // ========================================================================
    // HELPER METHODS
    // ========================================================================
    
    /**
     * Create a test user with the custom permission
     */
    private static User createUserWithPermission() {
        Profile p = [SELECT Id FROM Profile WHERE Name = 'System Administrator' LIMIT 1];
        
        String uniqueId = String.valueOf(System.now().getTime());
        User u = new User(
            FirstName = 'Test',
            LastName = 'Admin',
            Email = 'testadmin' + uniqueId + '@example.com',
            Username = 'testadmin' + uniqueId + '@example.com.test',
            Alias = 'tadmin',
            TimeZoneSidKey = 'America/Los_Angeles',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            ProfileId = p.Id,
            LanguageLocaleKey = 'en_US'
        );
        insert u;
        
        // Assign permission set with custom permission
        // Note: In real tests, you'd need a permission set that includes the custom permission
        // For this test, we create a minimal permission set with the custom permission
        PermissionSet ps = new PermissionSet(
            Name = 'TrailForge_Test_Override_' + uniqueId,
            Label = 'TrailForge Test Override'
        );
        insert ps;
        
        // Add custom permission to permission set
        SetupEntityAccess sea = new SetupEntityAccess(
            ParentId = ps.Id,
            SetupEntityId = [SELECT Id FROM CustomPermission WHERE DeveloperName = 'Trailforge_Access_Code_Override' LIMIT 1].Id
        );
        insert sea;
        
        // Assign permission set to user
        PermissionSetAssignment psa = new PermissionSetAssignment(
            AssigneeId = u.Id,
            PermissionSetId = ps.Id
        );
        insert psa;
        
        return u;
    }
}
