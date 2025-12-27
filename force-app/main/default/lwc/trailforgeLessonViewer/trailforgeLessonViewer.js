import { LightningElement, api, wire, track } from 'lwc';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';

import NAME_FIELD from '@salesforce/schema/Lesson__c.Name';
import CONTENT_TYPE_FIELD from '@salesforce/schema/Lesson__c.Content_Type__c';
import CONTENT_BODY_FIELD from '@salesforce/schema/Lesson__c.Content_Body__c';
import EXTERNAL_URL_FIELD from '@salesforce/schema/Lesson__c.External_URL__c';

const FIELDS = [NAME_FIELD, CONTENT_TYPE_FIELD, CONTENT_BODY_FIELD, EXTERNAL_URL_FIELD];

export default class TrailforgeLessonViewer extends LightningElement {
    @api lessonId;  // For Flow screens or explicit override
    @api recordId;  // Auto-populated on record pages
    
    @track lessonName = '';
    @track contentType = '';
    @track contentBody = '';
    @track externalUrl = '';
    @track renderedHtml = '';
    
    isLoading = true;
    error = null;
    
    // Computed property: use explicit lessonId if provided, otherwise use recordId from record page
    get effectiveLessonId() {
        return this.lessonId || this.recordId;
    }
    
    @wire(getRecord, { recordId: '$effectiveLessonId', fields: FIELDS })
    wiredLesson({ error, data }) {
        this.isLoading = false;
        if (data) {
            this.lessonName = getFieldValue(data, NAME_FIELD);
            this.contentType = getFieldValue(data, CONTENT_TYPE_FIELD) || '';
            this.contentBody = getFieldValue(data, CONTENT_BODY_FIELD) || '';
            this.externalUrl = getFieldValue(data, EXTERNAL_URL_FIELD) || '';
            this.error = null;
            
            // Process content for rendering
            this.processContent();
        } else if (error) {
            this.error = this.reduceErrors(error);
            console.error('Error loading lesson:', error);
        }
    }
    
    processContent() {
        if (this.contentType === 'Markdown') {
            this.renderedHtml = this.parseMarkdown(this.contentBody);
        } else if (this.contentType === 'HTML') {
            this.renderedHtml = this.sanitizeHtml(this.contentBody);
        }
    }
    
