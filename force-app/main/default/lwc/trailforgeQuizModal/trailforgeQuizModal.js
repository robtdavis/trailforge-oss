import { LightningElement, api } from 'lwc';
import isGuestUser from '@salesforce/user/isGuest';
import submitQuizAttempt from '@salesforce/apex/QuizService.submitQuizAttempt';
import submitQuizAttemptGuest from '@salesforce/apex/QuizGuestService.submitQuizAttempt';

export default class TrailforgeQuizModal extends LightningElement {
    @api lessonId;
    @api contactId;
    @api enrollmentId;

    // Track if user is guest
    isGuest = isGuestUser;

    questions = [];
    currentQuestionIndex = 0;
    isLoading = false;
    error;
    
    // Quiz result tracking
    quizResult = null;
    showResults = false;
    
    // Training mode explanation tracking
    showingExplanation = false;

    _showModal = false;
    _quizContext = null;
    _quizInitialized = false;

    @api
    get quizContext() {
        return this._quizContext;
    }
    set quizContext(value) {
        console.log('=== trailforgeQuizModal.quizContext setter ===');
        console.log('New quizContext:', value);
        this._quizContext = value;
        
        // If modal is already showing and we just got quiz context, initialize now
        if (this._showModal && value && !this._quizInitialized) {
            console.log('Quiz context received while modal open - initializing...');
            this.initializeQuiz();
        }
    }

    @api
    get showModal() {
        return this._showModal;
    }
    set showModal(value) {
        console.log('=== trailforgeQuizModal.showModal setter ===');
        console.log('Previous value:', this._showModal);
        console.log('New value:', value);
        console.log('lessonId:', this.lessonId);
        console.log('quizContext:', this._quizContext);
        
        this._showModal = value;
        
        // Reset initialization flag when modal opens
        if (value) {
            this._quizInitialized = false;
        }
        
        if (value && this._quizContext) {
            console.log('Initializing quiz...');
            this.initializeQuiz();
        } else if (value && !this._quizContext) {
            console.log('Modal opened but quizContext not yet available - waiting for it...');
        }
    }

    /**
     * Initialize quiz from quizContext
     */
    initializeQuiz() {
        console.log('=== initializeQuiz called ===');
        console.log('quizContext:', this._quizContext);
        console.log('quizContext type:', typeof this._quizContext);
        console.log('questions:', this._quizContext?.questions);
        console.log('questions length:', this._quizContext?.questions?.length);
        
        if (!this._quizContext) {
            console.error('Cannot initialize quiz: quizContext is null/undefined');
            this.error = 'No quiz data available';
            return;
        }
        
        if (!this._quizContext.questions || !Array.isArray(this._quizContext.questions)) {
            console.error('Cannot initialize quiz: questions is not an array');
            console.error('quizContext structure:', JSON.stringify(this._quizContext, null, 2));
            this.error = 'Quiz data is in an invalid format';
            return;
        }
        
        if (this._quizContext.questions.length === 0) {
            console.error('Cannot initialize quiz: questions array is empty');
            this.error = 'No questions available for this quiz';
            return;
        }

        try {
            // Transform questions into format with answer choices for radio group
            this.questions = this._quizContext.questions.map((q, idx) => {
                console.log(`Processing question ${idx + 1}:`, q);
                
                // Check for options (correct property name from Apex)
                if (!q.options || !Array.isArray(q.options)) {
                    console.error(`Question ${idx + 1} has invalid options:`, q.options);
                    throw new Error(`Question ${idx + 1} is missing valid answer options`);
                }
                
                if (q.options.length === 0) {
                    console.error(`Question ${idx + 1} has no answer options`);
                    throw new Error(`Question ${idx + 1} has no answer options`);
                }
                
                return {
                    questionId: q.questionId,
                    questionText: q.questionText,
                    selectedAnswerId: null,
                    explanation: q.explanation, // Explanation for Training mode
                    answerChoices: q.options.map(a => ({
                        label: a.answerText,
                        value: a.optionId  // Changed from answerId to optionId
                    }))
                };
            });

            console.log('Quiz initialized successfully with', this.questions.length, 'questions');
            console.log('First question:', this.questions[0]);
            this.currentQuestionIndex = 0;
            this.error = null;
            this._quizInitialized = true;
        } catch (error) {
            console.error('Error transforming quiz questions:', error);
            console.error('Error stack:', error.stack);
            this.error = 'Failed to load quiz questions: ' + error.message;
        }
    }

