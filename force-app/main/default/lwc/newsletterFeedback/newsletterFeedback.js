import { LightningElement, wire, track } from 'lwc';
import { CurrentPageReference } from 'lightning/navigation';
import saveFeedback from '@salesforce/apex/NewsletterFeedbackController.saveFeedback';

export default class NewsletterFeedback extends LightningElement {
    @track status = 'loading'; // loading | saved | already | error
    @track rating = '';

    @wire(CurrentPageReference)
    async wiredPageRef(pageRef) {
        if (!pageRef) return;
        const uid = pageRef.state?.uid;
        const tid = pageRef.state?.tid;
        const r = pageRef.state?.r;

        if (!uid || !tid || !r) {
            this.status = 'error';
            return;
        }

        this.rating = r === 'helpful' ? 'Helpful' : 'Not Helpful';

        try {
            const result = await saveFeedback({ userId: uid, topicId: tid, rating: this.rating });
            this.status = result === 'already' ? 'already' : result === 'saved' ? 'saved' : 'error';
        } catch (e) {
            this.status = 'error';
        }
    }

    get isLoading() { return this.status === 'loading'; }
    get isSaved()   { return this.status === 'saved'; }
    get isAlready() { return this.status === 'already'; }
    get isError()   { return this.status === 'error'; }

    get ratingEmoji() { return this.rating === 'Helpful' ? '👍' : '👎'; }
    get ratingLabel() { return this.rating; }
}
