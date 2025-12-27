import { LightningElement, api, track } from 'lwc';
import isGuestUser from '@salesforce/user/isGuest';

/**
 * TrailForge App Shell - Single-page container for entire TrailForge experience
 * Manages view state and context without URL navigation
 * 
 * View States:
 * - WELCOME: Landing screen with learner selection
 * - MY_LEARNING: Course dashboard
 * - LESSON_PLAYER: Active lesson (future)
 * - QUIZ_PLAYER: Active quiz (future)
 * 
 * For guest users authenticated via access code, the contactId is retrieved
 * from sessionStorage automatically.
 */

const VIEW_STATES = {
    WELCOME: 'welcome',
    MY_LEARNING: 'myLearning',
    LESSON_PLAYER: 'lessonPlayer',
    QUIZ_PLAYER: 'quizPlayer'
};

// Session storage key used by trailforgeAccessCodeEntry
const SESSION_KEY = 'trailforge_session';

export default class TrailforgeAppShell extends LightningElement {
    // API property for initial contactId (if needed)
    @api contactId;
    
    // Track if user is guest
    isGuest = isGuestUser;
    
    // Current view state - remove @track, use simple reactive property
    currentView = VIEW_STATES.WELCOME;
    
    // Context object passed to child components
    @track context = {
        contactId: null,
        courseId: null,
        lessonId: null,
        quizId: null,
        enrollmentId: null
    };
    
    // Review mode state
    @track quizReviewMode = false;
    @track quizReviewAttemptId = null;
    
    /**
     * Lifecycle - initialize with contactId if provided or from session for guest users
     */
    connectedCallback() {
        try {
            console.log('=== TRAILFORGE APP SHELL CONNECTED ===');
            console.log('trailforgeAppShell.connectedCallback - contactId:', this.contactId);
            console.log('trailforgeAppShell.connectedCallback - isGuest:', this.isGuest);
            console.log('trailforgeAppShell.connectedCallback - currentView:', this.currentView);
            
            let effectiveContactId = this.contactId;
            
            // For guest users, check if we have an authenticated session from access code
            if (this.isGuest && !effectiveContactId) {
                const sessionData = this.getAccessCodeSession();
                if (sessionData && sessionData.contactId) {
                    effectiveContactId = sessionData.contactId;
                    console.log('Guest user - using contactId from access code session:', effectiveContactId);
                }
            }
            
            if (effectiveContactId) {
                this.context = { ...this.context, contactId: effectiveContactId };
            }
            console.log('trailforgeAppShell.connectedCallback - context:', JSON.stringify(this.context));
            console.log('=== APP SHELL INITIALIZED SUCCESSFULLY ===');
        } catch (error) {
            console.error('ERROR in trailforgeAppShell.connectedCallback:', error);
            console.error('Error stack:', error.stack);
        }
    }
    
    /**
     * Get session data from access code authentication
     */
    getAccessCodeSession() {
        try {
            const sessionJson = sessionStorage.getItem(SESSION_KEY);
            if (sessionJson) {
                return JSON.parse(sessionJson);
            }
        } catch (e) {
            console.error('Error reading access code session:', e);
        }
        return null;
    }
    
    errorCallback(error, stack) {
        console.error('=== ERROR BOUNDARY CAUGHT ERROR ===');
        console.error('Error:', error);
        console.error('Stack:', stack);
    }
    
    /**
     * View state getters
     */
    get isWelcome() {
        return this.currentView === VIEW_STATES.WELCOME;
    }
    
    get isMyLearning() {
        return this.currentView === VIEW_STATES.MY_LEARNING;
    }
    
    get isLessonPlayer() {
        return this.currentView === VIEW_STATES.LESSON_PLAYER;
    }
    
    get isQuizPlayer() {
        return this.currentView === VIEW_STATES.QUIZ_PLAYER;
    }
    
    /**
     * Event Handlers - Listen to custom events from children
     */
    
    /**
     * Welcome -> My Learning transition
     * Fired when user clicks "Continue to My Learning"
     * Event detail: { contactId }
     */
    handleNavigateToMyLearning(event) {
        console.log('=== handleNavigateToMyLearning CALLED ===');
        console.log('Event:', event);
        console.log('Event detail:', event?.detail);
        
        const contactId = event?.detail?.contactId;
        console.log('ContactId extracted:', contactId);
        console.log('Current view BEFORE:', this.currentView);
        console.log('VIEW_STATES.MY_LEARNING value:', VIEW_STATES.MY_LEARNING);
        console.log('VIEW_STATES.WELCOME value:', VIEW_STATES.WELCOME);
        
        // Replace the whole context object
        this.context = {
            contactId: contactId,
            courseId: null,
            lessonId: null,
            quizId: null,
            enrollmentId: null
        };
        console.log('Context updated:', JSON.stringify(this.context));
        
        // Force view change
        this.currentView = VIEW_STATES.MY_LEARNING;
        console.log('Current view AFTER:', this.currentView);
        console.log('isMyLearning getter:', this.isMyLearning);
        console.log('isWelcome getter:', this.isWelcome);
        console.log('=== handleNavigateToMyLearning COMPLETE ===');
    }
    
