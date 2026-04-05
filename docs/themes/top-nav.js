/*
 * Top navigation bar — full-width header with:
 *   [icon + title] [nav tabs] ... [social icons] [search]
 *
 * When top_level_folders_as_top_control is true, top-level sidebar
 * folders become tabs. Social links and search style are config-driven.
 *
 * Search styles:
 *   - "magnify-glass" (default): icon on right, click to expand overlay
 *   - "box": always-visible input field
 */

(function () {
  var topNavEl = null;
  var folderData = [];
  var cfg = window.__docsifyExtConfig || {};
  var TOP_NAV_OFFSET = 75;

  function getCurrentPath() {
    return (window.location.hash || '#/').split('?')[0];
  }

  function getFolderHeader(li) {
    return (
      li.querySelector(':scope > p') || li.querySelector(':scope > strong')
    );
  }

  function findActiveIndex() {
    var path = getCurrentPath();
    for (var i = 0; i < folderData.length; i++) {
      for (var j = 0; j < folderData[i].links.length; j++) {
        var href = (folderData[i].links[j].getAttribute('href') || '').split(
          '?'
        )[0];
        if (href === path) return i;
      }
    }
    return 0;
  }

  function activateFolder(index) {
    for (var i = 0; i < folderData.length; i++) {
      var isActive = i === index;
      folderData[i].button.classList.toggle('ext-top-active', isActive);
      folderData[i].li.classList.toggle('ext-top-hidden', !isActive);

      /* Always hide the folder header text — it's redundant with the tab */
      var header = getFolderHeader(folderData[i].li);
      if (header) header.style.display = 'none';
    }
  }

  /* Re-acquire fresh DOM references after docsify rebuilds the sidebar */
  function refreshFolderRefs() {
    var nav = document.querySelector('.sidebar-nav');
    if (!nav) return;

    var rootUl = nav.querySelector(':scope > ul');
    if (!rootUl) return;

    var topLis = rootUl.querySelectorAll(':scope > li');

    for (var i = 0; i < topLis.length; i++) {
      var li = topLis[i];
      var header = getFolderHeader(li);
      if (!header) continue;

      var label = header.textContent.trim();

      for (var j = 0; j < folderData.length; j++) {
        if (folderData[j].label === label) {
          folderData[j].li = li;
          folderData[j].links = Array.prototype.slice.call(
            li.querySelectorAll('ul a')
          );
          break;
        }
      }
    }
  }

  /* ---- Social icons mapping ---- */
  var SOCIAL_ICON_MAP = {
    github: 'icon-github',
    facebook: 'icon-facebook',
    x: 'icon-x',
    twitter: 'icon-x',
    instagram: 'icon-instagram',
    threads: 'icon-threads',
    bluesky: 'icon-bluesky',
  };

  function buildSocialIcons() {
    var links = cfg.social_links;
    if (!links || typeof links !== 'object') return null;

    var wrap = document.createElement('div');
    wrap.className = 'ext-top-social';

    var keys = Object.keys(links);
    for (var i = 0; i < keys.length; i++) {
      var key = keys[i];
      var url = links[key];
      var iconId = SOCIAL_ICON_MAP[key.toLowerCase()];
      if (!iconId || !url) continue;

      var a = document.createElement('a');
      a.href = url;
      a.target = '_blank';
      a.rel = 'noopener noreferrer';
      a.className = 'ext-top-social-link';
      a.title = key.charAt(0).toUpperCase() + key.slice(1);
      a.innerHTML =
        '<svg viewBox="0 0 24 24" width="18" height="18"><use href="#' +
        iconId +
        '"/></svg>';
      wrap.appendChild(a);
    }

    return wrap.children.length > 0 ? wrap : null;
  }

  function buildSearch() {
    var style = cfg.search_style || 'magnify-glass';
    var wrap = document.createElement('div');
    wrap.className = 'ext-top-search';

    if (style === 'box') {
      /* Always-visible search input */
      var input = document.createElement('input');
      input.type = 'search';
      input.placeholder = 'Search docs';
      input.className = 'ext-top-search-input';
      input.addEventListener('input', function () {
        triggerDocsifySearch(input.value);
      });
      wrap.appendChild(input);
    } else {
      /* Magnify-glass: icon button that opens overlay */
      var btn = document.createElement('button');
      btn.className = 'ext-top-search-btn';
      btn.title = 'Search';
      btn.innerHTML =
        '<svg viewBox="0 0 24 24" width="18" height="18"><use href="#icon-search"/></svg>';

      var overlay = document.createElement('div');
      overlay.className = 'ext-search-overlay';
      overlay.innerHTML =
        '<div class="ext-search-overlay-inner">' +
        '<input type="search" class="ext-search-overlay-input" placeholder="Search docs..." autofocus />' +
        '<div class="ext-search-overlay-results"></div>' +
        '</div>';

      btn.addEventListener('click', function (e) {
        e.stopPropagation();
        overlay.classList.add('ext-search-open');
        var inp = overlay.querySelector('input');
        if (inp) inp.focus();
      });

      overlay.addEventListener('click', function (e) {
        if (e.target === overlay) {
          overlay.classList.remove('ext-search-open');
        }
      });

      document.addEventListener('keydown', function (e) {
        if (e.key === 'Escape') {
          overlay.classList.remove('ext-search-open');
        }
        /* Ctrl/Cmd + K to open search */
        if ((e.ctrlKey || e.metaKey) && e.key === 'k') {
          e.preventDefault();
          overlay.classList.add('ext-search-open');
          var inp = overlay.querySelector('input');
          if (inp) inp.focus();
        }
      });

      /* Wire overlay input to docsify search */
      var overlayInput = overlay.querySelector('input');
      var resultsDiv = overlay.querySelector('.ext-search-overlay-results');
      if (overlayInput) {
        overlayInput.addEventListener('input', function () {
          triggerDocsifySearch(overlayInput.value);
          /* Poll for results from docsify's search panel */
          setTimeout(function () {
            copySearchResults(resultsDiv);
          }, 200);
        });
      }

      wrap.appendChild(btn);
      document.body.appendChild(overlay);
    }

    return wrap;
  }

  function triggerDocsifySearch(query) {
    /* Find docsify's hidden search input and drive it */
    var sidebarInput = document.querySelector('.search input[type="search"]');
    if (!sidebarInput) return;
    var nativeSetter = Object.getOwnPropertyDescriptor(
      HTMLInputElement.prototype,
      'value'
    ).set;
    nativeSetter.call(sidebarInput, query);
    sidebarInput.dispatchEvent(new Event('input', { bubbles: true }));
  }

  function copySearchResults(targetDiv) {
    if (!targetDiv) return;
    var sidebarResults = document.querySelector('.search .results-panel');
    if (sidebarResults) {
      targetDiv.innerHTML = sidebarResults.innerHTML;
      /* Make result links close the overlay */
      var links = targetDiv.querySelectorAll('a');
      for (var i = 0; i < links.length; i++) {
        links[i].addEventListener('click', function () {
          var overlay = document.querySelector('.ext-search-overlay');
          if (overlay) overlay.classList.remove('ext-search-open');
        });
      }
    }
  }

  function buildTopNav(nav) {
    if (topNavEl) return;

    var rootUl = nav.querySelector(':scope > ul');
    if (!rootUl) return;

    var topLis = rootUl.querySelectorAll(':scope > li');
    folderData = [];

    for (var i = 0; i < topLis.length; i++) {
      var li = topLis[i];
      var header = getFolderHeader(li);
      if (!header) continue;

      var label = header.textContent.trim();
      var links = li.querySelectorAll('ul a');

      /* Store the first page href as a string so tab clicks always
         navigate to the correct path, even after docsify rewrites
         link hrefs (e.g. homepage → #/README). */
      var firstHref = links.length > 0 ? links[0].getAttribute('href') : null;

      folderData.push({
        label: label,
        li: li,
        button: null,
        links: Array.prototype.slice.call(links),
        firstHref: firstHref,
      });
    }

    if (folderData.length === 0) return;

    /* Build the top bar */
    topNavEl = document.createElement('div');
    topNavEl.className = 'ext-top-nav';

    /* --- Left: icon + title --- */
    var brand = document.createElement('a');
    brand.className = 'ext-top-brand';
    brand.href = '#/overview/overview';

    if (cfg.site_icon) {
      var icon = document.createElement('img');
      icon.src = cfg.site_icon;
      icon.alt = '';
      icon.className = 'ext-top-brand-icon';
      brand.appendChild(icon);
    }

    var title = document.createElement('span');
    title.className = 'ext-top-brand-title';
    title.textContent = document.querySelector('.app-name-link')
      ? document.querySelector('.app-name-link').textContent.trim()
      : 'bruha';
    brand.appendChild(title);
    topNavEl.appendChild(brand);

    /* --- Center: nav tabs --- */
    var tabs = document.createElement('div');
    tabs.className = 'ext-top-tabs';

    for (var j = 0; j < folderData.length; j++) {
      var btn = document.createElement('button');
      btn.textContent = folderData[j].label;
      folderData[j].button = btn;

      (function (idx) {
        btn.addEventListener('click', function () {
          activateFolder(idx);
          var href = folderData[idx].firstHref;
          if (href) window.location.hash = href;
        });
      })(j);

      tabs.appendChild(btn);
    }

    topNavEl.appendChild(tabs);

    /* --- Spacer --- */
    var spacer = document.createElement('div');
    spacer.className = 'ext-top-spacer';
    topNavEl.appendChild(spacer);

    /* --- Right: social icons --- */
    var social = buildSocialIcons();
    if (social) topNavEl.appendChild(social);

    /* --- Far right: search --- */
    var search = buildSearch();
    if (search) topNavEl.appendChild(search);

    document.body.appendChild(topNavEl);
    activateFolder(findActiveIndex());
  }

  function applyFolderState() {
    if (!topNavEl || folderData.length === 0) return;
    refreshFolderRefs();
    activateFolder(findActiveIndex());
  }

  /* Scroll to the ?id= target with offset for the fixed top nav bar.
     Docsify's built-in topMargin/scrollIntoView is unreliable when
     auto2top is enabled, so we handle it ourselves. */
  function scrollToId() {
    var hash = window.location.hash || '';
    var match = hash.match(/[?&]id=([^&]*)/);
    if (!match) return;

    var el = document.getElementById(match[1]);
    if (!el) return;

    var targetY = el.offsetTop - TOP_NAV_OFFSET;
    window.scrollTo(0, Math.max(0, targetY));
  }

  function topNavPlugin(hook) {
    hook.doneEach(function () {
      var nav = document.querySelector('.sidebar-nav');
      if (nav) {
        buildTopNav(nav);
        applyFolderState();
      }
      requestAnimationFrame(scrollToId);
    });

    hook.ready(function () {
      window.addEventListener('hashchange', function () {
        applyFolderState();
        requestAnimationFrame(scrollToId);
      });
    });
  }

  window.topNavPlugin = topNavPlugin;
})();
