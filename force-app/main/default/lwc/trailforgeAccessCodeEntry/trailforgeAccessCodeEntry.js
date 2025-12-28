//
// SPDX-License-Identifier: MIT
// TrailForge — Open Source under the MIT License
// Copyright (c) 2025 Robert Davis
// See the LICENSE file in the project root for full license text.
//
import { LightningElement, track, api } from 'lwc';
import validateAndBurn from '@salesforce/apex/TrailForgeAccessCodeGuestController.validateAndBurn';
import getSession from '@salesforce/apex/TrailForgeAccessCodeGuestController.getSession';

// Session storage key - stores accessCodeId, NOT the raw code
const SESSION_KEY = 'trailforge_session';

export default class TrailforgeAccessCodeEntry extends LightningElement {
    // Configurable navigation URL (set in Experience Builder)
    // Use /s/pagename for Aura sites, /pagename for LWR sites
    @api navigationUrl = '/s/trailforge-welcome';
    
    // Configurable read-only Contact ID (set in Experience Builder)
    // When set, "Continue Read-Only" button appears and uses this Contact
    @api readOnlyContactId = '';
    @api readOnlyContactName = 'Guest Learner';
    
    @track codeInput = '';
    @track isLoading = false;
    @track isAuthenticated = false;
    @track contactId = null;
    @track contactName = '';
    @track accessCodeId = null;
    @track errorMessage = '';
    @track showError = false;
    
    /**
     * Show Read-Only button only if a readOnlyContactId is configured
     */
    get showReadOnlyButton() {
        return this.readOnlyContactId && this.readOnlyContactId.length > 0;
    }

    /**
     * Generate a simple client fingerprint for rate limiting
     */
    get clientFingerprint() {
        // In production, you might use a more sophisticated fingerprinting library
        const nav = window.navigator;
        const screen = window.screen;
        const fingerprint = [
            nav.userAgent,
            nav.language,
            screen.width + 'x' + screen.height,
            new Date().getTimezoneOffset()
        ].join('|');
        
        // Simple hash
        let hash = 0;
        for (let i = 0; i < fingerprint.length; i++) {
            const char = fingerprint.charCodeAt(i);
            hash = ((hash << 5) - hash) + char;
            hash = hash & hash;
        }
        return 'fp_' + Math.abs(hash).toString(16);
    }

    /**
     * Check if submit button should be disabled
     */
    get isSubmitDisabled() {
        return !this.codeInput || this.codeInput.length < 12 || this.isLoading;
    }

    /**
     * Lifecycle hook - check for existing session on load
     */
    connectedCallback() {
        this.checkExistingSession();
    }

    /**
     * Check if there's an existing session in sessionStorage
     */
    async checkExistingSession() {
        try {
            const sessionData = sessionStorage.getItem(SESSION_KEY);
            if (!sessionData) {
                return;
            }

            const parsed = JSON.parse(sessionData);
            if (!parsed.accessCodeId) {
                sessionStorage.removeItem(SESSION_KEY);
                return;
            }

            this.isLoading = true;
            this.accessCodeId = parsed.accessCodeId;

            // Validate session with server
            const result = await getSession({
                accessCodeId: parsed.accessCodeId,
                clientFingerprint: this.clientFingerprint
            });

            if (result.success) {
                this.isAuthenticated = true;
                this.contactId = result.contactId;
                this.contactName = result.contactName;
                this.dispatchSessionEvent(true);
            } else {
                // Session invalid - clear storage
                sessionStorage.removeItem(SESSION_KEY);
                this.accessCodeId = null;
            }
        } catch (error) {
            console.error('Error checking session:', error);
            sessionStorage.removeItem(SESSION_KEY);
        } finally {
            this.isLoading = false;
        }
    }

    /**
     * Handle code input change
     */
    handleCodeChange(event) {
        let value = event.target.value.toUpperCase();
        
        // Auto-format: add dashes if user types without them
        value = value.replace(/[^A-Z0-9-]/g, '');
        
        // Auto-insert dashes for TF-XXXX-XXXX format
        if (value.length === 2 && !value.includes('-')) {
            value = 'TF-';
        } else if (value.length === 7 && value.charAt(6) !== '-') {
            value = value.substring(0, 7) + '-' + value.substring(7);
        }
        
        this.codeInput = value;
        this.hideError();
    }

