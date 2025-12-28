//
// SPDX-License-Identifier: MIT
// TrailForge — Open Source under the MIT License
// Copyright (c) 2025 Robert Davis
// See the LICENSE file in the project root for full license text.
//
import { LightningElement, api, track, wire } from 'lwc';
import getAllQuizzes from '@salesforce/apex/QuizAdminController.getAllQuizzes';
import getQuizDetails from '@salesforce/apex/QuizAdminController.getQuizDetails';
import saveQuizFull from '@salesforce/apex/QuizAdminController.saveQuizFull';
import archiveQuiz from '@salesforce/apex/QuizAdminController.archiveQuiz';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';

export default class QuizBuilderAdmin extends LightningElement {
    // API properties for context when embedded in Content Builder
    @api courseId;
    @api lessonId;
    
    @track quizzes = [];
    @track selectedQuizId = null;
    @track quizDetail = this.getEmptyQuizDetail();
    @track searchTerm = '';
    @track showError = false;
    @track errorMessage = '';
    @track showSuccess = false;
    @track successMessage = '';
    @track lessonName = '';
    @track courseName = '';
    
    /**
     * Check if context was provided (embedded mode)
     */
    get hasProvidedContext() {
        return this.courseId || this.lessonId;
    }
    
    /**
     * Lifecycle - initialize with context if provided
     */
    connectedCallback() {
        if (this.hasProvidedContext) {
            // Start in "new quiz" mode with pre-filled context
            this.handleNewQuiz();
            if (this.lessonId) {
                this.quizDetail.lessonId = this.lessonId;
                this.quizDetail.level = 'Lesson';
            }
            if (this.courseId) {
                this.quizDetail.courseId = this.courseId;
                if (!this.lessonId) {
                    this.quizDetail.level = 'Course';
                }
            }
        }
    }
    
    wiredQuizzesResult;
    
    levelOptions = [
        { label: 'Lesson', value: 'Lesson' },
        { label: 'Course', value: 'Course' }
    ];
    
    questionTypeOptions = [
        { label: 'Multiple Choice', value: 'MultipleChoice' }
    ];
    
    // Wire getAllQuizzes
    @wire(getAllQuizzes)
    wiredQuizzes(result) {
        this.wiredQuizzesResult = result;
        if (result.data) {
            this.quizzes = result.data;
            this.showError = false;
        } else if (result.error) {
            this.showError = true;
            this.errorMessage = 'Error loading quizzes: ' + this.getErrorMessage(result.error);
        }
    }
    
    get filteredQuizzes() {
        if (!this.searchTerm) {
            return this.quizzes;
        }
        const term = this.searchTerm.toLowerCase();
        return this.quizzes.filter(quiz => 
            quiz.name.toLowerCase().includes(term) ||
            (quiz.assignedToName && quiz.assignedToName.toLowerCase().includes(term))
        );
    }
    
    get hasQuizzes() {
        return this.filteredQuizzes && this.filteredQuizzes.length > 0;
    }
    
    get hasQuestions() {
        return this.quizDetail.questions && this.quizDetail.questions.length > 0;
    }
    
    get questionCount() {
        return this.quizDetail.questions ? this.quizDetail.questions.length : 0;
    }
    
    get isLessonLevel() {
        return this.quizDetail.level === 'Lesson';
    }
    
    get isCourseLevel() {
        return this.quizDetail.level === 'Course';
    }
    
    getQuizClass(event) {
        const quizId = event.currentTarget.dataset.quizId;
        const baseClass = 'quiz-item slds-box slds-box_x-small slds-m-bottom_x-small';
        return quizId === this.selectedQuizId ? baseClass + ' selected' : baseClass;
    }
    
    handleSearch(event) {
        this.searchTerm = event.target.value;
    }
    
    handleQuizSelect(event) {
        const quizId = event.currentTarget.dataset.quizId;
        this.loadQuizDetails(quizId);
    }
    
