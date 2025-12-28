//
// SPDX-License-Identifier: MIT
// TrailForge — Open Source under the MIT License
// Copyright (c) 2025 Robert Davis
// See the LICENSE file in the project root for full license text.
//
import { LightningElement, api } from 'lwc';
import isGuestUser from '@salesforce/user/isGuest';
import getLessonContext from '@salesforce/apex/LessonPlayerController.getLessonContext';
import getLessonContextGuest from '@salesforce/apex/LessonPlayerGuestController.getLessonContext';
import markLessonCompleted from '@salesforce/apex/ProgressService.markLessonCompleted';
import markLessonCompletedGuest from '@salesforce/apex/ProgressGuestService.markLessonCompleted';
import markLessonStarted from '@salesforce/apex/ProgressService.markLessonStarted';
import markLessonStartedGuest from '@salesforce/apex/ProgressGuestService.markLessonStarted';
import isModuleCompleted from '@salesforce/apex/ProgressService.isModuleCompleted';
import isModuleCompletedGuest from '@salesforce/apex/ProgressGuestService.isModuleCompleted';
import getLessonQuizContext from '@salesforce/apex/QuizService.getLessonQuizContext';
import getLessonQuizContextGuest from '@salesforce/apex/QuizGuestService.getLessonQuizContext';
import getModuleQuizContext from '@salesforce/apex/QuizService.getModuleQuizContext';
import getModuleQuizContextGuest from '@salesforce/apex/QuizGuestService.getModuleQuizContext';
import getCourseQuizContext from '@salesforce/apex/QuizService.getCourseQuizContext';
import getCourseQuizContextGuest from '@salesforce/apex/QuizGuestService.getCourseQuizContext';

export default class LessonPlayer extends LightningElement {
    @api courseId;
    @api contactId;
    @api enrollmentId;
    
    // Track if user is guest
    isGuest = isGuestUser;
    
    // Design attributes for lesson modal
    @api hideCompleteButton = false; // When false, shows complete button
    @api modalSize = 'medium';
    
    // Computed property to pass to child
    get showCompleteButton() {
        return !this.hideCompleteButton;
    }

    lessonContext; // Contains: { courseName, enrollmentId, modules: [...], courseQuizId }
    selectedLesson;
    selectedLessonId;
    quizContext; // Quiz data for current lesson/module/course
    
    // Track which type of quiz we're loading/showing
    currentQuizType = 'lesson'; // 'lesson', 'module', or 'course'
    currentQuizModuleId = null; // For module-level quizzes
    
    showLessonModal = false;
    showQuizModal = false;
    isLoading = false;
    error;

    // Guard to prevent duplicate quiz loads
    _currentlyLoadingQuizForLesson;

    connectedCallback() {
        if (this.courseId && this.contactId) {
            this.loadLessonContext();
        }
    }

    /**
     * Load the full course structure (modules/lessons)
     */
    loadLessonContext() {
        this.isLoading = true;
        this.error = null;

        // Use guest controller for guest users
        const contextPromise = this.isGuest
            ? getLessonContextGuest({ courseId: this.courseId, contactId: this.contactId })
            : getLessonContext({ courseId: this.courseId, contactId: this.contactId });

        contextPromise
            .then(result => {
                console.log('=== RAW lessonContext from Apex ===');
                console.log('Raw result:', JSON.stringify(result, null, 2));
                console.log('Modules count:', result?.modules?.length);
                
                // Check for duplicate lessons across modules
                if (result?.modules) {
                    const allLessonIds = [];
                    result.modules.forEach((module, moduleIdx) => {
                        console.log(`Module ${moduleIdx}: ${module.moduleName}, Lessons: ${module.lessons?.length}`);
                        module.lessons?.forEach((lesson, lessonIdx) => {
                            console.log(`  Lesson ${lessonIdx}: ${lesson.lessonId} - ${lesson.lessonName}`);
                            if (allLessonIds.includes(lesson.lessonId)) {
                                console.error(`⚠️ DUPLICATE LESSON FOUND: ${lesson.lessonId} - ${lesson.lessonName}`);
                            }
                            allLessonIds.push(lesson.lessonId);
                        });
                    });
                }
                
                this.lessonContext = this.processLessonContext(result);
                this.setInitialSelectedLesson(this.lessonContext);
                this.isLoading = false;
            })
            .catch(error => {
                this.error = error.body ? error.body.message : 'Error loading course';
                this.isLoading = false;
            });
    }

