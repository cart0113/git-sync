/*
 * Published date — renders a date line below the page title.
 *
 * Usage in markdown (first line of the file):
 *   <!-- published: April 5, 2026 -->
 *
 * Renders as a small uppercase date below the first <h1>.
 * Styled by .published-date class (defined in blog.css).
 */

(function () {
  function publishedDatePlugin(hook) {
    hook.afterEach(function (html) {
      var m = html.match(/<!--\s*published:\s*(.+?)\s*-->/);
      if (!m) return html;
      var dateStr = m[1].trim();
      var dateHtml = '<div class="published-date">' + dateStr + '</div>';
      /* Insert after the closing </h1> tag */
      return html.replace(/(<\/h1>)/, '$1' + dateHtml);
    });
  }

  window.publishedDatePlugin = publishedDatePlugin;
})();
