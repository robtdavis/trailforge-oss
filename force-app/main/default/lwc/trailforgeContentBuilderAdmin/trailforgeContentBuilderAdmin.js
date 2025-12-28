//
// SPDX-License-Identifier: MIT
// TrailForge — Open Source under the MIT License
// Copyright (c) 2025 Robert Davis
// See the LICENSE file in the project root for full license text.
//
import { LightningElement, track, wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import createCourseContent from '@salesforce/apex/TrailForge_ContentBuilderController.createCourseContent';
import getAvailableQuizzes from '@salesforce/apex/TrailForge_ContentBuilderController.getAvailableQuizzes';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class TrailforgeContentBuilderAdmin extends NavigationMixin(LightningElement) {
    
    // Current wizard step (1-5)
    currentStep = '1';
    
    // Loading/saving state
    isSaving = false;
    
    // Messages
    errorMessage = '';
    successMessage = '';
    
    // Creation result for Finish screen
    @track creationResult = {
        courseId: null,
        courseName: '',
        moduleCount: 0,
        lessonCount: 0,
        quizCount: 0
    };
    
    // Quiz modal state
    showQuizModal = false;
    @track quizContext = {
        courseId: null,
        lessonId: null,
        moduleIndex: null,
        lessonIndex: null
    };
    
    // Available quizzes for selection
    @track quizOptions = [{ label: '-- None --', value: '' }];
    
    // Main data structure
    @track courseData = {
        name: '',
        description: '',
        active: true,
        modules: []
    };
    
    // Content type options for lessons
    contentTypeOptions = [
        { label: 'Markdown', value: 'Markdown' },
        { label: 'HTML', value: 'HTML' },
        { label: 'URL', value: 'URL' },
        { label: 'Video', value: 'Video' },
        { label: 'PDF', value: 'PDF' },
        { label: 'Quiz', value: 'Quiz' }
    ];
    
    // Wire available quizzes
    @wire(getAvailableQuizzes)
    wiredQuizzes({ error, data }) {
        if (data) {
            this.quizOptions = [{ label: '-- None --', value: '' }];
            data.forEach(quiz => {
                this.quizOptions.push({
                    label: `${quiz.name} (${quiz.assignedTo})`,
                    value: quiz.quizId
                });
            });
        } else if (error) {
            console.error('Error loading quizzes:', error);
        }
    }
    
    // Step getters
    get isStep1() {
        return this.currentStep === '1';
    }
    
    get isStep2() {
        return this.currentStep === '2';
    }
    
    get isStep3() {
        return this.currentStep === '3';
    }
    
    get isStep4() {
        return this.currentStep === '4';
    }
    
    get isStep5() {
        return this.currentStep === '5';
    }
    
    get hasModules() {
        return this.courseData.modules && this.courseData.modules.length > 0;
    }
    
    get courseActiveLabel() {
        return this.courseData.active ? 'Yes' : 'No';
    }
    
    get isNextDisabled() {
        if (this.currentStep === '1') {
            return !this.courseData.name || this.courseData.name.trim() === '';
        }
        if (this.currentStep === '2') {
            // Must have at least one module with a name
            return !this.hasModules || this.courseData.modules.some(m => !m.name || m.name.trim() === '');
        }
        if (this.currentStep === '3') {
            // Check all lessons have names
            for (const mod of this.courseData.modules) {
                if (mod.lessons && mod.lessons.length > 0) {
                    if (mod.lessons.some(l => !l.name || l.name.trim() === '')) {
                        return true;
                    }
                }
            }
            return false;
        }
        return false;
    }
    
    // Unique key generator
    generateKey() {
        return 'key-' + Date.now() + '-' + Math.random().toString(36).substr(2, 9);
    }
    
    // Course field handlers
    handleCourseNameChange(event) {
        this.courseData.name = event.target.value;
        this.clearMessages();
    }
    
    handleCourseDescriptionChange(event) {
        this.courseData.description = event.target.value;
    }
    
    handleCourseActiveChange(event) {
        this.courseData.active = event.target.checked;
    }
    
    // Module handlers
    handleAddModule() {
        const newModule = {
            key: this.generateKey(),
            name: '',
            summary: '',
            orderNumber: this.courseData.modules.length + 1,
            displayOrder: this.courseData.modules.length + 1,
            lessons: [],
            hasLessons: false
        };
        this.courseData.modules = [...this.courseData.modules, newModule];
    }
    
    handleDeleteModule(event) {
        const moduleIndex = parseInt(event.target.dataset.moduleIndex, 10);
        this.courseData.modules.splice(moduleIndex, 1);
        this.renumberModules();
        this.courseData = { ...this.courseData };
    }
    
    handleModuleFieldChange(event) {
        const moduleIndex = parseInt(event.target.dataset.moduleIndex, 10);
        const field = event.target.dataset.field;
        const value = event.target.value;
        
        this.courseData.modules[moduleIndex][field] = value;
        this.courseData = { ...this.courseData };
    }
    
    renumberModules() {
        this.courseData.modules.forEach((mod, index) => {
            mod.orderNumber = index + 1;
            mod.displayOrder = index + 1;
        });
    }
    
    // Lesson handlers
    handleAddLesson(event) {
        const moduleIndex = parseInt(event.target.dataset.moduleIndex, 10);
        const module = this.courseData.modules[moduleIndex];
        
        const newLesson = {
            key: this.generateKey(),
            name: '',
            orderNumber: (module.lessons ? module.lessons.length : 0) + 1,
            displayOrder: (module.lessons ? module.lessons.length : 0) + 1,
            contentType: 'Markdown',
            quizId: '',
            quizName: ''
        };
        
        if (!module.lessons) {
            module.lessons = [];
        }
        module.lessons.push(newLesson);
        module.hasLessons = true;
        
        this.courseData = { ...this.courseData };
    }
    
    handleDeleteLesson(event) {
        const moduleIndex = parseInt(event.target.dataset.moduleIndex, 10);
        const lessonIndex = parseInt(event.target.dataset.lessonIndex, 10);
        
        const module = this.courseData.modules[moduleIndex];
        module.lessons.splice(lessonIndex, 1);
        module.hasLessons = module.lessons.length > 0;
        this.renumberLessons(moduleIndex);
        
        this.courseData = { ...this.courseData };
    }
    
    handleLessonFieldChange(event) {
        const moduleIndex = parseInt(event.target.dataset.moduleIndex, 10);
        const lessonIndex = parseInt(event.target.dataset.lessonIndex, 10);
        const field = event.target.dataset.field;
        const value = event.target.value;
        
        const lesson = this.courseData.modules[moduleIndex].lessons[lessonIndex];
        lesson[field] = value;
        
        // If quiz was selected, find and set the quiz name
        if (field === 'quizId' && value) {
            const selectedQuiz = this.quizOptions.find(q => q.value === value);
            lesson.quizName = selectedQuiz ? selectedQuiz.label : '';
        } else if (field === 'quizId' && !value) {
            lesson.quizName = '';
        }
        
        this.courseData = { ...this.courseData };
    }
    
    renumberLessons(moduleIndex) {
        const module = this.courseData.modules[moduleIndex];
        if (module.lessons) {
            module.lessons.forEach((lesson, index) => {
                lesson.orderNumber = index + 1;
                lesson.displayOrder = index + 1;
            });
        }
    }
    
    // Quiz modal handlers
    handleCreateQuiz(event) {
        const moduleIndex = parseInt(event.target.dataset.moduleIndex, 10);
        const lessonIndex = parseInt(event.target.dataset.lessonIndex, 10);
        
        this.quizContext = {
            courseId: null, // Will be set after course is created
            lessonId: null, // Will be set after lesson is created
            moduleIndex: moduleIndex,
            lessonIndex: lessonIndex
        };
        
        this.showQuizModal = true;
    }
    
    handleCloseQuizModal() {
        this.showQuizModal = false;
        this.quizContext = {
            courseId: null,
            lessonId: null,
            moduleIndex: null,
            lessonIndex: null
        };
    }
    
    handleQuizCreated(event) {
        // Handle quiz created event from quizBuilderAdmin
        const quizId = event.detail.quizId;
        const quizName = event.detail.quizName;
        
        if (this.quizContext.moduleIndex !== null && this.quizContext.lessonIndex !== null) {
            const lesson = this.courseData.modules[this.quizContext.moduleIndex].lessons[this.quizContext.lessonIndex];
            lesson.quizId = quizId;
            lesson.quizName = quizName;
            this.courseData = { ...this.courseData };
        }
        
        this.handleCloseQuizModal();
        
        this.dispatchEvent(new ShowToastEvent({
            title: 'Success',
            message: 'Quiz created and assigned to lesson',
            variant: 'success'
        }));
    }
    
    // Navigation handlers
    handleNext() {
        this.clearMessages();
        
        if (this.currentStep === '1') {
            if (!this.courseData.name || this.courseData.name.trim() === '') {
                this.errorMessage = 'Please enter a course name.';
                return;
            }
            this.currentStep = '2';
        } else if (this.currentStep === '2') {
            if (!this.hasModules) {
                this.errorMessage = 'Please add at least one module.';
                return;
            }
            // Validate all modules have names
            const invalidModule = this.courseData.modules.find(m => !m.name || m.name.trim() === '');
            if (invalidModule) {
                this.errorMessage = 'All modules must have a name.';
                return;
            }
            this.currentStep = '3';
        } else if (this.currentStep === '3') {
            // Validate all lessons have names
            for (const mod of this.courseData.modules) {
                if (mod.lessons && mod.lessons.length > 0) {
                    const invalidLesson = mod.lessons.find(l => !l.name || l.name.trim() === '');
                    if (invalidLesson) {
                        this.errorMessage = 'All lessons must have a name.';
                        return;
                    }
                }
            }
            this.currentStep = '4';
        }
    }
    
    handlePrevious() {
        this.clearMessages();
        
        if (this.currentStep === '2') {
            this.currentStep = '1';
        } else if (this.currentStep === '3') {
            this.currentStep = '2';
        } else if (this.currentStep === '4') {
            this.currentStep = '3';
        }
    }
    
    // Save handler
    async handleSave() {
        this.clearMessages();
        this.isSaving = true;
        
        try {
            // Prepare the data for Apex
            const courseDTO = {
                name: this.courseData.name,
                description: this.courseData.description,
                active: this.courseData.active,
                modules: this.courseData.modules.map(mod => ({
                    name: mod.name,
                    orderNumber: mod.orderNumber,
                    summary: mod.summary,
                    lessons: (mod.lessons || []).map(lesson => ({
                        name: lesson.name,
                        orderNumber: lesson.orderNumber,
                        contentType: lesson.contentType,
                        quizId: lesson.quizId || null,
                        content: lesson.content || null
                    }))
                }))
            };
            
            const courseJson = JSON.stringify(courseDTO);
            const result = await createCourseContent({ courseJson: courseJson });
            
            if (result.success) {
                // Count quizzes assigned
                let quizCount = 0;
                this.courseData.modules.forEach(mod => {
                    if (mod.lessons) {
                        mod.lessons.forEach(lesson => {
                            if (lesson.quizId) {
                                quizCount++;
                            }
                        });
                    }
                });
                
                // Store creation result for Finish screen
                this.creationResult = {
                    courseId: result.courseId,
                    courseName: this.courseData.name,
                    moduleCount: result.moduleIds ? result.moduleIds.length : 0,
                    lessonCount: result.lessonIds ? result.lessonIds.length : 0,
                    quizCount: quizCount
                };
                
                this.dispatchEvent(new ShowToastEvent({
                    title: 'Success',
                    message: `Course "${this.courseData.name}" created successfully!`,
                    variant: 'success'
                }));
                
                // Navigate to Finish step instead of resetting
                this.currentStep = '5';
            } else {
                this.errorMessage = result.message;
            }
        } catch (error) {
            console.error('Error saving course content:', error);
            this.errorMessage = error.body ? error.body.message : error.message;
            
            this.dispatchEvent(new ShowToastEvent({
                title: 'Error',
                message: this.errorMessage,
                variant: 'error'
            }));
        } finally {
            this.isSaving = false;
        }
    }
    
    // Finish screen handlers
    handleViewCourse() {
        if (this.creationResult.courseId) {
            this[NavigationMixin.Navigate]({
                type: 'standard__recordPage',
                attributes: {
                    recordId: this.creationResult.courseId,
                    objectApiName: 'Course__c',
                    actionName: 'view'
                }
            });
        }
    }
    
    handleCreateAnother() {
        this.resetForm();
    }
    
    resetForm() {
        this.currentStep = '1';
        this.courseData = {
            name: '',
            description: '',
            active: true,
            modules: []
        };
        this.creationResult = {
            courseId: null,
            courseName: '',
            moduleCount: 0,
            lessonCount: 0,
            quizCount: 0
        };
    }
    
    clearMessages() {
        this.errorMessage = '';
        this.successMessage = '';
    }
}
