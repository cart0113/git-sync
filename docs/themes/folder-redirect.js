/*
 * Folder redirect — navigating to a folder path (e.g. /#/examples/)
 * redirects to the first page inside that folder.
 *
 * Parses _sidebar.md to build a map of folder paths to their first
 * child page link. Runs before Docsify loads so there is no 404 flash.
 */

(function () {
  var basePath = 'src/';
  var folderMap = {};

  function buildFolderMap(sidebarText) {
    var map = {};
    var stack = [];

    var lines = sidebarText.split('\n');
    for (var i = 0; i < lines.length; i++) {
      var line = lines[i];
      var indent = 0;
      while (indent < line.length && line[indent] === ' ') indent++;
      var depth = Math.floor(indent / 2);
      var trimmed = line.trim();
      if (!trimmed || trimmed === '-') continue;

      var linkMatch = trimmed.match(/\[.*?\]\((.*?)\)/);
      var isBoldOnly = /^-?\s*\*\*(.+?)\*\*\s*$/.test(trimmed) && !linkMatch;

      stack = stack.slice(0, depth);

      if (isBoldOnly) {
        var href = linkMatch ? linkMatch[1] : null;
        if (!href) {
          stack[depth] = 'folder';
        }
      }

      if (linkMatch) {
        var target = linkMatch[1].replace(/\.md$/, '');
        var parts = target.split('/');
        for (var p = 1; p <= parts.length - 1; p++) {
          var folderPath = parts.slice(0, p).join('/') + '/';
          if (!map[folderPath]) {
            map[folderPath] = target;
          }
        }
      }
    }
    return map;
  }

  var xhr = new XMLHttpRequest();
  xhr.open('GET', basePath + '_sidebar.md', false);
  try {
    xhr.send();
    if (xhr.status === 200) {
      folderMap = buildFolderMap(xhr.responseText);
    }
  } catch (e) {}

  function checkRedirect() {
    var hash = window.location.hash || '';
    var path = hash.replace(/^#\//, '');

    if (!path || !path.endsWith('/')) return;

    var target = folderMap[path];
    if (target) {
      window.location.hash = '#/' + target;
    }
  }

  checkRedirect();

  window.addEventListener('hashchange', checkRedirect);
})();