    /**
     * Process raw lesson context from server
     * Add UI helpers like rowClass, isCompleted flags
     */
    processLessonContext(context) {
        if (!context || !context.modules) return context;

        const processed = {
            ...context,
            modules: context.modules.map(module => {
                // Deduplicate lessons within each module
                const seenLessonIds = new Set();
                const uniqueLessons = [];
                
                if (module.lessons) {
                    module.lessons.forEach(lesson => {
                        if (!seenLessonIds.has(lesson.lessonId)) {
                            seenLessonIds.add(lesson.lessonId);
                            uniqueLessons.push({
                                ...lesson,
                                isCompleted: lesson.status === 'Completed',
                                rowClass: 'tf-lesson-row'
                            });
                        } else {
                            console.warn('Duplicate lesson removed:', lesson.lessonId, lesson.lessonName);
                        }
                    });
                }
                
                return {
                    ...module,
                    lessons: uniqueLessons
                };
            })
        };

        return processed;
    }

    /**
     * Auto-select the first incomplete lesson (or first lesson if all complete)
     */
    setInitialSelectedLesson(context) {
        if (!context || !context.modules) return;

        let firstLesson = null;
        let firstIncompleteLesson = null;

        for (const module of context.modules) {
            if (!module.lessons || module.lessons.length === 0) continue;
            
            for (const lesson of module.lessons) {
                if (!firstLesson) {
                    firstLesson = lesson;
                }
                if (!lesson.isCompleted && !firstIncompleteLesson) {
                    firstIncompleteLesson = lesson;
                    break;
                }
            }
            if (firstIncompleteLesson) break;
        }

        const lessonToSelect = firstIncompleteLesson || firstLesson;
        if (lessonToSelect) {
            this.selectLesson(lessonToSelect.lessonId);
        }
    }

    /**
     * Handle lesson selection from tree
     */
    handleLessonSelect(event) {
        const lessonId = event.currentTarget.dataset.lessonId;
        this.selectLesson(lessonId);
    }

    /**
     * Set the selected lesson and update row classes
     */
    selectLesson(lessonId) {
        this.selectedLessonId = lessonId;
        
        // Find the lesson object
        for (const module of this.lessonContext.modules) {
            for (const lesson of module.lessons) {
                if (lesson.lessonId === lessonId) {
                    this.selectedLesson = lesson;
                    lesson.rowClass = 'tf-lesson-row tf-lesson-row--selected';
                } else {
                    lesson.rowClass = 'tf-lesson-row';
                }
            }
        }

        // Load quiz context if lesson has a quiz
        this.loadQuizContext(lessonId);
        
        // Close any open modals when selecting a new lesson
        this.showLessonModal = false;
        this.showQuizModal = false;
    }

    /**
     * Load quiz data for a lesson (if it has one)
     */
    loadQuizContext(lessonId) {
        if (!lessonId || !this.contactId) {
            this.quizContext = null;
            return;
        }

        // Guard: prevent loading the same quiz multiple times
        if (this._currentlyLoadingQuizForLesson === lessonId) {
            return;
        }

        this._currentlyLoadingQuizForLesson = lessonId;

        const enrollmentId = this.lessonContext ? this.lessonContext.enrollmentId : null;

        console.log('=== loadQuizContext ===');
        console.log('lessonId:', lessonId);
        console.log('contactId:', this.contactId);
        console.log('enrollmentId:', enrollmentId);
        console.log('isGuest:', this.isGuest);

        // Use guest version for guest users
        const quizContextMethod = this.isGuest ? getLessonQuizContextGuest : getLessonQuizContext;

        quizContextMethod({ 
            lessonId: lessonId, 
            contactId: this.contactId,
            enrollmentId: enrollmentId
        })
            .then(result => {
                console.log('Quiz context loaded:', result);
                this.quizContext = result ? JSON.parse(JSON.stringify(result)) : null;
                this._currentlyLoadingQuizForLesson = null;
                console.log('canTakeQuiz after load:', this.canTakeQuiz);
            })
            .catch(error => {
                console.error('Error loading quiz:', error);
                this.quizContext = null;
                this._currentlyLoadingQuizForLesson = null;
            });
    }

    // ========== COMPUTED PROPERTIES ==========

    get hasModules() {
        return this.lessonContext && this.lessonContext.modules && this.lessonContext.modules.length > 0;
    }

    get hasSelectedLesson() {
        return this.selectedLesson != null;
    }

