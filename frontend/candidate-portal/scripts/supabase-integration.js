/**
 * BroyhillGOP Supabase Integration
 * Connects frontend to Supabase database with dual grading support
 */

// Supabase Configuration
const SUPABASE_URL = 'https://isbgjpnbocdkeslofota.supabase.co';
const SUPABASE_ANON_KEY = 'YOUR_ANON_KEY_HERE'; // Replace with actual anon key

// Initialize Supabase client
const supabase = window.supabase ? window.supabase.createClient(SUPABASE_URL, SUPABASE_ANON_KEY) : null;

/**
 * DONOR QUERIES - DUAL GRADING
 */

// Get donors by state grade
async function getDonorsByStateGrade(grade, limit = 100) {
    const { data, error } = await supabase
        .from('donors')
        .select('*')
        .eq('donor_grade_state', grade)
        .order('donor_rank_state', { ascending: true })
        .limit(limit);
    
    if (error) console.error('Error fetching donors:', error);
    return data;
}

// Get donors by county grade
async function getDonorsByCountyGrade(county, grade, limit = 100) {
    const { data, error } = await supabase
        .from('donors')
        .select('*')
        .eq('county', county)
        .eq('donor_grade_county', grade)
        .order('donor_rank_county', { ascending: true })
        .limit(limit);
    
    if (error) console.error('Error fetching donors:', error);
    return data;
}

// Get top donors statewide
async function getTopDonorsStatewide(limit = 100) {
    const { data, error } = await supabase
        .from('donors')
        .select('donor_id, full_name, email, phone, county, total_donations, donor_grade_state, donor_rank_state, donor_grade_county, donor_rank_county')
        .order('donor_rank_state', { ascending: true })
        .limit(limit);
    
    if (error) console.error('Error fetching top donors:', error);
    return data;
}

// Get top donors in a county
async function getTopDonorsInCounty(county, limit = 100) {
    const { data, error } = await supabase
        .from('donors')
        .select('donor_id, full_name, email, phone, county, total_donations, donor_grade_state, donor_rank_state, donor_grade_county, donor_rank_county')
        .eq('county', county)
        .order('donor_rank_county', { ascending: true })
        .limit(limit);
    
    if (error) console.error('Error fetching county donors:', error);
    return data;
}

// Get grade distribution statewide
async function getGradeDistribution() {
    const { data, error } = await supabase
        .rpc('get_grade_distribution');
    
    if (error) {
        // Fallback to manual query
        const { data: fallback, error: fallbackError } = await supabase
            .from('donors')
            .select('donor_grade_state')
            .not('donor_grade_state', 'is', null);
        
        if (fallbackError) return null;
        
        // Count manually
        const counts = {};
        fallback.forEach(d => {
            counts[d.donor_grade_state] = (counts[d.donor_grade_state] || 0) + 1;
        });
        return Object.entries(counts).map(([grade, count]) => ({ grade, count }));
    }
    return data;
}

// Get county summary
async function getCountySummary() {
    const { data, error } = await supabase
        .from('donors')
        .select('county, total_donations, donor_grade_county')
        .not('county', 'is', null);
    
    if (error) return null;
    
    // Aggregate by county
    const counties = {};
    data.forEach(d => {
        if (!counties[d.county]) {
            counties[d.county] = { 
                county: d.county, 
                donor_count: 0, 
                total_donations: 0,
                a_tier_count: 0 
            };
        }
        counties[d.county].donor_count++;
        counties[d.county].total_donations += parseFloat(d.total_donations) || 0;
        if (['A++', 'A+', 'A', 'A-'].includes(d.donor_grade_county)) {
            counties[d.county].a_tier_count++;
        }
    });
    
    return Object.values(counties).sort((a, b) => b.total_donations - a.total_donations);
}

// Search donors
async function searchDonors(query, limit = 50) {
    const { data, error } = await supabase
        .from('donors')
        .select('*')
        .or(`full_name.ilike.%${query}%,email.ilike.%${query}%,city.ilike.%${query}%`)
        .order('donor_rank_state', { ascending: true })
        .limit(limit);
    
    if (error) console.error('Error searching donors:', error);
    return data;
}

// Get single donor profile
async function getDonorProfile(donorId) {
    const { data, error } = await supabase
        .from('donors')
        .select('*')
        .eq('donor_id', donorId)
        .single();
    
    if (error) console.error('Error fetching donor:', error);
    return data;
}

/**
 * VOLUNTEER QUERIES
 */

// Get all volunteers
async function getVolunteers(limit = 100) {
    const { data, error } = await supabase
        .from('volunteers')
        .select('*')
        .order('volunteer_hours', { ascending: false })
        .limit(limit);
    
    if (error) console.error('Error fetching volunteers:', error);
    return data;
}

