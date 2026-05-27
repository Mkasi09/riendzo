import FirebaseService from './firebase-service.js';
import UIService from './ui-service.js';

export class CategoriesService {
    constructor() {
        this.firebaseService = new FirebaseService();
        this.uiService = new UIService();
        this.categories = [
            "Adventure", "Beaches", "Culture", "Cuisine", "Exploration", "Festivals",
            "Hiking", "History", "Relaxation", "Safari", "Scenery", "Sports",
            "Wildlife", "Cruises", "Mountains", "Photography", "Roadtrips",
            "Shopping", "Spa", "Waterfalls"
        ];
    }

    async initializeCategoriesSection() {
        try {
            this.uiService.showLoading('categories-content', 'Loading categories...');
            
            // Load categories
            await this.loadCategories();
            
            // Load modals
            await this.loadModals();
            
            // Setup event listeners
            this.setupEventListeners();
            
            this.uiService.hideLoading('categories-content');
        } catch (error) {
            console.error('Error initializing categories section:', error);
            this.uiService.showNotification('Error loading categories', 'error');
            this.uiService.hideLoading('categories-content');
        }
    }

    async loadCategories() {
        try {
            // In a real app, you might load categories from Firestore
            // For now, using the predefined categories
            this.displayCategories(this.categories);
        } catch (error) {
            console.error('Error loading categories:', error);
            throw error;
        }
    }

    displayCategories(categories) {
        const categoryCards = categories.map(category => this.createCategoryCard(category)).join('');
        
        const content = `
            <div class="bg-white rounded-xl shadow-lg p-6">
                <div class="flex justify-between items-center mb-6">
                    <h3 class="text-xl font-semibold">Travel Categories</h3>
                    <button onclick="app.categoriesService.openCategoryModal()" 
                            class="px-4 py-2 bg-green-600 text-white rounded-lg hover:bg-green-700 transition">
                        <i class="fas fa-plus mr-2"></i>Add Category
                    </button>
                </div>
                <div class="grid grid-cols-2 md:grid-cols-4 lg:grid-cols-6 gap-4">
                    ${categoryCards}
                </div>
            </div>
        `;

        document.getElementById('categories-content').innerHTML = content;
    }

    createCategoryCard(category) {
        const categoryColors = this.getCategoryColors(category);
        const icon = this.getCategoryIcon(category);
        
        return `
            <div class="bg-white p-4 rounded-lg shadow hover:shadow-lg transition text-center">
                <div class="w-16 h-16 ${categoryColors.bg} rounded-lg mx-auto mb-3 flex items-center justify-center">
                    <i class="fas fa-${icon} ${categoryColors.text} text-xl"></i>
                </div>
                <h4 class="font-medium text-sm">${category}</h4>
                <p class="text-xs text-gray-500 mt-1">0 trips</p>
                <div class="flex space-x-2 mt-3">
                    <button onclick="app.categoriesService.editCategory('${category}')" 
                            class="text-blue-600 hover:text-blue-800 text-sm">Edit</button>
                    <button onclick="app.categoriesService.deleteCategory('${category}')" 
                            class="text-red-600 hover:text-red-800 text-sm">Delete</button>
                </div>
            </div>
        `;
    }

