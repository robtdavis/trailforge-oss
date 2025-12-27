import { LightningElement, api } from 'lwc';
import isGuestUser from '@salesforce/user/isGuest';
import getSanitizedContent from '@salesforce/apex/ContentRenderingService.getSanitizedContent';
import getSanitizedContentGuest from '@salesforce/apex/ContentRenderingGuestService.getSanitizedContent';
import markLessonCompleted from '@salesforce/apex/ProgressService.markLessonCompleted';
import markLessonCompletedGuest from '@salesforce/apex/ProgressGuestService.markLessonCompleted';

export default class TrailforgeLessonModal extends LightningElement {
    @api lessonId;
    @api lessonName;
    @api contactId;
    @api enrollmentId;
    
    // Track if user is guest
    isGuest = isGuestUser;
    
    // Design attributes (fallbacks if lesson doesn't specify)
    @api showCompleteButton = false; // Hidden by default
    @api modalSize = 'medium'; // Options: medium, large, x-large
    
    // Internal values from lesson record (take priority over design attributes)
    _lessonModalSize = null;
    _lessonShowCompleteButton = null; // null means use design attribute

    slides = []; // Array of slide objects
    currentSlideIndex = 0;
    isLoading = false;
    isCompleting = false; // Track completion in progress
    error;
    _isMarkdown = false; // Track if content is markdown

    // External content properties
    _isExternal = false;
    _externalUrl = null;
    _contentType = null;

    _showModal = false;

    @api
    get showModal() {
        return this._showModal;
    }
    set showModal(value) {
        console.log('=== trailforgeLessonModal.showModal setter ===');
        console.log('Previous value:', this._showModal);
        console.log('New value:', value);
        console.log('lessonId:', this.lessonId);
        
        this._showModal = value;
        if (value && this.lessonId) {
            console.log('Loading content for lessonId:', this.lessonId);
            this.loadContent();
        }
    }

    /**
     * Load content from Apex and parse into slides
     */
    loadContent() {
        console.log('=== loadContent called ===');
        console.log('lessonId:', this.lessonId);
        
        if (this.isLoading) {
            console.warn('Already loading content, skipping duplicate call');
            return;
        }
        
        this.isLoading = true;
        this.error = null;
        this.currentSlideIndex = 0;

        // Use guest controller for guest users
        const contentPromise = this.isGuest
            ? getSanitizedContentGuest({ lessonId: this.lessonId })
            : getSanitizedContent({ lessonId: this.lessonId });

        contentPromise
            .then(result => {
                console.log('Content loaded:', result);
                
                // Get settings from lesson record (take priority over design attributes)
                if (result) {
                    if (result.modalSize) {
                        this._lessonModalSize = result.modalSize;
                        console.log('Modal size from lesson:', this._lessonModalSize);
                    }
                    // Store lesson-level showCompleteButton (true/false from checkbox field)
                    if (result.showCompleteButton !== undefined && result.showCompleteButton !== null) {
                        this._lessonShowCompleteButton = result.showCompleteButton;
                        console.log('Show complete button from lesson:', this._lessonShowCompleteButton);
                    }
                    // Store content type for external content handling
                    this._contentType = result.contentType;
                }
                
                // Handle external content (Video, URL, PDF)
                if (result && result.isExternal && result.externalUrl) {
                    console.log('External content detected:', result.contentType, result.externalUrl);
                    this._isExternal = true;
                    this._externalUrl = result.externalUrl;
                    // Create a single "slide" for external content
                    this.slides = [{
                        title: this.lessonName || 'Lesson',
                        body: '',
                        isHtml: false,
                        isExternal: true,
                        externalUrl: result.externalUrl,
                        contentType: result.contentType
                    }];
                    console.log('External content slide created');
                } else if (result && result.sanitizedContent) {
                    this._isExternal = false;
                    this._externalUrl = null;
                    this.slides = this.parseContentIntoSlides(result);
                    console.log('Parsed slides count:', this.slides.length);
                    console.log('Parsed slides:', JSON.parse(JSON.stringify(this.slides)));
                } else {
                    this.slides = [];
                    this.error = 'No content available';
                }
                this.isLoading = false;
            })
            .catch(error => {
                console.error('Error loading content:', error);
                this.error = error.body ? error.body.message : 'Error loading content';
                this.isLoading = false;
            });
    }

