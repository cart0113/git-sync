/*
 * Sidebar bar indicator — heading hierarchy + section highlight.
 *
 * Marks the active page's <li> with .sb-active-page. If the page has
 * sub-sections, also adds .sb-has-sections. Within the sub-sidebar:
 *   - depth 1 (H2) → .sb-bar-level (border-left indicator)
 *   - depth 2+ (H3+) → .sb-text-level (border-left indicator + text highlight)
 *
 * Current section's <li> gets .sb-current.
 */

(function () {
  var observer;
  var lastClickY = null;

  function getCurrentPath() {
    return (window.location.hash || '#/').split('?')[0];
  }

  function findActivePage(nav) {
    var subSidebar = nav.querySelector('.app-sub-sidebar');
    if (subSidebar) {
      var parentLi = subSidebar.closest('li');
      if (parentLi) return parentLi;
    }

    var currentPath = getCurrentPath();
    var links = nav.querySelectorAll('li > a');
    for (var i = 0; i < links.length; i++) {
      var href = (links[i].getAttribute('href') || '').split('?')[0];
      if (href === currentPath) return links[i].parentElement;
    }

    var activeLis = nav.querySelectorAll('li.active');
    for (var i = activeLis.length - 1; i >= 0; i--) {
      if (activeLis[i].querySelector(':scope > a')) return activeLis[i];
    }

    return null;
  }

  function findCurrentSection(pageLi) {
    var hash = window.location.hash;
    var subUl = pageLi.querySelector(':scope > ul');
    if (!subUl) return null;
    if (!hash || hash.indexOf('?id=') === -1) return null;

    var idPart = hash.split('?id=')[1];
    if (!idPart) return null;

    var links = subUl.querySelectorAll('a');

    for (var i = 0; i < links.length; i++) {
      if (links[i].getAttribute('href') === hash) return links[i];
    }

    for (var i = 0; i < links.length; i++) {
      var linkHref = links[i].getAttribute('href') || '';
      var linkId = linkHref.split('?id=')[1];
      if (linkId && linkId === idPart) return links[i];
    }

    var decoded = decodeURIComponent(idPart);
    for (var i = 0; i < links.length; i++) {
      var linkHref = links[i].getAttribute('href') || '';
      var linkId = linkHref.split('?id=')[1];
      if (linkId && decodeURIComponent(linkId) === decoded) return links[i];
    }

    var activeSub = subUl.querySelector('li.active > a');
    return activeSub || null;
  }

  function assignDepthClasses(pageLi) {
    var topUl = pageLi.querySelector(':scope > ul.app-sub-sidebar');
    if (!topUl) return;

    pageLi.classList.add('sb-has-sections');

    function walk(ul, depth) {
      var items = ul.querySelectorAll(':scope > li');
      for (var i = 0; i < items.length; i++) {
        var li = items[i];

        if (depth === 1) {
          li.classList.add('sb-bar-level');
        } else {
          li.classList.add('sb-text-level');
        }

        var childUl = li.querySelector(':scope > ul');
        if (childUl) walk(childUl, depth + 1);
      }

      // Docsify places H3+ items in sibling <ul> elements (direct children
      // of the parent <ul>), not nested inside the H2 <li>.
      var childUls = ul.querySelectorAll(':scope > ul');
      for (var j = 0; j < childUls.length; j++) {
        walk(childUls[j], depth + 1);
      }
    }

    walk(topUl, 1);
  }

  function applyActiveStates() {
    if (observer) observer.disconnect();

    var nav = document.querySelector('.sidebar-nav');
    if (!nav) {
      reconnect();
      return;
    }

    nav.querySelectorAll('.sb-active-page').forEach(function (el) {
      el.classList.remove('sb-active-page');
    });
    nav.querySelectorAll('.sb-has-sections').forEach(function (el) {
      el.classList.remove('sb-has-sections');
    });
    nav.querySelectorAll('.sb-current').forEach(function (el) {
      el.classList.remove('sb-current');
    });
    nav
      .querySelectorAll('.sb-bar-level, .sb-text-level')
      .forEach(function (el) {
        el.classList.remove('sb-bar-level', 'sb-text-level');
      });

    /* Mark every page-link <li> (has a direct <a>, not inside sub-sidebar)
       so CSS can show a collapsed chevron on non-active pages. */
    var allLis = nav.querySelectorAll('li');
    for (var i = 0; i < allLis.length; i++) {
      var li = allLis[i];
      if (li.closest('.app-sub-sidebar')) continue;
      if (li.querySelector(':scope > a')) {
        li.classList.add('sb-page-link');
      }
    }

    var pageLi = findActivePage(nav);
    if (pageLi) {
      pageLi.classList.add('sb-active-page');
      assignDepthClasses(pageLi);

      var link = findCurrentSection(pageLi);
      if (link) {
        var li = link.closest('li');
        if (li) li.classList.add('sb-current');
      }
    }

    reconnect();
  }

  function reconnect() {
    var sidebar = document.querySelector('.sidebar-nav');
    if (sidebar && observer) {
      observer.observe(sidebar, {
        attributes: true,
        subtree: true,
        attributeFilter: ['class'],
      });
    }
  }

  function scrollActiveToClickY() {
    var nav = document.querySelector('.sidebar-nav');
    if (nav) nav.style.paddingTop = '';

    if (lastClickY === null) return;
    var clickY = lastClickY;
    lastClickY = null;

    if (!nav) return;
    var pageLi = findActivePage(nav);
    if (!pageLi) return;

    var sidebarEl = nav.closest('.sidebar');
    if (!sidebarEl) return;

    var pageLink = pageLi.querySelector(':scope > a');
    var scrollTarget = pageLink || pageLi;
    var rect = scrollTarget.getBoundingClientRect();
    var offset = clickY - rect.top;

    if (offset > 0) {
      sidebarEl.scrollTop = 0;
      nav.style.paddingTop = offset + 'px';
    } else {
      sidebarEl.scrollTop += rect.top - clickY;
    }
  }

  function sidebarIndicatorPlugin(hook) {
    hook.doneEach(function () {
      applyActiveStates();
      scrollActiveToClickY();
    });

    hook.ready(function () {
      observer = new MutationObserver(applyActiveStates);
      reconnect();
      window.addEventListener('hashchange', applyActiveStates);

      document
        .querySelector('.sidebar')
        .addEventListener('click', function (e) {
          var link = e.target.closest('a');
          if (
            link &&
            link.closest('.sidebar-nav') &&
            !link.closest('.app-sub-sidebar')
          ) {
            lastClickY = e.clientY;
          }
        });
    });
  }

  window.sidebarIndicatorPlugin = sidebarIndicatorPlugin;
})();