// Get volunteers by county
async function getVolunteersByCounty(county, limit = 100) {
    const { data, error } = await supabase
        .from('volunteers')
        .select('*')
        .eq('county', county)
        .order('volunteer_hours', { ascending: false })
        .limit(limit);
    
    if (error) console.error('Error fetching volunteers:', error);
    return data;
}

/**
 * DONATION QUERIES
 */

// Get recent donations
async function getRecentDonations(limit = 50) {
    const { data, error } = await supabase
        .from('donation_transactions')
        .select('*, donors(full_name, email)')
        .order('transaction_date', { ascending: false })
        .limit(limit);
    
    if (error) console.error('Error fetching donations:', error);
    return data;
}

/**
 * STATS QUERIES
 */

// Get dashboard stats
async function getDashboardStats() {
    const stats = {};
    
    // Total donors
    const { count: donorCount } = await supabase
        .from('donors')
        .select('*', { count: 'exact', head: true });
    stats.totalDonors = donorCount;
    
    // Total donations
    const { data: donationSum } = await supabase
        .from('donors')
        .select('total_donations');
    stats.totalDonations = donationSum?.reduce((sum, d) => sum + (parseFloat(d.total_donations) || 0), 0) || 0;
    
    // A-tier count
    const { count: aTierCount } = await supabase
        .from('donors')
        .select('*', { count: 'exact', head: true })
        .in('donor_grade_state', ['A++', 'A+', 'A', 'A-']);
    stats.aTierCount = aTierCount;
    
    // Volunteer count
    const { count: volunteerCount } = await supabase
        .from('volunteers')
        .select('*', { count: 'exact', head: true });
    stats.volunteerCount = volunteerCount;
    
    return stats;
}

/**
 * UTILITY FUNCTIONS
 */

// Format currency
function formatCurrency(amount) {
    return new Intl.NumberFormat('en-US', {
        style: 'currency',
        currency: 'USD',
        minimumFractionDigits: 0,
        maximumFractionDigits: 0
    }).format(amount);
}

// Format large numbers
function formatNumber(num) {
    if (num >= 1000000) return (num / 1000000).toFixed(1) + 'M';
    if (num >= 1000) return (num / 1000).toFixed(1) + 'K';
    return num.toString();
}

// Get grade badge class
function getGradeBadgeClass(grade) {
    if (grade.startsWith('A')) return 'a-plus';
    if (grade.startsWith('B')) return 'b';
    if (grade.startsWith('C')) return 'c';
    return 'd';
}

// Render donor table row
function renderDonorRow(donor) {
    return `
        <tr data-donor-id="${donor.donor_id}">
            <td>
                <div class="donor-name">${donor.full_name || 'Unknown'}</div>
                <div class="donor-county">${donor.email || ''}</div>
            </td>
            <td><span class="grade-badge ${getGradeBadgeClass(donor.donor_grade_state)}">${donor.donor_grade_state}</span></td>
            <td><span class="grade-badge ${getGradeBadgeClass(donor.donor_grade_county)}">${donor.donor_grade_county}</span></td>
            <td class="amount">${formatCurrency(donor.total_donations)}</td>
            <td>${donor.county || 'Unknown'}</td>
            <td class="rank-badge"><strong>#${donor.donor_rank_state?.toLocaleString()}</strong></td>
            <td class="rank-badge"><strong>#${donor.donor_rank_county?.toLocaleString()}</strong></td>
        </tr>
    `;
}

// Initialize page with data
async function initializeDonorPage() {
    // Load stats
    const stats = await getDashboardStats();
    if (stats) {
        document.getElementById('total-donors').textContent = formatNumber(stats.totalDonors);
        document.getElementById('total-donations').textContent = formatCurrency(stats.totalDonations);
        document.getElementById('a-tier-count').textContent = formatNumber(stats.aTierCount);
    }
    
    // Load top donors
    const donors = await getTopDonorsStatewide(20);
    if (donors) {
        const tbody = document.getElementById('donor-table-body');
        tbody.innerHTML = donors.map(renderDonorRow).join('');
    }
}

// Export for use in other scripts
window.BroyhillGOP = {
    supabase,
    getDonorsByStateGrade,
    getDonorsByCountyGrade,
    getTopDonorsStatewide,
    getTopDonorsInCounty,
    getGradeDistribution,
    getCountySummary,
    searchDonors,
    getDonorProfile,
    getVolunteers,
    getVolunteersByCounty,
    getRecentDonations,
    getDashboardStats,
    formatCurrency,
    formatNumber,
    getGradeBadgeClass,
    renderDonorRow,
    initializeDonorPage
};

console.log('BroyhillGOP Supabase Integration loaded');
