import DataService from './modules/data-service.js';
import { formatCurrency, formatDate, getUserStatus, safeAvatar } from './modules/formatters.js';

class App {
    constructor() {
        this.dataService = new DataService();
        this.currentSection = 'dashboard';
        this.eventListenersReady = false;
        this.cache = { trips: [], users: [], chats: [], totalLikes: 0, totalMessages: 0 };
        this.sections = [
            { id: 'dashboard', label: 'Overview', icon: 'fa-table-cells-large' },
            { id: 'trips', label: 'Trips', icon: 'fa-route' },
            { id: 'users', label: 'Travelers', icon: 'fa-users' },
            { id: 'chats', label: 'Conversations', icon: 'fa-comments' },
            { id: 'analytics', label: 'Analytics', icon: 'fa-chart-line' },
            { id: 'categories', label: 'Categories', icon: 'fa-tags' }
        ];
    }

    async initialize() {
        this.showAppLoading();

        try {
            this.renderShell();
            this.setupGlobalEventListeners();
            await this.refreshCache();
            await this.showSection('dashboard');
            this.loadTheme();
            this.updateCurrentTime();
            setInterval(() => this.updateCurrentTime(), 1000);
            this.showNotification('Dashboard ready', 'success');
        } catch (error) {
            console.error('Error initializing app:', error);
            this.renderShell();
            this.setupGlobalEventListeners();
            this.showFatalError(error);
            this.showNotification('Live data unavailable', 'error');
        } finally {
            this.hideAppLoading();
        }
    }

    showFatalError(error) {
        document.querySelectorAll('section').forEach(section => section.classList.add('hidden'));
        const dashboard = document.getElementById('dashboard');
        dashboard?.classList.remove('hidden');
        document.getElementById('page-title').textContent = 'Backend Error';

        const message = error?.message || 'The dashboard could not connect to the live backend.';
        document.getElementById('dashboard-content').innerHTML = `
            <section class="content-panel page-panel error-state-panel">
                <span><i class="fa-solid fa-triangle-exclamation"></i></span>
                <h3>Live data is not available</h3>
                <p>${message}</p>
                <button class="primary-action" onclick="app.refreshData()">
                    <i class="fa-solid fa-rotate"></i>
                    Retry connection
                </button>
            </section>
        `;
    }

    async refreshCache() {
        this.cache = await this.dataService.getDashboardData();
    }

    renderShell() {
        document.getElementById('sidebar-container').innerHTML = `
            <aside class="app-sidebar">
                <div class="brand-block">
                    <div class="brand-mark"><i class="fa-solid fa-compass"></i></div>
                    <div>
                        <h1>Riendzo</h1>
                        <p>Admin Command</p>
                    </div>
                </div>

                <nav class="side-nav" aria-label="Main navigation">
                    ${this.sections.map(section => `
                        <button class="side-link" data-section="${section.id}" onclick="app.showSection('${section.id}')">
                            <i class="fa-solid ${section.icon}"></i>
                            <span>${section.label}</span>
                        </button>
                    `).join('')}
                </nav>

                <div class="sidebar-insight">
                    <span class="eyebrow">Network Health</span>
                    <strong>${this.calculateEngagement()}%</strong>
                    <p>Traveler engagement score across trips, chats, and likes.</p>
                    <div class="mini-meter"><span style="width: ${this.calculateEngagement()}%"></span></div>
                </div>

                <div class="sidebar-footer">
                    <div>
                        <span class="status-dot"></span>
                        <span>Live workspace</span>
                    </div>
                    <span id="current-time">--:--</span>
                </div>
            </aside>
        `;

        document.getElementById('header-container').innerHTML = `
            <header class="app-header">
                <div>
                    <p class="eyebrow">Admin dashboard</p>
                    <h2 id="page-title">Overview</h2>
                </div>

                <div class="header-actions">
                    <label class="global-search" aria-label="Search dashboard">
                        <i class="fa-solid fa-search"></i>
                        <input id="global-search" type="search" placeholder="Search trips, travelers, messages" oninput="app.search(this.value)">
                    </label>
                    <button class="icon-button" onclick="app.refreshData()" title="Refresh data">
                        <i class="fa-solid fa-rotate"></i>
                    </button>
                    <button class="icon-button" onclick="app.exportData()" title="Export data">
                        <i class="fa-solid fa-download"></i>
                    </button>
                    <button class="icon-button" onclick="app.toggleTheme()" title="Toggle theme">
                        <i class="fa-solid fa-moon" id="theme-icon"></i>
                    </button>
                    <button class="profile-button" onclick="app.openSettings()">
                        <span>AD</span>
                        <strong>Admin</strong>
                    </button>
                </div>
            </header>
        `;
    }

