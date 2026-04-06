/*
 * Mobile navigation — hamburger button + slide-out drawer.
 *
 * On screens <= 768px the desktop top nav bar is hidden (via CSS)
 * and a hamburger button appears. Tapping it opens a drawer with:
 *   - Brand (icon + title)
 *   - Search input (drives docsify's hidden search)
 *   - Folder tabs (same sections as the desktop top nav)
 *   - Sidebar page tree (cloned from docsify on each navigation)
 *   - Theme controls (dark mode, theme swatches, vivid toggle)
 *   - Social links
 *
 * Active when top_level_folders_as_top_control is true.
 * CSS show/hide is in mobile-nav.css.
 *
 * When adding new features to the mobile drawer:
 *   1. Add DOM creation in buildDrawer() (runs once)
 *      — or in syncDrawer() if it needs to update per-navigation
 *   2. Add styles in mobile-nav.css
 *   3. Add show/hide rules in the @media block in mobile-nav.css
 */

(function () {
  var cfg = window.__docsifyExtConfig || {};
  var DARK_KEY = 'doc-dark-mode';
  var THEME_KEY = 'doc-theme';
  var CODE_KEY = 'doc-code-highlighter';

  var THEMES = [
    { id: 'parchment', label: 'Parchment', color: '#4a6591' },
    { id: 'pylab', label: 'Pylab', color: '#2160bb' },
    { id: 'blossom', label: 'Blossom', color: '#9668c4' },
    { id: 'near-midnight', label: 'Near-Midnight', color: '#6c71c4' },
  ];

  var SOCIAL_ICON_MAP = {
    github: 'icon-github',
    facebook: 'icon-facebook',
    x: 'icon-x',
    twitter: 'icon-x',
    instagram: 'icon-instagram',
    threads: 'icon-threads',
    bluesky: 'icon-bluesky',
  };

  var drawerEl = null;
  var backdropEl = null;
  var tabsEl = null;
  var navEl = null;
  var folderData = [];
  var headerSectionEl = null;

  function getCurrentPath() {
    return (window.location.hash || '#/').split('?')[0];
  }

  function getFolderHeader(li) {
    return (
      li.querySelector(':scope > p') || li.querySelector(':scope > strong')
    );
  }

  function openDrawer() {
    drawerEl.classList.add('mobile-open');
    backdropEl.classList.add('mobile-open');
  }

  function closeDrawer() {
    drawerEl.classList.remove('mobile-open');
    backdropEl.classList.remove('mobile-open');
  }

  function findActiveIndex() {
    var path = getCurrentPath();
    for (var i = 0; i < folderData.length; i++) {
      for (var j = 0; j < folderData[i].hrefs.length; j++) {
        if (folderData[i].hrefs[j] === path) return i;
      }
    }
    return 0;
  }

  function activateTab(index) {
    var tabs = tabsEl.querySelectorAll('.mobile-tab');
    for (var i = 0; i < tabs.length; i++) {
      tabs[i].classList.toggle('mobile-tab-active', i === index);
    }
    var topLis = navEl.querySelectorAll(':scope > ul > li');
    for (var i = 0; i < topLis.length; i++) {
      topLis[i].style.display = i === index ? '' : 'none';
      var header = getFolderHeader(topLis[i]);
      if (header) header.style.display = 'none';
    }
  }

  function triggerDocsifySearch(query) {
    var inp = document.querySelector('.search input[type="search"]');
    if (!inp) return;
    var setter = Object.getOwnPropertyDescriptor(
      HTMLInputElement.prototype,
      'value'
    ).set;
    setter.call(inp, query);
    inp.dispatchEvent(new Event('input', { bubbles: true }));
  }

  /* ---- One-time drawer construction ---- */

  function buildDrawer() {
    if (drawerEl) return;

    /* Mobile header bar (hamburger + brand) */
    var mobileHeader = document.createElement('div');
    mobileHeader.className = 'mobile-header';

    var hamburger = document.createElement('button');
    hamburger.className = 'mobile-hamburger';
    hamburger.title = 'Menu';
    hamburger.innerHTML =
      '<svg viewBox="0 0 24 24" width="22" height="22"><use href="#icon-hamburger"/></svg>';
    hamburger.addEventListener('click', function (e) {
      e.stopPropagation();
      openDrawer();
    });
    mobileHeader.appendChild(hamburger);

    var headerBrand = document.createElement('a');
    headerBrand.className = 'mobile-header-brand';
    headerBrand.href = '#/overview/overview';
    if (cfg.site_icon) {
      headerBrand.innerHTML +=
        '<img src="' + cfg.site_icon + '" alt="" class="mobile-header-icon">';
    }
    var nameEl2 = document.querySelector('.app-name-link');
    headerBrand.innerHTML +=
      '<span class="mobile-header-title">' +
      (nameEl2 ? nameEl2.textContent.trim() : 'bruha') +
      '</span>';
    mobileHeader.appendChild(headerBrand);

    headerSectionEl = document.createElement('span');
    headerSectionEl.className = 'mobile-header-section';
    mobileHeader.appendChild(headerSectionEl);

    document.body.appendChild(mobileHeader);

    /* Backdrop */
    backdropEl = document.createElement('div');
    backdropEl.className = 'mobile-backdrop';
    backdropEl.addEventListener('click', closeDrawer);
    document.body.appendChild(backdropEl);

    /* Drawer shell */
    drawerEl = document.createElement('div');
    drawerEl.className = 'mobile-drawer';

    /* Header: brand + close */
    var header = document.createElement('div');
    header.className = 'mobile-drawer-header';

    var brand = document.createElement('a');
    brand.className = 'mobile-drawer-brand';
    brand.href = '#/overview/overview';
    brand.addEventListener('click', closeDrawer);
    if (cfg.site_icon) {
      brand.innerHTML +=
        '<img src="' + cfg.site_icon + '" alt="" class="mobile-drawer-icon">';
    }
    var nameEl = document.querySelector('.app-name-link');
    brand.innerHTML +=
      '<span class="mobile-drawer-title">' +
      (nameEl ? nameEl.textContent.trim() : 'bruha') +
      '</span>';
    header.appendChild(brand);

    var closeBtn = document.createElement('button');
    closeBtn.className = 'mobile-drawer-close';
    closeBtn.innerHTML = '&times;';
    closeBtn.addEventListener('click', closeDrawer);
    header.appendChild(closeBtn);
    drawerEl.appendChild(header);

    /* Search */
    var searchWrap = document.createElement('div');
    searchWrap.className = 'mobile-drawer-search';
    var searchInput = document.createElement('input');
    searchInput.type = 'search';
    searchInput.placeholder = 'Search docs...';
    searchInput.className = 'mobile-drawer-search-input';

    var searchResults = document.createElement('div');
    searchResults.className = 'mobile-drawer-search-results';

    searchInput.addEventListener('input', function () {
      triggerDocsifySearch(searchInput.value);
      setTimeout(function () {
        var panel = document.querySelector('.search .results-panel');
        if (panel) {
          searchResults.innerHTML = panel.innerHTML;
          var links = searchResults.querySelectorAll('a');
          for (var i = 0; i < links.length; i++) {
            links[i].addEventListener('click', closeDrawer);
          }
        }
      }, 200);
    });

    searchWrap.appendChild(searchInput);
    searchWrap.appendChild(searchResults);
    drawerEl.appendChild(searchWrap);

    /* Scrollable middle: tabs + sidebar tree */
    var scroll = document.createElement('div');
    scroll.className = 'mobile-drawer-scroll';

    tabsEl = document.createElement('div');
    tabsEl.className = 'mobile-drawer-tabs';
    scroll.appendChild(tabsEl);

    navEl = document.createElement('div');
    navEl.className = 'mobile-drawer-nav';
    scroll.appendChild(navEl);

    drawerEl.appendChild(scroll);

    /* Footer: theme controls + social */
    var footer = document.createElement('div');
    footer.className = 'mobile-drawer-footer';
    buildThemeControls(footer);
    buildSocialLinks(footer);
    drawerEl.appendChild(footer);

    document.body.appendChild(drawerEl);

    /* Keyboard: Escape closes */
    document.addEventListener('keydown', function (e) {
      if (e.key === 'Escape' && drawerEl.classList.contains('mobile-open')) {
        closeDrawer();
      }
    });

    /* Close drawer if window resizes above mobile breakpoint */
    window.addEventListener('resize', function () {
      if (window.innerWidth > 768) closeDrawer();
    });
  }

  /* ---- Theme controls (built once, in footer) ---- */

  function buildThemeControls(container) {
    var mode = cfg.theme_controls || 'dark_toggle';
    if (mode === 'none') return;

    var isDark = document.documentElement.classList.contains('dark-mode');

    /* Dark mode toggle */
    var darkRow = document.createElement('div');
    darkRow.className = 'mobile-drawer-row';
    darkRow.innerHTML =
      '<span>Dark mode</span>' +
      '<label class="mobile-toggle"><input type="checkbox"' +
      (isDark ? ' checked' : '') +
      '><span class="mobile-toggle-track"></span></label>';
    darkRow.querySelector('input').addEventListener('change', function () {
      document.documentElement.classList.toggle('dark-mode', this.checked);
      localStorage.setItem(DARK_KEY, this.checked ? '1' : '0');
    });
    container.appendChild(darkRow);

    if (mode !== 'theme_picker') return;

    /* Theme swatches */
    var current = localStorage.getItem(THEME_KEY) || cfg.light_theme;
    var swatchRow = document.createElement('div');
    swatchRow.className = 'mobile-drawer-row mobile-drawer-swatches-row';
    swatchRow.innerHTML = '<span>Theme</span>';

    var group = document.createElement('div');
    group.className = 'mobile-swatch-group';

    for (var i = 0; i < THEMES.length; i++) {
      var t = THEMES[i];
      var s = document.createElement('button');
      s.className =
        'mobile-swatch' + (t.id === current ? ' mobile-swatch-active' : '');
      s.setAttribute('data-theme', t.id);
      s.style.background = t.color;
      s.title = t.label;
      s.addEventListener('click', function () {
        var id = this.getAttribute('data-theme');
        document.documentElement.className = document.documentElement.className
          .replace(/\btheme-[\w-]+/g, '')
          .trim();
        document.documentElement.classList.add('theme-' + id);
        localStorage.setItem(THEME_KEY, id);
        var all = group.querySelectorAll('.mobile-swatch');
        for (var j = 0; j < all.length; j++) {
          all[j].classList.toggle(
            'mobile-swatch-active',
            all[j].getAttribute('data-theme') === id
          );
        }
      });
      group.appendChild(s);
    }

    swatchRow.appendChild(group);
    container.appendChild(swatchRow);

    /* Vivid code toggle */
    var isVivid = document.documentElement.classList.contains('code-vivid');
    var vividRow = document.createElement('div');
    vividRow.className = 'mobile-drawer-row';
    vividRow.innerHTML =
      '<span>Vivid code</span>' +
      '<label class="mobile-toggle"><input type="checkbox"' +
      (isVivid ? ' checked' : '') +
      '><span class="mobile-toggle-track"></span></label>';
    vividRow.querySelector('input').addEventListener('change', function () {
      document.documentElement.classList.toggle('code-vivid', this.checked);
      localStorage.setItem(CODE_KEY, this.checked ? 'vivid' : 'classic');
    });
    container.appendChild(vividRow);
  }

  /* ---- Social links (built once, in footer) ---- */

  function buildSocialLinks(container) {
    var links = cfg.social_links;
    if (!links || typeof links !== 'object') return;

    var wrap = document.createElement('div');
    wrap.className = 'mobile-drawer-social';

    var keys = Object.keys(links);
    for (var i = 0; i < keys.length; i++) {
      var key = keys[i];
      var url = links[key];
      var iconId = SOCIAL_ICON_MAP[key.toLowerCase()];
      if (!iconId || !url) continue;

      var label = key.charAt(0).toUpperCase() + key.slice(1);
      var a = document.createElement('a');
      a.href = url;
      a.target = '_blank';
      a.rel = 'noopener noreferrer';
      a.className = 'mobile-drawer-social-link';
      a.title = label;
      a.innerHTML =
        '<svg viewBox="0 0 24 24" width="18" height="18"><use href="#' +
        iconId +
        '"/></svg><span>' +
        label +
        '</span>';
      wrap.appendChild(a);
    }

    if (wrap.children.length > 0) container.appendChild(wrap);
  }

  /* ---- Sync drawer content (runs on every page navigation) ---- */

  function syncDrawer() {
    if (!drawerEl) return;
    var nav = document.querySelector('.sidebar-nav');
    if (!nav) return;

    /* Clone sidebar HTML into drawer */
    navEl.innerHTML = nav.innerHTML;

    var rootUl = navEl.querySelector(':scope > ul');
    if (!rootUl) return;

    /* Build folder data + tab buttons */
    var topLis = rootUl.querySelectorAll(':scope > li');
    folderData = [];
    tabsEl.innerHTML = '';

    for (var i = 0; i < topLis.length; i++) {
      var li = topLis[i];
      var header = getFolderHeader(li);
      if (!header) continue;

      var label = header.textContent.trim();
      var anchors = li.querySelectorAll('ul a');
      var hrefs = [];
      var firstHref =
        anchors.length > 0 ? anchors[0].getAttribute('href') : null;

      for (var j = 0; j < anchors.length; j++) {
        hrefs.push((anchors[j].getAttribute('href') || '').split('?')[0]);
      }

      folderData.push({ label: label, hrefs: hrefs, firstHref: firstHref });

      var tab = document.createElement('button');
      tab.className = 'mobile-tab';
      tab.textContent = label;
      (function (idx) {
        tab.addEventListener('click', function () {
          activateTab(idx);
          var href = folderData[idx].firstHref;
          if (href) {
            window.location.hash = href;
            closeDrawer();
          }
        });
      })(i);
      tabsEl.appendChild(tab);
    }

    /* Expand all folders in drawer (collapsed state is for desktop) */
    var collapsed = navEl.querySelectorAll('.ext-folder-collapsed');
    for (var c = 0; c < collapsed.length; c++) {
      collapsed[c].classList.remove('ext-folder-collapsed');
    }

    /* Re-attach folder collapse handlers on cloned DOM */
    var headers = navEl.querySelectorAll(
      'li.ext-folder > p, li.ext-folder > strong'
    );
    for (var h = 0; h < headers.length; h++) {
      headers[h].addEventListener('click', function () {
        this.parentElement.classList.toggle('ext-folder-collapsed');
      });
    }

    /* Close drawer when any page link is tapped */
    var allLinks = navEl.querySelectorAll('a');
    for (var k = 0; k < allLinks.length; k++) {
      allLinks[k].addEventListener('click', closeDrawer);
    }

    var activeIdx = findActiveIndex();
    activateTab(activeIdx);

    if (headerSectionEl) {
      if (folderData.length > 1) {
        headerSectionEl.textContent = folderData[activeIdx].label;
        headerSectionEl.style.display = '';
      } else {
        headerSectionEl.textContent = '';
        headerSectionEl.style.display = 'none';
      }
    }
  }

  /* ---- Docsify plugin entry point ---- */

  function mobileNavPlugin(hook) {
    hook.doneEach(function () {
      buildDrawer();
      syncDrawer();
    });
  }

  window.mobileNavPlugin = mobileNavPlugin;
})();
