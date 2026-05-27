import FirebaseService from './firebase-service.js';
import UIService from './ui-service.js';

export class AnalyticsService {
    constructor() {
        this.firebaseService = new FirebaseService();
        this.uiService = new UIService();
    }

    async initializeAnalyticsSection() {
        try {
            this.uiService.showLoading('analytics-content', 'Loading analytics...');
            
            // Load analytics data
            await this.loadAnalytics();
            
            this.uiService.hideLoading('analytics-content');
        } catch (error) {
            console.error('Error initializing analytics section:', error);
            this.uiService.showNotification('Error loading analytics', 'error');
            this.uiService.hideLoading('analytics-content');
        }
    }

    async loadAnalytics() {
        try {
            const [trips, users, chats] = await Promise.all([
                this.firebaseService.getTrips(),
                this.firebaseService.getUsers(),
                this.firebaseService.getChats()
            ]);

            // Display analytics
            this.displayAnalytics(trips, users, chats);
            
        } catch (error) {
            console.error('Error loading analytics:', error);
            throw error;
        }
    }

    displayAnalytics(trips, users, chats) {
        const content = `
            <div class="grid grid-cols-1 lg:grid-cols-2 gap-6">
                ${this.createCategoriesChart(trips)}
                ${this.createUserActivityChart(users, trips)}
                ${this.createTripStatistics(trips)}
                ${this.createChatStatistics(chats)}
            </div>
        `;

        document.getElementById('analytics-content').innerHTML = content;
    }

    createCategoriesChart(trips) {
        const categories = this.getTripCategories(trips);
        const chartData = categories.map(cat => ({
            name: cat.category,
            value: cat.count,
            percentage: ((cat.count / trips.length) * 100).toFixed(1)
        }));

        return `
            <div class="bg-white p-6 rounded-xl shadow-lg">
                <h3 class="text-lg font-semibold mb-4">Trip Categories Distribution</h3>
                <div class="space-y-4">
                    ${chartData.map(data => `
                        <div class="flex items-center justify-between">
                            <div class="flex items-center">
                                <div class="w-4 h-4 bg-indigo-500 rounded mr-3"></div>
                                <span class="text-sm font-medium">${data.name}</span>
                            </div>
                            <div class="flex items-center">
                                <div class="w-24 bg-gray-200 rounded-full h-2 mr-3">
                                    <div class="bg-indigo-500 h-2 rounded-full" style="width: ${data.percentage}%"></div>
                                </div>
                                <span class="text-sm text-gray-600">${data.value} (${data.percentage}%)</span>
                            </div>
                        </div>
                    `).join('')}
                </div>
                <div class="mt-6 pt-4 border-t">
                    <div class="text-sm text-gray-600">
                        <span class="font-medium">Total Trips:</span> ${trips.length}
                    </div>
                </div>
            </div>
        `;
    }

    createUserActivityChart(users, trips) {
        const monthlyData = this.getMonthlyActivity(users, trips);
        
        return `
            <div class="bg-white p-6 rounded-xl shadow-lg">
                <h3 class="text-lg font-semibold mb-4">User Activity Timeline</h3>
                <div class="space-y-4">
                    ${monthlyData.map(data => `
                        <div class="flex items-center justify-between">
                            <span class="text-sm font-medium">${data.month}</span>
                            <div class="flex items-center space-x-4">
                                <div class="flex items-center">
                                    <div class="w-3 h-3 bg-blue-500 rounded mr-2"></div>
                                    <span class="text-xs text-gray-600">Users: ${data.newUsers}</span>
                                </div>
                                <div class="flex items-center">
                                    <div class="w-3 h-3 bg-green-500 rounded mr-2"></div>
                                    <span class="text-xs text-gray-600">Trips: ${data.newTrips}</span>
                                </div>
                            </div>
                        </div>
                    `).join('')}
                </div>
                <div class="mt-6 pt-4 border-t">
                    <div class="flex justify-between text-sm text-gray-600">
                        <span><span class="font-medium">Total Users:</span> ${users.length}</span>
                        <span><span class="font-medium">Total Trips:</span> ${trips.length}</span>
                    </div>
                </div>
            </div>
        `;
    }