    setupGlobalEventListeners() {
        if (this.eventListenersReady) return;

        document.addEventListener('keydown', event => {
            if (!(event.ctrlKey || event.metaKey)) return;

            const section = this.sections[Number(event.key) - 1];
            if (section) {
                event.preventDefault();
                this.showSection(section.id);
            }

            if (event.key.toLowerCase() === 'k') {
                event.preventDefault();
                document.getElementById('global-search')?.focus();
            }
        });

        window.addEventListener('error', event => this.handleGlobalError(event.error));
        window.addEventListener('unhandledrejection', event => this.handleGlobalError(event.reason));
        this.eventListenersReady = true;
    }

    async showSection(sectionName) {
        this.currentSection = sectionName;
        document.querySelectorAll('section').forEach(section => section.classList.add('hidden'));
        document.getElementById(sectionName)?.classList.remove('hidden');
        document.querySelectorAll('.side-link').forEach(link => {
            link.classList.toggle('active', link.dataset.section === sectionName);
        });

        const section = this.sections.find(item => item.id === sectionName);
        document.getElementById('page-title').textContent = section?.label || 'Overview';

        const loaders = {
            dashboard: () => this.loadDashboard(),
            trips: () => this.loadTrips(),
            users: () => this.loadUsers(),
            chats: () => this.loadChats(),
            analytics: () => this.loadAnalytics(),
            categories: () => this.loadCategories()
        };

        await loaders[sectionName]?.();
    }

    loadDashboard() {
        const { trips, users, chats, totalLikes, totalMessages } = this.cache;
        const featuredTrip = trips[0] || {};
        const conversion = Math.min(94, Math.round((trips.length / Math.max(users.length, 1)) * 62 + 32));

        document.getElementById('dashboard-content').innerHTML = `
            <div class="dashboard-grid">
                <section class="hero-panel">
                    <div class="hero-copy">
                        <p class="eyebrow">Today in Riendzo</p>
                        <h3>Travel operations, community signals, and trip momentum in one calm view.</h3>
                        <div class="hero-actions">
                            <button class="primary-action" onclick="app.showSection('trips')">
                                <i class="fa-solid fa-route"></i>
                                Review trips
                            </button>
                            <button class="secondary-action" onclick="app.showSection('analytics')">
                                <i class="fa-solid fa-chart-simple"></i>
                                View analytics
                            </button>
                        </div>
                    </div>
                    <div class="destination-card" style="background-image: linear-gradient(180deg, rgba(7, 20, 33, .04), rgba(7, 20, 33, .78)), url('${featuredTrip.imagePath || 'https://images.pexels.com/photos/2413613/pexels-photo-2413613.jpeg?auto=compress&cs=tinysrgb&w=1200'}')">
                        <span>Featured route</span>
                        <strong>${featuredTrip.destination || 'No live trips yet'}</strong>
                        <small>${featuredTrip.tripName || 'Create or sync trips to populate this space'}</small>
                    </div>
                </section>

                <div class="metric-grid">
                    ${this.metricCard('Trips', trips.length, 'fa-route', '+12%', 'Planned and active journeys')}
                    ${this.metricCard('Travelers', users.length, 'fa-users', '+8%', 'Registered community members')}
                    ${this.metricCard('Messages', totalMessages, 'fa-comments', '+18%', 'Conversation volume')}
                    ${this.metricCard('Likes', totalLikes, 'fa-heart', '+24%', 'Trip inspiration signals')}
                </div>

                <section class="content-panel wide">
                    <div class="panel-heading">
                        <div>
                            <p class="eyebrow">Trip pipeline</p>
                            <h3>Recently created journeys</h3>
                        </div>
                        <button class="ghost-action" onclick="app.showSection('trips')">Open trips</button>
                    </div>
                    <div class="trip-strip">
                        ${trips.length ? trips.slice(0, 3).map(trip => this.tripPreview(trip)).join('') : this.emptyState('No trips found', 'Live trips from Firebase will appear here.')}
                    </div>
                </section>

                <section class="content-panel">
                    <div class="panel-heading">
                        <div>
                            <p class="eyebrow">Engagement</p>
                            <h3>Community pulse</h3>
                        </div>
                        <strong>${conversion}%</strong>
                    </div>
                    <div class="pulse-chart">
                        ${[38, 55, 46, 72, 68, 84, conversion].map(value => `<span style="height:${value}%"></span>`).join('')}
                    </div>
                </section>

                <section class="content-panel">
                    <div class="panel-heading">
                        <div>
                            <p class="eyebrow">Activity</p>
                            <h3>Latest signals</h3>
                        </div>
                    </div>
                    <div class="activity-list">
                        ${this.activityItems().join('')}
                    </div>
                </section>
            </div>
        `;
    }

