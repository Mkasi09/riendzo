import FirebaseService from './firebase-service.js';
import UIService from './ui-service.js';

export class DashboardService {
    constructor() {
        this.firebaseService = new FirebaseService();
        this.uiService = new UIService();
        this.refreshInterval = null;
    }

    async initializeDashboard() {
        try {
            this.uiService.showLoading('dashboard-content', 'Loading dashboard...');
            
            // Load dashboard stats
            await this.loadDashboardStats();
            
            // Load dashboard components
            await this.loadDashboardComponents();
            
            // Set up auto-refresh
            this.setupAutoRefresh();
            
            this.uiService.hideLoading('dashboard-content');
        } catch (error) {
            console.error('Error initializing dashboard:', error);
            this.uiService.showNotification('Error loading dashboard', 'error');
            this.uiService.hideLoading('dashboard-content');
        }
    }

    async loadDashboardStats() {
        try {
            const stats = await this.firebaseService.getDashboardStats();
            
            // Update stat cards
            document.getElementById('total-trips').textContent = stats.totalTrips || 0;
            document.getElementById('total-users').textContent = stats.totalUsers || 0;
            document.getElementById('total-messages').textContent = stats.totalMessages || 0;
            document.getElementById('total-likes').textContent = stats.totalLikes || 0;
            
            return stats;
        } catch (error) {
            console.error('Error loading dashboard stats:', error);
            throw error;
        }
    }

    async loadDashboardComponents() {
        try {
            // Load stats component
            await this.uiService.loadComponent('dashboard-content', '../components/dashboard-stats.html');
            
            // Load recent trips
            await this.loadRecentTrips();
            
            // Load recent activity
            await this.loadRecentActivity();
            
        } catch (error) {
            console.error('Error loading dashboard components:', error);
            throw error;
        }
    }

    async loadRecentTrips() {
        try {
            const trips = await this.firebaseService.getTrips();
            const recentTrips = trips.slice(0, 5);
            
            const container = document.createElement('div');
            container.className = 'bg-white p-6 rounded-xl shadow-lg';
            container.innerHTML = `
                <h3 class="text-lg font-semibold mb-4">Recent Trips</h3>
                <div class="space-y-3" id="recent-trips-list">
                    ${recentTrips.map(trip => this.createTripCard(trip)).join('')}
                </div>
            `;
            
            // Append to dashboard content
            const dashboardContent = document.getElementById('dashboard-content');
            if (dashboardContent) {
                dashboardContent.appendChild(container);
            }
            
        } catch (error) {
            console.error('Error loading recent trips:', error);
            throw error;
        }
    }

    async loadRecentActivity() {
        try {
            const trips = await this.firebaseService.getTrips();
            const recentTrips = trips.slice(0, 3);
            
            const container = document.createElement('div');
            container.className = 'bg-white p-6 rounded-xl shadow-lg';
            container.innerHTML = `
                <h3 class="text-lg font-semibold mb-4">Recent Activity</h3>
                <div class="space-y-3" id="recent-activity-list">
                    ${recentTrips.map(trip => this.createActivityItem(trip)).join('')}
                </div>
            `;
            
            // Append to dashboard content
            const dashboardContent = document.getElementById('dashboard-content');
            if (dashboardContent) {
                dashboardContent.appendChild(container);
            }
            
        } catch (error) {
            console.error('Error loading recent activity:', error);
            throw error;
        }
    }

    createTripCard(trip) {
        return `
            <div class="p-4 border rounded-lg hover:bg-gray-50 transition cursor-pointer" onclick="app.viewTripDetails('${trip.id}')">
                <div class="flex justify-between items-start">
                    <div>
                        <h4 class="font-semibold">${trip.destination || 'Unknown'}</h4>
                        <p class="text-sm text-gray-600">${trip.tripName || 'No name'}</p>
                        <p class="text-xs text-gray-500">${this.uiService.formatDate(trip.startDate)} - ${this.uiService.formatDate(trip.endDate)}</p>
                    </div>
                    <span class="px-2 py-1 bg-green-100 text-green-800 text-xs rounded-full">Active</span>
                </div>
            </div>
        `;
    }

    createActivityItem(trip) {
        return `
            <div class="flex items-center space-x-3 p-3 hover:bg-gray-50 rounded-lg transition">
                <div class="w-10 h-10 bg-indigo-100 rounded-full flex items-center justify-center">
                    <i class="fas fa-map-marker-alt text-indigo-600"></i>
                </div>
                <div class="flex-1">
                    <p class="text-sm font-medium">New trip created</p>
                    <p class="text-xs text-gray-500">${trip.destination || 'Unknown destination'}</p>
                </div>
                <span class="text-xs text-gray-400">Just now</span>
            </div>
        `;
    }

    setupAutoRefresh() {
        // Clear existing interval
        if (this.refreshInterval) {
            clearInterval(this.refreshInterval);
        }
        
        // Set up new interval (refresh every 30 seconds)
        this.refreshInterval = setInterval(async () => {
            try {
                await this.refreshDashboard();
            } catch (error) {
                console.error('Error auto-refreshing dashboard:', error);
            }
        }, 30000);
    }

    async refreshDashboard() {
        try {
            await this.loadDashboardStats();
            this.uiService.showNotification('Dashboard refreshed', 'success');
        } catch (error) {
            console.error('Error refreshing dashboard:', error);
            this.uiService.showNotification('Error refreshing dashboard', 'error');
        }
    }

    destroy() {
        if (this.refreshInterval) {
            clearInterval(this.refreshInterval);
        }
    }
}

export default DashboardService;
