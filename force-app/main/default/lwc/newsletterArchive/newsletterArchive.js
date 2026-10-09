import { LightningElement, track, wire } from 'lwc';
import getDeliveryHistory from '@salesforce/apex/TopicSubscriptionController.getDeliveryHistory';

export default class NewsletterArchive extends LightningElement {
    @track history = [];
    @track isLoading = true;
    @track errorMessage = '';
    @track expandedIds = new Set();

    @wire(getDeliveryHistory)
    wiredHistory({ data, error }) {
        this.isLoading = false;
        if (data) {
            this.history = data;
        } else if (error) {
            this.errorMessage = 'Failed to load archive. Please refresh the page.';
        }
    }

    get isEmpty() {
        return !this.isLoading && this.history.length === 0;
    }

    get totalCount() {
        return this.history.length || null;
    }

    get processedHistory() {
        return this.history.map(entry => {
            const isExpanded = this.expandedIds.has(entry.Id);
            return {
                ...entry,
                isExpanded,
                formattedDate: this._formatDate(entry.SentDate__c),
                chevron: isExpanded ? '▲' : '▼',
                entryClass: isExpanded ? 'arch-item arch-item-open' : 'arch-item'
            };
        });
    }

    handleToggle(event) {
        const id = event.currentTarget.dataset.id;
        const next = new Set(this.expandedIds);
        if (next.has(id)) {
            next.delete(id);
        } else {
            next.add(id);
        }
        this.expandedIds = next;
    }

    _formatDate(dateStr) {
        if (!dateStr) return '';
        const d = new Date(dateStr);
        return d.toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' });
    }
}
