//
// SPDX-License-Identifier: MIT
// TrailForge — Open Source under the MIT License
// Copyright (c) 2025 Robert Davis
// See the LICENSE file in the project root for full license text.
//
import { LightningElement, api, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';
import getLessonQuizContext from '@salesforce/apex/QuizService.getLessonQuizContext';
import submitQuizAttempt from '@salesforce/apex/QuizService.submitQuizAttempt';

export default class QuizPlayer extends LightningElement {
    @api lessonId;
    @api contactId;
    @api enrollmentId;
    
    quizContext;
    error;
    isLoading = true;
    
    // Slice 6.2: Answer selection and submission
    selectedAnswers = new Map(); // questionId -> optionId
    isSubmitting = false;
    validationError = '';
    
    // Slice 6.2: Results display
    showResults = false;
    latestGradingResult = null;
    
    // Store wire result for refresh
    wiredQuizResult;
    
    /**
     * Wire the quiz context from Apex
     */
    @wire(getLessonQuizContext, { 
        lessonId: '$lessonId', 
        contactId: '$contactId', 
        enrollmentId: '$enrollmentId' 
    })
    wiredQuizContext(result) {
        this.wiredQuizResult = result; // Save for refreshApex
        
        const { error, data } = result;
        this.isLoading = false;
        
        if (data) {
            this.quizContext = data;
            this.error = undefined;
        } else if (error) {
            this.error = error;
            this.quizContext = undefined;
            console.error('Error loading quiz context:', error);
        }
    }
    
    /**
     * Slice 6.2: Handle answer selection
     */
    handleAnswerSelection(event) {
        const questionId = event.target.dataset.questionId;
        const optionId = event.target.value;
        
        this.selectedAnswers.set(questionId, optionId);
        this.validationError = ''; // Clear validation error when user selects
    }
    
    /**
     * Slice 6.2: Validate that all required questions are answered
     */
    validateAnswers() {
        if (!this.quizContext || !this.quizContext.questions) {
            return false;
        }
        
        for (let question of this.quizContext.questions) {
            if (question.required && !this.selectedAnswers.has(question.questionId)) {
                this.validationError = 'Please answer all required questions before submitting.';
                return false;
            }
        }
        
        return true;
    }
    
    /**
     * Slice 6.2: Submit quiz attempt
     */
    async handleSubmitQuiz() {
        // Validate answers
        if (!this.validateAnswers()) {
            this.showToast('Validation Error', this.validationError, 'error');
            return;
        }
        
        this.isSubmitting = true;
        
        try {
            // Build submission DTO
            const submission = {
                quizId: this.quizContext.quizId,
                contactId: this.contactId,
                enrollmentId: this.enrollmentId,
                responses: this.buildAnswersArray()
            };
            
            // Call Apex imperatively
            const result = await submitQuizAttempt({ 
                submissionJSON: JSON.stringify(submission) 
            });
            
            // Store result and show results panel
            this.latestGradingResult = result;
            this.showResults = true;
            
            // Refresh quiz context to update attempt count and latest attempt
            await refreshApex(this.wiredQuizResult);
            
            // Show success toast
            const toastVariant = result.passed ? 'success' : 'warning';
            this.showToast(
                result.passed ? 'Quiz Passed!' : 'Quiz Completed',
                result.message,
                toastVariant
            );
            
        } catch (error) {
            console.error('Error submitting quiz:', error);
            const errorMessage = error.body?.message || error.message || 'An error occurred while submitting the quiz.';
            this.showToast('Submission Error', errorMessage, 'error');
        } finally {
            this.isSubmitting = false;
        }
    }
    
    /**
     * Slice 6.2: Build answers array from selectedAnswers map
     */
    buildAnswersArray() {
        const answers = [];
        
        this.selectedAnswers.forEach((optionId, questionId) => {
            answers.push({
                questionId: questionId,
                selectedOptionId: optionId
            });
        });
        
        return answers;
    }
    
    /**
     * Slice 6.2: Handle retake quiz
     */
    async handleRetakeQuiz() {
        // Clear selected answers
        this.selectedAnswers.clear();
        
        // Clear results
        this.showResults = false;
        this.latestGradingResult = null;
        this.validationError = '';
        
        // Refresh quiz context to get updated attempt count
        await refreshApex(this.wiredQuizResult);
        
        // Scroll to top
        window.scrollTo(0, 0);
    }
    
    /**
     * Helper to show toast messages
     */
    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({
            title: title,
            message: message,
            variant: variant
        }));
    }
    
    /**
     * Check if quiz exists
     */
    get hasQuiz() {
        return this.quizContext != null;
    }
    
    /**
     * Check if quiz has questions
     */
    get hasQuestions() {
        return this.quizContext && 
               this.quizContext.questions && 
               this.quizContext.questions.length > 0;
    }
    
    /**
     * Get formatted passing score
     */
    get passingScoreFormatted() {
        return this.quizContext && this.quizContext.passingScore 
            ? `${this.quizContext.passingScore}%` 
            : 'N/A';
    }
    
    /**
     * Get formatted max score
     */
    get maxScoreFormatted() {
        return this.quizContext && this.quizContext.maxScore 
            ? `${this.quizContext.maxScore} points` 
            : 'N/A';
    }
    
    /**
     * Check if learner has previous attempts
     */
    get hasPreviousAttempts() {
        return this.quizContext && this.quizContext.attemptCount > 0;
    }
    
    /**
     * Get attempt count display
     */
    get attemptCountDisplay() {
        if (!this.quizContext) return '';
        
        const count = this.quizContext.attemptCount || 0;
        const max = this.quizContext.maxAttempts || 0;
        
        if (max > 0) {
            return `Attempt ${count} of ${max}`;
        } else {
            return count === 0 ? 'No attempts yet' : `${count} attempt${count === 1 ? '' : 's'}`;
        }
    }
    
    /**
     * Check if latest attempt passed
     */
    get latestAttemptPassed() {
        return this.quizContext && 
               this.quizContext.latestAttempt && 
               this.quizContext.latestAttempt.passed;
    }
    
    /**
     * Get latest attempt score display
     */
    get latestAttemptScoreDisplay() {
        if (!this.quizContext || !this.quizContext.latestAttempt) return '';
        
        const attempt = this.quizContext.latestAttempt;
        return `${attempt.scorePercent}% (${attempt.score}/${this.quizContext.maxScore} points)`;
    }
    
    /**
     * Get error message
     */
    get errorMessage() {
        if (!this.error) return '';
        
        if (this.error.body && this.error.body.message) {
            return this.error.body.message;
        } else if (this.error.message) {
            return this.error.message;
        }
        return 'An unknown error occurred while loading the quiz.';
    }
    
    /**
     * Slice 6.2: Check if option is selected
     */
    isOptionSelected(questionId, optionId) {
        return this.selectedAnswers.get(questionId) === optionId;
    }
    
    /**
     * Slice 6.2: Get questions answered count
     */
    get questionsAnsweredCount() {
        return this.selectedAnswers.size;
    }
    
    /**
     * Slice 6.2: Get total questions count
     */
    get totalQuestionsCount() {
        return this.quizContext?.questions?.length || 0;
    }
    
    /**
     * Slice 6.2: Get progress display (X of Y questions answered)
     */
    get progressDisplay() {
        return `${this.questionsAnsweredCount} of ${this.totalQuestionsCount} questions answered`;
    }
    
    /**
     * Slice 6.2: Check if all required questions are answered
     */
    get canSubmit() {
        if (!this.quizContext || !this.quizContext.questions) {
            return false;
        }
        
        for (let question of this.quizContext.questions) {
            if (question.required && !this.selectedAnswers.has(question.questionId)) {
                return false;
            }
        }
        
        return this.selectedAnswers.size > 0;
    }
    
    /**
     * Slice 6.2: Check if retake is allowed
     */
    get canRetake() {
        if (!this.quizContext) {
            return false;
        }
        
        // Check if retakes are allowed
        if (!this.quizContext.allowRetakes) {
            return false;
        }
        
        // Check if max attempts reached
        const maxAttempts = this.quizContext.maxAttempts || 0;
        const attemptCount = this.quizContext.attemptCount || 0;
        
        if (maxAttempts > 0 && attemptCount >= maxAttempts) {
            return false;
        }
        
        return true;
    }
    
    /**
     * Slice 6.2: Format score display for results
     */
    get resultsScoreDisplay() {
        if (!this.latestGradingResult) return '';
        
        const score = this.latestGradingResult.score || 0;
        const maxScore = this.quizContext?.maxScore || 0;
        const percent = this.latestGradingResult.scorePercent || 0;
        
        return `${score} of ${maxScore} points (${Math.round(percent)}%)`;
    }
}