    metricCard(label, value, icon, trend, description) {
        return `
            <article class="metric-card">
                <div>
                    <span>${label}</span>
                    <strong>${value}</strong>
                    <p>${description}</p>
                </div>
                <div class="metric-icon"><i class="fa-solid ${icon}"></i></div>
                <small>${trend}</small>
            </article>
        `;
    }

    tripPreview(trip) {
        return `
            <article class="trip-preview" onclick="app.viewTripDetails('${trip.id}')">
                <img src="${trip.imagePath || 'https://images.pexels.com/photos/7412095/pexels-photo-7412095.jpeg?auto=compress&cs=tinysrgb&w=600'}" alt="">
                <div>
                    <span>${trip.travelType || 'Experience'}</span>
                    <h4>${trip.destination || 'Unknown destination'}</h4>
                    <p>${trip.tripName || 'Untitled trip'}</p>
                </div>
            </article>
        `;
    }

    activityItems() {
        const items = [
            ['fa-user-plus', 'Traveler activity', this.cache.users[0]?.displayName || 'No traveler activity yet', 'Live'],
            ['fa-route', 'Trip activity', this.cache.trips[0]?.destination || 'No trip activity yet', 'Live'],
            ['fa-message', 'Conversation activity', this.cache.chats[0]?.lastMessage || 'No conversation activity yet', 'Live'],
            ['fa-heart', 'Trip received likes', `${this.cache.totalLikes || 0} total reactions`, 'Today']
        ];

        return items.map(([icon, title, detail, time]) => `
            <div class="activity-row">
                <span><i class="fa-solid ${icon}"></i></span>
                <div>
                    <strong>${title}</strong>
                    <p>${detail}</p>
                </div>
                <small>${time}</small>
            </div>
        `);
    }

    emptyState(title, description) {
        return `
            <article class="empty-data">
                <span><i class="fa-solid fa-database"></i></span>
                <strong>${title}</strong>
                <p>${description}</p>
            </article>
        `;
    }

    loadTrips(trips = this.cache.trips) {
        document.getElementById('trips-content').innerHTML = `
            <section class="content-panel page-panel">
                <div class="panel-heading">
                    <div>
                        <p class="eyebrow">Trip management</p>
                        <h3>${trips.length} journeys in the network</h3>
                    </div>
                    <button class="primary-action" onclick="app.openTripModal()">
                        <i class="fa-solid fa-plus"></i>
                        New trip
                    </button>
                </div>
                <div class="table-shell">
                    <table>
                        <thead>
                            <tr>
                                <th>Destination</th>
                                <th>Dates</th>
                                <th>Budget</th>
                                <th>Type</th>
                                <th>Signal</th>
                            </tr>
                        </thead>
                        <tbody>
                            ${trips.length ? trips.map(trip => `
                                <tr onclick="app.viewTripDetails('${trip.id}')">
                                    <td>
                                        <div class="identity-cell">
                                            <img src="${trip.imagePath || 'https://images.pexels.com/photos/7412095/pexels-photo-7412095.jpeg?auto=compress&cs=tinysrgb&w=400'}" alt="">
                                            <div>
                                                <strong>${trip.destination || 'Unknown'}</strong>
                                                <span>${trip.tripName || 'Untitled trip'}</span>
                                            </div>
                                        </div>
                                    </td>
                                    <td>${formatDate(trip.startDate)} - ${formatDate(trip.endDate)}</td>
                                    <td>${formatCurrency(trip.budget)}</td>
                                    <td><span class="soft-badge">${trip.travelType || 'General'}</span></td>
                                    <td>${trip.likes || 0} likes</td>
                                </tr>
                            `).join('') : `
                                <tr>
                                    <td colspan="5">
                                        ${this.emptyState('No trips in Firebase', 'Once users create trips, they will appear in this table.')}
                                    </td>
                                </tr>
                            `}
                        </tbody>
                    </table>
                </div>
            </section>
        `;
    }

