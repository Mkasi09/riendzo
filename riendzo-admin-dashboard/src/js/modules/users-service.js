import FirebaseService from './firebase-service.js';
import UIService from './ui-service.js';

export class UsersService {
    constructor() {
        this.firebaseService = new FirebaseService();
        this.uiService = new UIService();
    }

    async initializeUsersSection() {
        try {
            this.uiService.showLoading('users-content', 'Loading users...');
            
            // Load users
            await this.loadUsers();
            
            this.uiService.hideLoading('users-content');
        } catch (error) {
            console.error('Error initializing users section:', error);
            this.uiService.showNotification('Error loading users', 'error');
            this.uiService.hideLoading('users-content');
        }
    }

    async loadUsers() {
        try {
            const users = await this.firebaseService.getUsers();
            this.displayUsers(users);
        } catch (error) {
            console.error('Error loading users:', error);
            throw error;
        }
    }

    displayUsers(users) {
        const userCards = users.map(user => this.createUserCard(user)).join('');
        
        const content = `
            <div class="bg-white rounded-xl shadow-lg p-6">
                <h3 class="text-xl font-semibold mb-6">User Management</h3>
                <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
                    ${userCards}
                </div>
            </div>
        `;

        document.getElementById('users-content').innerHTML = content;
    }

    createUserCard(user) {
        const status = this.getUserStatus(user);
        const joinDate = this.uiService.formatDate(user.createdAt);
        
        return `
            <div class="bg-white p-6 rounded-lg shadow hover:shadow-lg transition">
                <div class="flex items-center mb-4">
                    <img class="h-12 w-12 rounded-full object-cover mr-3" 
                         src="${user.photoURL || 'https://via.placeholder.com/48'}" 
                         alt="${user.displayName}">
                    <div>
                        <h4 class="font-semibold">${user.displayName || 'Unknown User'}</h4>
                        <p class="text-sm text-gray-500">${user.email || 'No email'}</p>
                    </div>
                </div>
                <div class="space-y-2">
                    <div class="flex justify-between text-sm">
                        <span class="text-gray-500">Status:</span>
                        <span class="text-${status.color}-600 font-medium">${status.text}</span>
                    </div>
                    <div class="flex justify-between text-sm">
                        <span class="text-gray-500">Joined:</span>
                        <span>${joinDate}</span>
                    </div>
                    <div class="flex justify-between text-sm">
                        <span class="text-gray-500">User ID:</span>
                        <span class="text-xs">${user.id?.substring(0, 8) || 'N/A'}...</span>
                    </div>
                    <div class="flex space-x-2 mt-4">
                        <button onclick="app.usersService.viewUserDetails('${user.id}')" 
                                class="flex-1 px-3 py-1 bg-blue-100 text-blue-700 rounded hover:bg-blue-200 transition text-sm">
                            View
                        </button>
                        <button onclick="app.usersService.suspendUser('${user.id}')" 
                                class="flex-1 px-3 py-1 bg-red-100 text-red-700 rounded hover:bg-red-200 transition text-sm">
                            Suspend
                        </button>
                    </div>
                </div>
            </div>
        `;
    }

    getUserStatus(user) {
        // Simple status logic - in a real app, this would be more complex
        const lastSeen = user.lastSeen ? new Date(user.lastSeen) : new Date();
        const now = new Date();
        const hoursDiff = (now - lastSeen) / (1000 * 60 * 60);
        
        if (hoursDiff < 1) {
            return { text: 'Online', color: 'green' };
        } else if (hoursDiff < 24) {
            return { text: 'Recently Active', color: 'yellow' };
        } else if (user.suspended) {
            return { text: 'Suspended', color: 'red' };
        } else {
            return { text: 'Inactive', color: 'gray' };
        }
    }

    async viewUserDetails(userId) {
        try {
            const user = await this.firebaseService.getUser(userId);
            if (user) {
                // Get user's trips
                const trips = await this.firebaseService.getTrips();
                const userTrips = trips.filter(trip => trip.userId === userId);
                
                const details = `
                    User Details:
                    
                    Name: ${user.displayName || 'Not provided'}
                    Email: ${user.email || 'Not provided'}
                    User ID: ${user.id}
                    Joined: ${this.uiService.formatDate(user.createdAt)}
                    Last Seen: ${this.uiService.formatDateTime(user.lastSeen)}
                    Status: ${this.getUserStatus(user).text}
                    
                    User's Trips: ${userTrips.length}
                    ${userTrips.map(trip => `- ${trip.tripName || trip.destination} (${this.uiService.formatDate(trip.startDate)})`).join('\n')}
                `;
                alert(details);
            }
        } catch (error) {
            console.error('Error loading user details:', error);
            this.uiService.showNotification('Error loading user details', 'error');
        }
    }

