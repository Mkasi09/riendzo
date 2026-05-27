// Firebase Configuration
const firebaseConfig = {
  apiKey: "AIzaSyBuWQKQ1yInAf0dDA99jT9PY7-7eT4zixU",
  authDomain: "riendzo.firebaseapp.com",
  databaseURL: "https://riendzo-default-rtdb.firebaseio.com",
  projectId: "riendzo",
  storageBucket: "riendzo.appspot.com",
  messagingSenderId: "354234220170",
  appId: "1:354234220170:web:44cdcc695afdf2dc28f773",
  measurementId: "G-FLH0H5Z9NE"
};

// Initialize Firebase only if config is valid
let db, auth, rtdb;
let firebaseInitializationError = null;

try {
    // Check if Firebase is loaded and config is valid
    if (typeof firebase !== 'undefined' && firebaseConfig.apiKey !== 'your-api-key') {
        firebase.initializeApp(firebaseConfig);
        db = firebase.firestore();
        auth = firebase.auth();
        rtdb = firebase.database();
        console.log('Firebase initialized successfully');
    } else {
        firebaseInitializationError = new Error('Firebase SDK is not loaded or Firebase config is missing.');
        console.error(firebaseInitializationError.message);
    }
} catch (error) {
    firebaseInitializationError = error;
    console.error('Firebase initialization failed:', error);
}

// Export Firebase services
export { db, auth, rtdb, firebaseInitializationError };

// Development mode check
export const isDevelopment = window.location.hostname === 'localhost' || window.location.hostname === '127.0.0.1';

// Firebase collections
export const collections = {
    trips: 'trips',
    users: 'users',
    chats: 'chats',
    categories: 'categories'
};

// Firebase paths for real-time database
export const paths = {
    userConversations: 'user_conversations',
    onlineUsers: 'online_users',
    notifications: 'notifications'
};
