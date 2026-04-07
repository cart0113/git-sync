/*
 * Callouts — styled alert boxes from blockquote syntax.
 *
 * Usage in markdown:
 *   > [!tip]
 *   > This renders as a green callout box.
 *
 * Types: note, tip, important, warning
 *
 * The plugin runs on hook.afterEach (HTML post-processing) and
 * converts matching <blockquote> elements into <div class="callout">.
 */

(function () {
  var CALLOUT_TYPES = {
    note: { label: 'Note', cssClass: 'callout-note' },
    tip: { label: 'Tip', cssClass: 'callout-tip' },
    important: { label: 'Important', cssClass: 'callout-important' },
    warning: { label: 'Warning', cssClass: 'callout-warning' },
    success: { label: 'Success', cssClass: 'callout-success' },
    danger: { label: 'Danger', cssClass: 'callout-danger' },
    example: { label: 'Example', cssClass: 'callout-example' },
    quote: { label: 'Quote', cssClass: 'callout-quote' },
  };

  function calloutsPlugin(hook) {
    hook.afterEach(function (html) {
      return html.replace(
        /<blockquote>([\s\S]*?)<\/blockquote>/g,
        function (full, inner) {
          var m = inner.match(
            /^\s*<p>\s*\[!(note|tip|important|warning|success|danger|example|quote)\]\s*/i
          );
          if (!m) return full;
          var type = m[1].toLowerCase();
          var t = CALLOUT_TYPES[type];
          /* Strip the [!type] marker from the content */
          var content = inner.replace(
            /^\s*<p>\s*\[!\w+\]\s*(<br\s*\/?>)?\s*/i,
            '<p>'
          );
          return (
            '<div class="callout ' +
            t.cssClass +
            '">' +
            '<div class="callout-title">' +
            t.label +
            '</div>' +
            content +
            '</div>'
          );
        }
      );
    });
  }

  window.calloutsPlugin = calloutsPlugin;
})();