    async suspendUser(userId) {
        this.uiService.confirmAction('Are you sure you want to suspend this user?', async () => {
            try {
                await this.firebaseService.updateUser(userId, { 
                    suspended: true, 
                    suspendedAt: new Date().toISOString() 
                });
                this.uiService.showNotification('User suspended successfully', 'success');
                await this.loadUsers();
            } catch (error) {
                console.error('Error suspending user:', error);
                this.uiService.showNotification('Error suspending user', 'error');
            }
        });
    }

    async unsuspendUser(userId) {
        try {
            await this.firebaseService.updateUser(userId, { 
                suspended: false, 
                unsuspendedAt: new Date().toISOString() 
            });
            this.uiService.showNotification('User unsuspended successfully', 'success');
            await this.loadUsers();
        } catch (error) {
            console.error('Error unsuspending user:', error);
            this.uiService.showNotification('Error unsuspending user', 'error');
        }
    }

    async deleteUser(userId) {
        this.uiService.confirmAction('Are you sure you want to delete this user? This action cannot be undone.', async () => {
            try {
                await this.firebaseService.deleteUser(userId);
                this.uiService.showNotification('User deleted successfully', 'success');
                await this.loadUsers();
            } catch (error) {
                console.error('Error deleting user:', error);
                this.uiService.showNotification('Error deleting user', 'error');
            }
        });
    }

    async searchUsers(query) {
        try {
            const users = await this.firebaseService.getUsers();
            const filteredUsers = users.filter(user => 
                user.displayName?.toLowerCase().includes(query.toLowerCase()) ||
                user.email?.toLowerCase().includes(query.toLowerCase())
            );
            this.displayUsers(filteredUsers);
        } catch (error) {
            console.error('Error searching users:', error);
            this.uiService.showNotification('Error searching users', 'error');
        }
    }

    async filterUsersByStatus(status) {
        try {
            const users = await this.firebaseService.getUsers();
            let filteredUsers = users;

            switch (status) {
                case 'active':
                    filteredUsers = users.filter(user => {
                        const lastSeen = user.lastSeen ? new Date(user.lastSeen) : new Date();
                        const now = new Date();
                        const hoursDiff = (now - lastSeen) / (1000 * 60 * 60);
                        return hoursDiff < 24 && !user.suspended;
                    });
                    break;
                case 'suspended':
                    filteredUsers = users.filter(user => user.suspended);
                    break;
                case 'inactive':
                    filteredUsers = users.filter(user => {
                        const lastSeen = user.lastSeen ? new Date(user.lastSeen) : new Date();
                        const now = new Date();
                        const hoursDiff = (now - lastSeen) / (1000 * 60 * 60);
                        return hoursDiff >= 24 && !user.suspended;
                    });
                    break;
            }

            this.displayUsers(filteredUsers);
        } catch (error) {
            console.error('Error filtering users:', error);
            this.uiService.showNotification('Error filtering users', 'error');
        }
    }

    async sortUsers(sortBy) {
        try {
            const users = await this.firebaseService.getUsers();
            let sortedUsers = [...users];

            switch (sortBy) {
                case 'name':
                    sortedUsers.sort((a, b) => (a.displayName || '').localeCompare(b.displayName || ''));
                    break;
                case 'email':
                    sortedUsers.sort((a, b) => (a.email || '').localeCompare(b.email || ''));
                    break;
                case 'joined':
                    sortedUsers.sort((a, b) => new Date(b.createdAt || 0) - new Date(a.createdAt || 0));
                    break;
                case 'lastSeen':
                    sortedUsers.sort((a, b) => new Date(b.lastSeen || 0) - new Date(a.lastSeen || 0));
                    break;
            }

            this.displayUsers(sortedUsers);
        } catch (error) {
            console.error('Error sorting users:', error);
            this.uiService.showNotification('Error sorting users', 'error');
        }
    }

    async exportUsers() {
        try {
            const users = await this.firebaseService.getUsers();
            const csv = this.convertUsersToCSV(users);
            this.downloadCSV(csv, 'users.csv');
            this.uiService.showNotification('Users exported successfully', 'success');
        } catch (error) {
            console.error('Error exporting users:', error);
            this.uiService.showNotification('Error exporting users', 'error');
        }
    }

    convertUsersToCSV(users) {
        const headers = ['ID', 'Name', 'Email', 'Joined', 'Last Seen', 'Status'];
        const rows = users.map(user => [
            user.id || '',
            user.displayName || '',
            user.email || '',
            this.uiService.formatDate(user.createdAt),
            this.uiService.formatDate(user.lastSeen),
            this.getUserStatus(user).text
        ]);

        return [headers, ...rows].map(row => row.join(',')).join('\n');
    }

    downloadCSV(csv, filename) {
        const blob = new Blob([csv], { type: 'text/csv' });
        const url = window.URL.createObjectURL(blob);
        const a = document.createElement('a');
        a.href = url;
        a.download = filename;
        a.click();
        window.URL.revokeObjectURL(url);
    }
}

export default UsersService;
