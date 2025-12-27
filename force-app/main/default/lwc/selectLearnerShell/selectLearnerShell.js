import { LightningElement, track } from 'lwc';
import getLearnerOptions from '@salesforce/apex/LessonPlayerController.getLearnerOptions';

export default class SelectLearnerShell extends LightningElement {
    @track searchTerm = '';
    @track learnerOptions = [];
    @track selectedContactId;
    @track selectedLearnerName;
    @track error;

    searchTimeout;

    get hasLearnerOptions() {
        return this.learnerOptions && this.learnerOptions.length > 0;
    }

    handleSearchChange(event) {
        this.searchTerm = event.target.value;

        // Clear previous timeout
        if (this.searchTimeout) {
            clearTimeout(this.searchTimeout);
        }

        // Debounce search
        if (this.searchTerm && this.searchTerm.length >= 2) {
            this.searchTimeout = setTimeout(() => {
                this.searchLearners();
            }, 300);
        } else {
            this.learnerOptions = [];
        }
    }

    searchLearners() {
        getLearnerOptions({ searchTerm: this.searchTerm })
            .then(result => {
                this.learnerOptions = result;
                this.error = undefined;
            })
            .catch(error => {
                this.error = error.body ? error.body.message : 'Error searching for learners';
                this.learnerOptions = [];
            });
    }

    handleLearnerSelect(event) {
        const contactId = event.currentTarget.dataset.contactId;
        const selectedOption = this.learnerOptions.find(opt => opt.value === contactId);

        if (selectedOption) {
            this.selectedContactId = contactId;
            this.selectedLearnerName = selectedOption.label;
            this.learnerOptions = [];
            this.searchTerm = '';
        }
    }

    handleLaunchTrailForge() {
        if (!this.selectedContactId) {
            this.error = 'Please select a learner first.';
            return;
        }

        this.dispatchEvent(new CustomEvent('learnerselected', {
            detail: {
                contactId: this.selectedContactId,
                learnerName: this.selectedLearnerName
            }
        }));
    }
}