    // ========== COMPUTED PROPERTIES ==========

    get quizTitle() {
        return this._quizContext ? this._quizContext.quizName : 'Quiz';
    }

    get hasQuestions() {
        return this.questions && this.questions.length > 0;
    }

    get currentQuestion() {
        return this.hasQuestions ? this.questions[this.currentQuestionIndex] : {};
    }

    get currentQuestionNumber() {
        return this.currentQuestionIndex + 1;
    }

    get totalQuestions() {
        return this.questions.length;
    }

    get isFirstQuestion() {
        return this.currentQuestionIndex === 0;
    }

    get isLastQuestion() {
        return this.currentQuestionIndex === this.questions.length - 1;
    }

    /**
     * Computed property for modal section class
     */
    get modalSectionClass() {
        return 'slds-modal slds-fade-in-open';
    }

    /**
     * Computed property for modal container class based on quiz's modal size
     * Default is 'large' for quizzes
     */
    get modalContainerClass() {
        const size = this._quizContext?.modalSize || 'large';
        
        let sizeClass = '';
        switch(size) {
            case 'medium':
                sizeClass = 'slds-modal_medium';
                break;
            case 'x-large':
                sizeClass = 'slds-modal_x-large';
                break;
            default:
                sizeClass = 'slds-modal_large';
        }
        return `slds-modal__container ${sizeClass}`;
    }

    /**
     * Disable Next if current question hasn't been answered
     */
    get isNextDisabled() {
        return !this.currentQuestion.selectedAnswerId;
    }

    /**
     * Disable Submit if any question is unanswered
     */
    get isSubmitDisabled() {
        return this.questions.some(q => !q.selectedAnswerId);
    }
    
    /**
     * Check if we should show the quiz questions (not showing results)
     */
    get showQuizQuestions() {
        return !this.showResults && !this.isLoading && !this.error;
    }
    
    /**
     * Result icon name based on pass/fail
     */
    get resultIconName() {
        return this.quizResult?.passed ? 'utility:success' : 'utility:warning';
    }
    
    /**
     * Result icon variant based on pass/fail
     */
    get resultIconVariant() {
        return this.quizResult?.passed ? 'success' : 'warning';
    }
    
    /**
     * Result heading text
     */
    get resultHeading() {
        return this.quizResult?.passed ? 'Congratulations! You Passed!' : 'Almost There - Try Again!';
    }
    
    /**
     * Result box class based on pass/fail
     */
    get resultBoxClass() {
        return this.quizResult?.passed 
            ? 'slds-box slds-theme_success slds-m-bottom_medium' 
            : 'slds-box slds-theme_warning slds-m-bottom_medium';
    }
    
    /**
     * Check if quiz is in Training mode
     */
    get isTrainingMode() {
        return this._quizContext?.mode === 'Training';
    }
    
    /**
     * Check if current question has an explanation and user has selected an answer
     */
    get canShowExplanation() {
        return this.isTrainingMode && 
               this.currentQuestion?.selectedAnswerId && 
               this.currentQuestion?.explanation;
    }
    
    /**
     * Get the current question's explanation text
     */
    get currentExplanation() {
        return this.currentQuestion?.explanation || '';
    }

    // ========== EVENT HANDLERS ==========

    handleAnswerSelect(event) {
        const selectedAnswerId = event.detail.value;
        console.log('Answer selected:', selectedAnswerId);
        
        // Update the selected answer
        this.questions[this.currentQuestionIndex].selectedAnswerId = selectedAnswerId;
        
        // Force reactivity by creating new array reference
        this.questions = [...this.questions];
        
        console.log('Current question answered:', this.currentQuestion.selectedAnswerId);
        console.log('isNextDisabled:', this.isNextDisabled);
        console.log('isSubmitDisabled:', this.isSubmitDisabled);
    }

    handlePrevious() {
        if (this.currentQuestionIndex > 0) {
            this.showingExplanation = false; // Hide explanation when navigating
            this.currentQuestionIndex--;
        }
    }