    createTripStatistics(trips) {
        const stats = this.calculateTripStatistics(trips);
        
        return `
            <div class="bg-white p-6 rounded-xl shadow-lg">
                <h3 class="text-lg font-semibold mb-4">Trip Statistics</h3>
                <div class="space-y-4">
                    <div class="grid grid-cols-2 gap-4">
                        <div class="text-center p-4 bg-blue-50 rounded-lg">
                            <div class="text-2xl font-bold text-blue-600">${stats.totalTrips}</div>
                            <div class="text-sm text-gray-600">Total Trips</div>
                        </div>
                        <div class="text-center p-4 bg-green-50 rounded-lg">
                            <div class="text-2xl font-bold text-green-600">${stats.avgBudget}</div>
                            <div class="text-sm text-gray-600">Avg Budget</div>
                        </div>
                        <div class="text-center p-4 bg-purple-50 rounded-lg">
                            <div class="text-2xl font-bold text-purple-600">${stats.avgDuration}</div>
                            <div class="text-sm text-gray-600">Avg Duration</div>
                        </div>
                        <div class="text-center p-4 bg-orange-50 rounded-lg">
                            <div class="text-2xl font-bold text-orange-600">${stats.topDestination}</div>
                            <div class="text-sm text-gray-600">Top Destination</div>
                        </div>
                    </div>
                    <div class="mt-4">
                        <h4 class="font-medium mb-2">Popular Destinations</h4>
                        <div class="space-y-2">
                            ${stats.popularDestinations.map(dest => `
                                <div class="flex justify-between text-sm">
                                    <span>${dest.destination}</span>
                                    <span class="text-gray-600">${dest.count} trips</span>
                                </div>
                            `).join('')}
                        </div>
                    </div>
                </div>
            </div>
        `;
    }

    createChatStatistics(chats) {
        const stats = this.calculateChatStatistics(chats);
        
        return `
            <div class="bg-white p-6 rounded-xl shadow-lg">
                <h3 class="text-lg font-semibold mb-4">Chat Statistics</h3>
                <div class="space-y-4">
                    <div class="grid grid-cols-2 gap-4">
                        <div class="text-center p-4 bg-indigo-50 rounded-lg">
                            <div class="text-2xl font-bold text-indigo-600">${stats.totalChats}</div>
                            <div class="text-sm text-gray-600">Total Chats</div>
                        </div>
                        <div class="text-center p-4 bg-teal-50 rounded-lg">
                            <div class="text-2xl font-bold text-teal-600">${stats.totalMessages}</div>
                            <div class="text-sm text-gray-600">Total Messages</div>
                        </div>
                        <div class="text-center p-4 bg-pink-50 rounded-lg">
                            <div class="text-2xl font-bold text-pink-600">${stats.avgMessagesPerChat}</div>
                            <div class="text-sm text-gray-600">Avg Messages/Chat</div>
                        </div>
                        <div class="text-center p-4 bg-yellow-50 rounded-lg">
                            <div class="text-2xl font-bold text-yellow-600">${stats.activeChats}</div>
                            <div class="text-sm text-gray-600">Active Chats</div>
                        </div>
                    </div>
                    <div class="mt-4">
                        <h4 class="font-medium mb-2">Chat Activity</h4>
                        <div class="space-y-2">
                            <div class="flex justify-between text-sm">
                                <span>Messages per day (avg)</span>
                                <span class="text-gray-600">${stats.messagesPerDay}</span>
                            </div>
                            <div class="flex justify-between text-sm">
                                <span>Response rate</span>
                                <span class="text-gray-600">${stats.responseRate}%</span>
                            </div>
                            <div class="flex justify-between text-sm">
                                <span>Peak activity time</span>
                                <span class="text-gray-600">${stats.peakTime}</span>
                            </div>
                        </div>
                    </div>
                </div>
            </div>
        `;
    }

    getTripCategories(trips) {
        const categoryCount = {};
        
        trips.forEach(trip => {
            const category = trip.travelType || 'Unknown';
            categoryCount[category] = (categoryCount[category] || 0) + 1;
        });

        return Object.entries(categoryCount)
            .map(([category, count]) => ({ category, count }))
            .sort((a, b) => b.count - a.count);
    }

    getMonthlyActivity(users, trips) {
        const monthlyData = [];
        const now = new Date();
        
        for (let i = 5; i >= 0; i--) {
            const date = new Date(now.getFullYear(), now.getMonth() - i, 1);
            const monthYear = date.toLocaleDateString('en-US', { year: 'numeric', month: 'short' });
            
            const newUsers = users.filter(user => {
                const userDate = new Date(user.createdAt);
                return userDate.getMonth() === date.getMonth() && 
                       userDate.getFullYear() === date.getFullYear();
            }).length;
            
            const newTrips = trips.filter(trip => {
                const tripDate = new Date(trip.createdAt);
                return tripDate.getMonth() === date.getMonth() && 
                       tripDate.getFullYear() === date.getFullYear();
            }).length;
            
            monthlyData.push({
                month: monthYear,
                newUsers,
                newTrips
            });
        }
        
        return monthlyData;
    }

