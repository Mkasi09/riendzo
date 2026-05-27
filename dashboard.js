// Global variables
let currentSection = 'dashboard';
let tripsData = [];
let usersData = [];
let categoriesData = [];

// Initialize dashboard
document.addEventListener('DOMContentLoaded', function() {
    loadInitialData();
    setupEventListeners();
    setInterval(refreshData, 30000); // Auto-refresh every 30 seconds
});

// Setup event listeners
function setupEventListeners() {
    // Trip form submission
    document.getElementById('trip-form').addEventListener('submit', function(e) {
        e.preventDefault();
        saveTrip();
    });

    // Category form submission
    document.getElementById('category-form').addEventListener('submit', function(e) {
        e.preventDefault();
        saveCategory();
    });
}

// Load initial data
async function loadInitialData() {
    try {
        await Promise.all([
            loadTrips(),
            loadUsers(),
            loadCategories(),
            loadChats(),
            updateDashboardStats()
        ]);
    } catch (error) {
        console.error('Error loading initial data:', error);
        showNotification('Error loading data', 'error');
    }
}

// Show section
function showSection(sectionName) {
    // Hide all sections
    document.querySelectorAll('section').forEach(section => {
        section.classList.add('hidden');
    });

    // Show selected section
    document.getElementById(sectionName).classList.remove('hidden');
    
    // Update title
    const titles = {
        'dashboard': 'Dashboard',
        'trips': 'Trip Management',
        'users': 'User Management',
        'chats': 'Chat Management',
        'analytics': 'Analytics',
        'categories': 'Category Management'
    };
    document.getElementById('section-title').textContent = titles[sectionName] || 'Dashboard';
    
    currentSection = sectionName;
    
    // Load section-specific data
    switch(sectionName) {
        case 'trips':
            displayTrips();
            break;
        case 'users':
            displayUsers();
            break;
        case 'chats':
            displayChats();
            break;
        case 'analytics':
            displayAnalytics();
            break;
        case 'categories':
            displayCategories();
            break;
    }
}

// Load trips from Firestore
async function loadTrips() {
    try {
        const snapshot = await db.collection('trips').get();
        tripsData = [];
        snapshot.forEach(doc => {
            tripsData.push({ id: doc.id, ...doc.data() });
        });
        return tripsData;
    } catch (error) {
        console.error('Error loading trips:', error);
        return [];
    }
}

// Load users from Firestore
async function loadUsers() {
    try {
        const snapshot = await db.collection('users').get();
        usersData = [];
        snapshot.forEach(doc => {
            usersData.push({ id: doc.id, ...doc.data() });
        });
        return usersData;
    } catch (error) {
        console.error('Error loading users:', error);
        return [];
    }
}

// Load categories
async function loadCategories() {
    // Using the categories from the Flutter app
    categoriesData = [
        "Adventure", "Beaches", "Culture", "Cuisine", "Exploration", "Festivals",
        "Hiking", "History", "Relaxation", "Safari", "Scenery", "Sports",
        "Wildlife", "Cruises", "Mountains", "Photography", "Roadtrips",
        "Shopping", "Spa", "Waterfalls"
    ];
    return categoriesData;
}

// Load chats
async function loadChats() {
    try {
        const snapshot = await db.collection('chats').get();
        const chatsData = [];
        snapshot.forEach(doc => {
            chatsData.push({ id: doc.id, ...doc.data() });
        });
        return chatsData;
    } catch (error) {
        console.error('Error loading chats:', error);
        return [];
    }
}

// Update dashboard statistics
async function updateDashboardStats() {
    try {
        const trips = await loadTrips();
        const users = await loadUsers();
        const chats = await loadChats();
        
        let totalLikes = 0;
        let totalMessages = 0;
        
        // Count likes and messages
        for (const trip of trips) {
            const likesSnapshot = await db.collection('trips').doc(trip.id).collection('likes').get();
            totalLikes += likesSnapshot.size;
        }
        
        for (const chat of chats) {
            const messagesSnapshot = await db.collection('chats').doc(chat.id).collection('messages').get();
            totalMessages += messagesSnapshot.size;
        }
        
        // Update UI
        document.getElementById('total-trips').textContent = trips.length;
        document.getElementById('total-users').textContent = users.length;
        document.getElementById('total-messages').textContent = totalMessages;
        document.getElementById('total-likes').textContent = totalLikes;
        
        // Display recent trips
        displayRecentTrips(trips.slice(0, 5));
        
        // Display recent activity
        displayRecentActivity(trips.slice(0, 3));
        
    } catch (error) {
        console.error('Error updating stats:', error);
    }
}

