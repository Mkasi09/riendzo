export function formatDate(dateString) {
    if (!dateString) return 'N/A';
    const date = new Date(dateString);
    if (Number.isNaN(date.getTime())) return dateString;
    return date.toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' });
}

export function formatCurrency(amount) {
    const numericAmount = Number(amount);
    if (!Number.isFinite(numericAmount)) return 'Not set';

    return new Intl.NumberFormat('en-US', {
        style: 'currency',
        currency: 'USD',
        maximumFractionDigits: 0
    }).format(numericAmount);
}

export function getUserStatus(user) {
    if (user.suspended) return { text: 'Suspended', color: 'red' };

    const lastSeen = user.lastSeen ? new Date(user.lastSeen) : new Date();
    const hoursDiff = (new Date() - lastSeen) / (1000 * 60 * 60);

    if (hoursDiff < 1) return { text: 'Online', color: 'green' };
    if (hoursDiff < 24) return { text: 'Recently active', color: 'yellow' };
    return { text: 'Inactive', color: 'gray' };
}

export function safeAvatar(url) {
    if (!url || url.includes('pexels.com/photo/')) {
        return 'https://images.pexels.com/photos/774909/pexels-photo-774909.jpeg?auto=compress&cs=tinysrgb&w=300';
    }

    return url;
}
