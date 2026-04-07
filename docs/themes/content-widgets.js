/*
 * Content widgets — table styles.
 *
 * Table styles are activated by an HTML comment before the table:
 *   <!-- table-striped -->
 *   <!-- table-bordered -->
 *   <!-- table-compact -->
 *   <!-- table-borderless -->
 *   <!-- table-striped table-bordered -->  (combine multiple)
 *
 * The plugin uses hook.doneEach (after DOM insertion) to walk comment
 * nodes in the rendered content, find the next sibling <table>, and
 * apply the requested CSS classes. This avoids all markdown-it and
 * string-matching issues.
 */

(function () {
  var CLASS_RE =
    /^\s*((?:table-(?:striped|bordered|compact|borderless)\s*)+)\s*$/i;
  var VALID_CLASSES = [
    'table-striped',
    'table-bordered',
    'table-compact',
    'table-borderless',
  ];

  function contentWidgetsPlugin(hook) {
    hook.doneEach(function () {
      var section = document.querySelector('.markdown-section');
      if (!section) return;

      /* Walk all comment nodes inside the rendered content */
      var walker = document.createTreeWalker(
        section,
        NodeFilter.SHOW_COMMENT,
        null,
        false
      );

      var toRemove = [];

      while (walker.nextNode()) {
        var comment = walker.currentNode;
        var m = comment.textContent.match(CLASS_RE);
        if (!m) continue;

        /* Parse requested classes */
        var classes = [];
        VALID_CLASSES.forEach(function (cls) {
          if (m[1].indexOf(cls) !== -1) classes.push(cls);
        });
        if (!classes.length) continue;

        /* Find the next sibling that is a <table> */
        var el = comment.nextSibling;
        while (el && !(el.nodeType === 1 && el.tagName === 'TABLE')) {
          el = el.nextSibling;
        }

        if (el) {
          classes.forEach(function (cls) {
            el.classList.add(cls);
          });
        }

        toRemove.push(comment);
      }

      /* Clean up comment nodes so they don't show in dev tools */
      toRemove.forEach(function (c) {
        c.parentNode.removeChild(c);
      });
    });
  }

  window.contentWidgetsPlugin = contentWidgetsPlugin;
})();
