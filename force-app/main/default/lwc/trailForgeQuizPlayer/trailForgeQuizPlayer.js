import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import isGuestUser from '@salesforce/user/isGuest';
import getQuizForUi from '@salesforce/apex/QuizService.getQuizForUi';
import getQuizForUiGuest from '@salesforce/apex/QuizGuestService.getQuizForUi';
import submitQuizAttempt from '@salesforce/apex/QuizService.submitQuizAttempt';
import submitQuizAttemptGuest from '@salesforce/apex/QuizGuestService.submitQuizAttempt';
import getQuizAttemptDetail from '@salesforce/apex/QuizService.getQuizAttemptDetail';

export default class TrailForgeQuizPlayer extends LightningElement {
    @api quizId;
    @api contactId;
    @api enrollmentId;
    @api lessonId;
    @api reviewMode = false;
    @api reviewAttemptId;
    
    // Track if user is guest
    isGuest = isGuestUser;
    
    @track quizContext;
    @track isLoading = true;
    @track error;
    @track selectedAnswers = {};
    @track isSubmitting = false;
    @track quizResult;
    @track attemptDetail; // For review mode
    
    connectedCallback() {
        this.loadQuiz();
    }
    
    loadQuiz() {
        if (!this.quizId || !this.contactId) {
            this.error = 'Quiz ID and Contact ID are required';
            this.isLoading = false;
            return;
        }
        
        this.isLoading = true;
        this.error = null;
        
        // Load review mode data if in review mode
        if (this.reviewMode && this.reviewAttemptId) {
            this.loadReviewData();
            return;
        }
        
        // Load normal quiz data for taking the quiz
        // Use guest version for guest users
        const quizLoadMethod = this.isGuest ? getQuizForUiGuest : getQuizForUi;
        
        quizLoadMethod({
            quizId: this.quizId,
            contactId: this.contactId,
            enrollmentId: this.enrollmentId
        })
            .then(result => {
                // Create a deep copy since cacheable methods return read-only data
                let quizData = result ? JSON.parse(JSON.stringify(result)) : null;
                
                // Transform options to lightning-radio-group format
                if (quizData && quizData.questions) {
                    quizData.questions = quizData.questions.map(q => ({
                        ...q,
                        options: q.options.map(opt => ({
                            label: opt.answerText,
                            value: opt.optionId
                        }))
                    }));
                }
                this.quizContext = quizData;
                this.isLoading = false;
            })
            .catch(err => {
                this.error = err.body ? err.body.message : 'Error loading quiz';
                this.isLoading = false;
            });
    }
    
    loadReviewData() {
        getQuizAttemptDetail({ attemptId: this.reviewAttemptId })
            .then(result => {
                this.attemptDetail = result;
                
                // Transform to quiz context format for display
                const quizData = {
                    quizId: result.quizId,
                    lessonId: result.lessonId,
                    quizName: `Review: Attempt #${result.attemptNumber}`,
                    passingScore: result.passingScore,
                    maxScore: result.maxScore,
                    questions: result.questions.map(q => {
                        // Find selected option for this question
                        const selectedOption = q.options.find(opt => opt.selected);
                        
                        return {
                            ...q,
                            options: q.options.map(opt => ({
                                label: opt.answerText,
                                value: opt.optionId,
                                selected: opt.selected,
                                correct: opt.correct
                            })),
                            selectedValue: selectedOption ? selectedOption.optionId : null
                        };
                    })
                };
                
                this.quizContext = quizData;
                
                // Pre-populate selected answers for display
                this.selectedAnswers = {};
                result.questions.forEach(q => {
                    const selectedOption = q.options.find(opt => opt.selected);
                    if (selectedOption) {
                        this.selectedAnswers[q.questionId] = selectedOption.optionId;
                    }
                });
                
                this.isLoading = false;
            })
            .catch(err => {
                this.error = err.body ? err.body.message : 'Error loading quiz attempt details';
                this.isLoading = false;
            });
    }
    
    handleAnswerSelect(event) {
        const questionId = event.currentTarget.dataset.questionId;
        const selectedValue = event.detail.value;
        
        this.selectedAnswers = {
            ...this.selectedAnswers,
            [questionId]: selectedValue
        };
    }
    