    loadUsers(users = this.cache.users) {
        document.getElementById('users-content').innerHTML = `
            <section class="card-grid">
                ${users.length ? users.map(user => `
                    <article class="traveler-card">
                        <img src="${safeAvatar(user.photoURL)}" alt="">
                        <div>
                            <h3>${user.displayName || 'Unknown traveler'}</h3>
                            <p>${user.email || 'No email provided'}</p>
                        </div>
                        <dl>
                            <div><dt>Status</dt><dd>${getUserStatus(user).text}</dd></div>
                            <div><dt>Joined</dt><dd>${formatDate(user.createdAt)}</dd></div>
                        </dl>
                        <div class="card-actions">
                            <button onclick="app.viewUserDetails('${user.id}')">View</button>
                            <button onclick="app.suspendUser('${user.id}')">Suspend</button>
                        </div>
                    </article>
                `).join('') : this.emptyState('No travelers in Firebase', 'Registered users will appear here after they are created.')}
            </section>
        `;
    }

    loadChats(chats = this.cache.chats) {
        document.getElementById('chats-content').innerHTML = `
            <section class="content-panel page-panel">
                <div class="panel-heading">
                    <div>
                        <p class="eyebrow">Conversation safety</p>
                        <h3>Active message threads</h3>
                    </div>
                    <span class="soft-badge">${chats.length} monitored</span>
                </div>
                <div class="conversation-list">
                    ${chats.length ? chats.map(chat => `
                        <button class="conversation-row" onclick="app.viewChat('${chat.id}')">
                            <span><i class="fa-solid fa-comments"></i></span>
                            <div>
                                <strong>Thread ${chat.id.substring(0, 8)}</strong>
                                <p>${chat.lastMessage || 'No recent message'}</p>
                            </div>
                            <small>${chat.messages ? chat.messages.length : 1} msgs</small>
                        </button>
                    `).join('') : this.emptyState('No conversations in Firebase', 'Message threads will appear here when users start chatting.')}
                </div>
            </section>
        `;
    }

    loadAnalytics() {
        const segments = [
            ['Adventure', 44],
            ['Beaches', 31],
            ['Culture', 25],
            ['City breaks', 18]
        ];

        document.getElementById('analytics-content').innerHTML = `
            <section class="analytics-layout">
                <div class="content-panel page-panel">
                    <div class="panel-heading">
                        <div>
                            <p class="eyebrow">Demand mix</p>
                            <h3>Travel intent by category</h3>
                        </div>
                    </div>
                    <div class="segment-list">
                        ${segments.map(([label, value]) => `
                            <div>
                                <div><strong>${label}</strong><span>${value}%</span></div>
                                <p><span style="width:${value}%"></span></p>
                            </div>
                        `).join('')}
                    </div>
                </div>
                <div class="content-panel page-panel">
                    <div class="panel-heading">
                        <div>
                            <p class="eyebrow">Retention</p>
                            <h3>Seven day activity</h3>
                        </div>
                    </div>
                    <div class="large-chart">
                        ${[42, 58, 52, 69, 73, 81, 76].map(value => `<span style="height:${value}%"></span>`).join('')}
                    </div>
                </div>
            </section>
        `;
    }

    loadCategories() {
        const categoryTotals = this.cache.trips.reduce((acc, trip) => {
            const type = trip.travelType || 'General';
            acc[type] = (acc[type] || 0) + 1;
            return acc;
        }, {});

        document.getElementById('categories-content').innerHTML = `
            <section class="card-grid">
                ${Object.entries(categoryTotals).length ? Object.entries(categoryTotals).map(([name, total]) => `
                    <article class="category-card">
                        <span><i class="fa-solid fa-tag"></i></span>
                        <h3>${name}</h3>
                        <p>${total} active ${total === 1 ? 'trip' : 'trips'} using this category.</p>
                        <button onclick="app.showNotification('Category tools coming soon', 'info')">Manage</button>
                    </article>
                `).join('') : this.emptyState('No categories from live trips', 'Categories will appear after trips include travel types.')}
            </section>
        `;
    }

    async refreshData() {
        try {
            this.showNotification('Refreshing live data...', 'info');
            await this.refreshCache();
            this.renderShell();
            await this.showSection(this.currentSection);
            this.showNotification('Live data refreshed', 'success');
        } catch (error) {
            console.error('Error refreshing live data:', error);
            this.showFatalError(error);
            this.showNotification('Live data unavailable', 'error');
        }
    }

