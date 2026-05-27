# Riendo Admin Dashboard

A comprehensive HTML/JavaScript admin dashboard to manage all aspects of the Riendo travel social app.

## Features

### 📊 Dashboard Overview
- **Real-time Statistics**: Total trips, active users, messages, and likes
- **Recent Trips Display**: Latest trips with quick access to details
- **Activity Feed**: Recent app activities and updates
- **Auto-refresh**: Data updates every 30 seconds

### 🗺️ Trip Management
- **View All Trips**: Complete list with destination, user, dates, budget, and likes
- **Add New Trips**: Create trips with all details including travel type and description
- **Edit Existing Trips**: Modify trip information
- **Delete Trips**: Remove trips with confirmation
- **Trip Categories**: Support for 20+ travel categories from the Flutter app

### 👥 User Management
- **User Profiles**: View user information, status, and join dates
- **User Actions**: View details and suspend users
- **User Statistics**: Track active users and their activities

### 💬 Chat Management
- **Active Conversations**: Monitor ongoing chats between users
- **Recent Messages**: View latest messages across all conversations
- **Real-time Updates**: Live chat monitoring capabilities

### 📈 Analytics
- **Trip Categories Distribution**: Visual representation of travel preferences
- **User Activity Timeline**: Track user engagement over time
- **Performance Metrics**: Comprehensive app usage statistics

### 🏷️ Category Management
- **Travel Categories**: Manage the 20 predefined categories
- **Add/Edit Categories**: Customize travel categories
- **Category Statistics**: Track trips per category

## Technical Implementation

### Frontend Technologies
- **HTML5**: Semantic structure
- **Tailwind CSS**: Modern responsive design
- **Vanilla JavaScript**: No framework dependencies
- **Font Awesome**: Icon library

### Backend Integration
- **Firebase Firestore**: Database operations
- **Firebase Authentication**: User management
- **Firebase Realtime Database**: Chat functionality
- **RESTful API**: Standard CRUD operations

### Data Models
The dashboard manages the following data structures:

#### Trip Model
```javascript
{
  id: string,
  tripName: string,
  destination: string,
  startDate: string,
  endDate: string,
  budget: number,
  travelType: string,
  description: string,
  imagePath: string,
  userId: string,
  createdAt: timestamp
}
```

#### User Model
```javascript
{
  id: string,
  displayName: string,
  email: string,
  photoURL: string,
  createdAt: timestamp,
  status: string
}
```

#### Chat Model
```javascript
{
  id: string,
  participants: array,
  lastMessage: string,
  timestamp: timestamp,
  messages: [{
    text: string,
    sender: string,
    timestamp: timestamp
  }]
}
```

## Setup Instructions

### 1. Firebase Configuration
Update the Firebase configuration in `admin-dashboard.html`:
```javascript
const firebaseConfig = {
    apiKey: "your-api-key",
    authDomain: "riendzo.firebaseapp.com",
    projectId: "riendzo",
    storageBucket: "riendzo.appspot.com",
    messagingSenderId: "your-sender-id",
    appId: "your-app-id"
};
```

### 2. Firebase Security Rules
Ensure your Firestore rules allow admin access:
```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /{document=**} {
      allow read, write: if request.auth != null;
    }
  }
}
```

### 3. Local Development
1. Open `admin-dashboard.html` in a web browser
2. Configure Firebase with your project details
3. The dashboard will automatically connect to your Firebase project

## File Structure
```
riendzo/
├── admin-dashboard.html    # Main dashboard HTML
├── dashboard.js           # JavaScript functionality
└── README-ADMIN.md       # This documentation
```

## Dashboard Sections

### 1. Dashboard Tab
- Overview statistics cards with gradient backgrounds
- Recent trips with hover effects
- Activity feed with timestamps
- Real-time data updates

### 2. Trips Tab
- Sortable table with trip information
- Add/Edit/Delete functionality
- Modal forms for trip creation
- Image previews and user information

### 3. Users Tab
- Grid layout for user cards
- User status indicators
- Quick action buttons
- Profile information display

### 4. Chats Tab
- Two-column layout for conversations and messages
- Real-time message updates
- User avatars and timestamps
- Active conversation indicators

### 5. Analytics Tab
- Chart placeholders for data visualization
- Category distribution analysis
- User activity tracking
- Performance metrics

### 6. Categories Tab
- Grid layout for travel categories
- Category management options
- Trip count per category
- Visual category representation

## Responsive Design
- Mobile-friendly layout
- Adaptive grid systems
- Touch-friendly interactions
- Optimized for all screen sizes

## Security Features
- Firebase authentication required
- Role-based access control
- Data validation on forms
- Confirmation dialogs for destructive actions

## Performance Optimizations
- Efficient data loading
- Auto-refresh with configurable intervals
- Lazy loading for large datasets
- Optimized Firebase queries

## Browser Compatibility
- Chrome 60+
- Firefox 55+
- Safari 12+
- Edge 79+

## Future Enhancements
- Real-time WebSocket connections
- Advanced filtering and search
- Export functionality for reports
- Email notifications for admin actions
- Multi-language support
- Dark mode toggle

## Support
For issues or questions regarding the admin dashboard, refer to the Firebase documentation or contact the development team.
