import { LightningElement, wire, track } from 'lwc';
import getStats from '@salesforce/apex/NewsletterAdminController.getStats';
import getTopTopics from '@salesforce/apex/NewsletterAdminController.getTopTopics';
import getRecentDeliveries from '@salesforce/apex/NewsletterAdminController.getRecentDeliveries';

export default class NewsletterAdminDashboard extends LightningElement {
    @wire(getStats) stats;
    @wire(getRecentDeliveries) recentDeliveries;

    _topTopicsData = [];
    _topTopicsError;

    @wire(getTopTopics)
    wiredTopTopics({ data, error }) {
        if (data) {
            this._topTopicsData = data.map((t, i) => ({ ...t, rank: i + 1 }));
            this._topTopicsError = undefined;
        } else if (error) {
            this._topTopicsError = error;
            this._topTopicsData = [];
        }
    }

    get topTopics() {
        return { data: this._topTopicsData, error: this._topTopicsError };
    }

    get hasTopics() {
        return this._topTopicsData && this._topTopicsData.length > 0;
    }

    get hasDeliveries() {
        return this.recentDeliveries.data && this.recentDeliveries.data.length > 0;
    }

    get deliveriesWithFeedback() {
        if (!this.recentDeliveries.data) return [];
        return this.recentDeliveries.data.map(d => ({
            ...d,
            feedbackEmoji: d.feedbackRating === 'Helpful' ? '👍' : d.feedbackRating === 'Not Helpful' ? '👎' : '—'
        }));
    }

    get feedbackRate() {
        const s = this.stats.data;
        if (!s || !s.totalEmailsSent) return '—';
        const total = (s.totalHelpful || 0) + (s.totalNotHelpful || 0);
        return Math.round((total / s.totalEmailsSent) * 100) + '%';
    }

    get satisfactionScore() {
        const s = this.stats.data;
        if (!s) return '—';
        const total = (s.totalHelpful || 0) + (s.totalNotHelpful || 0);
        if (!total) return '—';
        return Math.round(((s.totalHelpful || 0) / total) * 100) + '%';
    }
}
