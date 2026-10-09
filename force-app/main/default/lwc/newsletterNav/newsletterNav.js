import { LightningElement, track, api } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import getCurrentUser from '@salesforce/apex/NavController.getCurrentUser';
import isGuest from '@salesforce/user/isGuest';
import basePath from '@salesforce/community/basePath';

export default class NewsletterNav extends NavigationMixin(LightningElement) {
    @track open = false;
    @track userName = '';
    @track initials = '';
    @api subscriptionPath = 'topicsubscription';
    @api archivePath = 'archive';

    _handleOutsideClick;

    get showNav() {
        return !isGuest;
    }

    connectedCallback() {
        if (!isGuest) {
            this._handleOutsideClick = this.closeDropdown.bind(this);
            getCurrentUser()
                .then(user => {
                    this.userName = user.Name;
                    const f = (user.FirstName || '').charAt(0).toUpperCase();
                    const l = (user.LastName || '').charAt(0).toUpperCase();
                    this.initials = f + l || '?';
                })
                .catch(() => {
                    this.initials = '?';
                });
        }
    }

    disconnectedCallback() {
        document.removeEventListener('click', this._handleOutsideClick);
    }

    toggleDropdown(event) {
        event.stopPropagation();
        this.open = !this.open;
        if (this.open) {
            document.addEventListener('click', this._handleOutsideClick);
        } else {
            document.removeEventListener('click', this._handleOutsideClick);
        }
    }

    closeDropdown() {
        this.open = false;
        document.removeEventListener('click', this._handleOutsideClick);
    }

    goToSubscriptions() {
        this.closeDropdown();
        const path = (this.subscriptionPath || '').replace(/^\//, '');
        this[NavigationMixin.Navigate]({
            type: 'standard__webPage',
            attributes: { url: path ? basePath + '/' + path : basePath + '/' }
        });
    }

    goToArchive() {
        this.closeDropdown();
        const path = (this.archivePath || '').replace(/^\//, '');
        this[NavigationMixin.Navigate]({
            type: 'standard__webPage',
            attributes: { url: path ? basePath + '/' + path : basePath + '/' }
        });
    }

    handleLogout() {
        window.location.href = '/secur/logout.jsp?retURL=' + encodeURIComponent(basePath + '/login');
    }
}