    calculateTripStatistics(trips) {
        const totalTrips = trips.length;
        const totalBudget = trips.reduce((sum, trip) => sum + (trip.budget || 0), 0);
        const avgBudget = this.uiService.formatCurrency(totalBudget / totalTrips);
        
        // Calculate average duration
        let totalDuration = 0;
        let validDurations = 0;
        
        trips.forEach(trip => {
            if (trip.startDate && trip.endDate) {
                const start = new Date(trip.startDate);
                const end = new Date(trip.endDate);
                const duration = Math.ceil((end - start) / (1000 * 60 * 60 * 24));
                if (duration > 0) {
                    totalDuration += duration;
                    validDurations++;
                }
            }
        });
        
        const avgDuration = validDurations > 0 ? Math.round(totalDuration / validDurations) + ' days' : 'N/A';
        
        // Find top destination
        const destinations = {};
        trips.forEach(trip => {
            const dest = trip.destination || 'Unknown';
            destinations[dest] = (destinations[dest] || 0) + 1;
        });
        
        const topDestination = Object.entries(destinations)
            .sort((a, b) => b[1] - a[1])[0];
        
        const popularDestinations = Object.entries(destinations)
            .sort((a, b) => b[1] - a[1])
            .slice(0, 5)
            .map(([destination, count]) => ({ destination, count }));
        
        return {
            totalTrips,
            avgBudget,
            avgDuration,
            topDestination: topDestination ? topDestination[0] : 'N/A',
            popularDestinations
        };
    }

    async calculateChatStatistics(chats) {
        let totalMessages = 0;
        let activeChats = 0;
        const messagesByDay = {};
        
        for (const chat of chats) {
            try {
                const messages = await this.firebaseService.getChatMessages(chat.id);
                totalMessages += messages.length;
                
                // Check if chat is active (messages in last 24 hours)
                const lastMessage = messages[0];
                if (lastMessage) {
                    const lastMessageTime = new Date(lastMessage.timestamp);
                    const now = new Date();
                    const hoursDiff = (now - lastMessageTime) / (1000 * 60 * 60);
                    
                    if (hoursDiff < 24) {
                        activeChats++;
                    }
                    
                    // Count messages by day
                    const dayKey = lastMessageTime.toDateString();
                    messagesByDay[dayKey] = (messagesByDay[dayKey] || 0) + 1;
                }
            } catch (error) {
                console.error(`Error loading messages for chat ${chat.id}:`, error);
            }
        }
        
        const avgMessagesPerChat = chats.length > 0 ? Math.round(totalMessages / chats.length) : 0;
        const messagesPerDay = Object.keys(messagesByDay).length > 0 ? 
            Math.round(totalMessages / Object.keys(messagesByDay).length) : 0;
        
        return {
            totalChats: chats.length,
            totalMessages,
            avgMessagesPerChat,
            activeChats,
            messagesPerDay,
            responseRate: 85, // Mock data
            peakTime: '2:00 PM - 4:00 PM' // Mock data
        };
    }

    async exportAnalytics() {
        try {
            const [trips, users, chats] = await Promise.all([
                this.firebaseService.getTrips(),
                this.firebaseService.getUsers(),
                this.firebaseService.getChats()
            ]);

            const analyticsData = {
                generatedAt: new Date().toISOString(),
                summary: {
                    totalUsers: users.length,
                    totalTrips: trips.length,
                    totalChats: chats.length
                },
                tripStats: this.calculateTripStatistics(trips),
                chatStats: await this.calculateChatStatistics(chats),
                categories: this.getTripCategories(trips),
                monthlyActivity: this.getMonthlyActivity(users, trips)
            };

            const jsonStr = JSON.stringify(analyticsData, null, 2);
            const blob = new Blob([jsonStr], { type: 'application/json' });
            const url = window.URL.createObjectURL(blob);
            const a = document.createElement('a');
            a.href = url;
            a.download = `analytics-${new Date().toISOString().split('T')[0]}.json`;
            a.click();
            window.URL.revokeObjectURL(url);

            this.uiService.showNotification('Analytics exported successfully', 'success');
        } catch (error) {
            console.error('Error exporting analytics:', error);
            this.uiService.showNotification('Error exporting analytics', 'error');
        }
    }
}

export default AnalyticsService;
