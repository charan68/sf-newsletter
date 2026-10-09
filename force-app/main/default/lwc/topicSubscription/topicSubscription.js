import { LightningElement, track } from 'lwc';
import getTopics from '@salesforce/apex/TopicSubscriptionController.getTopics';
import getUserSubscriptions from '@salesforce/apex/TopicSubscriptionController.getUserSubscriptions';
import saveSubscriptions from '@salesforce/apex/TopicSubscriptionController.saveSubscriptions';
import getTopicSubscriberCounts from '@salesforce/apex/TopicSubscriptionController.getTopicSubscriberCounts';

export default class TopicSubscription extends LightningElement {
    @track topicsByCategory = [];
    @track isLoading = true;
    @track isSaving = false;
    @track errorMessage = '';
    @track searchTerm = '';
    @track selectedCategory = 'All';
    @track activeTab = 'general';

    allTopics = [];
    selectedTopicIds = new Set();
    subscriberCounts = {};
    _toastTimer;

    connectedCallback() {
        this.loadData();
    }

    disconnectedCallback() {
        clearTimeout(this._toastTimer);
        const toast = document.getElementById('nl-sub-toast');
        if (toast) toast.remove();
    }

    async loadData() {
        this.isLoading = true;
        this.errorMessage = '';
        try {
            const [topics, subscriptions, counts] = await Promise.all([
                getTopics(),
                getUserSubscriptions(),
                getTopicSubscriberCounts()
            ]);
            this.allTopics = topics;
            this.selectedTopicIds = new Set(subscriptions);
            this.subscriberCounts = counts || {};
            this.buildCategoryGroups();
        } catch (e) {
            this.errorMessage = 'Failed to load topics. Please refresh the page.';
        } finally {
            this.isLoading = false;
        }
    }

    buildCategoryGroups() {
        const groupMap = {};
        this.allTopics.forEach(t => {
            const cat = t.Category__c || 'General';
            if (!groupMap[cat]) {
                groupMap[cat] = { topics: [], isSupport: t.Tab__c === 'Support Exclusive' };
            }
            groupMap[cat].topics.push({
                ...t,
                selected: this.selectedTopicIds.has(t.Id),
                cardClass: this.selectedTopicIds.has(t.Id) ? 'topic-card topic-card-selected' : 'topic-card',
                subscriberCount: this.subscriberCounts[t.Id] || 0,
                subscriberLabel: (this.subscriberCounts[t.Id] || 0) === 1 ? '1 subscriber' : (this.subscriberCounts[t.Id] || 0) + ' subscribers'
            });
        });
        const SUPPORT_ORDER = ['Sales Cloud', 'Service Cloud', 'Salesforce Development'];
        this.topicsByCategory = Object.keys(groupMap).sort((a, b) => {
            const ai = SUPPORT_ORDER.indexOf(a);
            const bi = SUPPORT_ORDER.indexOf(b);
            if (ai !== -1 && bi !== -1) return ai - bi;
            if (ai !== -1) return -1;
            if (bi !== -1) return 1;
            return a.localeCompare(b);
        }).map(cat => ({
            category: cat,
            topics: groupMap[cat].topics,
            isSupport: groupMap[cat].isSupport
        }));
    }

    get topicsReady() {
        return !this.isLoading && this.topicsByCategory.length > 0;
    }

    get generalTabClass() {
        return this.activeTab === 'general' ? 'tab-btn tab-btn-active' : 'tab-btn';
    }

    get supportTabClass() {
        return this.activeTab === 'support' ? 'tab-btn tab-btn-active' : 'tab-btn';
    }

    get categoryChips() {
        const isSupport = this.activeTab === 'support';
        const allChip = { label: 'All', chipClass: this.selectedCategory === 'All' ? 'cat-chip cat-chip-active' : 'cat-chip' };
        const cats = this.topicsByCategory
            .filter(g => g.isSupport === isSupport)
            .map(g => ({
                label: g.category,
                chipClass: this.selectedCategory === g.category ? 'cat-chip cat-chip-active' : 'cat-chip'
            }));
        return [allChip, ...cats];
    }

