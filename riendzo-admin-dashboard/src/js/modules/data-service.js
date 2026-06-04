import FirebaseService from './firebase-service.js';

export class DataService {
    constructor() {
        this.firebaseService = new FirebaseService();
    }

    async getDashboardData() {
        const [trips, users, chats] = await Promise.all([
            this.firebaseService.getTrips(),
            this.firebaseService.getUsers(),
            this.firebaseService.getChats()
        ]);
        const transportRequests = await this.firebaseService.getTransportRequests();

        const totalLikes = trips.reduce((sum, trip) => sum + Number(trip.likes || 0), 0);
        const totalMessages = chats.reduce((sum, chat) => sum + (chat.messages ? chat.messages.length : 1), 0);

        return { trips, users, chats, transportRequests, totalLikes, totalMessages };
    }

    async getTrip(tripId) {
        return this.firebaseService.getTrip(tripId);
    }

    async getUser(userId) {
        return this.firebaseService.getUser(userId);
    }

    async createTrip(tripData) {
        return this.firebaseService.createTrip(tripData);
    }

    async updateTrip(tripId, tripData) {
        return this.firebaseService.updateTrip(tripId, tripData);
    }

    async updateUser(userId, userData) {
        return this.firebaseService.updateUser(userId, userData);
    }
}

export default DataService;
