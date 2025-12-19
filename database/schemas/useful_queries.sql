-- BroyhillGOP Donor Database - Useful SQL Queries
-- Copy and paste these into Supabase SQL Editor or your application

-- ============================================================================
-- PROSPECTING QUERIES
-- ============================================================================

-- 1. High-Value Prospects (Never donated but high probability)
-- Use this to identify people who are likely to donate
SELECT 
    full_name,
    email,
    phone,
    city,
    state,
    donation_probability,
    volunteer_probability,
    engagement_score
FROM donors
WHERE 
    donation_count = 0
    AND donation_probability > 0.70
    AND is_duplicate = FALSE
    AND state = 'NC'  -- Change to your target state
ORDER BY donation_probability DESC
LIMIT 100;

-- 2. Lapsed Major Donors
-- People who gave a lot but haven't donated recently
SELECT 
    full_name,
    email,
    phone,
    city,
    total_donations,
    donation_count,
    average_donation,
    last_donation_date,
    EXTRACT(DAYS FROM NOW() - last_donation_date) as days_since_donation,
    donation_probability
FROM donors
WHERE 
    total_donations > 500
    AND last_donation_date < NOW() - INTERVAL '1 year'
    AND is_duplicate = FALSE
ORDER BY total_donations DESC
LIMIT 100;

-- 3. High Engagement, No Donations
-- People who engage with emails but haven't donated
SELECT 
    full_name,
    email,
    phone,
    email_opened_count,
    email_clicked_count,
    last_email_clicked_date,
    donation_probability,
    total_donations
FROM donors
WHERE 
    email_clicked_count > 5
    AND donation_count = 0
    AND is_duplicate = FALSE
ORDER BY email_clicked_count DESC
LIMIT 100;

-- ============================================================================
-- VOLUNTEER RECRUITMENT
-- ============================================================================

-- 4. High Volunteer Probability (Not currently volunteering)
SELECT 
    full_name,
    email,
    phone,
    city,
    volunteer_probability,
    donation_probability,
    total_donations
FROM donors
WHERE 
    volunteer_probability > 0.70
    AND is_volunteer = FALSE
    AND is_duplicate = FALSE
ORDER BY volunteer_probability DESC
LIMIT 100;

-- 5. Donors Who Might Volunteer
-- Existing donors who might be interested in volunteering
SELECT 
    full_name,
    email,
    phone,
    total_donations,
    donation_count,
    volunteer_probability,
    last_donation_date
FROM donors
WHERE 
    donation_count > 0
    AND volunteer_probability > 0.65
    AND is_volunteer = FALSE
    AND is_duplicate = FALSE
ORDER BY volunteer_probability DESC, total_donations DESC
LIMIT 100;

-- ============================================================================
-- DONOR RETENTION
-- ============================================================================

-- 6. At-Risk Donors
-- Regular donors who haven't donated in 6+ months
SELECT 
    full_name,
    email,
    phone,
    total_donations,
    donation_count,
    average_donation,
    last_donation_date,
    EXTRACT(MONTHS FROM NOW() - last_donation_date) as months_since_donation
FROM donors
WHERE 
    donation_count >= 3
    AND last_donation_date < NOW() - INTERVAL '6 months'
    AND last_donation_date > NOW() - INTERVAL '3 years'
    AND is_duplicate = FALSE
ORDER BY total_donations DESC
LIMIT 100;

-- 7. Loyal Donors (Active and Consistent)
SELECT 
    full_name,
    email,
    phone,
    city,
    total_donations,
    donation_count,
    average_donation,
    last_donation_date
FROM donors
WHERE 
    donation_count >= 5
    AND last_donation_date > NOW() - INTERVAL '6 months'
    AND is_duplicate = FALSE
ORDER BY donation_count DESC, total_donations DESC
LIMIT 100;

-- ============================================================================
-- GEOGRAPHIC TARGETING
-- ============================================================================

-- 8. Donors by City
SELECT 
    city,
    state,
    COUNT(*) as donor_count,
    SUM(total_donations) as total_city_donations,
    AVG(donation_probability) as avg_probability,
    COUNT(CASE WHEN is_volunteer THEN 1 END) as volunteer_count
FROM donors
WHERE 
    state = 'NC'  -- Change to your target state
    AND is_duplicate = FALSE
GROUP BY city, state
HAVING COUNT(*) > 10
ORDER BY total_city_donations DESC;

-- 9. High-Value Zip Codes
SELECT 
    zip_code,
    city,
    COUNT(*) as donor_count,
    SUM(total_donations) as total_donations,
    AVG(donation_probability) as avg_probability,
    ROUND(AVG(total_donations), 2) as avg_donation_per_donor
