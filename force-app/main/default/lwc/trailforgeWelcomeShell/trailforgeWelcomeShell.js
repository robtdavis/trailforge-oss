//
// SPDX-License-Identifier: MIT
// TrailForge — Open Source under the MIT License
// Copyright (c) 2025 Robert Davis
// See the LICENSE file in the project root for full license text.
//
import { LightningElement, api, track } from 'lwc';
import isGuestUser from '@salesforce/user/isGuest';
import prepareLearnerProfile from '@salesforce/apex/TrailForgeWelcomeService.prepareLearnerProfile';
import prepareLearnerProfileGuest from '@salesforce/apex/TrailForgeWelcomeGuestController.prepareLearnerProfile';
import COW_LOGO from '@salesforce/resourceUrl/TrailForgeCowLogo';

// Session storage key used by trailforgeAccessCodeEntry
const SESSION_KEY = 'trailforge_session';

export default class TrailforgeWelcomeShell extends LightningElement {
    // Cow logo URL
    cowLogoUrl = COW_LOGO;
    
    // Receive contactId from parent shell
    @api contactId;
    
    @track isLoading = true;
    @track hasError = false;
    @track isReady = false;
    @track errorMessage;
    @track welcomeContext;
    
    // Track if user is guest
    isGuest = isGuestUser;
    
    // Internal tracking for selected contact (before continue)
    _selectedContactId;
    _accessCodeId;

    connectedCallback() {
        console.log('=== WELCOME SHELL CONNECTED ===');
        console.log('contactId:', this.contactId);
        console.log('isGuest:', this.isGuest);
        
        // For guest users, get accessCodeId from session for security validation
        if (this.isGuest) {
            const sessionData = this.getAccessCodeSession();
            if (sessionData) {
                this._accessCodeId = sessionData.accessCodeId;
                console.log('Guest user - accessCodeId from session:', this._accessCodeId);
            }
        }
        
        try {
            if (this.contactId) {
                this._selectedContactId = this.contactId;
                this.initializeProfile();
            } else {
                // No contactId - show selection UI
                this.isLoading = false;
                console.log('No contactId - isLoading set to false');
            }
        } catch (error) {
            console.error('Error in connectedCallback:', error);
            this.isLoading = false;
            this.hasError = true;
            this.errorMessage = 'Failed to initialize: ' + error.message;
        }
    }
    
    /**
     * Get session data from access code authentication
     */
    getAccessCodeSession() {
        try {
            const sessionJson = sessionStorage.getItem(SESSION_KEY);
            if (sessionJson) {
                return JSON.parse(sessionJson);
            }
        } catch (e) {
            console.error('Error reading access code session:', e);
        }
        return null;
    }

    handleLearnerSelected(event) {
        this._selectedContactId = event.detail.contactId;
        this.initializeProfile();
    }

    handleChangeLearner() {
        // Clear current learner and summary state so we return to selector mode
        this._selectedContactId = null;
        this.welcomeContext = null;
        this.isReady = false;
        this.hasError = false;
        this.isLoading = false;
    }

    initializeProfile() {
        if (!this._selectedContactId) {
            return;
        }

        this.isLoading = true;
        this.hasError = false;
        this.isReady = false;

        // Use guest controller for guest users, regular controller for internal users
        let profilePromise;
        if (this.isGuest) {
            console.log('Using guest controller with contactId:', this._selectedContactId, 'accessCodeId:', this._accessCodeId);
            profilePromise = prepareLearnerProfileGuest({ 
                contactId: this._selectedContactId, 
                accessCodeId: this._accessCodeId 
            });
        } else {
            profilePromise = prepareLearnerProfile({ contactId: this._selectedContactId });
        }

        profilePromise
            .then(result => {
                this.welcomeContext = result;
                this.isLoading = false;
                this.isReady = true;
            })
            .catch(error => {
                this.errorMessage = error.body ? error.body.message : 'An unexpected error occurred';
                this.isLoading = false;
                this.hasError = true;
            });
    }

    get enrollmentCount() {
        return this.welcomeContext ? this.welcomeContext.enrollmentCount : 0;
    }

    get enrollmentCountPlural() {
        return this.enrollmentCount === 1 ? '' : 's';
    }

    get overallProgress() {
        return this.welcomeContext ? this.welcomeContext.overallProgress : 0;
    }

    get primaryCourseName() {
        return this.welcomeContext ? this.welcomeContext.primaryCourseName : null;
    }

    get completedCount() {
        return this.welcomeContext ? this.welcomeContext.completedCount : 0;
    }

    get inProgressCount() {
        return this.welcomeContext ? this.welcomeContext.inProgressCount : 0;
    }

    get notStartedCount() {
        return this.welcomeContext ? this.welcomeContext.notStartedCount : 0;
    }

    handleContinue() {
        // Fire event to parent shell to navigate to My Learning
        const navigateEvent = new CustomEvent('navigatetomylearning', {
            detail: { contactId: this._selectedContactId },
            bubbles: true,
            composed: true
        });
        this.dispatchEvent(navigateEvent);
        console.log(' handleContinue fired navigatetomylearning event ');
    }
    
    get displayContactId() {
        return this._selectedContactId;
    }
}