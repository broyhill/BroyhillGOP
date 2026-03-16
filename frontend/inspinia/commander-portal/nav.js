// Shared navigation for Commander Portal
function renderSidebar(activePage) {
    const donors = [
        {id:1,name:'Vaughn Prillaman',amt:'$169K'},{id:2,name:'Timothy Wyatt',amt:'$25K'},
        {id:3,name:'Charles Neely',amt:'$22K'},{id:4,name:'James Burnette',amt:'$22K'},
        {id:5,name:'Fred Steen',amt:'$17K'},{id:6,name:'James Howard',amt:'$16K'},
        {id:7,name:'Robert Ingram',amt:'$14K'},{id:8,name:'Elizabeth Fentress',amt:'$12K'},
        {id:9,name:'Robert Lee',amt:'$12K'},{id:10,name:'Michael Boliek',amt:'$11K'},
        {id:11,name:'Dennis Ramsey',amt:'$10K'},{id:12,name:'Charles Davis',amt:'$10K'},
        {id:13,name:'Betty Craven',amt:'$10K'},{id:14,name:'James Narron',amt:'$10K'},
        {id:15,name:'John Hood',amt:'$10K'},{id:16,name:'Jack Clark',amt:'$9K'},
        {id:17,name:'Ashley Woolard',amt:'$9K'},{id:18,name:'Susan Boliek',amt:'$8K'},
        {id:19,name:'John Harris',amt:'$8K'},{id:20,name:'William Rand',amt:'$8K'}
    ];
    const donorLinks = donors.map(d =>
        `<li class="side-nav-item"><a href="donor-profile.html?id=${d.id}" class="side-nav-link"><span class="menu-text">${d.name} — ${d.amt}</span></a></li>`
    ).join('\n');

    const active = p => p === activePage ? ' active' : '';
    return `
        <div class="sidenav-menu">
            <a href="index.html" class="logo">
                <span class="logo logo-light">
                    <span class="logo-lg"><strong class="text-white fs-20">BROYHILL</strong><span class="text-warning">GOP</span></span>
                    <span class="logo-sm"><strong class="text-white">B</strong></span>
                </span>
                <span class="logo logo-dark">
                    <span class="logo-lg"><strong class="text-dark fs-20">BROYHILL</strong><span class="text-warning">GOP</span></span>
                    <span class="logo-sm"><strong class="text-dark">B</strong></span>
                </span>
            </a>
            <button class="button-on-hover"><i class="ti ti-menu-4 fs-22 align-middle"></i></button>
            <button class="button-close-offcanvas"><i class="ti ti-x align-middle"></i></button>
            <div class="scrollbar" data-simplebar>
                <div class="sidenav-user">
                    <div class="d-flex justify-content-between align-items-center">
                        <div>
                            <span class="sidenav-user-name fw-bold">Dave Boliek</span>
                            <span class="fs-12 fw-semibold d-block text-muted">NC State Auditor</span>
                        </div>
                    </div>
                </div>
                <ul class="side-nav">
                    <li class="side-nav-title">COMMANDER</li>
                    <li class="side-nav-item"><a href="index.html" class="side-nav-link${active('index')}"><span class="menu-icon"><i class="ti ti-dashboard"></i></span><span class="menu-text">Command Center</span></a></li>
                    <li class="side-nav-item"><a href="admin.html" class="side-nav-link${active('admin')}"><span class="menu-icon"><i class="ti ti-settings-2"></i></span><span class="menu-text">Admin Panel</span></a></li>
                    <li class="side-nav-item"><a href="ecosystem.html" class="side-nav-link${active('ecosystem')}"><span class="menu-icon"><i class="ti ti-users-group"></i></span><span class="menu-text">Donor Ecosystem</span><span class="badge bg-info">820</span></a></li>
                    <li class="side-nav-title">TOP DONORS</li>
                    <li class="side-nav-item">
                        <a data-bs-toggle="collapse" href="#topDonors" aria-expanded="false" class="side-nav-link">
                            <span class="menu-icon"><i class="ti ti-star"></i></span>
                            <span class="menu-text">Featured Donors</span>
                            <span class="badge bg-danger">20</span>
                        </a>
                        <div class="collapse" id="topDonors"><ul class="sub-menu">${donorLinks}</ul></div>
                    </li>
                    <li class="side-nav-title">INTELLIGENCE</li>
                    <li class="side-nav-item"><a href="#" class="side-nav-link"><span class="menu-icon"><i class="ti ti-building-bank"></i></span><span class="menu-text">Legislative Intel</span></a></li>
                    <li class="side-nav-item"><a href="#" class="side-nav-link"><span class="menu-icon"><i class="ti ti-news"></i></span><span class="menu-text">News Alerts</span></a></li>
                    <li class="side-nav-item"><a href="#" class="side-nav-link"><span class="menu-icon"><i class="ti ti-map-pin"></i></span><span class="menu-text">Charlotte Micro-Ecos</span><span class="badge bg-success">7</span></a></li>
                    <li class="side-nav-item"><a href="#" class="side-nav-link"><span class="menu-icon"><i class="ti ti-mail"></i></span><span class="menu-text">Newsletter Engine</span></a></li>
                </ul>
            </div>
        </div>`;
}

function renderTopbar(title) {
    return `
        <header class="app-topbar">
            <div class="container-fluid">
                <div class="navbar-header">
                    <div class="d-flex align-items-center gap-2">
                        <div class="topbar-item">
                            <button type="button" class="topbar-button" id="dripicons-menu">
                                <i class="ti ti-menu-2 fs-22"></i>
                            </button>
                        </div>
                    </div>
                    <div class="d-flex align-items-center gap-1">
                        <h5 class="text-white mb-0 me-3">${title}</h5>
                        <span class="badge bg-success">LIVE</span>
                    </div>
                </div>
            </div>
        </header>`;
}

document.addEventListener('DOMContentLoaded', function() {
    const sidebar = document.getElementById('sidebar-container');
    const topbar = document.getElementById('topbar-container');
    if (sidebar) sidebar.outerHTML = renderSidebar(sidebar.dataset.active || 'index');
    if (topbar) topbar.outerHTML = renderTopbar(topbar.dataset.title || 'COMMANDER PORTAL');
});
