export class UIService {
    constructor() {
        this.currentSection = 'dashboard';
        this.notifications = [];
    }

    // Navigation
    showSection(sectionName) {
        // Hide all sections
        document.querySelectorAll('section').forEach(section => {
            section.classList.add('hidden');
        });

        // Show selected section
        const selectedSection = document.getElementById(sectionName);
        if (selectedSection) {
            selectedSection.classList.remove('hidden');
        }

        // Update title
        this.updateSectionTitle(sectionName);
        this.currentSection = sectionName;

        // Update active nav item
        this.updateActiveNavItem(sectionName);
    }

    updateSectionTitle(sectionName) {
        const titles = {
            'dashboard': 'Dashboard',
            'trips': 'Trip Management',
            'users': 'User Management',
            'chats': 'Chat Management',
            'analytics': 'Analytics',
            'categories': 'Category Management'
        };
        
        const titleElement = document.getElementById('section-title');
        if (titleElement) {
            titleElement.textContent = titles[sectionName] || 'Dashboard';
        }
    }

    updateActiveNavItem(sectionName) {
        document.querySelectorAll('.nav-item').forEach(item => {
            item.classList.remove('bg-indigo-50', 'text-indigo-600');
            item.classList.add('text-gray-700');
        });

        const activeItem = document.querySelector(`[onclick="app.showSection('${sectionName}')"]`);
        if (activeItem) {
            activeItem.classList.add('bg-indigo-50', 'text-indigo-600');
            activeItem.classList.remove('text-gray-700');
        }
    }

    // Component loading
    async loadComponent(containerId, componentPath) {
        try {
            // Convert relative path to absolute path
            const absolutePath = componentPath.startsWith('../') 
                ? componentPath.replace('../', 'src/components/')
                : componentPath;
            
            console.log(`Loading component: ${absolutePath}`);
            const response = await fetch(absolutePath);
            if (!response.ok) {
                throw new Error(`Failed to load component: ${response.status} ${response.statusText}`);
            }
            const html = await response.text();
            const container = document.getElementById(containerId);
            if (container) {
                container.innerHTML = html;
                console.log(`✅ Component loaded into ${containerId}`);
            } else {
                throw new Error(`Container ${containerId} not found`);
            }
        } catch (error) {
            console.error('❌ Error loading component:', error);
            throw error;
        }
    }

    // Modal management
    showModal(modalId) {
        const modal = document.getElementById(modalId);
        if (modal) {
            modal.classList.remove('hidden');
            document.body.style.overflow = 'hidden';
        }
    }

    hideModal(modalId) {
        const modal = document.getElementById(modalId);
        if (modal) {
            modal.classList.add('hidden');
            document.body.style.overflow = 'auto';
        }
    }

    // Notifications
    showNotification(message, type = 'info', duration = 3000) {
        const notification = document.createElement('div');
        notification.className = `fixed top-4 right-4 px-6 py-3 rounded-lg shadow-lg z-50 transform transition-all duration-300 ${
            type === 'success' ? 'bg-green-500 text-white' :
            type === 'error' ? 'bg-red-500 text-white' :
            type === 'warning' ? 'bg-yellow-500 text-white' :
            'bg-blue-500 text-white'
        }`;
        notification.textContent = message;
        
        // Add animation
        notification.style.transform = 'translateX(100%)';
        document.getElementById('notification-container').appendChild(notification);
        
        // Animate in
        setTimeout(() => {
            notification.style.transform = 'translateX(0)';
        }, 100);

        // Remove after duration
        setTimeout(() => {
            notification.style.transform = 'translateX(100%)';
            setTimeout(() => {
                notification.remove();
            }, 300);
        }, duration);
    }

    // Loading states
    showLoading(containerId, message = 'Loading...') {
        const container = document.getElementById(containerId);
        if (container) {
            container.innerHTML = `
                <div class="flex items-center justify-center h-64">
                    <div class="text-center">
                        <div class="animate-spin rounded-full h-12 w-12 border-b-2 border-indigo-600 mx-auto mb-4"></div>
                        <p class="text-gray-600">${message}</p>
                    </div>
                </div>
            `;
        }
    }

    hideLoading(containerId) {
        const container = document.getElementById(containerId);
        if (container) {
            container.innerHTML = '';
        }
    }

    // Form utilities
    resetForm(formId) {
        const form = document.getElementById(formId);
        if (form) {
            form.reset();
        }
    }

