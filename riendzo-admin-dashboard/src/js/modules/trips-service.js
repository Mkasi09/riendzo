import FirebaseService from './firebase-service.js';
import UIService from './ui-service.js';

export class TripsService {
    constructor() {
        this.firebaseService = new FirebaseService();
        this.uiService = new UIService();
        this.currentEditingTrip = null;
    }

    async initializeTripsSection() {
        try {
            this.uiService.showLoading('trips-content', 'Loading trips...');
            
            // Load trips
            await this.loadTrips();
            
            // Load modals
            await this.loadModals();
            
            // Setup event listeners
            this.setupEventListeners();
            
            this.uiService.hideLoading('trips-content');
        } catch (error) {
            console.error('Error initializing trips section:', error);
            this.uiService.showNotification('Error loading trips', 'error');
            this.uiService.hideLoading('trips-content');
        }
    }

    async loadTrips() {
        try {
            const trips = await this.firebaseService.getTrips();
            this.displayTrips(trips);
        } catch (error) {
            console.error('Error loading trips:', error);
            throw error;
        }
    }

    displayTrips(trips) {
        const headers = ['Destination', 'User', 'Dates', 'Budget', 'Likes'];
        const actions = [
            {
                label: 'Edit',
                color: 'indigo',
                callback: `app.tripsService.editTrip('${trips[0]?.id || ''}')`
            },
            {
                label: 'Delete',
                color: 'red',
                callback: `app.tripsService.deleteTrip('${trips[0]?.id || ''}')`
            }
        ];

        const tableData = trips.map(trip => ({
            Destination: this.createTripDisplay(trip),
            User: trip.userId || 'Unknown',
            Dates: `${this.uiService.formatDate(trip.startDate)} - ${this.uiService.formatDate(trip.endDate)}`,
            Budget: this.uiService.formatCurrency(trip.budget || 0),
            Likes: `<span class="text-red-500"><i class="fas fa-heart"></i> ${trip.likes || 0}</span>`
        }));

        const tableHTML = this.uiService.createTable(headers, tableData, actions);
        
        const content = `
            <div class="bg-white rounded-xl shadow-lg p-6">
                <div class="flex justify-between items-center mb-6">
                    <h3 class="text-xl font-semibold">Trip Management</h3>
                    <button onclick="app.tripsService.openTripModal()" class="px-4 py-2 bg-green-600 text-white rounded-lg hover:bg-green-700 transition">
                        <i class="fas fa-plus mr-2"></i>Add Trip
                    </button>
                </div>
                ${tableHTML}
            </div>
        `;

        document.getElementById('trips-content').innerHTML = content;
    }

    createTripDisplay(trip) {
        return `
            <div class="flex items-center">
                <img class="h-10 w-10 rounded-full object-cover mr-3" 
                     src="${trip.imagePath || 'https://via.placeholder.com/40'}" 
                     alt="${trip.destination}">
                <div>
                    <div class="text-sm font-medium text-gray-900">${trip.destination || 'Unknown'}</div>
                    <div class="text-sm text-gray-500">${trip.tripName || 'No name'}</div>
                </div>
            </div>
        `;
    }

    async loadModals() {
        try {
            await this.uiService.loadComponent('modal-container', '../components/modals.html');
        } catch (error) {
            console.error('Error loading modals:', error);
        }
    }

    setupEventListeners() {
        // Trip form submission
        const tripForm = document.getElementById('trip-form');
        if (tripForm) {
            tripForm.addEventListener('submit', (e) => {
                e.preventDefault();
                this.saveTrip();
            });
        }
    }

    openTripModal(tripId = null) {
        this.currentEditingTrip = tripId;
        
        if (tripId) {
            this.loadTripForEdit(tripId);
        } else {
            this.uiService.resetForm('trip-form');
        }
        
        this.uiService.showModal('trip-modal');
    }

    async loadTripForEdit(tripId) {
        try {
            const trip = await this.firebaseService.getTrip(tripId);
            if (trip) {
                this.uiService.setFormData('trip-form', {
                    'trip-name': trip.tripName || '',
                    'destination': trip.destination || '',
                    'start-date': trip.startDate || '',
                    'end-date': trip.endDate || '',
                    'budget': trip.budget || '',
                    'travel-type': trip.travelType || '',
                    'description': trip.description || ''
                });
            }
        } catch (error) {
            console.error('Error loading trip for edit:', error);
            this.uiService.showNotification('Error loading trip data', 'error');
        }
    }