    handleNext() {
        console.log('handleNext called, current index:', this.currentQuestionIndex);
        if (this.currentQuestionIndex < this.questions.length - 1) {
            this.showingExplanation = false; // Hide explanation when navigating
            this.currentQuestionIndex++;
            console.log('Moved to question:', this.currentQuestionIndex + 1);
        }
    }
    
    /**
     * Toggle explanation display (Training mode only)
     */
    handleToggleExplanation() {
        this.showingExplanation = !this.showingExplanation;
        
        // If showing explanation, render the HTML content after DOM update
        if (this.showingExplanation) {
            // Use setTimeout to wait for the template to render
            // eslint-disable-next-line @lwc/lwc/no-async-operation
            setTimeout(() => {
                this.renderExplanationContent();
            }, 0);
        }
    }
    
    /**
     * Render HTML explanation content into the lwc:dom="manual" container
     */
    renderExplanationContent() {
        const explanationContainer = this.template.querySelector('.explanation-content');
        if (explanationContainer && this.currentExplanation) {
            explanationContainer.innerHTML = this.currentExplanation;
        }
    }

    handleSubmit() {
        if (this.isSubmitDisabled) {
            return;
        }

        this.isLoading = true;

        // Build submission payload matching Apex DTO structure
        // Apex expects: answers: [{questionId, selectedOptionIds: []}]
        const answers = this.questions.map(q => ({
            questionId: q.questionId,
            selectedOptionIds: [q.selectedAnswerId] // Wrap in array for Apex
        }));

        console.log('=== QUIZ SUBMISSION DEBUG ===');
        console.log('isGuest value:', this.isGuest);
        console.log('Using guest method:', this.isGuest ? 'YES - submitQuizAttemptGuest' : 'NO - submitQuizAttempt');
        console.log('Submitting quiz with answers:', JSON.stringify(answers, null, 2));

        // ALWAYS use guest version for Experience Sites to avoid sharing issues
        // The guest version runs "without sharing" and can access quiz records
        const submitMethod = submitQuizAttemptGuest;

        // Build request object matching Apex DTO structure
        const request = {
            quizId: this._quizContext.quizId,
            lessonId: this.lessonId,
            contactId: this.contactId,
            enrollmentId: this.enrollmentId,
            answers: answers
        };

        console.log('Request:', JSON.stringify(request, null, 2));

        submitMethod({ request: request })
            .then(result => {
                this.isLoading = false;
                
                // Store result and show results view
                this.quizResult = {
                    passed: result.passed,
                    score: result.score,
                    maxScore: result.maxScore,
                    passingScore: result.passingScore,
                    scorePercent: result.maxScore > 0 ? Math.round((result.score / result.maxScore) * 100) : 0,
                    message: result.message,
                    attemptNumber: result.attemptNumber,
                    correctCount: this.questions.filter((q, idx) => {
                        // Count how many were answered (we don't know correct count from result)
                        return q.selectedAnswerId != null;
                    }).length
                };
                this.showResults = true;

                // Fire event to parent with results
                this.dispatchEvent(new CustomEvent('quizcomplete', {
                    detail: {
                        quizId: this._quizContext.quizId,
                        lessonId: this.lessonId,
                        score: result.score,
                        maxScore: result.maxScore,
                        passed: result.passed,
                        scorePercent: this.quizResult.scorePercent
                    }
                }));
            })
            .catch(error => {
                console.error('=== QUIZ SUBMISSION ERROR ===');
                console.error('Full error object:', error);
                console.error('Error body:', error.body);
                console.error('Error message:', error.body ? error.body.message : error.message);
                this.error = error.body ? error.body.message : 'Error submitting quiz';
                this.isLoading = false;
            });
    }

    handleClose() {
        console.log('=== Quiz modal closed ===');
        this._showModal = false;
        
        // Reset quiz state
        this.currentQuestionIndex = 0;
        this.questions = [];
        this.error = null;
        this._quizInitialized = false;
        this.quizResult = null;
        this.showResults = false;
        this.showingExplanation = false;
        
        this.dispatchEvent(new CustomEvent('close'));
    }
}