    /**
     * Parse ContentDTO into slide array
     * For now, treats entire content as one slide
     * You can enhance this to split by delimiter (e.g., "---" or slide markers)
     */
    parseContentIntoSlides(contentDTO) {
        console.log('=== parseContentIntoSlides ===');
        console.log('contentDTO:', contentDTO);
        console.log('sanitizedContent:', contentDTO?.sanitizedContent);
        console.log('isHtml:', contentDTO?.isHtml);
        console.log('isMarkdown:', contentDTO?.isMarkdown);
        
        if (!contentDTO || !contentDTO.sanitizedContent) {
            console.error('No content to parse!');
            return [];
        }

        // Track if this is markdown content
        this._isMarkdown = contentDTO.isMarkdown || false;

        // Check if content has slide delimiters (---)
        const content = contentDTO.sanitizedContent;
        const hasDelimiters = content.includes('---');
        
        console.log('Content length:', content.length);
        console.log('Has delimiters:', hasDelimiters);

        if (!hasDelimiters) {
            // Single slide - convert markdown to HTML if needed
            let bodyContent = content;
            if (this._isMarkdown) {
                bodyContent = this.parseMarkdown(content);
            }
            
            const slide = {
                title: this.lessonName || 'Lesson',
                body: bodyContent,
                isHtml: contentDTO.isHtml || this._isMarkdown, // Treat parsed markdown as HTML
                imageUrl: null,
                imageAlt: ''
            };
            console.log('Single slide created:', slide);
            return [slide];
        }

        // Multi-slide: split by --- delimiter
        const slideTexts = content.split('---').filter(text => text.trim());
        console.log('Split into', slideTexts.length, 'slides');
        
        const slides = slideTexts.map((slideText, idx) => {
            const trimmedText = slideText.trim();
            
            // Try to extract title from first line if it looks like a heading
            let title = `Slide ${idx + 1}`;
            let body = trimmedText;
            
            // Check for markdown heading or HTML h-tag
            if (trimmedText.startsWith('#')) {
                const lines = trimmedText.split('\n');
                title = lines[0].replace(/^#+\s*/, '').trim();
                body = lines.slice(1).join('\n').trim();
            } else if (trimmedText.match(/^<h[1-6]>/i)) {
                const match = trimmedText.match(/^<h[1-6]>(.+?)<\/h[1-6]>/i);
                if (match) {
                    title = match[1];
                    body = trimmedText.replace(/^<h[1-6]>.+?<\/h[1-6]>/i, '').trim();
                }
            }

            // Convert markdown to HTML if needed
            if (this._isMarkdown) {
                body = this.parseMarkdown(body);
            }

            const slide = {
                title: title,
                body: body,
                isHtml: contentDTO.isHtml || this._isMarkdown, // Treat parsed markdown as HTML
                imageUrl: null,
                imageAlt: ''
            };
            
            console.log(`Slide ${idx + 1}:`, slide);
            return slide;
        });
        
        return slides;
    }

    // ========== COMPUTED PROPERTIES ==========

    get hasSlides() {
        return this.slides && this.slides.length > 0;
    }

    get currentSlide() {
        return this.hasSlides ? this.slides[this.currentSlideIndex] : {};
    }

    get currentSlideNumber() {
        return this.currentSlideIndex + 1;
    }

    get totalSlides() {
        return this.slides.length;
    }

    get isFirstSlide() {
        return this.currentSlideIndex === 0;
    }

    get isLastSlide() {
        return this.currentSlideIndex === this.slides.length - 1;
    }

    /**
     * Check if current slide is external content
     */
    get isExternalContent() {
        return this.currentSlide && this.currentSlide.isExternal;
    }

    /**
     * Check if current slide is a video (YouTube, Vimeo, etc.)
     */
    get isVideoContent() {
        return this.isExternalContent && this._contentType === 'Video';
    }

    /**
     * Check if current slide is a URL/iframe content
     */
    get isUrlContent() {
        return this.isExternalContent && this._contentType === 'URL';
    }

    /**
     * Check if current slide is a PDF
     */
    get isPdfContent() {
        return this.isExternalContent && (
            this._contentType === 'PDF' || 
            (this._externalUrl && this._externalUrl.toLowerCase().endsWith('.pdf'))
        );
    }

    /**
     * Get the external URL for rendering
     */
    get externalUrl() {
        return this._externalUrl;
    }

    /**
     * Get embed URL for video content (converts YouTube/Vimeo watch URLs to embed)
     */
    get videoEmbedUrl() {
        if (!this._externalUrl) return '';
        
        const url = this._externalUrl;
        
        // YouTube - convert watch URL to embed
        if (url.includes('youtube.com/watch')) {
            const videoId = this.extractYouTubeId(url);
            if (videoId) {
                return `https://www.youtube.com/embed/${videoId}`;
            }
        }
        
        // YouTube short URL
        if (url.includes('youtu.be/')) {
            const videoId = url.split('youtu.be/')[1]?.split('?')[0];
            if (videoId) {
                return `https://www.youtube.com/embed/${videoId}`;
            }
        }
        
        // Vimeo - convert to embed
        if (url.includes('vimeo.com/')) {
            const videoId = url.split('vimeo.com/')[1]?.split('?')[0];
            if (videoId) {
                return `https://player.vimeo.com/video/${videoId}`;
            }
        }
        
        // Already an embed URL or other video URL - use as-is
        return url;
    }

    /**
     * Extract YouTube video ID from various URL formats
     */
    extractYouTubeId(url) {
        // Match youtube.com/watch?v=ID format
        const match = url.match(/[?&]v=([^&]+)/);
        if (match) return match[1];
        
        // Match youtube.com/embed/ID format
        const embedMatch = url.match(/embed\/([^?&]+)/);
        if (embedMatch) return embedMatch[1];
        
        return null;
    }

    /**
     * Computed property for modal container class based on size
     * Priority: Lesson record > Design attribute > Default (medium)
     */
    get modalContainerClass() {
        // Use lesson's modal size if set, otherwise fall back to design attribute
        const effectiveSize = this._lessonModalSize || this.modalSize || 'medium';
        
        let sizeClass = '';
        switch(effectiveSize) {
            case 'large':
                sizeClass = 'slds-modal_large';
                break;
            case 'x-large':
                sizeClass = 'slds-modal_x-large';
                break;
            default:
                sizeClass = 'slds-modal_medium';
        }
        return `slds-modal__container ${sizeClass}`;
    }

    /**
     * Computed property to determine if Complete button should be shown
     * Priority: Lesson record > Design attribute > Default (false)
     * Shows on last slide only
     */
    get showCompleteButtonOnLastSlide() {
        // Use lesson's setting if available, otherwise fall back to design attribute
        const effectiveShowComplete = this._lessonShowCompleteButton !== null 
            ? this._lessonShowCompleteButton 
            : this.showCompleteButton;
        return this.isLastSlide && effectiveShowComplete;
    }

    /**
     * Show Close button on last slide when Complete button is hidden
     */
    get showCloseButtonOnLastSlide() {
        // Use lesson's setting if available, otherwise fall back to design attribute
        const effectiveShowComplete = this._lessonShowCompleteButton !== null 
            ? this._lessonShowCompleteButton 
            : this.showCompleteButton;
        return this.isLastSlide && !effectiveShowComplete;
    }

    /**
     * After render, inject HTML content into the slide body container
     */
    renderedCallback() {
        if (this.hasSlides && this.currentSlide.isHtml && this.currentSlide.body) {
            const container = this.template.querySelector('.slide-body-content');
            if (container) {
                container.innerHTML = this.currentSlide.body;
            }
        }
    }
    // ========== EVENT HANDLERS ==========

    handlePrevious() {
        if (this.currentSlideIndex > 0) {
            this.currentSlideIndex--;
        }
    }

    handleNext() {
        if (this.currentSlideIndex < this.slides.length - 1) {
            this.currentSlideIndex++;
        }
    }

    /**
     * Handle lesson completion - marks progress in database
     */
    async handleComplete() {
        if (!this.enrollmentId || !this.lessonId) {
            console.warn('Cannot complete lesson: missing enrollmentId or lessonId');
            // Still fire event and close for graceful degradation
            this.dispatchEvent(new CustomEvent('lessoncomplete', {
                detail: { lessonId: this.lessonId, success: false }
            }));
            this.handleClose();
            return;
        }

        this.isCompleting = true;
        
        try {
            // Call Apex to mark lesson as completed (use guest version for guest users)
            const completeMethod = this.isGuest ? markLessonCompletedGuest : markLessonCompleted;
            const result = await completeMethod({
                enrollmentId: this.enrollmentId,
                lessonId: this.lessonId
            });
            
            console.log('Lesson marked complete:', result);
            
            // Fire event to parent indicating lesson was completed successfully
            this.dispatchEvent(new CustomEvent('lessoncomplete', {
                detail: { 
                    lessonId: this.lessonId,
                    enrollmentId: this.enrollmentId,
                    progressId: result.progressId,
                    success: true
                }
            }));
            
        } catch (error) {
            console.error('Error completing lesson:', error);
            // Still fire event but indicate failure
            this.dispatchEvent(new CustomEvent('lessoncomplete', {
                detail: { 
                    lessonId: this.lessonId,
                    success: false,
                    error: error.body ? error.body.message : error.message
                }
            }));
        } finally {
            this.isCompleting = false;
            this.handleClose();
        }
    }

    handleClose() {
        this._showModal = false;
        // Reset state when closing to prevent issues on re-open
        this.currentSlideIndex = 0;
        this.slides = [];
        this.error = null;
        this._isMarkdown = false;
        this._isExternal = false;
        this._externalUrl = null;
        this._contentType = null;
        this._lessonModalSize = null; // Reset lesson-specific modal size
        this._lessonShowCompleteButton = null; // Reset lesson-specific setting
        this.dispatchEvent(new CustomEvent('close'));
    }

    /**
     * Handle close on last slide when Complete button is hidden
     * Auto-marks the lesson as complete since user viewed all slides
     */
    async handleCloseAndComplete() {
        if (!this.enrollmentId || !this.lessonId) {
            console.warn('Cannot auto-complete lesson: missing enrollmentId or lessonId');
            // Still fire event and close
            this.dispatchEvent(new CustomEvent('lessoncomplete', {
                detail: { lessonId: this.lessonId, success: false }
            }));
            this.handleClose();
            return;
        }

        try {
            // Call Apex to mark lesson as completed (use guest version for guest users)
            const completeMethod = this.isGuest ? markLessonCompletedGuest : markLessonCompleted;
            const result = await completeMethod({
                enrollmentId: this.enrollmentId,
                lessonId: this.lessonId
            });
            
            console.log('Lesson auto-completed on close:', result);
            
            // Fire event to parent indicating lesson was completed
            this.dispatchEvent(new CustomEvent('lessoncomplete', {
                detail: { 
                    lessonId: this.lessonId,
                    enrollmentId: this.enrollmentId,
                    progressId: result.progressId,
                    success: true
                }
            }));
            
        } catch (error) {
            console.error('Error auto-completing lesson:', error);
            // Still fire event but indicate failure
            this.dispatchEvent(new CustomEvent('lessoncomplete', {
                detail: { 
                    lessonId: this.lessonId,
                    success: false,
                    error: error.body ? error.body.message : error.message
                }
            }));
        }
        
        this.handleClose();
    }

    /**
     * Simple markdown parser - converts markdown to HTML
     * Supports: headings, bold, italic, lists, links, code, blockquotes
     */
    parseMarkdown(markdown) {
        if (!markdown) return '';
        
        let html = markdown;
        
        // Escape HTML entities first for security
        html = html.replace(/&/g, '&amp;')
                   .replace(/</g, '&lt;')
                   .replace(/>/g, '&gt;');
        
        // Headers (h1-h6) - process in reverse order to avoid conflicts
        html = html.replace(/^###### (.*)$/gm, '<h6>$1</h6>');
        html = html.replace(/^##### (.*)$/gm, '<h5>$1</h5>');
        html = html.replace(/^#### (.*)$/gm, '<h4>$1</h4>');
        html = html.replace(/^### (.*)$/gm, '<h3>$1</h3>');
        html = html.replace(/^## (.*)$/gm, '<h2>$1</h2>');
        html = html.replace(/^# (.*)$/gm, '<h1>$1</h1>');
        
        // Bold and italic (order matters)
        html = html.replace(/\*\*\*(.+?)\*\*\*/g, '<strong><em>$1</em></strong>');
        html = html.replace(/\*\*(.+?)\*\*/g, '<strong>$1</strong>');
        html = html.replace(/\*(.+?)\*/g, '<em>$1</em>');
        html = html.replace(/___(.+?)___/g, '<strong><em>$1</em></strong>');
        html = html.replace(/__(.+?)__/g, '<strong>$1</strong>');
        html = html.replace(/_(.+?)_/g, '<em>$1</em>');
        
        // Strikethrough
        html = html.replace(/~~(.+?)~~/g, '<del>$1</del>');
        
        // Inline code
        html = html.replace(/`([^`]+)`/g, '<code style="background:#f4f4f4;padding:2px 6px;border-radius:3px;">$1</code>');
        
        // Blockquotes (after escaping >)
        html = html.replace(/^&gt; (.*)$/gm, '<blockquote style="border-left:4px solid #ccc;margin:1em 0;padding-left:1em;color:#666;">$1</blockquote>');
        
        // Horizontal rules
        html = html.replace(/^---$/gm, '<hr>');
        html = html.replace(/^\*\*\*$/gm, '<hr>');
        
        // Unordered lists - wrap consecutive list items
        html = html.replace(/^[\*\-] (.*)$/gm, '<li>$1</li>');
        
        // Ordered lists
        html = html.replace(/^\d+\. (.*)$/gm, '<li>$1</li>');
        
        // Wrap consecutive <li> in <ul>
        html = html.replace(/((?:<li>.*<\/li>\n?)+)/g, '<ul style="margin:1em 0;padding-left:2em;">$1</ul>');
        
        // Links
        html = html.replace(/\[([^\]]+)\]\(([^\)]+)\)/g, '<a href="$2" target="_blank" rel="noopener noreferrer" style="color:#0070d2;">$1</a>');
        
        // Images
        html = html.replace(/!\[([^\]]*)\]\(([^\)]+)\)/g, '<img src="$2" alt="$1" style="max-width:100%;">');
        
        // Line breaks - convert double newlines to paragraphs
        const paragraphs = html.split(/\n\n+/);
        html = paragraphs.map(p => {
            p = p.trim();
            // Don't wrap block elements in <p>
            if (p.startsWith('<h') || p.startsWith('<ul') || p.startsWith('<ol') || 
                p.startsWith('<blockquote') || p.startsWith('<pre') || p.startsWith('<hr')) {
                return p;
            }
            // Convert single newlines to <br>
            p = p.replace(/\n/g, '<br>');
            return p ? `<p>${p}</p>` : '';
        }).join('\n');
        
        return html;
    }
}
