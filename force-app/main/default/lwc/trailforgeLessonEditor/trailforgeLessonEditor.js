import { LightningElement, api, wire, track } from 'lwc';
import { getRecord, getFieldValue, updateRecord } from 'lightning/uiRecordApi';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

import ID_FIELD from '@salesforce/schema/Lesson__c.Id';
import NAME_FIELD from '@salesforce/schema/Lesson__c.Name';
import CONTENT_TYPE_FIELD from '@salesforce/schema/Lesson__c.Content_Type__c';
import CONTENT_BODY_FIELD from '@salesforce/schema/Lesson__c.Content_Body__c';
import EXTERNAL_URL_FIELD from '@salesforce/schema/Lesson__c.External_URL__c';

const FIELDS = [NAME_FIELD, CONTENT_TYPE_FIELD, CONTENT_BODY_FIELD, EXTERNAL_URL_FIELD];

export default class TrailforgeLessonEditor extends LightningElement {
    @api lessonId;  // For Flow screens or explicit override
    @api recordId;  // Auto-populated on record pages
    
    @track lessonName = '';
    @track contentType = '';
    @track contentBody = '';
    @track externalUrl = '';
    
    isLoading = true;
    isSaving = false;
    error = null;
    
    // Content type options
    contentTypeOptions = [
        { label: 'Markdown', value: 'Markdown' },
        { label: 'HTML', value: 'HTML' },
        { label: 'URL', value: 'URL' },
        { label: 'Video', value: 'Video' },
        { label: 'PDF', value: 'PDF' }
    ];
    
    // Computed property: use explicit lessonId if provided, otherwise use recordId from record page
    get effectiveLessonId() {
        return this.lessonId || this.recordId;
    }
    
    @wire(getRecord, { recordId: '$effectiveLessonId', fields: FIELDS })
    wiredLesson({ error, data }) {
        this.isLoading = false;
        if (data) {
            this.lessonName = getFieldValue(data, NAME_FIELD);
            this.contentType = getFieldValue(data, CONTENT_TYPE_FIELD) || '';
            this.contentBody = getFieldValue(data, CONTENT_BODY_FIELD) || '';
            this.externalUrl = getFieldValue(data, EXTERNAL_URL_FIELD) || '';
            this.error = null;
        } else if (error) {
            this.error = this.reduceErrors(error);
            console.error('Error loading lesson:', error);
        }
    }
    
    // Computed properties for showing/hiding fields based on content type
    get showContentBody() {
        return this.contentType === 'Markdown' || this.contentType === 'HTML';
    }
    
    get showExternalUrl() {
        return this.contentType === 'URL' || this.contentType === 'Video' || this.contentType === 'PDF';
    }
    
    get contentBodyLabel() {
        if (this.contentType === 'Markdown') {
            return 'Markdown Content';
        } else if (this.contentType === 'HTML') {
            return 'HTML Content';
        }
        return 'Content Body';
    }
    
    get contentBodyPlaceholder() {
        if (this.contentType === 'Markdown') {
            return '# Heading\n\nYour markdown content here...\n\n- List item 1\n- List item 2\n\n**Bold text** and *italic text*';
        } else if (this.contentType === 'HTML') {
            return '<h1>Heading</h1>\n<p>Your HTML content here...</p>';
        }
        return 'Enter content...';
    }
    
    get externalUrlLabel() {
        if (this.contentType === 'Video') {
            return 'Video URL';
        } else if (this.contentType === 'PDF') {
            return 'PDF URL';
        }
        return 'External URL';
    }
    
    get externalUrlPlaceholder() {
        if (this.contentType === 'Video') {
            return 'https://www.youtube.com/watch?v=...';
        } else if (this.contentType === 'PDF') {
            return 'https://example.com/document.pdf';
        }
        return 'https://...';
    }
    
    get hasLessonId() {
        return !!this.effectiveLessonId;
    }
    
    get cardTitle() {
        return this.lessonName ? `Edit Lesson: ${this.lessonName}` : 'Lesson Content Editor';
    }
    
    // Content type specific getters for template use
    get isMarkdownType() {
        return this.contentType === 'Markdown';
    }
    
    get isHtmlType() {
        return this.contentType === 'HTML';
    }
    
    get isVideoType() {
        return this.contentType === 'Video';
    }
    
    get isPdfType() {
        return this.contentType === 'PDF';
    }
    
    get isUrlType() {
        return this.contentType === 'URL';
    }
    
    // Event handlers
    handleContentTypeChange(event) {
        this.contentType = event.detail.value;
    }
    
    handleContentBodyChange(event) {
        this.contentBody = event.target.value;
    }
    
    handleExternalUrlChange(event) {
        this.externalUrl = event.target.value;
    }
    
    async handleSave() {
        this.isSaving = true;
        this.error = null;
        
        const fields = {};
        fields[ID_FIELD.fieldApiName] = this.effectiveLessonId;
        fields[CONTENT_TYPE_FIELD.fieldApiName] = this.contentType;
        fields[CONTENT_BODY_FIELD.fieldApiName] = this.contentBody;
        fields[EXTERNAL_URL_FIELD.fieldApiName] = this.externalUrl;
        
        try {
            await updateRecord({ fields });
            
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Success',
                    message: 'Lesson content saved successfully',
                    variant: 'success'
                })
            );
            
            // Dispatch custom event for parent components
            this.dispatchEvent(new CustomEvent('save', {
                detail: { lessonId: this.effectiveLessonId }
            }));
            
        } catch (error) {
            this.error = this.reduceErrors(error);
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Error saving lesson',
                    message: this.error,
                    variant: 'error'
                })
            );
        } finally {
            this.isSaving = false;
        }
    }
    
    handleCancel() {
        this.dispatchEvent(new CustomEvent('cancel'));
    }
    
    reduceErrors(error) {
        if (typeof error === 'string') {
            return error;
        }
        if (error.body) {
            if (typeof error.body.message === 'string') {
                return error.body.message;
            }
            if (error.body.output && error.body.output.errors) {
                return error.body.output.errors.map(e => e.message).join(', ');
            }
        }
        if (error.message) {
            return error.message;
        }
        return 'Unknown error';
    }
}
