import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import saveQuiz from '@salesforce/apex/QuizAdminController.saveQuiz';
import saveQuestions from '@salesforce/apex/QuizAdminController.saveQuestions';
import archiveQuiz from '@salesforce/apex/QuizAdminController.archiveQuiz';

export default class QuizEditor extends LightningElement {
    @api quiz;
    
    @track activeSections = ['settings', 'questions'];
    
    get questionsLabel() {
        const count = this.quiz && this.quiz.questions ? this.quiz.questions.length : 0;
        return `Questions (${count})`;
    }
    
    get hasQuestions() {
        return this.quiz && this.quiz.questions && this.quiz.questions.length > 0;
    }
    
    handlePassingScoreChange(event) {
        this.quiz = { ...this.quiz, passingScore: parseFloat(event.target.value) };
    }
    
    handleMaxAttemptsChange(event) {
        this.quiz = { ...this.quiz, maxAttempts: parseInt(event.target.value, 10) };
    }
    
    handleAllowRetakesChange(event) {
        this.quiz = { ...this.quiz, allowRetakes: event.target.checked };
    }
    
    handleActiveChange(event) {
        this.quiz = { ...this.quiz, isActive: event.target.checked };
    }
    
    handleInstructionsChange(event) {
        this.quiz = { ...this.quiz, instructions: event.target.value };
    }
    
    async handleSaveSettings() {
        try {
            await saveQuiz({ quizJSON: JSON.stringify(this.quiz) });
            this.showSuccess('Settings saved successfully');
            this.dispatchEvent(new CustomEvent('quizsaved', {
                detail: { quizId: this.quiz.quizId }
            }));
        } catch (error) {
            this.showError('Error saving settings', error);
        }
    }
    
    handleAddQuestion() {
        const newQuestion = {
            questionId: null,
            quizId: this.quiz.quizId,
            questionText: '',
            questionType: 'MultipleChoice',
            points: 1,
            required: true,
            sortOrder: this.quiz.questions ? this.quiz.questions.length + 1 : 1,
            options: []
        };
        
        const questions = this.quiz.questions ? [...this.quiz.questions] : [];
        questions.push(newQuestion);
        this.quiz = { ...this.quiz, questions };
    }
    
    handleQuestionChanged(event) {
        const updatedQuestion = event.detail;
        const questions = [...this.quiz.questions];
        const index = questions.findIndex(q => 
            (q.questionId && q.questionId === updatedQuestion.questionId) ||
            (!q.questionId && q.sortOrder === updatedQuestion.sortOrder)
        );
        
        if (index !== -1) {
            questions[index] = updatedQuestion;
            this.quiz = { ...this.quiz, questions };
        }
    }
    
    handleQuestionDeleted(event) {
        const questionToDelete = event.detail;
        const questions = this.quiz.questions.filter(q => 
            q.questionId !== questionToDelete.questionId &&
            q.sortOrder !== questionToDelete.sortOrder
        );
        this.quiz = { ...this.quiz, questions };
    }
    
    async handleSaveAllQuestions() {
        try {
            await saveQuestions({
                quizId: this.quiz.quizId,
                questionDTOs: this.quiz.questions
            });
            this.showSuccess('All questions saved successfully');
            this.dispatchEvent(new CustomEvent('quizsaved', {
                detail: { quizId: this.quiz.quizId }
            }));
        } catch (error) {
            this.showError('Error saving questions', error);
        }
    }
    
    async handleArchiveQuiz() {
        if (confirm('Are you sure you want to archive this quiz?')) {
            try {
                await archiveQuiz({ quizId: this.quiz.quizId, isArchived: true });
                this.dispatchEvent(new CustomEvent('quizdeleted'));
            } catch (error) {
                this.showError('Error archiving quiz', error);
            }
        }
    }
    
    showSuccess(message) {
        this.dispatchEvent(new ShowToastEvent({
            title: 'Success',
            message,
            variant: 'success'
        }));
    }
    
    showError(title, error) {
        let message = 'An error occurred';
        if (error && error.body && error.body.message) {
            message = error.body.message;
        } else if (typeof error === 'string') {
            message = error;
        }
        
        this.dispatchEvent(new ShowToastEvent({
            title,
            message,
            variant: 'error',
            mode: 'sticky'
        }));
    }
}