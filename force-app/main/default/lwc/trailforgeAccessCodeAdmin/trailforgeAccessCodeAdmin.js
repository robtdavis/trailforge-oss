//
// SPDX-License-Identifier: MIT
// TrailForge — Open Source under the MIT License
// Copyright (c) 2025 Robert Davis
// See the LICENSE file in the project root for full license text.
//
import { LightningElement, api, wire, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';
import generateForContact from '@salesforce/apex/TrailForgeAccessCodeService.generateForContact';
import getLatestForContact from '@salesforce/apex/TrailForgeAccessCodeService.getLatestForContact';
import clearAccessCode from '@salesforce/apex/TrailForgeAccessCodeService.clearAccessCode';
import hasOverridePermission from '@salesforce/apex/TrailForgeAccessCodeService.hasOverridePermission';

export default class TrailforgeAccessCodeAdmin extends LightningElement {
    @api recordId;
    
    @track isLoading = true;
    @track isGenerating = false;
    @track hasCode = false;
    @track currentCode = '';
    @track codeStatus = '';
    @track issuedOn = null;
    @track expiresOn = null;
    @track usedOn = null;
    @track isCodeUsed = false;
    @track isCodeExpired = false;
    @track isCodeActive = false;
    @track canOverrideExpiry = false;
    @track customExpiryHours = null;
    @track showCopySuccess = false;

    _wiredCodeResult;

    /**
     * Wire to check if user has override permission
     */
    @wire(hasOverridePermission)
    wiredPermission({ error, data }) {
        if (data !== undefined) {
            this.canOverrideExpiry = data;
        } else if (error) {
            console.error('Error checking permission:', error);
            this.canOverrideExpiry = false;
        }
    }

    /**
     * Wire to get latest code info
     */
    @wire(getLatestForContact, { contactId: '$recordId' })
    wiredCode(result) {
        this._wiredCodeResult = result;
        const { error, data } = result;
        
        if (data) {
            this.processCodeData(data);
            this.isLoading = false;
        } else if (error) {
            console.error('Error loading code:', error);
            this.hasCode = false;
            this.isLoading = false;
        }
    }

    /**
     * Process code data from Apex
     */
    processCodeData(data) {
        this.hasCode = data.hasCode === true;
        
        if (this.hasCode) {
            this.currentCode = data.code || '';
            this.codeStatus = data.status || 'Unknown';
            this.issuedOn = data.issuedOn;
            this.expiresOn = data.expiresOn;
            this.usedOn = data.usedOn;
            this.isCodeUsed = data.isUsed === true;
            this.isCodeExpired = data.isExpired === true;
            this.isCodeActive = data.isActive === true;
        } else {
            this.resetCodeState();
        }
    }

    /**
     * Reset code state
     */
    resetCodeState() {
        this.currentCode = '';
        this.codeStatus = '';
        this.issuedOn = null;
        this.expiresOn = null;
        this.usedOn = null;
        this.isCodeUsed = false;
        this.isCodeExpired = false;
        this.isCodeActive = false;
    }

    /**
     * Get the status badge CSS class
     */
    get statusBadgeClass() {
        let baseClass = 'slds-badge ';
        
        switch(this.codeStatus) {
            case 'Active':
                return baseClass + 'slds-badge_success';
            case 'Used':
                return baseClass + 'slds-badge_inverse';
            case 'Expired':
                return baseClass + 'slds-badge_warning';
            case 'Inactive':
                return baseClass + 'slds-badge_lightest';
            default:
                return baseClass;
        }
    }

    /**
     * Get the generate button label
     */
    get generateButtonLabel() {
        if (this.isGenerating) {
            return 'Generating...';
        }
        return this.hasCode && this.isCodeActive ? 'Regenerate Code' : 'Generate Code';
    }

    /**
     * Handle custom expiry hours change
     */
    handleExpiryChange(event) {
        const value = event.target.value;
        this.customExpiryHours = value ? parseInt(value, 10) : null;
    }

    /**
     * Generate a new access code
     */
    async handleGenerateCode() {
        this.isGenerating = true;

        try {
            const code = await generateForContact({
                contactId: this.recordId,
                expiryHours: this.customExpiryHours
            });

            // Show success toast
            this.dispatchEvent(new ShowToastEvent({
                title: 'Success',
                message: `Access code generated: ${code}`,
                variant: 'success'
            }));

            // Refresh the wire - wrap in try/catch as it can fail
            try {
                if (this._wiredCodeResult) {
                    await refreshApex(this._wiredCodeResult);
                }
            } catch (refreshError) {
                console.warn('refreshApex failed, fetching manually:', refreshError);
                // Fallback: manually fetch the latest data
                await this.fetchLatestCode();
            }

            // Clear custom expiry input
            this.customExpiryHours = null;

        } catch (error) {
            console.error('Error generating code:', error);
            this.dispatchEvent(new ShowToastEvent({
                title: 'Error',
                message: error.body?.message || 'Failed to generate access code.',
                variant: 'error'
            }));
        } finally {
            this.isGenerating = false;
        }
    }

    /**
     * Clear/deactivate the current access code
     */
    async handleClearCode() {
        this.isGenerating = true;

        try {
            await clearAccessCode({
                contactId: this.recordId
            });

            // Show success toast
            this.dispatchEvent(new ShowToastEvent({
                title: 'Success',
                message: 'Access code cleared.',
                variant: 'success'
            }));

            // Refresh the wire - wrap in try/catch as it can fail
            try {
                if (this._wiredCodeResult) {
                    await refreshApex(this._wiredCodeResult);
                }
            } catch (refreshError) {
                console.warn('refreshApex failed, fetching manually:', refreshError);
                await this.fetchLatestCode();
            }

        } catch (error) {
            console.error('Error clearing code:', error);
            this.dispatchEvent(new ShowToastEvent({
                title: 'Error',
                message: error.body?.message || 'Failed to clear access code.',
                variant: 'error'
            }));
        } finally {
            this.isGenerating = false;
        }
    }

    /**
     * Manually fetch latest code data (fallback when refreshApex fails)
     */
    async fetchLatestCode() {
        try {
            const data = await getLatestForContact({ contactId: this.recordId });
            this.processCodeData(data);
        } catch (error) {
            console.error('Error fetching latest code:', error);
        }
    }

    /**
     * Copy code to clipboard
     */
    async handleCopyCode() {
        if (!this.currentCode || this.isCodeUsed) {
            return;
        }

        try {
            await navigator.clipboard.writeText(this.currentCode);
            
            // Show inline success message
            this.showCopySuccess = true;
            
            // Hide after 2 seconds
            // eslint-disable-next-line @lwc/lwc/no-async-operation
            setTimeout(() => {
                this.showCopySuccess = false;
            }, 2000);

        } catch (error) {
            console.error('Error copying to clipboard:', error);
            this.dispatchEvent(new ShowToastEvent({
                title: 'Error',
                message: 'Failed to copy to clipboard.',
                variant: 'error'
            }));
        }
    }
}