    getCategoryColors(category) {
        const colorMap = {
            'Adventure': { bg: 'bg-orange-100', text: 'text-orange-600' },
            'Beaches': { bg: 'bg-blue-100', text: 'text-blue-600' },
            'Culture': { bg: 'bg-purple-100', text: 'text-purple-600' },
            'Cuisine': { bg: 'bg-red-100', text: 'text-red-600' },
            'Exploration': { bg: 'bg-green-100', text: 'text-green-600' },
            'Festivals': { bg: 'bg-pink-100', text: 'text-pink-600' },
            'Hiking': { bg: 'bg-emerald-100', text: 'text-emerald-600' },
            'History': { bg: 'bg-amber-100', text: 'text-amber-600' },
            'Relaxation': { bg: 'bg-cyan-100', text: 'text-cyan-600' },
            'Safari': { bg: 'bg-yellow-100', text: 'text-yellow-600' },
            'Scenery': { bg: 'bg-teal-100', text: 'text-teal-600' },
            'Sports': { bg: 'bg-indigo-100', text: 'text-indigo-600' },
            'Wildlife': { bg: 'bg-lime-100', text: 'text-lime-600' },
            'Cruises': { bg: 'bg-sky-100', text: 'text-sky-600' },
            'Mountains': { bg: 'bg-gray-100', text: 'text-gray-600' },
            'Photography': { bg: 'bg-violet-100', text: 'text-violet-600' },
            'Roadtrips': { bg: 'bg-rose-100', text: 'text-rose-600' },
            'Shopping': { bg: 'bg-fuchsia-100', text: 'text-fuchsia-600' },
            'Spa': { bg: 'bg-stone-100', text: 'text-stone-600' },
            'Waterfalls': { bg: 'bg-slate-100', text: 'text-slate-600' }
        };
        
        return colorMap[category] || { bg: 'bg-gray-100', text: 'text-gray-600' };
    }

    getCategoryIcon(category) {
        const iconMap = {
            'Adventure': 'mountain',
            'Beaches': 'umbrella-beach',
            'Culture': 'landmark',
            'Cuisine': 'utensils',
            'Exploration': 'compass',
            'Festivals': 'music',
            'Hiking': 'hiking',
            'History': 'monument',
            'Relaxation': 'spa',
            'Safari': 'hippo',
            'Scenery': 'camera',
            'Sports': 'football',
            'Wildlife': 'paw',
            'Cruises': 'ship',
            'Mountains': 'mountain-city',
            'Photography': 'camera-retro',
            'Roadtrips': 'car',
            'Shopping': 'shopping-bag',
            'Spa': 'hot-tub',
            'Waterfalls': 'water'
        };
        
        return iconMap[category] || 'tag';
    }

    async loadModals() {
        try {
            await this.uiService.loadComponent('modal-container', '../components/modals.html');
        } catch (error) {
            console.error('Error loading modals:', error);
        }
    }

    setupEventListeners() {
        // Category form submission
        const categoryForm = document.getElementById('category-form');
        if (categoryForm) {
            categoryForm.addEventListener('submit', (e) => {
                e.preventDefault();
                this.saveCategory();
            });
        }
    }

    openCategoryModal(categoryName = null) {
        if (categoryName) {
            document.getElementById('category-name').value = categoryName;
        } else {
            this.uiService.resetForm('category-form');
        }
        
        this.uiService.showModal('category-modal');
    }

    closeCategoryModal() {
        this.uiService.hideModal('category-modal');
        this.uiService.resetForm('category-form');
    }

    saveCategory() {
        const categoryName = document.getElementById('category-name').value.trim();
        
        if (!categoryName) {
            this.uiService.showNotification('Please enter a category name', 'error');
            return;
        }

        if (this.categories.includes(categoryName)) {
            this.uiService.showNotification('Category already exists', 'error');
            return;
        }

        this.categories.push(categoryName);
        this.closeCategoryModal();
        this.displayCategories(this.categories);
        this.uiService.showNotification('Category added successfully', 'success');
    }

    editCategory(categoryName) {
        const newName = prompt('Enter new category name:', categoryName);
        if (newName && newName !== categoryName) {
            const index = this.categories.indexOf(categoryName);
            if (index > -1) {
                this.categories[index] = newName;
                this.displayCategories(this.categories);
                this.uiService.showNotification('Category updated successfully', 'success');
            }
        }
    }

    deleteCategory(categoryName) {
        this.uiService.confirmAction(`Are you sure you want to delete "${categoryName}"?`, () => {
            this.categories = this.categories.filter(cat => cat !== categoryName);
            this.displayCategories(this.categories);
            this.uiService.showNotification('Category deleted successfully', 'success');
        });
    }

