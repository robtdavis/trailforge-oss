/**
 * Enrollment Wizard LWC
 * Admin tool for bulk enrolling contacts into a course
 * 
 * Features:
 * - Step 1: Select contacts via Account lookup OR global search
 * - Step 2: Select a Course
 * - Step 3: Confirm and enroll
 * 
 * Usage:
 *   Add this component to a Lightning App Page in your admin app.
 *   Required permissions: Contact (Read), Account (Read), Course__c (Read), Enrollment__c (Create)
 */
import { LightningElement, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

// Apex methods
import getContactsByAccount from '@salesforce/apex/EnrollmentWizardController.getContactsByAccount';
import getContactCountForAccount from '@salesforce/apex/EnrollmentWizardController.getContactCountForAccount';
import searchContactsGlobal from '@salesforce/apex/EnrollmentWizardController.searchContactsGlobal';
import searchCourses from '@salesforce/apex/EnrollmentWizardController.searchCourses';
import enrollContacts from '@salesforce/apex/EnrollmentWizardController.enrollContacts';

const CONTACT_LIMIT = 200;
const SEARCH_LIMIT = 50;
const DEBOUNCE_DELAY = 400;

// Columns for contact datatable
const CONTACT_COLUMNS = [
    { label: 'Name', fieldName: 'Name', type: 'text', sortable: true },
    { label: 'Email', fieldName: 'Email', type: 'email' },
    { label: 'Title', fieldName: 'Title', type: 'text' },
    { label: 'Account', fieldName: 'AccountName', type: 'text' }
];

export default class TrailforgeEnrollmentWizard extends LightningElement {
    // Current wizard step
    @track currentStep = 1;
    
    // Step 1: Contact Selection
    @track selectedAccountId = null;
    @track accountContacts = [];
    @track accountContactCount = 0;
    @track filteredContacts = [];
    @track contactFilterText = '';
    @track selectedContactIds = [];
    @track selectedContacts = []; // Full contact objects for display
    
    // Global search
    @track isGlobalSearch = false;
    @track globalSearchTerm = '';
    @track globalSearchResults = [];
    @track isSearching = false;
    
    // Step 2: Course Selection
    @track selectedCourseId = null;
    @track selectedCourse = null;
    @track courseSearchTerm = '';
    @track courseSearchResults = [];
    @track isSearchingCourses = false;
    
    // Step 3: Enrollment
    @track isEnrolling = false;
    @track enrollmentResult = null;
    
    // UI State
    @track isLoadingContacts = false;
    @track error = null;
    
    // Debounce timer
    searchTimer = null;
    courseSearchTimer = null;
    
    // Column definitions
    contactColumns = CONTACT_COLUMNS;
    
    // ========================================================================
    // COMPUTED PROPERTIES
    // ========================================================================
    
    get isStep1() {
        return this.currentStep === 1;
    }
    
    get isStep2() {
        return this.currentStep === 2;
    }
    
    get isStep3() {
        return this.currentStep === 3;
    }
    
    get accountButtonVariant() {
        return this.isGlobalSearch ? 'neutral' : 'brand';
    }
    
    get globalSearchButtonVariant() {
        return this.isGlobalSearch ? 'brand' : 'neutral';
    }
    
    get stepIndicatorClass1() {
        return this.currentStep >= 1 ? 'slds-is-active' : '';
    }
    
    get stepIndicatorClass2() {
        return this.currentStep >= 2 ? 'slds-is-active' : '';
    }
    
    get stepIndicatorClass3() {
        return this.currentStep >= 3 ? 'slds-is-active' : '';
    }
    
    get hasSelectedContacts() {
        return this.selectedContactIds.length > 0;
    }
    
    get selectedContactCount() {
        return this.selectedContactIds.length;
    }
    
    get showAccountContactsTable() {
        return !this.isGlobalSearch && this.selectedAccountId && this.filteredContacts.length > 0;
    }
    
    get showGlobalSearchResults() {
        return this.isGlobalSearch && this.globalSearchResults.length > 0;
    }
    
    get showContactLimitWarning() {
        return !this.isGlobalSearch && this.accountContactCount > CONTACT_LIMIT;
    }
    
    get contactLimitMessage() {
        return `Showing first ${CONTACT_LIMIT} of ${this.accountContactCount} contacts. Use the filter to narrow results.`;
    }
    
    get displayedContacts() {
        return this.isGlobalSearch ? this.globalSearchResults : this.filteredContacts;
    }
    
    get canProceedToStep2() {
        return this.selectedContactIds.length > 0;
    }
    
    get cannotProceedToStep2() {
        return !this.canProceedToStep2;
    }
    
    get canProceedToStep3() {
        return this.selectedCourseId !== null;
    }
    
    get cannotProceedToStep3() {
        return !this.canProceedToStep3;
    }
    
    get canEnroll() {
        return this.selectedContactIds.length > 0 && this.selectedCourseId !== null && !this.isEnrolling;
    }
    
    get cannotEnroll() {
        return !this.canEnroll;
    }
    
    get enrollButtonLabel() {
        return this.isEnrolling ? 'Enrolling...' : `Enroll ${this.selectedContactCount} Contact${this.selectedContactCount !== 1 ? 's' : ''}`;
    }
    
    get showEnrollmentResults() {
        return this.enrollmentResult !== null;
    }
    
    get enrollmentSummary() {
        if (!this.enrollmentResult) return '';
        const r = this.enrollmentResult;
        let summary = `Created: ${r.createdCount}`;
        if (r.skippedCount > 0) summary += ` | Skipped (already enrolled): ${r.skippedCount}`;
        if (r.failedCount > 0) summary += ` | Failed: ${r.failedCount}`;
        return summary;
    }
    
    get enrollmentResultsForDisplay() {
        if (!this.enrollmentResult || !this.enrollmentResult.contactResults) return [];
        return this.enrollmentResult.contactResults.map(cr => ({
            ...cr,
            statusClass: this.getStatusClass(cr.status),
            statusIcon: this.getStatusIcon(cr.status)
        }));
    }
    
    // ========================================================================
    // LIFECYCLE
    // ========================================================================
    
    connectedCallback() {
        // Load initial course list
        this.loadInitialCourses();
    }
    
    // ========================================================================
    // STEP 1: CONTACT SELECTION
    // ========================================================================
    
    handleAccountChange(event) {
        const previousAccountId = this.selectedAccountId;
        this.selectedAccountId = event.detail.recordId;
        this.accountContacts = [];
        this.filteredContacts = [];
        this.contactFilterText = '';
        
        // Clear selection when account changes to prevent enrolling contacts from multiple accounts
        if (previousAccountId && previousAccountId !== this.selectedAccountId && this.selectedContactIds.length > 0) {
            this.clearContactSelection();
            this.showToast('Selection Cleared', 'Contact selection cleared due to account change.', 'info');
        }
        
        if (this.selectedAccountId) {
            this.loadAccountContacts();
        }
    }
    
    async loadAccountContacts() {
        this.isLoadingContacts = true;
        this.error = null;
        
        try {
            // Get contacts and count in parallel
            const [contacts, count] = await Promise.all([
                getContactsByAccount({ accountId: this.selectedAccountId, limitSize: CONTACT_LIMIT }),
                getContactCountForAccount({ accountId: this.selectedAccountId })
            ]);
            
            this.accountContacts = this.formatContactsForTable(contacts);
            this.accountContactCount = count;
            this.applyContactFilter();
            
        } catch (error) {
            this.handleError(error, 'Error loading contacts');
        } finally {
            this.isLoadingContacts = false;
        }
    }
    
    handleContactFilterChange(event) {
        this.contactFilterText = event.target.value;
        this.applyContactFilter();
    }
    
    applyContactFilter() {
        if (!this.contactFilterText) {
            this.filteredContacts = [...this.accountContacts];
            return;
        }
        
        const filterLower = this.contactFilterText.toLowerCase();
        this.filteredContacts = this.accountContacts.filter(contact => 
            (contact.Name && contact.Name.toLowerCase().includes(filterLower)) ||
            (contact.Email && contact.Email.toLowerCase().includes(filterLower)) ||
            (contact.Title && contact.Title.toLowerCase().includes(filterLower))
        );
    }
    
    // Global Search Toggle
    handleToggleGlobalSearch() {
        const wasGlobalSearch = this.isGlobalSearch;
        this.isGlobalSearch = !this.isGlobalSearch;
        
        // Clear selection when switching modes (Option A: clear on mode change)
        if (this.selectedContactIds.length > 0) {
            this.clearContactSelection();
            this.showToast('Selection Cleared', 'Contact selection cleared when switching modes.', 'info');
        }
        
        // Clear mode-specific data
        if (this.isGlobalSearch) {
            // Switching TO global search - clear account data
            this.selectedAccountId = null;
            this.accountContacts = [];
            this.filteredContacts = [];
            this.contactFilterText = '';
            // Clear the record picker
            const recordPicker = this.template.querySelector('lightning-record-picker');
            if (recordPicker) {
                recordPicker.value = null;
            }
        } else {
            // Switching TO account mode - clear global search data
            this.globalSearchTerm = '';
            this.globalSearchResults = [];
        }
    }
    
    handleGlobalSearchChange(event) {
        this.globalSearchTerm = event.target.value;
        
        // Debounce the search
        if (this.searchTimer) {
            clearTimeout(this.searchTimer);
        }
        
        if (this.globalSearchTerm.length >= 2) {
            this.searchTimer = setTimeout(() => {
                this.performGlobalSearch();
            }, DEBOUNCE_DELAY);
        } else {
            this.globalSearchResults = [];
        }
    }
    
    async performGlobalSearch() {
        this.isSearching = true;
        this.error = null;
        
        try {
            const results = await searchContactsGlobal({ 
                searchTerm: this.globalSearchTerm, 
                limitSize: SEARCH_LIMIT 
            });
            this.globalSearchResults = this.formatContactsForTable(results);
        } catch (error) {
            this.handleError(error, 'Error searching contacts');
        } finally {
            this.isSearching = false;
        }
    }
    
    formatContactsForTable(contacts) {
        return contacts.map(c => ({
            ...c,
            AccountName: c.Account ? c.Account.Name : ''
        }));
    }
    
    // Contact Selection
    handleContactSelection(event) {
        const selectedRows = event.detail.selectedRows;
        this.selectedContactIds = selectedRows.map(row => row.Id);
        this.selectedContacts = selectedRows;
    }
    
    handleRemoveContact(event) {
        const contactId = event.currentTarget.dataset.id;
        this.selectedContactIds = this.selectedContactIds.filter(id => id !== contactId);
        this.selectedContacts = this.selectedContacts.filter(c => c.Id !== contactId);
        
        // Update datatable selection
        const datatable = this.template.querySelector('lightning-datatable');
        if (datatable) {
            datatable.selectedRows = this.selectedContactIds;
        }
    }
    
    handleClearSelection() {
        this.clearContactSelection();
    }
    
    /**
     * Helper method to clear contact selection and sync datatable
     * Used by mode toggle, account change, and manual clear button
     */
    clearContactSelection() {
        this.selectedContactIds = [];
        this.selectedContacts = [];
        
        const datatable = this.template.querySelector('lightning-datatable');
        if (datatable) {
            datatable.selectedRows = [];
        }
    }
    
    // ========================================================================
    // STEP 2: COURSE SELECTION
    // ========================================================================
    
    async loadInitialCourses() {
        try {
            const courses = await searchCourses({ searchTerm: '', limitSize: 10 });
            this.courseSearchResults = courses;
        } catch (error) {
            console.error('Error loading courses:', error);
        }
    }
    
    handleCourseSearchChange(event) {
        this.courseSearchTerm = event.target.value;
        
        if (this.courseSearchTimer) {
            clearTimeout(this.courseSearchTimer);
        }
        
        this.courseSearchTimer = setTimeout(() => {
            this.performCourseSearch();
        }, DEBOUNCE_DELAY);
    }
    
    async performCourseSearch() {
        this.isSearchingCourses = true;
        
        try {
            const courses = await searchCourses({ 
                searchTerm: this.courseSearchTerm, 
                limitSize: 25 
            });
            this.courseSearchResults = courses;
        } catch (error) {
            this.handleError(error, 'Error searching courses');
        } finally {
            this.isSearchingCourses = false;
        }
    }
    
    handleCourseSelect(event) {
        const courseId = event.currentTarget.dataset.id;
        this.selectedCourseId = courseId;
        this.selectedCourse = this.courseSearchResults.find(c => c.Id === courseId);
    }
    
    handleClearCourse() {
        this.selectedCourseId = null;
        this.selectedCourse = null;
    }
    
    // ========================================================================
    // STEP 3: ENROLLMENT
    // ========================================================================
    
    async handleEnroll() {
        if (!this.canEnroll) return;
        
        this.isEnrolling = true;
        this.error = null;
        this.enrollmentResult = null;
        
        try {
            const result = await enrollContacts({
                courseId: this.selectedCourseId,
                contactIds: this.selectedContactIds
            });
            
            this.enrollmentResult = result;
            
            // Show toast
            const variant = result.failedCount > 0 ? 'warning' : 'success';
            const title = result.failedCount > 0 ? 'Enrollment Completed with Issues' : 'Enrollment Successful';
            const message = `Created ${result.createdCount} enrollment(s)` + 
                (result.skippedCount > 0 ? `, ${result.skippedCount} already enrolled` : '') +
                (result.failedCount > 0 ? `, ${result.failedCount} failed` : '');
            
            this.showToast(title, message, variant);
            
        } catch (error) {
            this.handleError(error, 'Error creating enrollments');
        } finally {
            this.isEnrolling = false;
        }
    }
    
    handleStartOver() {
        // Reset everything
        this.currentStep = 1;
        this.selectedAccountId = null;
        this.accountContacts = [];
        this.filteredContacts = [];
        this.contactFilterText = '';
        this.selectedContactIds = [];
        this.selectedContacts = [];
        this.isGlobalSearch = false;
        this.globalSearchTerm = '';
        this.globalSearchResults = [];
        this.selectedCourseId = null;
        this.selectedCourse = null;
        this.enrollmentResult = null;
        this.error = null;
        
        // Reload initial courses
        this.loadInitialCourses();
    }
    
    // ========================================================================
    // NAVIGATION
    // ========================================================================
    
    handleNext() {
        if (this.currentStep === 1 && this.canProceedToStep2) {
            this.currentStep = 2;
        } else if (this.currentStep === 2 && this.canProceedToStep3) {
            this.currentStep = 3;
        }
    }
    
    handleBack() {
        if (this.currentStep > 1) {
            this.currentStep--;
        }
    }
    
    handleGoToStep(event) {
        const step = parseInt(event.currentTarget.dataset.step, 10);
        // Only allow going back or staying on current step
        if (step <= this.currentStep) {
            this.currentStep = step;
        }
    }
    
    // ========================================================================
    // UTILITIES
    // ========================================================================
    
    getStatusClass(status) {
        switch (status) {
            case 'Created': return 'slds-text-color_success';
            case 'Skipped': return 'slds-text-color_weak';
            case 'Failed': return 'slds-text-color_error';
            default: return '';
        }
    }
    
    getStatusIcon(status) {
        switch (status) {
            case 'Created': return 'utility:success';
            case 'Skipped': return 'utility:info';
            case 'Failed': return 'utility:error';
            default: return 'utility:help';
        }
    }
    
    handleError(error, context) {
        console.error(context, error);
        let message = 'An unexpected error occurred';
        
        if (error.body && error.body.message) {
            message = error.body.message;
        } else if (error.message) {
            message = error.message;
        }
        
        this.error = message;
        this.showToast('Error', message, 'error');
    }
    
    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({
            title,
            message,
            variant
        }));
    }
}