FROM donors
WHERE 
    is_duplicate = FALSE
    AND zip_code IS NOT NULL
GROUP BY zip_code, city
HAVING COUNT(*) > 5
ORDER BY total_donations DESC
LIMIT 50;

-- ============================================================================
-- ENGAGEMENT ANALYSIS
-- ============================================================================

-- 10. Email Engagement Leaders
SELECT 
    full_name,
    email,
    email_opened_count,
    email_clicked_count,
    ROUND(email_clicked_count::numeric / NULLIF(email_opened_count, 0) * 100, 1) as click_rate_pct,
    donation_probability,
    total_donations
FROM donors
WHERE 
    email_opened_count > 0
    AND is_duplicate = FALSE
ORDER BY email_clicked_count DESC
LIMIT 100;

-- 11. Donors Who Opened But Never Clicked
-- These people engage but might need better content
SELECT 
    full_name,
    email,
    email_opened_count,
    last_email_opened_date,
    donation_probability,
    total_donations
FROM donors
WHERE 
    email_opened_count >= 5
    AND email_clicked_count = 0
    AND is_duplicate = FALSE
ORDER BY email_opened_count DESC
LIMIT 100;

-- ============================================================================
-- VOLUNTEER MANAGEMENT
-- ============================================================================

-- 12. Most Active Volunteers
SELECT 
    d.full_name,
    d.email,
    d.phone,
    v.volunteer_type,
    v.total_hours,
    v.events_attended,
    v.calls_made,
    v.doors_knocked,
    d.total_donations
FROM volunteers v
JOIN donors d ON v.donor_id = d.donor_id
WHERE v.status = 'active'
ORDER BY v.total_hours DESC
LIMIT 50;

-- 13. Volunteers Available This Weekend
SELECT 
    d.full_name,
    d.email,
    d.phone,
    d.city,
    v.volunteer_type,
    v.skills,
    v.total_hours
FROM volunteers v
JOIN donors d ON v.donor_id = d.donor_id
WHERE 
    v.status = 'active'
    AND v.available_weekends = TRUE
ORDER BY v.total_hours DESC;

-- ============================================================================
-- DONATION ANALYTICS
-- ============================================================================

-- 14. Donation Trends by Month
SELECT 
    DATE_TRUNC('month', donation_date) as month,
    COUNT(*) as donation_count,
    SUM(amount) as total_amount,
    ROUND(AVG(amount), 2) as avg_amount,
    COUNT(DISTINCT donor_id) as unique_donors
FROM donations
WHERE donation_date > NOW() - INTERVAL '12 months'
GROUP BY DATE_TRUNC('month', donation_date)
ORDER BY month DESC;

-- 15. First-Time Donors (Last 30 Days)
SELECT 
    d.full_name,
    d.email,
    d.phone,
    d.city,
    d.state,
    d.first_donation_date,
    d.total_donations
FROM donors d
WHERE 
    d.first_donation_date > NOW() - INTERVAL '30 days'
    AND d.donation_count = 1
    AND d.is_duplicate = FALSE
ORDER BY d.first_donation_date DESC;

-- ============================================================================
-- SEGMENTATION
-- ============================================================================

-- 16. Donor Segments by Value
SELECT 
    CASE 
        WHEN total_donations = 0 THEN 'Never Donated'
        WHEN total_donations < 100 THEN 'Small Donor ($1-99)'
        WHEN total_donations < 500 THEN 'Medium Donor ($100-499)'
        WHEN total_donations < 1000 THEN 'Major Donor ($500-999)'
        ELSE 'Super Donor ($1000+)'
    END as donor_segment,
    COUNT(*) as count,
    SUM(total_donations) as total_donations,
    ROUND(AVG(donation_probability), 3) as avg_probability,
    ROUND(AVG(volunteer_probability), 3) as avg_volunteer_prob
FROM donors
WHERE is_duplicate = FALSE
GROUP BY donor_segment
ORDER BY 
    CASE 
        WHEN total_donations = 0 THEN 0
        WHEN total_donations < 100 THEN 1
        WHEN total_donations < 500 THEN 2
        WHEN total_donations < 1000 THEN 3
        ELSE 4
    END;

-- 17. Multi-Dimensional Segmentation
SELECT 
    CASE 
        WHEN donation_probability > 0.7 THEN 'High'
        WHEN donation_probability > 0.4 THEN 'Medium'
        ELSE 'Low'
    END as donation_prob,
    CASE 
        WHEN volunteer_probability > 0.7 THEN 'High'
        WHEN volunteer_probability > 0.4 THEN 'Medium'
        ELSE 'Low'
    END as volunteer_prob,
    COUNT(*) as count,
    ROUND(AVG(total_donations), 2) as avg_donations