    handleNewQuiz() {
        this.selectedQuizId = 'new';
        this.quizDetail = this.getEmptyQuizDetail();
        this.lessonName = '';
        this.courseName = '';
        this.clearMessages();
    }
    
    loadQuizDetails(quizId) {
        this.selectedQuizId = quizId;
        this.clearMessages();
        
        getQuizDetails({ quizId: quizId })
            .then(result => {
                this.quizDetail = result;
                
                // Ensure questions array exists
                if (!this.quizDetail.questions) {
                    this.quizDetail.questions = [];
                }
                
                // Add display numbers to questions
                this.quizDetail.questions.forEach((q, index) => {
                    q.displayNumber = index + 1;
                    
                    // Ensure options array exists
                    if (!q.options) {
                        q.options = [];
                    }
                });
                
                // Load lookup display names
                this.loadLookupNames();
            })
            .catch(error => {
                this.showError = true;
                this.errorMessage = 'Error loading quiz details: ' + this.getErrorMessage(error);
            });
    }
    
    loadLookupNames() {
        // In a production implementation, we would query the Course/Lesson names
        // For now, we'll just show the IDs
        this.lessonName = this.quizDetail.lessonId || '';
        this.courseName = this.quizDetail.courseId || '';
    }
    
    handleFieldChange(event) {
        const field = event.target.dataset.field;
        const value = event.target.type === 'checkbox' ? event.target.checked : event.target.value;
        
        this.quizDetail[field] = value;
        
        // Clear lookup when level changes
        if (field === 'level') {
            if (value === 'Lesson') {
                this.quizDetail.courseId = null;
                this.courseName = '';
            } else if (value === 'Course') {
                this.quizDetail.lessonId = null;
                this.lessonName = '';
            }
        }
    }
    
    handleAddQuestion() {
        const newQuestion = {
            questionId: 'temp-' + Date.now(),
            questionText: '',
            questionType: 'MultipleChoice',
            points: 1,
            required: true,
            sortOrder: this.quizDetail.questions.length,
            options: [],
            displayNumber: this.quizDetail.questions.length + 1
        };
        
        this.quizDetail.questions = [...this.quizDetail.questions, newQuestion];
    }
    
    handleQuestionChange(event) {
        const questionIndex = parseInt(event.target.dataset.questionIndex);
        const field = event.target.dataset.field;
        const value = event.target.type === 'checkbox' ? event.target.checked : event.target.value;
        
        this.quizDetail.questions[questionIndex][field] = value;
        this.quizDetail = { ...this.quizDetail }; // Trigger reactivity
    }
    
    handleDeleteQuestion(event) {
        const questionIndex = parseInt(event.target.dataset.questionIndex);
        
        if (confirm('Are you sure you want to delete this question?')) {
            this.quizDetail.questions.splice(questionIndex, 1);
            
            // Renumber questions
            this.quizDetail.questions.forEach((q, index) => {
                q.displayNumber = index + 1;
                q.sortOrder = index;
            });
            
            this.quizDetail = { ...this.quizDetail }; // Trigger reactivity
        }
    }
    
    handleAddOption(event) {
        const questionIndex = parseInt(event.target.dataset.questionIndex);
        
        const newOption = {
            optionId: 'temp-' + Date.now(),
            answerText: '',
            isCorrect: false,
            sortOrder: this.quizDetail.questions[questionIndex].options.length,
            isActive: true
        };
        
        this.quizDetail.questions[questionIndex].options = [
            ...this.quizDetail.questions[questionIndex].options,
            newOption
        ];
        
        this.quizDetail = { ...this.quizDetail }; // Trigger reactivity
    }
    
    handleOptionChange(event) {
        const questionIndex = parseInt(event.target.dataset.questionIndex);
        const optionIndex = parseInt(event.target.dataset.optionIndex);
        const field = event.target.dataset.field;
        const value = event.target.type === 'checkbox' ? event.target.checked : event.target.value;
        
        this.quizDetail.questions[questionIndex].options[optionIndex][field] = value;
        this.quizDetail = { ...this.quizDetail }; // Trigger reactivity
    }
    
