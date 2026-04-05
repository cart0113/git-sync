/*
 * Docsify plugin: line numbers + copy button for code blocks.
 *
 * Adds line numbers with a gutter divider and a copy-to-clipboard
 * icon to every fenced code block. Load BEFORE docsify.js.
 */

var COPY_ICON =
  '<svg viewBox="0 0 24 24"><rect x="9" y="9" width="13" height="13" rx="2"/><path d="M5 15H4a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2h9a2 2 0 0 1 2 2v1"/></svg>';
var CHECK_ICON =
  '<svg viewBox="0 0 24 24"><polyline points="20 6 9 17 4 12"/></svg>';

function codeEnhancementsPlugin(hook) {
  hook.doneEach(function () {
    var blocks = document.querySelectorAll('pre[data-lang] > code');
    blocks.forEach(function (block) {
      if (block.querySelector('.code-line')) return;

      var pre = block.parentElement;

      var html = block.innerHTML;
      var lines = html.split('\n');
      if (lines.length > 0 && lines[lines.length - 1].trim() === '') {
        lines.pop();
      }
      block.innerHTML = lines
        .map(function (line, i) {
          var num = i + 1;
          return (
            '<span class="code-line">' +
            '<span class="line-num">' +
            num +
            '</span>' +
            '<span class="line-content">' +
            (line || ' ') +
            '</span>' +
            '</span>'
          );
        })
        .join('');

      if (!pre.querySelector('.copy-btn')) {
        var btn = document.createElement('button');
        btn.className = 'copy-btn';
        btn.innerHTML = COPY_ICON;
        btn.addEventListener('click', function () {
          var text = block.textContent;
          navigator.clipboard.writeText(text).then(function () {
            btn.innerHTML = CHECK_ICON;
            setTimeout(function () {
              btn.innerHTML = COPY_ICON;
            }, 1200);
          });
        });
        pre.appendChild(btn);
      }
    });
  });
}