    get filteredTopicsByCategory() {
        const term = this.searchTerm.toLowerCase().trim();
        const isSupport = this.activeTab === 'support';
        return this.topicsByCategory
            .filter(g => g.isSupport === isSupport)
            .filter(g => this.selectedCategory === 'All' || g.category === this.selectedCategory)
            .map(g => ({
                ...g,
                topics: g.topics.filter(t =>
                    !term ||
                    t.Name.toLowerCase().includes(term) ||
                    (t.Description__c || '').toLowerCase().includes(term)
                )
            }))
            .filter(g => g.topics.length > 0);
    }

    get noResults() {
        return this.topicsReady && this.filteredTopicsByCategory.length === 0;
    }

    get selectedCount() {
        return this.selectedTopicIds.size;
    }

    handleTabSwitch(event) {
        this.activeTab = event.currentTarget.dataset.tab;
        this.selectedCategory = 'All';
        this.searchTerm = '';
    }

    handleSearchChange(event) {
        this.searchTerm = event.target.value;
    }

    handleCategorySelect(event) {
        this.selectedCategory = event.target.dataset.category;
    }

    clearFilters() {
        this.searchTerm = '';
        this.selectedCategory = 'All';
    }

    handleTopicToggle(event) {
        const topicId = event.currentTarget.dataset.id;
        if (this.selectedTopicIds.has(topicId)) {
            this.selectedTopicIds.delete(topicId);
        } else {
            this.selectedTopicIds.add(topicId);
        }
        this.buildCategoryGroups();
    }

    async handleSave() {
        this.isSaving = true;
        this.errorMessage = '';
        try {
            await saveSubscriptions({ topicIds: [...this.selectedTopicIds] });
            this._showFloatingToast('Subscriptions saved! You\'ll start receiving daily emails for your selected topics.');
        } catch (e) {
            this.errorMessage = 'Failed to save subscriptions. Please try again.';
        } finally {
            this.isSaving = false;
        }
    }

    _showFloatingToast(message) {
        const existing = document.getElementById('nl-sub-toast');
        if (existing) existing.remove();

        if (!document.getElementById('nl-sub-toast-style')) {
            const style = document.createElement('style');
            style.id = 'nl-sub-toast-style';
            style.textContent = '@keyframes nl-toast-in{from{opacity:0;transform:translateX(-50%) translateY(-12px)}to{opacity:1;transform:translateX(-50%) translateY(0)}}';
            document.head.appendChild(style);
        }

        const toast = document.createElement('div');
        toast.id = 'nl-sub-toast';
        toast.setAttribute('style', 'position:fixed;top:20px;left:50%;transform:translateX(-50%);z-index:99999;background:#1E7E34;color:#fff;padding:14px 18px;border-radius:8px;display:flex;align-items:center;gap:12px;box-shadow:0 4px 20px rgba(0,0,0,.25);min-width:320px;max-width:540px;font-family:Arial,sans-serif;font-size:14px;font-weight:500;line-height:1.4;animation:nl-toast-in .2s ease');

        const icon = document.createElement('span');
        icon.textContent = '✓';
        icon.setAttribute('style', 'flex-shrink:0;width:22px;height:22px;background:rgba(255,255,255,.25);border-radius:50%;display:inline-flex;align-items:center;justify-content:center;font-size:13px;font-weight:700');

        const msg = document.createElement('span');
        msg.style.flex = '1';
        msg.textContent = message;

        const btn = document.createElement('button');
        btn.innerHTML = '&times;';
        btn.setAttribute('style', 'flex-shrink:0;background:transparent;border:none;color:rgba(255,255,255,.8);font-size:20px;line-height:1;cursor:pointer;padding:0 2px');
        btn.onclick = () => { toast.remove(); clearTimeout(this._toastTimer); };

        toast.appendChild(icon);
        toast.appendChild(msg);
        toast.appendChild(btn);
        document.body.appendChild(toast);

        clearTimeout(this._toastTimer);
        this._toastTimer = setTimeout(() => { const t = document.getElementById('nl-sub-toast'); if (t) t.remove(); }, 5000);
    }
}