    get selectedLessonName() {
        return this.selectedLesson?.lessonName || '';
    }

    /**
     * Determine if "Start Lesson" button should show
     * Show if lesson has content (not quiz-only)
     */
    get canStartLesson() {
        if (!this.selectedLesson) return false;
        
        // For now, assume all lessons have content unless they're marked quiz-only
        // You can add a Lesson_Type__c field check here if needed:
        // return this.selectedLesson.lessonType !== 'QuizOnly';
        
        return true; // Default: show Start Lesson for all
    }

    /**
     * Determine if "Take Quiz" button should show
     * Show if lesson has a quiz
     */
    get canTakeQuiz() {
        if (!this.selectedLesson) return false;
        
        // Check if quizContext has data or if lesson has a quizId
        const hasQuiz = this.quizContext != null || this.selectedLesson.quizId != null;
        console.log('canTakeQuiz evaluated:', hasQuiz, 'quizContext:', !!this.quizContext, 'quizId:', this.selectedLesson.quizId);
        return hasQuiz;
    }

    /**
     * Determine if course has a course-level quiz
     */
    get hasCourseQuiz() {
        return this.lessonContext?.courseQuizId != null;
    }

    // ========== BUTTON HANDLERS ==========

    handleStartLesson() {
        console.log('=== handleStartLesson clicked ===');
        console.log('showLessonModal before:', this.showLessonModal);
        console.log('selectedLessonId:', this.selectedLessonId);
        console.log('selectedLessonName:', this.selectedLessonName);
        
        if (this.showLessonModal) {
            console.warn('Modal already showing! This might be a double-click.');
            return;
        }
        
        // Mark lesson as In Progress when starting (use guest version for guest users)
        if (this.enrollmentId && this.selectedLessonId && this.selectedLesson?.status !== 'Completed') {
            const startMethod = this.isGuest ? markLessonStartedGuest : markLessonStarted;
            
            startMethod({
                enrollmentId: this.enrollmentId,
                lessonId: this.selectedLessonId
            })
                .then(result => {
                    console.log('Lesson marked as started:', result);
                    // Update local UI state
                    if (this.selectedLesson && this.selectedLesson.status === 'Not Started') {
                        this.selectedLesson.status = 'In Progress';
                    }
                })
                .catch(error => {
                    console.error('Error marking lesson started:', error);
                    // Don't block opening the modal on error
                });
        }
        
        this.showLessonModal = true;
        console.log('showLessonModal after:', this.showLessonModal);
    }

    handleTakeQuiz() {
        console.log('=== handleTakeQuiz clicked ===');
        console.log('selectedLessonId:', this.selectedLessonId);
        console.log('quizContext:', this.quizContext);
        console.log('selectedLesson:', this.selectedLesson);
        console.log('showQuizModal before:', this.showQuizModal);
        
        // Guard: check if modal already showing
        if (this.showQuizModal) {
            console.warn('Quiz modal already showing! This might be a double-click.');
            return;
        }
        
        // Guard: ensure we have required data
        if (!this.selectedLessonId) {
            console.error('Cannot open quiz modal: selectedLessonId is missing');
            return;
        }
        
        if (!this.quizContext && !this.selectedLesson?.quizId) {
            console.error('Cannot open quiz modal: no quiz context or quizId');
            return;
        }
        
        try {
            this.currentQuizType = 'lesson';
            this.showQuizModal = true;
            console.log('showQuizModal after:', this.showQuizModal);
        } catch (error) {
            console.error('Error opening quiz modal:', error);
        }
    }

    /**
     * Handle module quiz button click
     */
    handleTakeModuleQuiz(event) {
        const moduleId = event.currentTarget.dataset.moduleId;
        console.log('=== handleTakeModuleQuiz clicked for module:', moduleId);
        
        if (this.showQuizModal) {
            console.warn('Quiz modal already showing!');
            return;
        }
        
        this.currentQuizType = 'module';
        this.currentQuizModuleId = moduleId;
        
        // Load module quiz context - use guest version for guest users
        const enrollmentId = this.lessonContext?.enrollmentId;
        const moduleQuizMethod = this.isGuest ? getModuleQuizContextGuest : getModuleQuizContext;
        
        moduleQuizMethod({
            moduleId: moduleId,
            contactId: this.contactId,
            enrollmentId: enrollmentId
        })
            .then(result => {
                console.log('Module quiz context loaded:', result);
                if (result) {
                    this.quizContext = JSON.parse(JSON.stringify(result));
                    this.showQuizModal = true;
                } else {
                    console.error('No quiz context returned for module');
                }
            })
            .catch(error => {
                console.error('Error loading module quiz:', error);
            });
    }