    handleSubmitQuiz() {
        if (!this.quizContext) {
            return;
        }
        
        // Validate all required questions answered
        const unansweredQuestions = this.quizContext.questions.filter(q => 
            q.required && !this.selectedAnswers[q.questionId]
        );
        
        if (unansweredQuestions.length > 0) {
            this.dispatchEvent(new ShowToastEvent({
                title: 'Validation Error',
                message: 'Please answer all required questions before submitting.',
                variant: 'error'
            }));
            return;
        }
        
        // Build submission request DTO with new structure
        const answers = this.quizContext.questions.map(q => {
            const selectedOptionId = this.selectedAnswers[q.questionId];
            if (!selectedOptionId) return null;
            
            return {
                questionId: q.questionId,
                selectedOptionIds: [selectedOptionId] // Array to support future multi-select
            };
        }).filter(a => a !== null);
        
        // Get lessonId from multiple sources (priority: @api property > quizContext)
        const lessonIdToUse = this.lessonId || this.quizContext.lessonId;
        
        const request = {
            quizId: this.quizContext.quizId,
            lessonId: lessonIdToUse, // Use the resolved lessonId
            contactId: this.contactId,
            enrollmentId: this.enrollmentId,
            answers: answers
        };
        
        this.isSubmitting = true;
        
        // Use guest version for guest users
        const submitMethod = this.isGuest ? submitQuizAttemptGuest : submitQuizAttempt;
        
        submitMethod({ request: request })
            .then(result => {
                this.quizResult = result;
                this.isSubmitting = false;
                
                // Show success/warning toast
                this.dispatchEvent(new ShowToastEvent({
                    title: result.passed ? 'Quiz Passed!' : 'Quiz Completed',
                    message: result.message,
                    variant: result.passed ? 'success' : 'warning'
                }));
                
                // Fire quizcompleted event for parent components
                this.dispatchEvent(new CustomEvent('quizcompleted', {
                    bubbles: true,
                    composed: true,
                    detail: {
                        quizId: result.quizId,
                        lessonId: result.lessonId,
                        enrollmentId: result.enrollmentId,
                        attemptId: result.attemptId,
                        score: result.score,
                        maxScore: result.maxScore,
                        passingScore: result.passingScore,
                        passed: result.passed
                    }
                }));
                
                // Reload quiz to show updated attempt info
                this.loadQuiz();
            })
            .catch(err => {
                this.error = err.body ? err.body.message : 'Error submitting quiz';
                this.isSubmitting = false;
                
                this.dispatchEvent(new ShowToastEvent({
                    title: 'Submission Error',
                    message: this.error,
                    variant: 'error'
                }));
            });
    }
    
    handleBackToLesson() {
        // Fire event to parent shell to navigate back to lesson player
        this.dispatchEvent(new CustomEvent('backtolesson', {
            bubbles: true,
            composed: true
        }));
    }
    
    get hasQuiz() {
        return this.quizContext && this.quizContext.questions && this.quizContext.questions.length > 0;
    }
    
    get hasQuizResult() {
        return this.quizResult != null;
    }
    
    get canTakeQuiz() {
        if (!this.quizContext) return false;
        
        // Check if max attempts reached
        if (this.quizContext.maxAttempts > 0 && 
            this.quizContext.attemptCount >= this.quizContext.maxAttempts) {
            return false;
        }
        
        // Check if retakes allowed
        if (!this.quizContext.allowRetakes && this.quizContext.attemptCount > 0) {
            return false;
        }
        
        return true;
    }
    
    get attemptInfo() {
        if (!this.quizContext) return '';
        
        const count = this.quizContext.attemptCount || 0;
        const max = this.quizContext.maxAttempts || 0;
        
        if (max > 0) {
            return `Attempt ${count + 1} of ${max}`;
        }
        return count === 0 ? 'First Attempt' : `Attempt ${count + 1}`;
    }
    
    get passingScoreDisplay() {
        return this.quizContext ? `${this.quizContext.passingScore}%` : 'N/A';
    }
    
    get maxScoreDisplay() {
        return this.quizContext ? `${this.quizContext.maxScore} points` : 'N/A';
    }
    
    get previousAttemptBadgeClass() {
        return this.quizContext?.latestAttempt?.passed ? 'slds-theme_success' : 'slds-theme_error';
    }
    
    get previousAttemptBadgeLabel() {
        return this.quizContext?.latestAttempt?.passed ? 'PASSED' : 'FAILED';
    }
    
    get quizTitle() {
        return this.quizContext?.quizName || 'Quiz';
    }
    
    get showSubmitButton() {
        return !this.reviewMode && !this.hasQuizResult;
    }
    
    get reviewBannerMessage() {
        if (!this.reviewMode || !this.attemptDetail) return '';
        
        const status = this.attemptDetail.passed ? 'Passed' : 'Failed';
        return `Reviewing Attempt #${this.attemptDetail.attemptNumber} – Score ${this.attemptDetail.score} / ${this.attemptDetail.maxScore} (${status})`;
    }
    
    get isAnswerDisabled() {
        return this.reviewMode;
    }
    
    getSelectedAnswer(questionId) {
        return this.selectedAnswers[questionId];
    }
}