    /**
     * Handle Enter key press
     */
    handleKeyUp(event) {
        if (event.key === 'Enter' && !this.isSubmitDisabled) {
            this.handleSubmit();
        }
    }

    /**
     * Submit the access code for validation
     */
    async handleSubmit() {
        if (this.isSubmitDisabled) {
            return;
        }

        this.isLoading = true;
        this.hideError();

        try {
            const result = await validateAndBurn({
                code: this.codeInput.trim(),
                clientFingerprint: this.clientFingerprint
            });

            if (result.success) {
                // Store session (NOT the raw code)
                this.accessCodeId = result.accessCodeId;
                this.contactId = result.contactId;
                this.contactName = result.contactName;
                this.isAuthenticated = true;

                // Save to sessionStorage
                sessionStorage.setItem(SESSION_KEY, JSON.stringify({
                    accessCodeId: result.accessCodeId,
                    contactId: result.contactId,
                    contactName: result.contactName
                }));

                // Clear input
                this.codeInput = '';

                // Dispatch event for parent components
                this.dispatchSessionEvent(true);

            } else {
                this.showErrorMessage(result.message || 'Invalid access code.');
            }

        } catch (error) {
            console.error('Error validating code:', error);
            this.showErrorMessage(error.body?.message || 'An error occurred. Please try again.');
        } finally {
            this.isLoading = false;
        }
    }

    /**
     * Clear the current session
     */
    handleClearSession() {
        sessionStorage.removeItem(SESSION_KEY);
        this.isAuthenticated = false;
        this.contactId = null;
        this.contactName = '';
        this.accessCodeId = null;
        this.codeInput = '';
        this.dispatchSessionEvent(false);
    }

    /**
     * Continue to learning (authenticated)
     */
    handleContinue() {
        // Dispatch event for parent components
        this.dispatchEvent(new CustomEvent('continue', {
            detail: {
                authenticated: true,
                contactId: this.contactId,
                contactName: this.contactName,
                accessCodeId: this.accessCodeId
            }
        }));

        // Navigate to the learning page
        this.navigateToLearning();
    }

    /**
     * Continue in read-only mode using the configured readOnlyContactId
     */
    handleContinueReadOnly() {
        if (!this.readOnlyContactId) {
            this.showErrorMessage('Read-only mode is not configured. Please contact your administrator.');
            return;
        }
        
        // Store in session as read-only (no accessCodeId means read-only)
        sessionStorage.setItem(SESSION_KEY, JSON.stringify({
            contactId: this.readOnlyContactId,
            contactName: this.readOnlyContactName,
            accessCodeId: null,
            readOnly: true
        }));
        
        this.dispatchEvent(new CustomEvent('continue', {
            detail: {
                authenticated: false,
                readOnly: true,
                contactId: this.readOnlyContactId,
                contactName: this.readOnlyContactName
            }
        }));

        // Navigate to the learning page
        this.navigateToLearning();
    }

    /**
     * Navigate to the configured learning page
     */
    navigateToLearning() {
        if (this.navigationUrl) {
            // Use direct window.location for guest users (avoids auth redirect)
            window.location.href = this.navigationUrl;
        }
    }

    /**
     * Dispatch session state change event
     */
    dispatchSessionEvent(authenticated) {
        this.dispatchEvent(new CustomEvent('sessionchange', {
            detail: {
                authenticated: authenticated,
                contactId: this.contactId,
                contactName: this.contactName,
                accessCodeId: this.accessCodeId
            }
        }));
    }

    /**
     * Show error message
     */
    showErrorMessage(message) {
        this.errorMessage = message;
        this.showError = true;
    }

    /**
     * Hide error message
     */
    hideError() {
        this.showError = false;
        this.errorMessage = '';
    }
}
