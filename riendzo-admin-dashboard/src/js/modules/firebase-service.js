import { db, auth, rtdb, collections, paths, firebaseInitializationError } from '../../config/firebase.js';

export class FirebaseService {
    constructor() {
        this.db = db;
        this.auth = auth;
        this.rtdb = rtdb;
        this.collections = collections;
        this.paths = paths;
    }

    assertReady() {
        if (firebaseInitializationError) {
            throw firebaseInitializationError;
        }

        if (!this.db) {
            throw new Error('Firestore is not available. Check Firebase SDK loading and configuration.');
        }
    }

    // Trips CRUD operations
    async getTrips() {
        try {
            this.assertReady();
            const snapshot = await this.db.collection(this.collections.trips).get();
            return snapshot.docs.map(doc => ({ id: doc.id, ...doc.data() }));
        } catch (error) {
            console.error('Error fetching trips:', error);
            throw error;
        }
    }

    async getTrip(tripId) {
        try {
            this.assertReady();
            const doc = await this.db.collection(this.collections.trips).doc(tripId).get();
            return doc.exists ? { id: doc.id, ...doc.data() } : null;
        } catch (error) {
            console.error('Error fetching trip:', error);
            throw error;
        }
    }

    async createTrip(tripData) {
        try {
            this.assertReady();
            const docRef = await this.db.collection(this.collections.trips).add({
                ...tripData,
                createdAt: new Date().toISOString()
            });
            return docRef.id;
        } catch (error) {
            console.error('Error creating trip:', error);
            throw error;
        }
    }

    async updateTrip(tripId, tripData) {
        try {
            this.assertReady();
            await this.db.collection(this.collections.trips).doc(tripId).update(tripData);
            return true;
        } catch (error) {
            console.error('Error updating trip:', error);
            throw error;
        }
    }

    async deleteTrip(tripId) {
        try {
            this.assertReady();
            await this.db.collection(this.collections.trips).doc(tripId).delete();
            return true;
        } catch (error) {
            console.error('Error deleting trip:', error);
            throw error;
        }
    }

    // Users CRUD operations
    async getUsers() {
        try {
            this.assertReady();
            const snapshot = await this.db.collection(this.collections.users).get();
            return snapshot.docs.map(doc => ({ id: doc.id, ...doc.data() }));
        } catch (error) {
            console.error('Error fetching users:', error);
            throw error;
        }
    }

    async getUser(userId) {
        try {
            this.assertReady();
            const doc = await this.db.collection(this.collections.users).doc(userId).get();
            return doc.exists ? { id: doc.id, ...doc.data() } : null;
        } catch (error) {
            console.error('Error fetching user:', error);
            throw error;
        }
    }

    // Chats operations
    async getChats() {
        try {
            this.assertReady();
            const snapshot = await this.db.collection(this.collections.chats).get();
            return snapshot.docs.map(doc => ({ id: doc.id, ...doc.data() }));
        } catch (error) {
            console.error('Error fetching chats:', error);
            throw error;
        }
    }

    async getChatMessages(chatId, limit = 50) {
        try {
            this.assertReady();
            const snapshot = await this.db
                .collection(this.collections.chats)
                .doc(chatId)
                .collection('messages')
                .orderBy('timestamp', 'desc')
                .limit(limit)
                .get();
            return snapshot.docs.map(doc => ({ id: doc.id, ...doc.data() }));
        } catch (error) {
            console.error('Error fetching chat messages:', error);
            throw error;
        }
    }

    // Likes operations
    async getTripLikes(tripId) {
        try {
            this.assertReady();
            const snapshot = await this.db
                .collection(this.collections.trips)
                .doc(tripId)
                .collection('likes')
                .get();
            return snapshot.docs.map(doc => ({ id: doc.id, ...doc.data() }));
        } catch (error) {
            console.error('Error fetching trip likes:', error);
            throw error;
        }
    }

    // Comments operations
    async getTripComments(tripId) {
        try {
            this.assertReady();
            const snapshot = await this.db
                .collection(this.collections.trips)
                .doc(tripId)
                .collection('comments')
                .get();
            return snapshot.docs.map(doc => ({ id: doc.id, ...doc.data() }));
        } catch (error) {
            console.error('Error fetching trip comments:', error);
            throw error;
        }
    }

    // Statistics
    async getDashboardStats() {
        try {
            const [trips, users, chats] = await Promise.all([
                this.getTrips(),
                this.getUsers(),
                this.getChats()
            ]);

            let totalLikes = 0;
            let totalMessages = 0;

            // Count likes
            for (const trip of trips) {
                const likes = await this.getTripLikes(trip.id);
                totalLikes += likes.length;
            }

            // Count messages
            for (const chat of chats) {
                const messages = await this.getChatMessages(chat.id);
                totalMessages += messages.length;
            }

            return {
                totalTrips: trips.length,
                totalUsers: users.length,
                totalMessages: totalMessages,
                totalLikes: totalLikes,
                trips: trips.slice(0, 5), // Recent trips
                users: users.slice(0, 5)  // Recent users
            };
        } catch (error) {
            console.error('Error fetching dashboard stats:', error);
            throw error;
        }
    }

    // Real-time listeners
    onTripsChange(callback) {
        this.assertReady();
        return this.db.collection(this.collections.trips).onSnapshot(callback);
    }

    onUsersChange(callback) {
        this.assertReady();
        return this.db.collection(this.collections.users).onSnapshot(callback);
    }

    onChatsChange(callback) {
        this.assertReady();
        return this.db.collection(this.collections.chats).onSnapshot(callback);
    }
}

export default FirebaseService;
