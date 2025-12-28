//
// SPDX-License-Identifier: MIT
// TrailForge — Open Source under the MIT License
// Copyright (c) 2025 Robert Davis
// See the LICENSE file in the project root for full license text.
//
import { LightningElement, api, track } from 'lwc';
import isGuestUser from '@salesforce/user/isGuest';
import getEnrollmentsForContact from '@salesforce/apex/TrailForgeMyLearningController.getEnrollmentsForContact';
import getEnrollmentsForContactGuest from '@salesforce/apex/TrailForgeMyLearningGuestController.getEnrollmentsForContact';

export default class MyLearningShell extends LightningElement {
    // Receive contactId from parent shell
    @api contactId;
    
    // Track if user is guest
    isGuest = isGuestUser;
    
    @track enrollments = [];
    @track error;
    @track isLoading = true;

    connectedCallback() {
        console.log('=== myLearningShell.connectedCallback ===');
        console.log('contactId:', this.contactId);
        console.log('isGuest:', this.isGuest);
        console.log('typeof contactId:', typeof this.contactId);
        if (this.contactId) {
            this.loadEnrollments();
        } else {
            this.isLoading = false;
            this.error = 'No learner selected';
        }
    }

    loadEnrollments() {
        console.log('=== myLearningShell.loadEnrollments ===');
        console.log('contactId:', this.contactId);
        if (!this.contactId) {
            console.error('NO CONTACT ID - setting error state');
            this.error = 'No learner selected. Please return to the Welcome screen.';
            this.isLoading = false;
            return;
        }

        this.isLoading = true;
        console.log('Calling getEnrollmentsForContact with contactId:', this.contactId);
        
        // Use guest controller for guest users, regular controller for internal users
        const enrollmentPromise = this.isGuest 
            ? getEnrollmentsForContactGuest({ contactId: this.contactId })
            : getEnrollmentsForContact({ contactId: this.contactId });
        
        enrollmentPromise
            .then(data => {
                console.log('=== getEnrollmentsForContact SUCCESS ===');
                console.log('Data length:', data ? data.length : 0);
                console.log('Data:', JSON.stringify(data));
                this.enrollments = data.map(enrollment => ({
                    ...enrollment,
                    statusVariant: this.getStatusVariant(enrollment.status),
                    truncatedDescription: this.truncateText(enrollment.courseDescription, 120)
                }));
                this.error = undefined;
                this.isLoading = false;
                console.log('isLoading set to false');
            })
            .catch(error => {
                console.error('=== getEnrollmentsForContact ERROR ===');
                console.error('Error:', error);
                console.error('Error body:', error.body);
                console.error('Error message:', error.body ? error.body.message : error.message);
                this.error = error.body ? error.body.message : 'Error loading enrollments';
                this.enrollments = [];
                this.isLoading = false;
                console.log('isLoading set to false (error case)');
            });
    }

    handleImageError(event) {
        // If the image fails to load, hide it to show fallback icon
        event.target.style.display = 'none';
    }

    get hasEnrollments() {
        return this.enrollments && this.enrollments.length > 0;
    }

    getStatusVariant(status) {
        switch(status) {
            case 'Completed':
                return 'success';
            case 'In Progress':
                return 'warning';
            case 'Not Started':
                return 'inverse';
            default:
                return 'inverse';
        }
    }

    truncateText(text, maxLength) {
        if (!text) return '';
        if (text.length <= maxLength) return text;
        return text.substring(0, maxLength).trim() + '...';
    }

    handleContinueLearning(event) {
        const courseId = event.target.dataset.courseId;
        const enrollmentId = event.target.dataset.enrollmentId;
        
        // Fire event to parent shell to navigate to lesson player
        const navigateEvent = new CustomEvent('navigatetolessonplayer', {
            detail: { 
                courseId: courseId,
                enrollmentId: enrollmentId
            },
            bubbles: true,
            composed: true
        });
        this.dispatchEvent(navigateEvent);
    }

    get selectedContactId() {
        return this.contactId;
    }

    handleBackToWelcome() {
        // Fire event to parent shell to navigate back to welcome
        // Don't preserve contact so user can select a different learner
        const navigateEvent = new CustomEvent('navigatetowelcome', {
            detail: { preserveContact: false },
            bubbles: true,
            composed: true
        });
        this.dispatchEvent(navigateEvent);
    }
}