    getFormData(formId) {
        const form = document.getElementById(formId);
        if (!form) return {};

        const formData = new FormData(form);
        const data = {};
        
        for (let [key, value] of formData.entries()) {
            data[key] = value;
        }
        
        return data;
    }

    setFormData(formId, data) {
        const form = document.getElementById(formId);
        if (!form) return;

        Object.keys(data).forEach(key => {
            const field = form.querySelector(`[name="${key}"], #${key}`);
            if (field) {
                if (field.type === 'checkbox') {
                    field.checked = data[key];
                } else {
                    field.value = data[key];
                }
            }
        });
    }

    // Confirmation dialogs
    confirmAction(message, callback) {
        if (confirm(message)) {
            callback();
        }
    }

    // Date formatting
    formatDate(dateString) {
        if (!dateString) return 'N/A';
        const date = new Date(dateString);
        return date.toLocaleDateString();
    }

    formatDateTime(dateString) {
        if (!dateString) return 'N/A';
        const date = new Date(dateString);
        return date.toLocaleString();
    }

    // Number formatting
    formatNumber(num) {
        return new Intl.NumberFormat().format(num);
    }

    formatCurrency(amount, currency = 'ZAR') {
        const numericAmount = typeof amount === 'number'
            ? amount
            : Number(String(amount || '').replace(/\b(ZAR|USD)\b/gi, '').replace(/[R$,]/g, '').trim());

        if (!Number.isFinite(numericAmount)) return 'Not set';

        return new Intl.NumberFormat('en-ZA', {
            style: 'currency',
            currency: currency
        }).format(numericAmount);
    }

    // Table utilities
    createTable(headers, data, actions = []) {
        let tableHTML = `
            <div class="overflow-x-auto">
                <table class="w-full table-auto">
                    <thead class="bg-gray-50">
                        <tr>
        `;
        
        headers.forEach(header => {
            tableHTML += `<th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">${header}</th>`;
        });
        
        if (actions.length > 0) {
            tableHTML += `<th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Actions</th>`;
        }
        
        tableHTML += `
                        </tr>
                    </thead>
                    <tbody class="bg-white divide-y divide-gray-200">
        `;
        
        data.forEach(row => {
            tableHTML += '<tr class="hover:bg-gray-50 transition">';
            
            headers.forEach(header => {
                tableHTML += `<td class="px-6 py-4 whitespace-nowrap text-sm text-gray-900">${row[header] || ''}</td>`;
            });
            
            if (actions.length > 0) {
                tableHTML += '<td class="px-6 py-4 whitespace-nowrap text-sm font-medium">';
                actions.forEach(action => {
                    tableHTML += `<button onclick="${action.callback}" class="text-${action.color}-600 hover:text-${action.color}-900 mr-3">${action.label}</button>`;
                });
                tableHTML += '</td>';
            }
            
            tableHTML += '</tr>';
        });
        
        tableHTML += `
                    </tbody>
                </table>
            </div>
        `;
        
        return tableHTML;
    }

    // Card utilities
    createCard(title, content, actions = []) {
        let cardHTML = `
            <div class="bg-white rounded-xl shadow-lg p-6">
                <div class="flex justify-between items-center mb-6">
                    <h3 class="text-xl font-semibold">${title}</h3>
        `;
        
        actions.forEach(action => {
            cardHTML += `<button onclick="${action.callback}" class="px-4 py-2 bg-${action.color}-600 text-white rounded-lg hover:bg-${action.color}-700 transition">
                <i class="fas fa-${action.icon} mr-2"></i>${action.label}
            </button>`;
        });
        
        cardHTML += `
                </div>
                <div class="content">
                    ${content}
                </div>
            </div>
        `;
        
        return cardHTML;
    }

    // Grid utilities
    createGrid(items, itemTemplate, columns = 3) {
        const gridClass = columns === 2 ? 'grid-cols-2' : 
                         columns === 4 ? 'grid-cols-4' : 
                         columns === 6 ? 'grid-cols-6' : 'grid-cols-3';
        
        let gridHTML = `<div class="grid grid-cols-1 md:${gridClass} gap-6">`;
        
        items.forEach(item => {
            gridHTML += itemTemplate(item);
        });
        
        gridHTML += '</div>';
        return gridHTML;
    }
}

export default UIService;