// Display recent trips on dashboard
function displayRecentTrips(trips) {
    const container = document.getElementById('recent-trips');
    container.innerHTML = '';
    
    trips.forEach(trip => {
        const tripElement = document.createElement('div');
        tripElement.className = 'p-4 border rounded-lg hover:bg-gray-50 transition cursor-pointer';
        tripElement.innerHTML = `
            <div class="flex justify-between items-start">
                <div>
                    <h4 class="font-semibold">${trip.destination || 'Unknown'}</h4>
                    <p class="text-sm text-gray-600">${trip.tripName || 'No name'}</p>
                    <p class="text-xs text-gray-500">${trip.startDate || 'No date'} - ${trip.endDate || 'No date'}</p>
                </div>
                <span class="px-2 py-1 bg-green-100 text-green-800 text-xs rounded-full">Active</span>
            </div>
        `;
        tripElement.onclick = () => viewTripDetails(trip.id);
        container.appendChild(tripElement);
    });
}

// Display recent activity
function displayRecentActivity(trips) {
    const container = document.getElementById('recent-activity');
    container.innerHTML = '';
    
    trips.forEach(trip => {
        const activityElement = document.createElement('div');
        activityElement.className = 'flex items-center space-x-3 p-3 hover:bg-gray-50 rounded-lg transition';
        activityElement.innerHTML = `
            <div class="w-10 h-10 bg-indigo-100 rounded-full flex items-center justify-center">
                <i class="fas fa-map-marker-alt text-indigo-600"></i>
            </div>
            <div class="flex-1">
                <p class="text-sm font-medium">New trip created</p>
                <p class="text-xs text-gray-500">${trip.destination || 'Unknown destination'}</p>
            </div>
            <span class="text-xs text-gray-400">Just now</span>
        `;
        container.appendChild(activityElement);
    });
}

// Display trips in trips section
function displayTrips() {
    const tbody = document.getElementById('trips-table');
    tbody.innerHTML = '';
    
    tripsData.forEach(trip => {
        const row = document.createElement('tr');
        row.className = 'hover:bg-gray-50 transition';
        row.innerHTML = `
            <td class="px-6 py-4 whitespace-nowrap">
                <div class="flex items-center">
                    <img class="h-10 w-10 rounded-full object-cover mr-3" src="${trip.imagePath || 'https://via.placeholder.com/40'}" alt="">
                    <div>
                        <div class="text-sm font-medium text-gray-900">${trip.destination || 'Unknown'}</div>
                        <div class="text-sm text-gray-500">${trip.tripName || 'No name'}</div>
                    </div>
                </div>
            </td>
            <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                ${trip.userId || 'Unknown'}
            </td>
            <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                ${trip.startDate || 'N/A'} - ${trip.endDate || 'N/A'}
            </td>
            <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                $${trip.budget || '0'}
            </td>
            <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                <span class="text-red-500"><i class="fas fa-heart"></i> ${trip.likes || 0}</span>
            </td>
            <td class="px-6 py-4 whitespace-nowrap text-sm font-medium">
                <button onclick="editTrip('${trip.id}')" class="text-indigo-600 hover:text-indigo-900 mr-3">Edit</button>
                <button onclick="deleteTrip('${trip.id}')" class="text-red-600 hover:text-red-900">Delete</button>
            </td>
        `;
        tbody.appendChild(row);
    });
}

// Display users
function displayUsers() {
    const grid = document.getElementById('users-grid');
    grid.innerHTML = '';
    
    usersData.forEach(user => {
        const userCard = document.createElement('div');
        userCard.className = 'bg-white p-6 rounded-lg shadow hover:shadow-lg transition';
        userCard.innerHTML = `
            <div class="flex items-center mb-4">
                <img class="h-12 w-12 rounded-full object-cover mr-3" src="${user.photoURL || 'https://via.placeholder.com/48'}" alt="">
                <div>
                    <h4 class="font-semibold">${user.displayName || 'Unknown User'}</h4>
                    <p class="text-sm text-gray-500">${user.email || 'No email'}</p>
                </div>
            </div>
            <div class="space-y-2">
                <div class="flex justify-between text-sm">
                    <span class="text-gray-500">Status:</span>
                    <span class="text-green-600 font-medium">Active</span>
                </div>
                <div class="flex justify-between text-sm">
                    <span class="text-gray-500">Joined:</span>
                    <span>${new Date(user.createdAt || Date.now()).toLocaleDateString()}</span>
                </div>
                <div class="flex space-x-2 mt-4">
                    <button onclick="viewUserDetails('${user.id}')" class="flex-1 px-3 py-1 bg-blue-100 text-blue-700 rounded hover:bg-blue-200 transition text-sm">View</button>
                    <button onclick="suspendUser('${user.id}')" class="flex-1 px-3 py-1 bg-red-100 text-red-700 rounded hover:bg-red-200 transition text-sm">Suspend</button>
                </div>
            </div>
        `;
        grid.appendChild(userCard);
    });
}

