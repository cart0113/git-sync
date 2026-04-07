/*
 * KaTeX — LaTeX math rendering for docsify.
 *
 * Inline math:  $x^2 + 1$
 * Display math: $$\int_0^1 f(x)\,dx$$
 *
 * The plugin extracts math blocks in hook.beforeEach (before markdown-it
 * processes the content), preserving LaTeX characters like & that would
 * otherwise be HTML-encoded. Rendered output is inserted in hook.afterEach.
 */

(function () {
  function katexPlugin(hook) {
    var mathStore = [];

    hook.beforeEach(function (content) {
      mathStore = [];

      /* Protect fenced code blocks and inline code from math extraction */
      var codeSlots = [];
      content = content.replace(
        /````[\s\S]*?````|```[\s\S]*?```|`[^`\n]+`/g,
        function (m) {
          codeSlots.push(m);
          return '\x01CODE' + (codeSlots.length - 1) + '\x01';
        }
      );

      /* Display math: $$...$$ — replace with HTML placeholder */
      content = content.replace(/\$\$([\s\S]+?)\$\$/g, function (_, tex) {
        mathStore.push({ tex: tex.trim(), display: true });
        return (
          '<div data-katex-id="' + (mathStore.length - 1) + '"></div>'
        );
      });

      /* Inline math: $...$ (single line, no nested $) */
      content = content.replace(/\$([^\$\n]+?)\$/g, function (_, tex) {
        mathStore.push({ tex: tex.trim(), display: false });
        return (
          '<span data-katex-id="' + (mathStore.length - 1) + '"></span>'
        );
      });

      /* Restore code blocks */
      content = content.replace(/\x01CODE(\d+)\x01/g, function (_, i) {
        return codeSlots[parseInt(i)];
      });

      return content;
    });

    hook.afterEach(function (html) {
      if (typeof katex === 'undefined') return html;

      /* Replace placeholders with rendered KaTeX */
      html = html.replace(
        /<(div|span) data-katex-id="(\d+)"><\/(div|span)>/g,
        function (_, tag, i) {
          var block = mathStore[parseInt(i)];
          if (!block) return '';
          try {
            return katex.renderToString(block.tex, {
              displayMode: block.display,
              throwOnError: false,
            });
          } catch (e) {
            return block.display
              ? '$$' + block.tex + '$$'
              : '$' + block.tex + '$';
          }
        }
      );

      return html;
    });
  }

  window.katexPlugin = katexPlugin;
})();
