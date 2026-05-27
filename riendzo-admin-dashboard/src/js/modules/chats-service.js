import FirebaseService from './firebase-service.js';
import UIService from './ui-service.js';

export class ChatsService {
    constructor() {
        this.firebaseService = new FirebaseService();
        this.uiService = new UIService();
    }

    async initializeChatsSection() {
        try {
            this.uiService.showLoading('chats-content', 'Loading chats...');
            
            // Load chats
            await this.loadChats();
            
            this.uiService.hideLoading('chats-content');
        } catch (error) {
            console.error('Error initializing chats section:', error);
            this.uiService.showNotification('Error loading chats', 'error');
            this.uiService.hideLoading('chats-content');
        }
    }

    async loadChats() {
        try {
            const chats = await this.firebaseService.getChats();
            await this.displayConversations(chats);
            await this.displayRecentMessages(chats);
        } catch (error) {
            console.error('Error loading chats:', error);
            throw error;
        }
    }

    async displayConversations(chats) {
        const conversationCards = await Promise.all(
            chats.map(chat => this.createConversationCard(chat))
        );
        
        const content = `
            <div class="bg-white rounded-xl shadow-lg p-6">
                <h4 class="font-medium mb-4">Active Conversations</h4>
                <div class="space-y-2">
                    ${conversationCards.join('')}
                </div>
            </div>
        `;

        const container = document.createElement('div');
        container.className = 'lg:col-span-1';
        container.innerHTML = content;
        
        const chatsContent = document.getElementById('chats-content');
        if (chatsContent) {
            chatsContent.innerHTML = '';
            chatsContent.appendChild(container);
        }
    }

    async displayRecentMessages(chats) {
        const allMessages = [];
        
        for (const chat of chats) {
            try {
                const messages = await this.firebaseService.getChatMessages(chat.id, 5);
                messages.forEach(message => {
                    allMessages.push({
                        ...message,
                        chatId: chat.id,
                        chatInfo: chat
                    });
                });
            } catch (error) {
                console.error(`Error loading messages for chat ${chat.id}:`, error);
            }
        }

        // Sort messages by timestamp (most recent first)
        allMessages.sort((a, b) => b.timestamp - a.timestamp);
        
        const messageCards = allMessages.slice(0, 10).map(message => 
            this.createMessageCard(message)
        );
        
        const content = `
            <div class="bg-white rounded-xl shadow-lg p-6">
                <h4 class="font-medium mb-4">Recent Messages</h4>
                <div class="space-y-2">
                    ${messageCards.join('')}
                </div>
            </div>
        `;

        const container = document.createElement('div');
        container.className = 'lg:col-span-1';
        container.innerHTML = content;
        
        const chatsContent = document.getElementById('chats-content');
        if (chatsContent && chatsContent.children.length > 0) {
            chatsContent.appendChild(container);
        }
    }

    async createConversationCard(chat) {
        try {
            const messages = await this.firebaseService.getChatMessages(chat.id, 1);
            const lastMessage = messages[0];
            
            return `
                <div class="p-3 border rounded-lg hover:bg-gray-50 transition cursor-pointer" 
                     onclick="app.chatsService.viewChat('${chat.id}')">
                    <div class="flex items-center justify-between">
                        <div class="flex items-center">
                            <div class="w-10 h-10 bg-blue-100 rounded-full flex items-center justify-center mr-3">
                                <i class="fas fa-comments text-blue-600"></i>
                            </div>
                            <div>
                                <p class="font-medium text-sm">Chat ${chat.id.substring(0, 8)}...</p>
                                <p class="text-xs text-gray-500">
                                    ${lastMessage ? (lastMessage.text || '').substring(0, 30) + '...' : 'No messages'}
                                </p>
                            </div>
                        </div>
                        <span class="w-2 h-2 bg-green-500 rounded-full"></span>
                    </div>
                </div>
            `;
        } catch (error) {
            console.error('Error creating conversation card:', error);
            return '';
        }
    }

    createMessageCard(message) {
        const time = this.uiService.formatDateTime(new Date(message.timestamp));
        
        return `
            <div class="message-item p-3 border rounded-lg">
                <div class="flex items-start">
                    <div class="w-8 h-8 bg-gray-200 rounded-full flex items-center justify-center mr-3">
                        <i class="fas fa-user text-gray-600 text-xs"></i>
                    </div>
                    <div class="flex-1">
                        <p class="text-sm font-medium">User ${message.sender?.substring(0, 8) || 'Unknown'}...</p>
                        <p class="text-sm text-gray-700">${message.text || 'No message text'}</p>
                        <p class="text-xs text-gray-500">${time}</p>
                    </div>
                </div>
            </div>
        `;
    }

    async viewChat(chatId) {
        try {
            const messages = await this.firebaseService.getChatMessages(chatId, 50);
            this.displayChatMessages(chatId, messages);
        } catch (error) {
            console.error('Error viewing chat:', error);
            this.uiService.showNotification('Error loading chat messages', 'error');
        }
    }

