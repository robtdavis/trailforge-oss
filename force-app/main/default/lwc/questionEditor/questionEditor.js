import { LightningElement, api } from 'lwc';
import deleteQuestion from '@salesforce/apex/QuizAdminController.deleteQuestion';
import deleteOption from '@salesforce/apex/QuizAdminController.deleteOption';

export default class QuestionEditor extends LightningElement {
    @api question;
    @api questionNumber;
    
    get displayNumber() {
        return this.questionNumber + 1;
    }
    
    get hasOptions() {
        return this.question && this.question.options && this.question.options.length > 0;
    }
    
    get radioGroupName() {
        return `question-${this.question.questionId || this.question.sortOrder}-correct`;
    }
    
    handleQuestionTextChange(event) {
        const updatedQuestion = { ...this.question, questionText: event.target.value };
        this.dispatchQuestionChanged(updatedQuestion);
    }
    
    handlePointsChange(event) {
        const updatedQuestion = { ...this.question, points: parseFloat(event.target.value) };
        this.dispatchQuestionChanged(updatedQuestion);
    }
    
    handleRequiredChange(event) {
        const updatedQuestion = { ...this.question, required: event.target.checked };
        this.dispatchQuestionChanged(updatedQuestion);
    }
    
    handleAddOption() {
        const newOption = {
            optionId: null,
            questionId: this.question.questionId,
            answerText: '',
            isCorrect: false,
            isActive: true,
            sortOrder: this.question.options ? this.question.options.length + 1 : 1
        };
        
        const options = this.question.options ? [...this.question.options] : [];
        options.push(newOption);
        
        const updatedQuestion = { ...this.question, options };
        this.dispatchQuestionChanged(updatedQuestion);
    }
    
    handleOptionTextChange(event) {
        const optionIndex = parseInt(event.target.dataset.optionIndex, 10);
        const options = [...this.question.options];
        options[optionIndex] = { ...options[optionIndex], answerText: event.target.value };
        
        const updatedQuestion = { ...this.question, options };
        this.dispatchQuestionChanged(updatedQuestion);
    }
    
    handleCorrectChange(event) {
        const optionIndex = parseInt(event.target.dataset.optionIndex, 10);
        const options = this.question.options.map((opt, idx) => ({
            ...opt,
            isCorrect: idx === optionIndex
        }));
        
        const updatedQuestion = { ...this.question, options };
        this.dispatchQuestionChanged(updatedQuestion);
    }
    
    async handleDeleteOption(event) {
        const optionIndex = parseInt(event.target.dataset.optionIndex, 10);
        const optionToDelete = this.question.options[optionIndex];
        
        // If option has ID, delete from server
        if (optionToDelete.optionId) {
            try {
                await deleteOption({ optionId: optionToDelete.optionId });
            } catch (error) {
                console.error('Error deleting option:', error);
                return;
            }
        }
        
        // Remove from local array
        const options = this.question.options.filter((_, idx) => idx !== optionIndex);
        const updatedQuestion = { ...this.question, options };
        this.dispatchQuestionChanged(updatedQuestion);
    }
    
    async handleDeleteQuestion() {
        if (this.question.questionId) {
            if (confirm('Are you sure you want to delete this question?')) {
                try {
                    await deleteQuestion({ questionId: this.question.questionId });
                    this.dispatchEvent(new CustomEvent('questiondeleted', {
                        detail: this.question
                    }));
                } catch (error) {
                    console.error('Error deleting question:', error);
                }
            }
        } else {
            // Question not yet saved, just remove from UI
            this.dispatchEvent(new CustomEvent('questiondeleted', {
                detail: this.question
            }));
        }
    }
    
    dispatchQuestionChanged(updatedQuestion) {
        this.dispatchEvent(new CustomEvent('questionchanged', {
            detail: updatedQuestion
        }));
    }
}