    search(query) {
        const normalized = query.trim().toLowerCase();
        if (!normalized) {
            this.showSection(this.currentSection);
            return;
        }

        if (this.currentSection === 'trips') {
            this.loadTrips(this.cache.trips.filter(trip => [
                trip.destination,
                trip.tripName,
                trip.travelType
            ].some(value => String(value || '').toLowerCase().includes(normalized))));
        }

        if (this.currentSection === 'users') {
            this.loadUsers(this.cache.users.filter(user => [
                user.displayName,
                user.email
            ].some(value => String(value || '').toLowerCase().includes(normalized))));
        }

        if (this.currentSection === 'chats') {
            this.loadChats(this.cache.chats.filter(chat => String(chat.lastMessage || '').toLowerCase().includes(normalized)));
        }
    }

    async exportData() {
        const blob = new Blob([JSON.stringify({ exportedAt: new Date().toISOString(), ...this.cache }, null, 2)], {
            type: 'application/json'
        });
        const url = URL.createObjectURL(blob);
        const anchor = document.createElement('a');
        anchor.href = url;
        anchor.download = `riendzo-admin-export-${new Date().toISOString().split('T')[0]}.json`;
        anchor.click();
        URL.revokeObjectURL(url);
        this.showNotification('Export created', 'success');
    }

    showAppLoading() {
        const loadingOverlay = document.createElement('div');
        loadingOverlay.className = 'loading-overlay';
        loadingOverlay.id = 'loading-overlay';
        loadingOverlay.innerHTML = `
            <div>
                <span class="loader-ring"></span>
                <h2>Loading Riendzo Admin</h2>
                <p>Preparing your workspace</p>
            </div>
        `;
        document.body.appendChild(loadingOverlay);
    }

    hideAppLoading() {
        document.getElementById('loading-overlay')?.remove();
    }

    showNotification(message, type = 'info') {
        const notification = document.createElement('div');
        notification.className = `notification ${type}`;
        notification.textContent = message;
        document.getElementById('notification-container').appendChild(notification);
        setTimeout(() => notification.classList.add('show'), 20);
        setTimeout(() => {
            notification.classList.remove('show');
            setTimeout(() => notification.remove(), 250);
        }, 2600);
    }

    calculateEngagement() {
        const score = (this.cache.totalLikes || 0) + (this.cache.totalMessages || 0) * 8 + this.cache.trips.length * 12;
        return Math.max(48, Math.min(96, score));
    }

    updateCurrentTime() {
        const timeElement = document.getElementById('current-time');
        if (timeElement) {
            timeElement.textContent = new Date().toLocaleTimeString('en-US', {
                hour: 'numeric',
                minute: '2-digit',
                hour12: true
            });
        }
    }

    toggleTheme() {
        document.body.classList.toggle('dark');
        const isDark = document.body.classList.contains('dark');
        localStorage.setItem('theme', isDark ? 'dark' : 'light');
        const icon = document.getElementById('theme-icon');
        if (icon) icon.className = isDark ? 'fa-solid fa-sun' : 'fa-solid fa-moon';
    }

    loadTheme() {
        if (localStorage.getItem('theme') === 'dark') {
            document.body.classList.add('dark');
            const icon = document.getElementById('theme-icon');
            if (icon) icon.className = 'fa-solid fa-sun';
        }
    }

    async viewTripDetails(tripId) {
        const trip = this.cache.trips.find(item => item.id === tripId) || await this.dataService.getTrip(tripId);
        if (!trip) return;
        this.showNotification(`${trip.tripName || 'Trip'}: ${trip.destination || 'Unknown destination'}`, 'info');
    }

    async viewUserDetails(userId) {
        const user = this.cache.users.find(item => item.id === userId) || await this.dataService.getUser(userId);
        if (!user) return;
        this.showNotification(`${user.displayName || 'Traveler'} is ${getUserStatus(user).text.toLowerCase()}`, 'info');
    }

    suspendUser() {
        this.showNotification('Suspension workflow queued', 'warning');
    }

    viewChat() {
        this.showNotification('Conversation viewer coming soon', 'info');
    }

    openTripModal() {
        this.showNotification('Trip creation workflow coming soon', 'info');
    }

    openSettings() {
        this.showNotification('Settings panel coming soon', 'info');
    }

    handleGlobalError(error) {
        console.error('Global error:', error);
        this.showNotification('An unexpected error occurred', 'error');
    }
}

document.addEventListener('DOMContentLoaded', async () => {
    window.app = new App();
    await window.app.initialize();
});

export default App;
