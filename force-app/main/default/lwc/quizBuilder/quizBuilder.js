//
// SPDX-License-Identifier: MIT
// TrailForge — Open Source under the MIT License
// Copyright (c) 2025 Robert Davis
// See the LICENSE file in the project root for full license text.
//
import { LightningElement, wire, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';
import getAllQuizzes from '@salesforce/apex/QuizAdminController.getAllQuizzes';
import getQuizDetails from '@salesforce/apex/QuizAdminController.getQuizDetails';
import saveQuiz from '@salesforce/apex/QuizAdminController.saveQuiz';

export default class QuizBuilder extends LightningElement {
    @api cardTitle = 'Quiz Builder';
    
    @track quizzes = [];
    @track selectedQuiz;
    @track isLoading = false;
    @track showNewQuizModal = false;
    
    // New Quiz Form
    @track newQuizName = '';
    @track newQuizLevel = '';
    @track newQuizLessonId;
    @track newQuizCourseId;
    
    wiredQuizzesResult;
    selectedQuizId;
    
    // Options for dropdowns
    get levelOptions() {
        return [
            { label: 'Lesson', value: 'Lesson' },
            { label: 'Course', value: 'Course' }
        ];
    }
    
    get lessonOptions() {
        // TODO: Load from server
        return [];
    }
    
    get courseOptions() {
        // TODO: Load from server
        return [];
    }
    
    get isLessonLevel() {
        return this.newQuizLevel === 'Lesson';
    }
    
    get isCourseLevel() {
        return this.newQuizLevel === 'Course';
    }
    
    get hasQuizzes() {
        return this.quizzes && this.quizzes.length > 0;
    }
    
    get getQuizItemClass() {
        return (quizId) => {
            const baseClass = 'quiz-item slds-box slds-m-bottom_x-small';
            return quizId === this.selectedQuizId ? `${baseClass} selected` : baseClass;
        };
    }
    
    @wire(getAllQuizzes)
    wiredQuizzes(result) {
        this.wiredQuizzesResult = result;
        if (result.data) {
            this.quizzes = result.data.map(quiz => ({
                ...quiz,
                levelLabel: quiz.level || 'Unknown',
                targetName: quiz.lessonName || quiz.courseName || 'Not assigned'
            }));
        } else if (result.error) {
            this.showError('Error loading quizzes', result.error);
        }
    }
    
    handleNewQuiz() {
        this.showNewQuizModal = true;
        this.newQuizName = '';
        this.newQuizLevel = '';
        this.newQuizLessonId = null;
        this.newQuizCourseId = null;
    }
    
    closeNewQuizModal() {
        this.showNewQuizModal = false;
    }
    
    handleNewQuizNameChange(event) {
        this.newQuizName = event.target.value;
    }
    
    handleNewQuizLevelChange(event) {
        this.newQuizLevel = event.target.value;
    }
    
    handleNewQuizLessonChange(event) {
        this.newQuizLessonId = event.target.value;
    }
    
    handleNewQuizCourseChange(event) {
        this.newQuizCourseId = event.target.value;
    }
    
    async createNewQuiz() {
        if (!this.newQuizName) {
            this.showError('Validation Error', 'Quiz name is required');
            return;
        }
        
        if (!this.newQuizLevel) {
            this.showError('Validation Error', 'Please select a level');
            return;
        }
        
        const quizData = {
            name: this.newQuizName,
            level: this.newQuizLevel,
            lessonId: this.newQuizLessonId,
            courseId: this.newQuizCourseId,
            passingScore: 70,
            isActive: false,
            isArchived: false,
            allowRetakes: true,
            questions: []
        };
        
        try {
            this.isLoading = true;
            const quizId = await saveQuiz({ quizJSON: JSON.stringify(quizData) });
            
            this.showSuccess('Success', 'Quiz created successfully');
            this.closeNewQuizModal();
            
            // Refresh quiz list
            await refreshApex(this.wiredQuizzesResult);
            
            // Select the new quiz
            this.selectedQuizId = quizId;
            await this.loadQuizDetails(quizId);
            
        } catch (error) {
            this.showError('Error creating quiz', error);
        } finally {
            this.isLoading = false;
        }
    }
    
    async handleQuizSelect(event) {
        const quizId = event.currentTarget.dataset.quizId;
        this.selectedQuizId = quizId;
        await this.loadQuizDetails(quizId);
    }
    
    async loadQuizDetails(quizId) {
        try {
            this.isLoading = true;
            const result = await getQuizDetails({ quizId });
            this.selectedQuiz = result;
        } catch (error) {
            this.showError('Error loading quiz details', error);
        } finally {
            this.isLoading = false;
        }
    }
    
    async handleQuizSaved(event) {
        this.showSuccess('Success', 'Quiz saved successfully');
        await refreshApex(this.wiredQuizzesResult);
        
        if (event.detail && event.detail.quizId) {
            await this.loadQuizDetails(event.detail.quizId);
        }
    }
    
    async handleQuizDeleted() {
        this.showSuccess('Success', 'Quiz archived successfully');
        this.selectedQuiz = null;
        this.selectedQuizId = null;
        await refreshApex(this.wiredQuizzesResult);
    }
    
    showSuccess(title, message) {
        this.dispatchEvent(new ShowToastEvent({
            title,
            message,
            variant: 'success'
        }));
    }
    
    showError(title, error) {
        let message = 'An error occurred';
        if (error) {
            if (error.body && error.body.message) {
                message = error.body.message;
            } else if (typeof error === 'string') {
                message = error;
            } else if (error.message) {
                message = error.message;
            }
        }
        
        this.dispatchEvent(new ShowToastEvent({
            title,
            message,
            variant: 'error',
            mode: 'sticky'
        }));
    }
}