    // Simple markdown parser
    parseMarkdown(markdown) {
        if (!markdown) return '';
        
        let html = markdown;
        
        // Escape HTML entities first for security
        html = html.replace(/&/g, '&amp;')
                   .replace(/</g, '&lt;')
                   .replace(/>/g, '&gt;');
        
        // Headers (h1-h6)
        html = html.replace(/^###### (.*)$/gm, '<h6>$1</h6>');
        html = html.replace(/^##### (.*)$/gm, '<h5>$1</h5>');
        html = html.replace(/^#### (.*)$/gm, '<h4>$1</h4>');
        html = html.replace(/^### (.*)$/gm, '<h3>$1</h3>');
        html = html.replace(/^## (.*)$/gm, '<h2>$1</h2>');
        html = html.replace(/^# (.*)$/gm, '<h1>$1</h1>');
        
        // Bold and italic
        html = html.replace(/\*\*\*(.+?)\*\*\*/g, '<strong><em>$1</em></strong>');
        html = html.replace(/\*\*(.+?)\*\*/g, '<strong>$1</strong>');
        html = html.replace(/\*(.+?)\*/g, '<em>$1</em>');
        html = html.replace(/___(.+?)___/g, '<strong><em>$1</em></strong>');
        html = html.replace(/__(.+?)__/g, '<strong>$1</strong>');
        html = html.replace(/_(.+?)_/g, '<em>$1</em>');
        
        // Strikethrough
        html = html.replace(/~~(.+?)~~/g, '<del>$1</del>');
        
        // Inline code
        html = html.replace(/`([^`]+)`/g, '<code>$1</code>');
        
        // Code blocks (simple version)
        html = html.replace(/```([\s\S]*?)```/g, '<pre><code>$1</code></pre>');
        
        // Blockquotes
        html = html.replace(/^&gt; (.*)$/gm, '<blockquote>$1</blockquote>');
        
        // Horizontal rules
        html = html.replace(/^---$/gm, '<hr>');
        html = html.replace(/^\*\*\*$/gm, '<hr>');
        
        // Unordered lists
        html = html.replace(/^[\*\-] (.*)$/gm, '<li>$1</li>');
        html = html.replace(/(<li>.*<\/li>)(\n<li>)/g, '$1$2');
        html = html.replace(/(<li>.*<\/li>)/s, '<ul>$1</ul>');
        
        // Ordered lists  
        html = html.replace(/^\d+\. (.*)$/gm, '<li>$1</li>');
        
        // Links
        html = html.replace(/\[([^\]]+)\]\(([^\)]+)\)/g, '<a href="$2" target="_blank" rel="noopener noreferrer">$1</a>');
        
        // Images (basic support)
        html = html.replace(/!\[([^\]]*)\]\(([^\)]+)\)/g, '<img src="$2" alt="$1" style="max-width: 100%;">');
        
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
    
    // Simple HTML sanitizer - removes dangerous elements
    sanitizeHtml(html) {
        if (!html) return '';
        
        // Remove script tags
        let clean = html.replace(/<script\b[^<]*(?:(?!<\/script>)<[^<]*)*<\/script>/gi, '');
        
        // Remove event handlers
        clean = clean.replace(/\s*on\w+\s*=\s*["'][^"']*["']/gi, '');
        clean = clean.replace(/\s*on\w+\s*=\s*[^\s>]*/gi, '');
        
        // Remove javascript: URLs
        clean = clean.replace(/href\s*=\s*["']javascript:[^"']*["']/gi, 'href="#"');
        
        // Remove style tags (can contain expressions)
        clean = clean.replace(/<style\b[^<]*(?:(?!<\/style>)<[^<]*)*<\/style>/gi, '');
        
        // Remove iframe (could embed malicious content)
        clean = clean.replace(/<iframe\b[^<]*(?:(?!<\/iframe>)<[^<]*)*<\/iframe>/gi, '');
        
        // Remove object/embed tags
        clean = clean.replace(/<object\b[^<]*(?:(?!<\/object>)<[^<]*)*<\/object>/gi, '');
        clean = clean.replace(/<embed\b[^>]*>/gi, '');
        
        return clean;
    }
    
    // Computed properties
    get hasLessonId() {
        return !!this.effectiveLessonId;
    }
    
    get isMarkdown() {
        return this.contentType === 'Markdown';
    }
    
    get isHtml() {
        return this.contentType === 'HTML';
    }
    
    get isUrl() {
        return this.contentType === 'URL';
    }
    
    get isVideo() {
        return this.contentType === 'Video';
    }
    
    get isPdf() {
        return this.contentType === 'PDF';
    }
    
    get isUnsupportedType() {
        return this.contentType && !this.isMarkdown && !this.isHtml && !this.isUrl && !this.isVideo && !this.isPdf;
    }
    
    get hasContent() {
        if (this.isMarkdown || this.isHtml) {
            return !!this.contentBody;
        }
        if (this.isUrl || this.isVideo || this.isPdf) {
            return !!this.externalUrl;
        }
        return false;
    }
    
    get showNoContent() {
        return !this.hasContent && !this.isUnsupportedType && this.contentType;
    }
    
    get showSelectType() {
        return !this.contentType;
    }
    
    // Video embed URL processing
    get videoEmbedUrl() {
        if (!this.externalUrl) return null;
        
        const url = this.externalUrl;
        
        // YouTube
        const youtubeMatch = url.match(/(?:youtube\.com\/(?:watch\?v=|embed\/)|youtu\.be\/)([a-zA-Z0-9_-]{11})/);
        if (youtubeMatch) {
            return `https://www.youtube.com/embed/${youtubeMatch[1]}`;
        }
        
        // Vimeo
        const vimeoMatch = url.match(/vimeo\.com\/(?:video\/)?(\d+)/);
        if (vimeoMatch) {
            return `https://player.vimeo.com/video/${vimeoMatch[1]}`;
        }
        
        // Direct video URL - return as-is for video tag
        return url;
    }
    
    get isEmbeddableVideo() {
        if (!this.externalUrl) return false;
        return this.externalUrl.includes('youtube.com') || 
               this.externalUrl.includes('youtu.be') || 
               this.externalUrl.includes('vimeo.com');
    }
    
    get isDirectVideo() {
        if (!this.externalUrl) return false;
        const url = this.externalUrl.toLowerCase();
        return url.endsWith('.mp4') || url.endsWith('.webm') || url.endsWith('.ogg');
    }
    
    renderedCallback() {
        // Inject HTML content after render
        if (this.isMarkdown && this.renderedHtml) {
            const container = this.template.querySelector('.markdown-content');
            if (container) {
                container.innerHTML = this.renderedHtml;
            }
        }
        
        if (this.isHtml && this.renderedHtml) {
            const container = this.template.querySelector('.html-content');
            if (container) {
                container.innerHTML = this.renderedHtml;
            }
        }
    }
    
    handleOpenUrl() {
        if (this.externalUrl) {
            window.open(this.externalUrl, '_blank');
        }
    }
    
    reduceErrors(error) {
        if (typeof error === 'string') {
            return error;
        }
        if (error.body) {
            if (typeof error.body.message === 'string') {
                return error.body.message;
            }
        }
        if (error.message) {
            return error.message;
        }
        return 'Unknown error';
    }
}