FROM donors
WHERE 
    is_duplicate = FALSE
    AND donation_probability IS NOT NULL
    AND volunteer_probability IS NOT NULL
GROUP BY 
    CASE 
        WHEN donation_probability > 0.7 THEN 'High'
        WHEN donation_probability > 0.4 THEN 'Medium'
        ELSE 'Low'
    END,
    CASE 
        WHEN volunteer_probability > 0.7 THEN 'High'
        WHEN volunteer_probability > 0.4 THEN 'Medium'
        ELSE 'Low'
    END
ORDER BY donation_prob DESC, volunteer_prob DESC;

-- ============================================================================
-- DATA QUALITY
-- ============================================================================

-- 18. Records Missing Key Information
SELECT 
    'Missing Email' as issue,
    COUNT(*) as count
FROM donors
WHERE email IS NULL OR email = ''
UNION ALL
SELECT 
    'Missing Phone' as issue,
    COUNT(*) as count
FROM donors
WHERE phone IS NULL OR phone = ''
UNION ALL
SELECT 
    'Missing Address' as issue,
    COUNT(*) as count
FROM donors
WHERE street_address IS NULL OR street_address = ''
UNION ALL
SELECT 
    'Possible Duplicates' as issue,
    COUNT(*) as count
FROM donors
WHERE is_duplicate = TRUE;

-- 19. Records Needing Review
SELECT 
    full_name,
    email,
    phone,
    city,
    state,
    CASE 
        WHEN email IS NULL THEN 'Missing Email'
        WHEN phone IS NULL THEN 'Missing Phone'
        WHEN street_address IS NULL THEN 'Missing Address'
        WHEN is_duplicate THEN 'Possible Duplicate'
        ELSE 'Other'
    END as reason
FROM donors
WHERE 
    needs_review = TRUE
    OR email IS NULL
    OR (phone IS NULL AND mobile_phone IS NULL)
ORDER BY full_name;

-- ============================================================================
-- EXPORT QUERIES (Use these to create targeted lists)
-- ============================================================================

-- 20. Export for Email Campaign (High Probability, Has Email)
SELECT 
    email,
    first_name,
    last_name,
    city,
    state,
    donation_probability,
    volunteer_probability,
    total_donations,
    last_donation_date
FROM donors
WHERE 
    email IS NOT NULL
    AND donation_probability > 0.60
    AND is_duplicate = FALSE
    AND state = 'NC'  -- Change to your target state
ORDER BY donation_probability DESC;

-- 21. Export for Phone Banking (High Priority Targets)
SELECT 
    full_name,
    phone,
    mobile_phone,
    street_address,
    city,
    state,
    zip_code,
    donation_probability,
    volunteer_probability,
    total_donations,
    last_donation_date
FROM donors
WHERE 
    (phone IS NOT NULL OR mobile_phone IS NOT NULL)
    AND donation_probability > 0.70
    AND is_duplicate = FALSE
ORDER BY donation_probability DESC
LIMIT 500;

-- ============================================================================
-- DASHBOARD METRICS
-- ============================================================================

-- 22. Key Performance Indicators
SELECT 
    COUNT(*) as total_donors,
    COUNT(CASE WHEN donation_count > 0 THEN 1 END) as donors_with_donations,
    SUM(total_donations) as total_raised,
    COUNT(CASE WHEN is_volunteer THEN 1 END) as total_volunteers,
    ROUND(AVG(donation_probability), 3) as avg_donation_prob,
    ROUND(AVG(volunteer_probability), 3) as avg_volunteer_prob,
    COUNT(CASE WHEN last_donation_date > NOW() - INTERVAL '30 days' THEN 1 END) as recent_donors
FROM donors
WHERE is_duplicate = FALSE;

-- 23. Monthly Growth Metrics
SELECT 
    DATE_TRUNC('month', created_at) as month,
    COUNT(*) as new_donors,
    SUM(COUNT(*)) OVER (ORDER BY DATE_TRUNC('month', created_at)) as cumulative_donors
FROM donors
WHERE is_duplicate = FALSE
GROUP BY DATE_TRUNC('month', created_at)
ORDER BY month DESC
LIMIT 12;

-- ============================================================================
-- END OF USEFUL QUERIES
-- ============================================================================

-- TIPS:
-- 1. Replace 'NC' with your target state throughout these queries
-- 2. Adjust probability thresholds (0.70, 0.60, etc.) based on your needs
-- 3. Modify time intervals (6 months, 1 year) to match your campaign cycle
-- 4. Use LIMIT to control result size for testing
-- 5. Add WHERE clauses to filter by city, zip code, or other criteria
-- 6. Export results to CSV using Supabase dashboard or your application