// Display chats
async function displayChats() {
    const conversationsList = document.getElementById('conversations-list');
    const messagesList = document.getElementById('messages-list');
    
    conversationsList.innerHTML = '';
    messagesList.innerHTML = '';
    
    try {
        const chats = await loadChats();
        
        for (const chat of chats) {
            // Display conversation
            const convElement = document.createElement('div');
            convElement.className = 'p-3 border rounded-lg hover:bg-gray-50 transition cursor-pointer';
            convElement.innerHTML = `
                <div class="flex items-center justify-between">
                    <div class="flex items-center">
                        <div class="w-10 h-10 bg-blue-100 rounded-full flex items-center justify-center mr-3">
                            <i class="fas fa-comments text-blue-600"></i>
                        </div>
                        <div>
                            <p class="font-medium text-sm">Chat ${chat.id}</p>
                            <p class="text-xs text-gray-500">Active conversation</p>
                        </div>
                    </div>
                    <span class="w-2 h-2 bg-green-500 rounded-full"></span>
                </div>
            `;
            conversationsList.appendChild(convElement);
            
            // Get messages for this chat
            const messagesSnapshot = await db.collection('chats').doc(chat.id).collection('messages').orderBy('timestamp', 'desc').limit(3).get();
            messagesSnapshot.forEach(msgDoc => {
                const msg = msgDoc.data();
                const msgElement = document.createElement('div');
                msgElement.className = 'message-item p-3 border rounded-lg';
                msgElement.innerHTML = `
                    <div class="flex items-start">
                        <div class="w-8 h-8 bg-gray-200 rounded-full flex items-center justify-center mr-3">
                            <i class="fas fa-user text-gray-600 text-xs"></i>
                        </div>
                        <div class="flex-1">
                            <p class="text-sm font-medium">User ${msg.sender}</p>
                            <p class="text-sm text-gray-700">${msg.text}</p>
                            <p class="text-xs text-gray-500">${new Date(msg.timestamp).toLocaleTimeString()}</p>
                        </div>
                    </div>
                `;
                messagesList.appendChild(msgElement);
            });
        }
    } catch (error) {
        console.error('Error displaying chats:', error);
    }
}

// Display analytics
function displayAnalytics() {
    // Create charts (simplified version - in production you'd use Chart.js or similar)
    const categoriesChart = document.getElementById('categories-chart');
    const activityChart = document.getElementById('activity-chart');
    
    categoriesChart.innerHTML = '<p class="text-center text-gray-500">Categories distribution chart would be displayed here</p>';
    activityChart.innerHTML = '<p class="text-center text-gray-500">User activity timeline chart would be displayed here</p>';
}

// Display categories
function displayCategories() {
    const grid = document.getElementById('categories-grid');
    grid.innerHTML = '';
    
    categoriesData.forEach(category => {
        const categoryCard = document.createElement('div');
        categoryCard.className = 'bg-white p-4 rounded-lg shadow hover:shadow-lg transition text-center';
        categoryCard.innerHTML = `
            <div class="w-16 h-16 bg-gradient-to-br from-indigo-100 to-purple-100 rounded-lg mx-auto mb-3 flex items-center justify-center">
                <i class="fas fa-tag text-indigo-600 text-xl"></i>
            </div>
            <h4 class="font-medium text-sm">${category}</h4>
            <p class="text-xs text-gray-500 mt-1">0 trips</p>
            <div class="flex space-x-2 mt-3">
                <button onclick="editCategory('${category}')" class="text-blue-600 hover:text-blue-800 text-sm">Edit</button>
                <button onclick="deleteCategory('${category}')" class="text-red-600 hover:text-red-800 text-sm">Delete</button>
            </div>
        `;
        grid.appendChild(categoryCard);
    });
}

// Trip management functions
function openTripModal(tripId = null) {
    document.getElementById('trip-modal').classList.remove('hidden');
    if (tripId) {
        // Load trip data for editing
        const trip = tripsData.find(t => t.id === tripId);
        if (trip) {
            document.getElementById('trip-name').value = trip.tripName || '';
            document.getElementById('destination').value = trip.destination || '';
            document.getElementById('start-date').value = trip.startDate || '';
            document.getElementById('end-date').value = trip.endDate || '';
            document.getElementById('budget').value = trip.budget || '';
            document.getElementById('travel-type').value = trip.travelType || '';
            document.getElementById('description').value = trip.description || '';
        }
    }
}