    async getCategoryStatistics() {
        try {
            const trips = await this.firebaseService.getTrips();
            const categoryStats = {};
            
            // Initialize stats for all categories
            this.categories.forEach(category => {
                categoryStats[category] = {
                    count: 0,
                    totalBudget: 0,
                    avgBudget: 0
                };
            });
            
            // Count trips by category
            trips.forEach(trip => {
                const category = trip.travelType;
                if (categoryStats[category]) {
                    categoryStats[category].count++;
                    categoryStats[category].totalBudget += trip.budget || 0;
                }
            });
            
            // Calculate average budget
            Object.keys(categoryStats).forEach(category => {
                const stats = categoryStats[category];
                stats.avgBudget = stats.count > 0 ? stats.totalBudget / stats.count : 0;
            });
            
            return categoryStats;
        } catch (error) {
            console.error('Error getting category statistics:', error);
            throw error;
        }
    }

    async displayCategoryStatistics() {
        try {
            const stats = await this.getCategoryStatistics();
            
            const content = `
                <div class="bg-white rounded-xl shadow-lg p-6">
                    <h3 class="text-xl font-semibold mb-6">Category Statistics</h3>
                    <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
                        ${Object.entries(stats).map(([category, data]) => `
                            <div class="border rounded-lg p-4">
                                <div class="flex items-center mb-2">
                                    <div class="w-8 h-8 ${this.getCategoryColors(category).bg} rounded-full flex items-center justify-center mr-2">
                                        <i class="fas fa-${this.getCategoryIcon(category)} ${this.getCategoryColors(category).text} text-sm"></i>
                                    </div>
                                    <h4 class="font-medium">${category}</h4>
                                </div>
                                <div class="space-y-1 text-sm">
                                    <div class="flex justify-between">
                                        <span class="text-gray-600">Trips:</span>
                                        <span class="font-medium">${data.count}</span>
                                    </div>
                                    <div class="flex justify-between">
                                        <span class="text-gray-600">Avg Budget:</span>
                                        <span class="font-medium">${this.uiService.formatCurrency(data.avgBudget)}</span>
                                    </div>
                                </div>
                            </div>
                        `).join('')}
                    </div>
                </div>
            `;
            
            document.getElementById('categories-content').innerHTML = content;
        } catch (error) {
            console.error('Error displaying category statistics:', error);
            this.uiService.showNotification('Error loading category statistics', 'error');
        }
    }

    async exportCategories() {
        try {
            const stats = await this.getCategoryStatistics();
            const csv = this.convertCategoriesToCSV(stats);
            this.downloadCSV(csv, 'categories.csv');
            this.uiService.showNotification('Categories exported successfully', 'success');
        } catch (error) {
            console.error('Error exporting categories:', error);
            this.uiService.showNotification('Error exporting categories', 'error');
        }
    }

    convertCategoriesToCSV(stats) {
        const headers = ['Category', 'Number of Trips', 'Total Budget', 'Average Budget'];
        const rows = Object.entries(stats).map(([category, data]) => [
            category,
            data.count,
            this.uiService.formatCurrency(data.totalBudget),
            this.uiService.formatCurrency(data.avgBudget)
        ]);

        return [headers, ...rows].map(row => row.join(',')).join('\n');
    }

    downloadCSV(csv, filename) {
        const blob = new Blob([csv], { type: 'text/csv' });
        const url = window.URL.createObjectURL(blob);
        const a = document.createElement('a');
        a.href = url;
        a.download = filename;
        a.click();
        window.URL.revokeObjectURL(url);
    }

    searchCategories(query) {
        const filteredCategories = this.categories.filter(category =>
            category.toLowerCase().includes(query.toLowerCase())
        );
        this.displayCategories(filteredCategories);
    }

    sortCategories(sortBy) {
        let sortedCategories = [...this.categories];

        switch (sortBy) {
            case 'name':
                sortedCategories.sort();
                break;
            case 'name-desc':
                sortedCategories.sort().reverse();
                break;
        }

        this.displayCategories(sortedCategories);
    }
}

export default CategoriesService;
