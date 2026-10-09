import { LightningElement, track, wire } from 'lwc';
import { refreshApex } from '@salesforce/apex';
import getSubscribedTopics from '@salesforce/apex/TopicSubscriptionController.getSubscribedTopics';
import removeSubscription from '@salesforce/apex/TopicSubscriptionController.removeSubscription';
import getUserPreference from '@salesforce/apex/TopicSubscriptionController.getUserPreference';
import saveUserPreference from '@salesforce/apex/TopicSubscriptionController.saveUserPreference';
import basePath from '@salesforce/community/basePath';

const DAYS = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];

export default class MySubscriptions extends LightningElement {
    @track topics = [];
    @track isLoading = true;
    @track errorMessage = '';
    @track frequency = 'Daily';
    @track weeklyDay = 'Monday';
    @track isSavingPref = false;
    @track prefSaved = false;
    _wiredResult;
    _prefTimer;

    get isEmpty() { return !this.isLoading && this.topics.length === 0; }
    get homeUrl() { return basePath + '/'; }
    get isDailySelected() { return this.frequency === 'Daily'; }
    get isWeeklySelected() { return this.frequency === 'Weekly'; }
    get savePrefLabel() { return this.isSavingPref ? 'Saving...' : 'Save Preference'; }

    get headerSubtitle() {
        return this.frequency === 'Weekly'
            ? 'Topics delivered as a weekly digest on ' + this.weeklyDay + 's'
            : 'Topics delivered daily to your inbox';
    }

    get dailyOptionClass() {
        return this.frequency === 'Daily' ? 'pref-option pref-option-selected' : 'pref-option';
    }

    get weeklyOptionClass() {
        return this.frequency === 'Weekly' ? 'pref-option pref-option-selected' : 'pref-option';
    }

    get dayOptions() {
        return DAYS.map(d => ({ value: d, label: d, selected: d === this.weeklyDay }));
    }

    @wire(getSubscribedTopics)
    wiredTopics(result) {
        this._wiredResult = result;
        this.isLoading = false;
        if (result.data) {
            this.topics = result.data.map(t => ({ ...t, _removing: false }));
            this.errorMessage = '';
        } else if (result.error) {
            this.errorMessage = 'Failed to load subscriptions. Please refresh the page.';
        }
    }

    connectedCallback() {
        this.loadPreference();
    }

    async loadPreference() {
        try {
            const pref = await getUserPreference();
            if (pref) {
                this.frequency = pref.DeliveryFrequency__c || 'Daily';
                this.weeklyDay = pref.WeeklyDeliveryDay__c || 'Monday';
            }
        } catch (e) {
            // keep defaults
        }
    }

    async handleRemove(event) {
        const topicId = event.target.dataset.id;
        this.topics = this.topics.map(t => t.Id === topicId ? { ...t, _removing: true } : t);
        try {
            await removeSubscription({ topicId });
            await refreshApex(this._wiredResult);
        } catch (e) {
            this.errorMessage = 'Failed to remove subscription. Please try again.';
            this.topics = this.topics.map(t => t.Id === topicId ? { ...t, _removing: false } : t);
        }
    }

    handleFrequencyChange(event) {
        this.frequency = event.target.value;
        this.prefSaved = false;
    }

    handleDayChange(event) {
        this.weeklyDay = event.target.value;
        this.prefSaved = false;
    }

    async handleSavePreference() {
        this.isSavingPref = true;
        this.prefSaved = false;
        try {
            await saveUserPreference({ frequency: this.frequency, weeklyDay: this.weeklyDay });
            this.prefSaved = true;
            clearTimeout(this._prefTimer);
            this._prefTimer = setTimeout(() => { this.prefSaved = false; }, 3000);
        } catch (e) {
            this.errorMessage = 'Failed to save preference. Please try again.';
        } finally {
            this.isSavingPref = false;
        }
    }

    disconnectedCallback() {
        clearTimeout(this._prefTimer);
    }
}