    /**
     * My Learning -> Welcome transition
     * Fired when user clicks "Back to Welcome"
     */
    handleNavigateToWelcome(event) {
        // Optionally preserve contactId or clear it
        const preserveContact = event.detail?.preserveContact !== false;
        if (!preserveContact) {
            // Clear the entire context to reset the app state
            this.context = {
                contactId: null,
                courseId: null,
                lessonId: null,
                quizId: null,
                enrollmentId: null
            };
        }
        this.currentView = VIEW_STATES.WELCOME;
    }
    
    /**
     * My Learning -> Lesson Player transition
     * Fired when user clicks "Continue Learning" on a course
     * Event detail: { courseId, enrollmentId }
     */
    handleNavigateToLessonPlayer(event) {
        console.log('=== handleNavigateToLessonPlayer CALLED ===');
        console.log('event.detail:', event.detail);
        console.log('courseId:', event.detail.courseId);
        console.log('enrollmentId:', event.detail.enrollmentId);
        
        this.context = {
            ...this.context,
            courseId: event.detail.courseId,
            enrollmentId: event.detail.enrollmentId
        };
        
        console.log('context updated:', JSON.stringify(this.context));
        this.currentView = VIEW_STATES.LESSON_PLAYER;
        console.log('=== handleNavigateToLessonPlayer COMPLETE ===');
    }
    
    /**
     * Lesson Player -> My Learning transition
     * Fired when user clicks "Back to My Courses" or "Back" button
     */
    handleNavigateBackToMyLearning() {
        // Clear course/lesson context
        this.context = {
            ...this.context,
            courseId: null,
            lessonId: null,
            quizId: null
        };
        this.currentView = VIEW_STATES.MY_LEARNING;
    }
    
    /**
     * Lesson Player -> My Learning transition (Back button)
     * Fired when user clicks "Back" in lesson player header
     */
    handleBackFromLesson() {
        this.handleNavigateBackToMyLearning();
    }
    
    /**
     * Lesson Player -> Quiz Player transition
     * Fired when user clicks "Take Quiz" in lesson player
     * Event detail: { quizId, lessonId }
     */
    handleStartQuiz(event) {
        this.context = {
            ...this.context,
            quizId: event.detail.quizId,
            lessonId: event.detail.lessonId
        };
        this.quizReviewMode = false;
        this.quizReviewAttemptId = null;
        this.currentView = VIEW_STATES.QUIZ_PLAYER;
    }
    
    /**
     * Lesson Player -> Quiz Player (Review Mode) transition
     * Fired when user clicks "Review Last Attempt"
     * Event detail: { attemptId, quizId, lessonId, enrollmentId }
     */
    handleReviewQuiz(event) {
        this.context = {
            ...this.context,
            quizId: event.detail.quizId,
            lessonId: event.detail.lessonId,
            enrollmentId: event.detail.enrollmentId
        };
        this.quizReviewMode = true;
        this.quizReviewAttemptId = event.detail.attemptId;
        this.currentView = VIEW_STATES.QUIZ_PLAYER;
    }
    
    /**
     * Lesson Player -> Quiz Player transition (alternative handler)
     * Event detail: { quizId, lessonId }
     */
    handleNavigateToQuizPlayer(event) {
        this.context = {
            ...this.context,
            quizId: event.detail.quizId,
            lessonId: event.detail.lessonId
        };
        this.currentView = VIEW_STATES.QUIZ_PLAYER;
    }
    
    /**
     * Quiz Player -> Lesson Player transition (future)
     */
    handleNavigateBackToLessonPlayer() {
        this.context = {
            ...this.context,
            quizId: null
        };
        this.currentView = VIEW_STATES.LESSON_PLAYER;
    }
    
    /**
     * Change learner (from any view)
     * Event detail: { contactId }
     */
    handleChangeLearner(event) {
        this.context = {
            ...this.context,
            contactId: event.detail.contactId
        };
        // Stay on current view, just update context
    }
}