function closeTripModal() {
    document.getElementById('trip-modal').classList.add('hidden');
    document.getElementById('trip-form').reset();
}

async function saveTrip() {
    try {
        const tripData = {
            tripName: document.getElementById('trip-name').value,
            destination: document.getElementById('destination').value,
            startDate: document.getElementById('start-date').value,
            endDate: document.getElementById('end-date').value,
            budget: document.getElementById('budget').value,
            travelType: document.getElementById('travel-type').value,
            description: document.getElementById('description').value,
            createdAt: new Date().toISOString(),
            userId: 'admin' // In production, this would be the current user's ID
        };
        
        await db.collection('trips').add(tripData);
        closeTripModal();
        loadTrips();
        displayTrips();
        showNotification('Trip saved successfully', 'success');
    } catch (error) {
        console.error('Error saving trip:', error);
        showNotification('Error saving trip', 'error');
    }
}

async function deleteTrip(tripId) {
    if (confirm('Are you sure you want to delete this trip?')) {
        try {
            await db.collection('trips').doc(tripId).delete();
            loadTrips();
            displayTrips();
            showNotification('Trip deleted successfully', 'success');
        } catch (error) {
            console.error('Error deleting trip:', error);
            showNotification('Error deleting trip', 'error');
        }
    }
}

function editTrip(tripId) {
    openTripModal(tripId);
}

// Category management functions
function openCategoryModal() {
    document.getElementById('category-modal').classList.remove('hidden');
}

function closeCategoryModal() {
    document.getElementById('category-modal').classList.add('hidden');
    document.getElementById('category-form').reset();
}

function saveCategory() {
    const categoryName = document.getElementById('category-name').value;
    const categoryImage = document.getElementById('category-image').value;
    
    if (categoryName) {
        categoriesData.push(categoryName);
        closeCategoryModal();
        displayCategories();
        showNotification('Category added successfully', 'success');
    }
}

function deleteCategory(categoryName) {
    if (confirm(`Are you sure you want to delete "${categoryName}"?`)) {
        categoriesData = categoriesData.filter(cat => cat !== categoryName);
        displayCategories();
        showNotification('Category deleted successfully', 'success');
    }
}

function editCategory(categoryName) {
    const newName = prompt('Enter new category name:', categoryName);
    if (newName && newName !== categoryName) {
        const index = categoriesData.indexOf(categoryName);
        if (index > -1) {
            categoriesData[index] = newName;
            displayCategories();
            showNotification('Category updated successfully', 'success');
        }
    }
}

// User management functions
function viewUserDetails(userId) {
    console.log('View user:', userId);
    showNotification('User details view would open here', 'info');
}

function suspendUser(userId) {
    if (confirm('Are you sure you want to suspend this user?')) {
        showNotification('User suspended successfully', 'success');
    }
}

function viewTripDetails(tripId) {
    console.log('View trip details:', tripId);
    showTripDetailsModal(tripId);
}

// Show trip details modal
async function showTripDetailsModal(tripId) {
    try {
        const tripDoc = await db.collection('trips').doc(tripId).get();
        const trip = tripDoc.data();
        
        if (trip) {
            alert(`Trip Details:\n\nName: ${trip.tripName || 'No name'}\nDestination: ${trip.destination || 'Unknown'}\nDates: ${trip.startDate || 'N/A'} - ${trip.endDate || 'N/A'}\nBudget: $${trip.budget || '0'}\nDescription: ${trip.description || 'No description'}`);
        }
    } catch (error) {
        console.error('Error loading trip details:', error);
        showNotification('Error loading trip details', 'error');
    }
}

// Refresh data
async function refreshData() {
    try {
        await loadInitialData();
        showNotification('Data refreshed successfully', 'success');
    } catch (error) {
        console.error('Error refreshing data:', error);
        showNotification('Error refreshing data', 'error');
    }
}

// Show notification
function showNotification(message, type = 'info') {
    const notification = document.createElement('div');
    notification.className = `fixed top-4 right-4 px-6 py-3 rounded-lg shadow-lg z-50 ${
        type === 'success' ? 'bg-green-500 text-white' :
        type === 'error' ? 'bg-red-500 text-white' :
        'bg-blue-500 text-white'
    }`;
    notification.textContent = message;
    document.body.appendChild(notification);
    
    setTimeout(() => {
        notification.remove();
    }, 3000);
}