    /**
     * Handle course quiz button click
     */
    handleTakeCourseQuiz() {
        console.log('=== handleTakeCourseQuiz clicked ===');
        
        if (this.showQuizModal) {
            console.warn('Quiz modal already showing!');
            return;
        }
        
        this.currentQuizType = 'course';
        
        // Load course quiz context - use guest version for guest users
        const enrollmentId = this.lessonContext?.enrollmentId;
        const courseQuizMethod = this.isGuest ? getCourseQuizContextGuest : getCourseQuizContext;
        
        courseQuizMethod({
            courseId: this.courseId,
            contactId: this.contactId,
            enrollmentId: enrollmentId
        })
            .then(result => {
                console.log('Course quiz context loaded:', result);
                if (result) {
                    this.quizContext = JSON.parse(JSON.stringify(result));
                    this.showQuizModal = true;
                } else {
                    console.error('No quiz context returned for course');
                }
            })
            .catch(error => {
                console.error('Error loading course quiz:', error);
            });
    }

    handleMarkComplete() {
        if (!this.selectedLessonId || !this.contactId) return;

        // Use guest version for guest users
        const completeMethod = this.isGuest ? markLessonCompletedGuest : markLessonCompleted;
        
        completeMethod({
            lessonId: this.selectedLessonId,
            contactId: this.contactId
        })
            .then(() => {
                // Update lesson status in UI
                this.selectedLesson.status = 'Completed';
                this.selectedLesson.isCompleted = true;
                
                // Refresh module completion status
                this.loadModuleCompletionForLesson(this.selectedLesson);
            })
            .catch(error => {
                console.error('Error marking complete:', error);
            });
    }

    /**
     * Load module completion status and update UI
     */
    loadModuleCompletionForLesson(lesson) {
        // Find the module this lesson belongs to
        const module = this.lessonContext.modules.find(m => 
            m.lessons.some(l => l.lessonId === lesson.lessonId)
        );
        
        if (!module) return;

        // Use guest version for guest users
        const moduleCompletedMethod = this.isGuest ? isModuleCompletedGuest : isModuleCompleted;
        
        moduleCompletedMethod({
            moduleId: module.moduleId,
            contactId: this.contactId
        })
            .then(isCompleted => {
                // Update module completion status
                this.lessonContext = {
                    ...this.lessonContext,
                    modules: this.lessonContext.modules.map(m =>
                        m.moduleId === module.moduleId
                            ? { ...m, isModuleCompleted: isCompleted }
                            : m
                    )
                };
            })
            .catch(error => {
                console.error('Error checking module completion:', error);
            });
    }

    handleBack() {
        // Fire event to navigate back to My Learning
        const navigateBackEvent = new CustomEvent('navigatetomylearning', {
            bubbles: true,
            composed: true
        });
        this.dispatchEvent(navigateBackEvent);
    }

    // ========== MODAL EVENT HANDLERS ==========

    handleLessonModalClose() {
        console.log('=== Lesson modal closed ===');
        this.showLessonModal = false;
    }

    handleQuizModalClose() {
        console.log('=== Quiz modal closed ===');
        this.showQuizModal = false;
        
        // Refresh lesson context AFTER modal closes to update completion status
        this.loadLessonContext();
    }

    /**
     * Fired when lesson modal is completed (user clicked Complete button)
     */
    handleLessonComplete(event) {
        console.log('=== handleLessonComplete fired ===');
        console.log('event.detail:', event?.detail);
        
        this.showLessonModal = false;
        
        // Update local UI state
        if (this.selectedLesson) {
            this.selectedLesson.status = 'Completed';
            this.selectedLesson.isCompleted = true;
        }
        
        // Refresh module completion status
        if (this.selectedLesson) {
            this.loadModuleCompletionForLesson(this.selectedLesson);
        }
    }

    /**
     * Fired when quiz is successfully submitted
     * Note: Don't close modal or refresh here - let user see results first
     * The refresh will happen when user clicks Close button (handleQuizModalClose)
     */
    handleQuizComplete(event) {
        // Don't close modal - let user see results first
        // Don't refresh lesson context here - it closes the modal!
        
        // Just log the result
        const result = event.detail;
        console.log('Quiz completed:', result);
        console.log('Showing results in modal - user will click Close when ready');
    }
}
