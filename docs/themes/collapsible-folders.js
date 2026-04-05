/*
 * Collapsible sections — folders and page sub-sections.
 *
 * Folders: <li> elements whose direct child is a <p> or <strong>
 * (not an <a>) become collapsible. Docsify renders **bold** sidebar
 * items as bare <strong> (no <p> wrapper).
 *
 * Pages: when page_section_collapsible is true, clicking an active
 * page's header link collapses its sub-sections — but only if the
 * user is already at the page top (no ?id= in the URL).
 */

(function () {
  function getCurrentPath() {
    return (window.location.hash || '#/').split('?')[0];
  }

  function getFolderHeader(li) {
    return (
      li.querySelector(':scope > p') || li.querySelector(':scope > strong')
    );
  }

  function folderContainsPath(li, path) {
    var links = li.querySelectorAll('ul a');
    for (var i = 0; i < links.length; i++) {
      var href = (links[i].getAttribute('href') || '').split('?')[0];
      if (href === path) return true;
    }
    return false;
  }

  function setupFolders() {
    var nav = document.querySelector('.sidebar-nav');
    if (!nav) return;

    var currentPath = getCurrentPath();

    var allLis = nav.querySelectorAll('li');
    for (var i = 0; i < allLis.length; i++) {
      var li = allLis[i];
      var header = getFolderHeader(li);
      var ul = li.querySelector(':scope > ul');

      if (!header || !ul) continue;
      if (li.classList.contains('ext-folder')) continue;

      li.classList.add('ext-folder');

      (function (folderLi, headerEl) {
        headerEl.addEventListener('click', function () {
          folderLi.classList.toggle('ext-folder-collapsed');
        });
      })(li, header);
    }

    /* When top nav is active, top-level folders are managed entirely
       by top-nav.js — collapsible-folders must not touch them. */
    var cfg = window.__docsifyExtConfig || {};
    var topNavActive = cfg.top_level_folders_as_top_control;
    var rootUl = nav.querySelector(':scope > ul');

    var folders = nav.querySelectorAll('li.ext-folder');
    for (var j = 0; j < folders.length; j++) {
      var folder = folders[j];
      if (topNavActive && folder.parentElement === rootUl) continue;
      if (folderContainsPath(folder, currentPath)) {
        folder.classList.remove('ext-folder-collapsed');
      } else {
        folder.classList.add('ext-folder-collapsed');
      }
    }
  }

  function setupPageCollapse(nav) {
    var cfg = window.__docsifyExtConfig;
    if (!cfg.page_section_collapsible) return;
    if (nav._pageCollapseAttached) return;
    nav._pageCollapseAttached = true;

    nav.addEventListener(
      'click',
      function (e) {
        var a = e.target.closest('a');
        if (!a) return;

        var li = a.closest('li');
        if (!li || !li.classList.contains('sb-active-page')) return;
        if (a.parentElement !== li) return;

        var subUl = li.querySelector(':scope > ul');
        if (!subUl) return;

        e.preventDefault();
        e.stopImmediatePropagation();

        if (li.classList.contains('sb-page-collapsed')) {
          li.classList.remove('sb-page-collapsed');
          return;
        }

        var hash = window.location.hash || '';
        if (hash.indexOf('?id=') !== -1) {
          /* On a sub-section — navigate to page top without
             letting docsify re-render (which destroys the
             sub-sidebar). */
          var base = hash.split('?')[0];
          history.pushState(null, '', window.location.pathname + base);
          window.dispatchEvent(new HashChangeEvent('hashchange'));
          window.scrollTo(0, 0);
          return;
        }

        /* Already at page top — toggle collapse. */
        li.classList.add('sb-page-collapsed');
      },
      true
    );
  }

  function collapsibleFoldersPlugin(hook) {
    hook.doneEach(function () {
      setupFolders();
    });

    hook.ready(function () {
      var nav = document.querySelector('.sidebar-nav');
      if (nav) setupPageCollapse(nav);
    });
  }

  window.collapsibleFoldersPlugin = collapsibleFoldersPlugin;
})();