    handleDeleteOption(event) {
        const questionIndex = parseInt(event.target.dataset.questionIndex);
        const optionIndex = parseInt(event.target.dataset.optionIndex);
        
        this.quizDetail.questions[questionIndex].options.splice(optionIndex, 1);
        
        // Renumber options
        this.quizDetail.questions[questionIndex].options.forEach((opt, index) => {
            opt.sortOrder = index;
        });
        
        this.quizDetail = { ...this.quizDetail }; // Trigger reactivity
    }
    
    handleLessonLookupChange(event) {
        // Handle lesson lookup field change from lightning-input-field
        const lessonId = event.detail.value ? event.detail.value[0] : null;
        if (lessonId) {
            this.quizDetail.lessonId = lessonId;
            this.lessonName = lessonId;
            // Optionally load the name via wire or imperative call
            this.loadLessonName(lessonId);
        } else {
            this.quizDetail.lessonId = null;
            this.lessonName = '';
        }
    }
    
    handleCourseLookupChange(event) {
        // Handle course lookup field change from lightning-input-field
        const courseId = event.detail.value ? event.detail.value[0] : null;
        if (courseId) {
            this.quizDetail.courseId = courseId;
            this.courseName = courseId;
            // Optionally load the name via wire or imperative call
            this.loadCourseName(courseId);
        } else {
            this.quizDetail.courseId = null;
            this.courseName = '';
        }
    }
    
    loadLessonName(lessonId) {
        // For now just show the ID - could be enhanced with getRecord wire
        this.lessonName = lessonId;
    }
    
    loadCourseName(courseId) {
        // For now just show the ID - could be enhanced with getRecord wire
        this.courseName = courseId;
    }
    
    handleSave() {
        // Validate
        if (!this.validateQuiz()) {
            return;
        }
        
        this.clearMessages();
        
        let savedQuizId = null;
        let savedQuizName = this.quizDetail.name;
        
        // Save quiz
        saveQuizFull({ quizJSON: JSON.stringify(this.quizDetail) })
            .then(result => {
                this.showSuccess = true;
                this.successMessage = 'Quiz saved successfully!';
                savedQuizId = result;
                
                // Refresh quiz list
                return refreshApex(this.wiredQuizzesResult);
            })
            .then(() => {
                // Reload quiz details if it was a new quiz
                if (this.selectedQuizId === 'new') {
                    this.selectedQuizId = savedQuizId;
                }
                
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Success',
                        message: 'Quiz saved successfully',
                        variant: 'success'
                    })
                );
                
                // Fire quizcreated event for parent components (Content Builder)
                if (this.hasProvidedContext && savedQuizId) {
                    this.dispatchEvent(new CustomEvent('quizcreated', {
                        detail: {
                            quizId: savedQuizId,
                            quizName: savedQuizName
                        }
                    }));
                }
                