    displayChatMessages(chatId, messages) {
        const messageList = messages.map(message => `
            <div class="flex ${message.sender === 'admin' ? 'justify-end' : 'justify-start'} mb-4">
                <div class="max-w-xs lg:max-w-md">
                    <div class="${message.sender === 'admin' ? 'bg-blue-500 text-white' : 'bg-gray-200 text-gray-800'} 
                                rounded-lg px-4 py-2">
                        <p>${message.text || 'No message text'}</p>
                    </div>
                    <p class="text-xs text-gray-500 mt-1 ${message.sender === 'admin' ? 'text-right' : ''}">
                        ${this.uiService.formatDateTime(new Date(message.timestamp))}
                    </p>
                </div>
            </div>
        `).join('');

        const modalHTML = `
            <div class="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50">
                <div class="bg-white rounded-xl p-6 max-w-2xl w-full max-h-[80vh] overflow-hidden">
                    <div class="flex justify-between items-center mb-4">
                        <h3 class="text-xl font-semibold">Chat ${chatId.substring(0, 8)}...</h3>
                        <button onclick="app.chatsService.closeChatModal()" 
                                class="text-gray-500 hover:text-gray-700">
                            <i class="fas fa-times"></i>
                        </button>
                    </div>
                    <div class="overflow-y-auto max-h-96 mb-4">
                        ${messageList}
                    </div>
                    <div class="border-t pt-4">
                        <div class="flex space-x-2">
                            <input type="text" id="message-input" 
                                   placeholder="Type a message..." 
                                   class="flex-1 px-4 py-2 border rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500">
                            <button onclick="app.chatsService.sendMessage('${chatId}')" 
                                    class="px-4 py-2 bg-blue-500 text-white rounded-lg hover:bg-blue-600 transition">
                                <i class="fas fa-paper-plane"></i>
                            </button>
                        </div>
                    </div>
                </div>
            </div>
        `;

        const modal = document.createElement('div');
        modal.id = 'chat-modal';
        modal.innerHTML = modalHTML;
        document.body.appendChild(modal);
    }

    closeChatModal() {
        const modal = document.getElementById('chat-modal');
        if (modal) {
            modal.remove();
        }
    }

    async sendMessage(chatId) {
        const input = document.getElementById('message-input');
        const text = input.value.trim();
        
        if (!text) return;

        try {
            const messageData = {
                text: text,
                sender: 'admin',
                timestamp: Date.now()
            };

            await this.firebaseService.db
                .collection('chats')
                .doc(chatId)
                .collection('messages')
                .add(messageData);

            input.value = '';
            this.uiService.showNotification('Message sent', 'success');
            
            // Refresh the chat view
            await this.viewChat(chatId);
            
        } catch (error) {
            console.error('Error sending message:', error);
            this.uiService.showNotification('Error sending message', 'error');
        }
    }

    async deleteChat(chatId) {
        this.uiService.confirmAction('Are you sure you want to delete this chat?', async () => {
            try {
                await this.firebaseService.deleteChat(chatId);
                this.uiService.showNotification('Chat deleted successfully', 'success');
                await this.loadChats();
            } catch (error) {
                console.error('Error deleting chat:', error);
                this.uiService.showNotification('Error deleting chat', 'error');
            }
        });
    }

    async searchChats(query) {
        try {
            const chats = await this.firebaseService.getChats();
            const filteredChats = chats.filter(chat => 
                chat.id.toLowerCase().includes(query.toLowerCase())
            );
            
            await this.displayConversations(filteredChats);
            await this.displayRecentMessages(filteredChats);
            
        } catch (error) {
            console.error('Error searching chats:', error);
            this.uiService.showNotification('Error searching chats', 'error');
        }
    }

    async getChatStatistics() {
        try {
            const chats = await this.firebaseService.getChats();
            let totalMessages = 0;
            let totalActiveChats = 0;
            
            for (const chat of chats) {
                const messages = await this.firebaseService.getChatMessages(chat.id);
                totalMessages += messages.length;
                
                // Consider chat active if it has messages in the last 24 hours
                const lastMessage = messages[0];
                if (lastMessage) {
                    const lastMessageTime = new Date(lastMessage.timestamp);
                    const now = new Date();
                    const hoursDiff = (now - lastMessageTime) / (1000 * 60 * 60);
                    
                    if (hoursDiff < 24) {
                        totalActiveChats++;
                    }
                }
            }
            
            return {
                totalChats: chats.length,
                totalMessages: totalMessages,
                activeChats: totalActiveChats,
                averageMessagesPerChat: totalMessages / chats.length || 0
            };
            
        } catch (error) {
            console.error('Error getting chat statistics:', error);
            throw error;
        }
    }
}

export default ChatsService;
