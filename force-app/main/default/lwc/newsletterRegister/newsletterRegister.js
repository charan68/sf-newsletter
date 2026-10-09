import { LightningElement, track } from 'lwc';
import registerUser from '@salesforce/apex/NewsletterRegisterController.registerUser';
import isUsernameAvailable from '@salesforce/apex/NewsletterRegisterController.isUsernameAvailable';
import basePath from '@salesforce/community/basePath';

export default class NewsletterRegister extends LightningElement {
    @track firstName = '';
    @track lastName = '';
    @track email = '';
    @track username = '';
    @track password = '';
    @track confirmPassword = '';
    @track errorMessage = '';
    @track isSaving = false;
    @track showSuccess = false;
    @track showForm = true;
    @track successViaEmail = false;
    @track usernameStatus = ''; // '' | 'checking' | 'available' | 'taken'

    _usernameTimer;

    get loginUrl() { return basePath + '/login'; }
    get isCheckingUsername() { return this.usernameStatus === 'checking'; }
    get isUsernameAvailable() { return this.usernameStatus === 'available'; }
    get isUsernameTaken() { return this.usernameStatus === 'taken'; }

    get usernameInputClass() {
        if (this.usernameStatus === 'available') return 'un-input un-input-valid';
        if (this.usernameStatus === 'taken') return 'un-input un-input-invalid';
        return 'un-input';
    }

    handleChange(event) {
        this[event.target.dataset.field] = event.target.value;
        this.errorMessage = '';
    }

    handleUsernameInput(event) {
        this.username = event.target.value.trim();
        this.usernameStatus = '';
        this.errorMessage = '';
        clearTimeout(this._usernameTimer);
        if (this.username.length > 3 && this.username.includes('@') && this.username.includes('.')) {
            this.usernameStatus = 'checking';
            this._usernameTimer = setTimeout(() => this.checkUsername(), 500);
        }
    }

    async checkUsername() {
        try {
            const available = await isUsernameAvailable({ username: this.username });
            this.usernameStatus = available ? 'available' : 'taken';
        } catch (e) {
            this.usernameStatus = '';
        }
    }

    async handleSubmit() {
        this.errorMessage = '';

        if (!this.firstName || !this.lastName || !this.email) {
            this.errorMessage = 'Please fill in all required fields.';
            return;
        }
        if (!this.email.includes('@')) {
            this.errorMessage = 'Please enter a valid email address.';
            return;
        }
        if (!this.username) {
            this.errorMessage = 'Please choose a username.';
            return;
        }
        if (!this.username.includes('@') || !this.username.includes('.')) {
            this.errorMessage = 'Username must be in email format (e.g. yourname@example.com).';
            return;
        }
        if (this.usernameStatus === 'taken') {
            this.errorMessage = 'That username is already taken. Please choose a different one.';
            return;
        }
        if (this.password.length < 8) {
            this.errorMessage = 'Password must be at least 8 characters.';
            return;
        }
        if (this.password !== this.confirmPassword) {
            this.errorMessage = 'Passwords do not match.';
            return;
        }

        this.isSaving = true;
        try {
            const result = await registerUser({
                firstName: this.firstName,
                lastName: this.lastName,
                email: this.email,
                password: this.password,
                username: this.username
            });

            if (result === 'SUCCESS' || result === 'SUCCESS_EMAIL') {
                this.successViaEmail = (result === 'SUCCESS_EMAIL');
                this.showForm = false;
                this.showSuccess = true;
            } else if (result === 'USERNAME_TAKEN') {
                this.errorMessage = 'That username was just taken. Please choose a different one.';
                this.usernameStatus = 'taken';
            } else if (result === 'ALREADY_EXISTS') {
                this.errorMessage = 'An account with this email already exists. Please sign in.';
            }
        } catch (e) {
            this.errorMessage = e.body?.message || 'Registration failed. Please try again.';
        } finally {
            this.isSaving = false;
        }
    }

    disconnectedCallback() {
        clearTimeout(this._usernameTimer);
    }
}