                // Auto-hide success message after 3 seconds
                setTimeout(() => {
                    this.showSuccess = false;
                }, 3000);
            })
            .catch(error => {
                this.showError = true;
                this.errorMessage = 'Error saving quiz: ' + this.getErrorMessage(error);
                
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Error',
                        message: this.errorMessage,
                        variant: 'error'
                    })
                );
            });
    }
    
    handleCancel() {
        if (this.selectedQuizId === 'new') {
            this.selectedQuizId = null;
            this.quizDetail = this.getEmptyQuizDetail();
        } else {
            // Reload quiz to discard changes
            this.loadQuizDetails(this.selectedQuizId);
        }
        this.clearMessages();
    }
    
    handleArchiveQuiz() {
        if (!confirm('Are you sure you want to archive this quiz?')) {
            return;
        }
        
        this.clearMessages();
        
        archiveQuiz({ quizId: this.selectedQuizId, forceArchive: false })
            .then(() => {
                this.showSuccess = true;
                this.successMessage = 'Quiz archived successfully!';
                
                this.selectedQuizId = null;
                this.quizDetail = this.getEmptyQuizDetail();
                
                // Refresh quiz list
                return refreshApex(this.wiredQuizzesResult);
            })
            .then(() => {
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Success',
                        message: 'Quiz archived successfully',
                        variant: 'success'
                    })
                );
            })
            .catch(error => {
                this.showError = true;
                this.errorMessage = 'Error archiving quiz: ' + this.getErrorMessage(error);
                
                // Check if error is about active attempts
                const errorMsg = this.getErrorMessage(error);
                if (errorMsg.includes('active attempt')) {
                    const forceArchive = confirm(errorMsg + '\n\nDo you want to force archive?');
                    if (forceArchive) {
                        this.forceArchiveQuiz();
                    }
                }
            });
    }
    
    forceArchiveQuiz() {
        archiveQuiz({ quizId: this.selectedQuizId, forceArchive: true })
            .then(() => {
                this.showSuccess = true;
                this.successMessage = 'Quiz force archived successfully!';
                
                this.selectedQuizId = null;
                this.quizDetail = this.getEmptyQuizDetail();
                
                return refreshApex(this.wiredQuizzesResult);
            })
            .catch(error => {
                this.showError = true;
                this.errorMessage = 'Error force archiving quiz: ' + this.getErrorMessage(error);
            });
    }
    
    validateQuiz() {
        // Check required fields
        if (!this.quizDetail.name) {
            this.showError = true;
            this.errorMessage = 'Quiz name is required';
            return false;
        }
        
        if (!this.quizDetail.level) {
            this.showError = true;
            this.errorMessage = 'Quiz level is required';
            return false;
        }
        
        if (this.quizDetail.level === 'Lesson' && !this.quizDetail.lessonId) {
            this.showError = true;
            this.errorMessage = 'Please select a lesson for lesson-level quiz';
            return false;
        }
        
        if (this.quizDetail.level === 'Course' && !this.quizDetail.courseId) {
            this.showError = true;
            this.errorMessage = 'Please select a course for course-level quiz';
            return false;
        }
        
        // Check for at least one question if active
        if (this.quizDetail.isActive && this.quizDetail.questions.length === 0) {
            this.showError = true;
            this.errorMessage = 'Active quizzes must have at least one question';
            return false;
        }
        
        // Check each question has at least one correct answer
        for (let i = 0; i < this.quizDetail.questions.length; i++) {
            const question = this.quizDetail.questions[i];
            
            if (!question.questionText) {
                this.showError = true;
                this.errorMessage = `Question ${i + 1} is missing question text`;
                return false;
            }
            
            if (question.options.length === 0) {
                this.showError = true;
                this.errorMessage = `Question ${i + 1} must have at least one answer option`;
                return false;
            }
            
            const hasCorrectAnswer = question.options.some(opt => opt.isCorrect);
            if (!hasCorrectAnswer) {
                this.showError = true;
                this.errorMessage = `Question ${i + 1} must have at least one correct answer`;
                return false;
            }
        }
        
        return true;
    }
    
    clearMessages() {
        this.showError = false;
        this.showSuccess = false;
        this.errorMessage = '';
        this.successMessage = '';
    }
    
    getEmptyQuizDetail() {
        return {
            quizId: null,
            name: '',
            level: 'Lesson',
            courseId: null,
            lessonId: null,
            isActive: false,
            isArchived: false,
            passingScore: 70,
            maxScore: null,
            allowRetakes: true,
            sortOrder: 0,
            instructions: '',
            questions: []
        };
    }
    
    getErrorMessage(error) {
        if (error.body && error.body.message) {
            return error.body.message;
        } else if (error.message) {
            return error.message;
        } else if (typeof error === 'string') {
            return error;
        }
        return 'Unknown error occurred';
    }
}