    closeTripModal() {
        this.uiService.hideModal('trip-modal');
        this.uiService.resetForm('trip-form');
        this.currentEditingTrip = null;
    }

    async saveTrip() {
        try {
            const formData = this.uiService.getFormData('trip-form');
            
            const tripData = {
                tripName: formData['trip-name'],
                destination: formData.destination,
                startDate: formData['start-date'],
                endDate: formData['end-date'],
                budget: parseFloat(formData.budget) || 0,
                travelType: formData['travel-type'],
                description: formData.description,
                userId: 'admin', // In production, this would be the current user's ID
                updatedAt: new Date().toISOString()
            };

            if (this.currentEditingTrip) {
                // Update existing trip
                await this.firebaseService.updateTrip(this.currentEditingTrip, tripData);
                this.uiService.showNotification('Trip updated successfully', 'success');
            } else {
                // Create new trip
                tripData.createdAt = new Date().toISOString();
                await this.firebaseService.createTrip(tripData);
                this.uiService.showNotification('Trip created successfully', 'success');
            }

            this.closeTripModal();
            await this.loadTrips();
            
        } catch (error) {
            console.error('Error saving trip:', error);
            this.uiService.showNotification('Error saving trip', 'error');
        }
    }

    async deleteTrip(tripId) {
        this.uiService.confirmAction('Are you sure you want to delete this trip?', async () => {
            try {
                await this.firebaseService.deleteTrip(tripId);
                this.uiService.showNotification('Trip deleted successfully', 'success');
                await this.loadTrips();
            } catch (error) {
                console.error('Error deleting trip:', error);
                this.uiService.showNotification('Error deleting trip', 'error');
            }
        });
    }

    async editTrip(tripId) {
        this.openTripModal(tripId);
    }

    async viewTripDetails(tripId) {
        try {
            const trip = await this.firebaseService.getTrip(tripId);
            if (trip) {
                const details = `
                    Trip Details:
                    
                    Name: ${trip.tripName || 'No name'}
                    Destination: ${trip.destination || 'Unknown'}
                    Dates: ${this.uiService.formatDate(trip.startDate)} - ${this.uiService.formatDate(trip.endDate)}
                    Budget: ${this.uiService.formatCurrency(trip.budget || 0)}
                    Travel Type: ${trip.travelType || 'Not specified'}
                    Description: ${trip.description || 'No description'}
                `;
                alert(details);
            }
        } catch (error) {
            console.error('Error loading trip details:', error);
            this.uiService.showNotification('Error loading trip details', 'error');
        }
    }

    async searchTrips(query) {
        try {
            const trips = await this.firebaseService.getTrips();
            const filteredTrips = trips.filter(trip => 
                trip.destination?.toLowerCase().includes(query.toLowerCase()) ||
                trip.tripName?.toLowerCase().includes(query.toLowerCase()) ||
                trip.travelType?.toLowerCase().includes(query.toLowerCase())
            );
            this.displayTrips(filteredTrips);
        } catch (error) {
            console.error('Error searching trips:', error);
            this.uiService.showNotification('Error searching trips', 'error');
        }
    }

    async filterTripsByType(travelType) {
        try {
            const trips = await this.firebaseService.getTrips();
            const filteredTrips = travelType ? 
                trips.filter(trip => trip.travelType === travelType) : 
                trips;
            this.displayTrips(filteredTrips);
        } catch (error) {
            console.error('Error filtering trips:', error);
            this.uiService.showNotification('Error filtering trips', 'error');
        }
    }

    async sortTrips(sortBy) {
        try {
            const trips = await this.firebaseService.getTrips();
            let sortedTrips = [...trips];

            switch (sortBy) {
                case 'destination':
                    sortedTrips.sort((a, b) => (a.destination || '').localeCompare(b.destination || ''));
                    break;
                case 'budget':
                    sortedTrips.sort((a, b) => (a.budget || 0) - (b.budget || 0));
                    break;
                case 'date':
                    sortedTrips.sort((a, b) => new Date(b.createdAt || 0) - new Date(a.createdAt || 0));
                    break;
                case 'likes':
                    sortedTrips.sort((a, b) => (a.likes || 0) - (b.likes || 0));
                    break;
            }

            this.displayTrips(sortedTrips);
        } catch (error) {
            console.error('Error sorting trips:', error);
            this.uiService.showNotification('Error sorting trips', 'error');
        }
    }
}

export default TripsService;
