// Ecosystem page — sort, filter, search, paginate
(function() {
    const ROWS_PER_PAGE = 25;
    let currentFilter = 'all';
    let searchTerm = '';
    let sortCol = 'rank';
    let sortDir = 'asc';
    let currentPage = 1;

    function tierBadge(tier) {
        const map = {mega:'mega',major:'major',mid:'mid',base:'base'};
        return `<span class="donor-badge ${map[tier]||'base'}">${tier.toUpperCase()}</span>`;
    }

    function getFiltered() {
        return DONORS.filter(d => {
            if (currentFilter !== 'all' && d.tier !== currentFilter) return false;
            if (searchTerm) {
                const s = searchTerm.toLowerCase();
                return d.name.toLowerCase().includes(s) ||
                       d.city.toLowerCase().includes(s) ||
                       d.industry.toLowerCase().includes(s) ||
                       d.employer.toLowerCase().includes(s);
            }
            return true;
        });
    }

    function getSorted(data) {
        return [...data].sort((a, b) => {
            let va = a[sortCol], vb = b[sortCol];
            if (typeof va === 'string') { va = va.toLowerCase(); vb = vb.toLowerCase(); }
            if (va < vb) return sortDir === 'asc' ? -1 : 1;
            if (va > vb) return sortDir === 'asc' ? 1 : -1;
            return 0;
        });
    }

    function render() {
        const filtered = getFiltered();
        const sorted = getSorted(filtered);
        const totalPages = Math.ceil(sorted.length / ROWS_PER_PAGE);
        if (currentPage > totalPages) currentPage = totalPages || 1;
        const start = (currentPage - 1) * ROWS_PER_PAGE;
        const page = sorted.slice(start, start + ROWS_PER_PAGE);

        const tbody = document.getElementById('donorBody');
        tbody.innerHTML = page.map(d => `
            <tr>
                <td>${d.rank}</td>
                <td class="fw-semibold">${d.name}</td>
                <td class="text-success fw-bold">$${d.amount.toLocaleString()}</td>
                <td>${d.donations}</td>
                <td>${d.city}</td>
                <td class="text-muted">${d.employer}</td>
                <td>${d.industry}</td>
                <td>${tierBadge(d.tier)}</td>
                <td><a href="donor-profile.html?id=${d.rank}" class="btn btn-sm btn-soft-info"><i class="ti ti-eye"></i></a></td>
            </tr>
        `).join('');

        document.getElementById('showingCount').textContent =
            `Showing ${page.length} of ${filtered.length} donors`;

        // Pagination
        const pag = document.getElementById('pagination');
        let pagHTML = '';
        if (totalPages > 1) {
            pagHTML += `<li class="page-item ${currentPage===1?'disabled':''}"><a class="page-link" href="#" data-page="${currentPage-1}">&laquo;</a></li>`;
            for (let i = 1; i <= totalPages; i++) {
                pagHTML += `<li class="page-item ${i===currentPage?'active':''}"><a class="page-link" href="#" data-page="${i}">${i}</a></li>`;
            }
            pagHTML += `<li class="page-item ${currentPage===totalPages?'disabled':''}"><a class="page-link" href="#" data-page="${currentPage+1}">&raquo;</a></li>`;
        }
        pag.innerHTML = pagHTML;
    }

    // Event: search
    document.getElementById('searchInput').addEventListener('input', function(e) {
        searchTerm = e.target.value;
        currentPage = 1;
        render();
    });

    // Event: filter buttons
    document.querySelectorAll('.filter-btn').forEach(btn => {
        btn.addEventListener('click', function() {
            document.querySelectorAll('.filter-btn').forEach(b => b.classList.remove('active'));
            this.classList.add('active');
            currentFilter = this.dataset.filter;
            currentPage = 1;
            render();
        });
    });

    // Event: sortable columns
    document.querySelectorAll('.sortable').forEach(th => {
        th.addEventListener('click', function() {
            const col = this.dataset.col;
            if (sortCol === col) {
                sortDir = sortDir === 'asc' ? 'desc' : 'asc';
            } else {
                sortCol = col;
                sortDir = 'asc';
            }
            document.querySelectorAll('.sort-arrow').forEach(a => a.classList.remove('active'));
            this.querySelector('.sort-arrow').classList.add('active');
            this.querySelector('.sort-arrow').textContent = sortDir === 'asc' ? '▼' : '▲';
            render();
        });
    });

    // Event: pagination
    document.getElementById('pagination').addEventListener('click', function(e) {
        e.preventDefault();
        const page = parseInt(e.target.dataset.page);
        if (page && page >= 1) {
            currentPage = page;
            render();
        }
    });

    // Initial render
    render();
})();
