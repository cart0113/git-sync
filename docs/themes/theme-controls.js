/*
 * Theme controls — bottom-right UI for dark mode, theme, and code style.
 *
 * Config key: theme_controls (in bruha.yaml)
 *   "none"         — no controls
 *   "dark_toggle"  — moon/sun button for light/dark
 *   "theme_picker" — palette button opening panel with theme swatches,
 *                     dark mode toggle, and vivid code toggle
 *
 * Also reads:
 *   light_theme       — theme for light mode (parchment|pylab|blossom|near-midnight)
 *   dark_theme        — theme for dark mode (defaults to light_theme)
 *   dark_mode_default — start in dark mode (boolean)
 *   code_highlighter  — "classic" or "vivid" (default vivid)
 *
 * Persists choices in localStorage. Applies classes to <html>
 * immediately (before docsify renders) so there is no flash.
 *
 * Icons are in the SVG sprite (index.html): icon-moon, icon-sun,
 * icon-palette. Referenced via <use href="#icon-name"/>.
 */

(function () {
  var DARK_KEY = 'doc-dark-mode';
  var THEME_KEY = 'doc-theme';
  var CODE_KEY = 'doc-code-highlighter';
  var cfg = window.__docsifyExtConfig || {};

  var THEMES = [
    { id: 'parchment', label: 'Parchment', color: '#4a6591' },
    { id: 'pylab', label: 'Pylab', color: '#2160bb' },
    { id: 'blossom', label: 'Blossom', color: '#9668c4' },
    { id: 'near-midnight', label: 'Near-Midnight', color: '#6c71c4' },
  ];

  function svgUse(id) {
    return '<svg><use href="#' + id + '"/></svg>';
  }

  /* --- Resolve initial dark state: localStorage > config default --- */
  var storedDark = localStorage.getItem(DARK_KEY);
  var isDark;
  if (storedDark !== null) {
    isDark = storedDark === '1';
  } else {
    isDark = !!cfg.dark_mode_default;
  }

  /* --- Resolve initial theme: localStorage > config --- */
  var storedTheme = localStorage.getItem(THEME_KEY);
  var currentTheme;
  if (cfg.theme_controls === 'theme_picker' && storedTheme) {
    currentTheme = storedTheme;
  } else {
    currentTheme = isDark ? cfg.dark_theme : cfg.light_theme;
  }

  /* --- Resolve initial code highlighter: localStorage > config --- */
  var storedCode = localStorage.getItem(CODE_KEY);
  var isVivid;
  if (storedCode !== null) {
    isVivid = storedCode === 'vivid';
  } else {
    isVivid = (cfg.code_highlighter || 'vivid') === 'vivid';
  }

  /* --- Apply immediately (before docsify renders) --- */
  if (isDark) {
    document.documentElement.classList.add('dark-mode');
  }
  if (isVivid) {
    document.documentElement.classList.add('code-vivid');
  }
  if (currentTheme !== cfg.light_theme) {
    document.documentElement.classList.remove('theme-' + cfg.light_theme);
    document.documentElement.classList.add('theme-' + currentTheme);
  }

  /* --- Helpers --- */
  function setDark(dark) {
    isDark = dark;
    document.documentElement.classList.toggle('dark-mode', dark);
    localStorage.setItem(DARK_KEY, dark ? '1' : '0');
  }

  function applyTheme(id) {
    document.documentElement.className = document.documentElement.className
      .replace(/\btheme-[\w-]+/g, '')
      .trim();
    document.documentElement.classList.add('theme-' + id);
    currentTheme = id;
  }

  function setTheme(id) {
    applyTheme(id);
    localStorage.setItem(THEME_KEY, id);
  }

  function setVivid(vivid) {
    isVivid = vivid;
    document.documentElement.classList.toggle('code-vivid', vivid);
    localStorage.setItem(CODE_KEY, vivid ? 'vivid' : 'classic');
  }

  /* ================================================================ */
  /* CSS (injected once)                                               */
  /* ================================================================ */

  var STYLES = [
    '.tc-wrap{position:fixed;bottom:24px;right:24px;z-index:10000;font-family:system-ui,-apple-system,sans-serif}',
    '.tc-btn{width:42px;height:42px;border-radius:50%;border:1px solid var(--t-border);background:var(--t-bg-alt);color:var(--t-text);cursor:pointer;display:flex;align-items:center;justify-content:center;box-shadow:0 2px 10px rgba(0,0,0,.12);transition:transform .15s,box-shadow .15s,background .2s,color .2s,border-color .2s}',
    '.tc-btn:hover{transform:scale(1.08);box-shadow:0 4px 14px rgba(0,0,0,.18)}',
    '.tc-btn svg{width:20px;height:20px}',
    '.tc-panel{position:absolute;bottom:54px;right:0;width:240px;background:var(--t-bg-alt);border:1px solid var(--t-border);border-radius:12px;box-shadow:0 8px 28px rgba(0,0,0,.14);padding:16px;display:none;transition:background .2s,border-color .2s}',
    '.tc-panel.tc-open{display:block;animation:tc-slide .15s ease-out}',
    '@keyframes tc-slide{from{opacity:0;transform:translateY(8px)}to{opacity:1;transform:translateY(0)}}',
    '.tc-head{display:flex;justify-content:space-between;align-items:center;margin-bottom:14px}',
    '.tc-head span{font-weight:600;font-size:14px;color:var(--t-heading);transition:color .2s}',
    '.tc-close{background:none;border:none;font-size:18px;cursor:pointer;color:var(--t-text-muted);padding:0 2px;line-height:1;transition:color .2s}',
    '.tc-close:hover{color:var(--t-text)}',
    '.tc-swatches{display:flex;gap:12px;justify-content:center;margin-bottom:28px}',
    '.tc-swatch{width:36px;height:36px;border-radius:50%;border:3px solid transparent;cursor:pointer;transition:all .12s;position:relative}',
    '.tc-swatch:hover{transform:scale(1.12)}',
    '.tc-swatch.tc-active{border-color:var(--t-accent);box-shadow:0 0 0 1px var(--t-accent)}',
    '.tc-swatch::after{content:attr(data-label);position:absolute;bottom:-18px;left:50%;transform:translateX(-50%);font-size:9px;color:var(--t-text-muted);white-space:nowrap;opacity:0;transition:opacity .12s;pointer-events:none}',
    '.tc-swatch:hover::after{opacity:1}',
    '.tc-row{display:flex;align-items:center;justify-content:space-between;padding-top:12px;border-top:1px solid var(--t-border);transition:border-color .2s}',
    '.tc-row+.tc-row{border-top:none;padding-top:6px}',
    '.tc-row-label{font-size:13px;color:var(--t-text);font-weight:500;transition:color .2s}',
    '.tc-toggle{position:relative;width:40px;height:22px;cursor:pointer}',
    '.tc-toggle input{opacity:0;width:0;height:0;position:absolute}',
    '.tc-toggle .tc-track{position:absolute;inset:0;background:var(--t-border);border-radius:11px;transition:background .2s}',
    '.tc-toggle input:checked+.tc-track{background:var(--t-accent)}',
    '.tc-toggle .tc-track::after{content:"";position:absolute;top:2px;left:2px;width:18px;height:18px;background:#fff;border-radius:50%;transition:transform .2s}',
    '.tc-toggle input:checked+.tc-track::after{transform:translateX(18px)}',
  ].join('\n');

  /* ================================================================ */
  /* dark_toggle mode — simple moon/sun button                         */
  /* ================================================================ */

  function mountDarkToggle() {
    var wrap = document.createElement('div');
    wrap.className = 'tc-wrap';
    wrap.innerHTML =
      '<button class="tc-btn" title="Toggle dark mode">' +
      svgUse(isDark ? 'icon-sun' : 'icon-moon') +
      '</button>';
    document.body.appendChild(wrap);

    var btn = wrap.querySelector('.tc-btn');
    btn.addEventListener('click', function () {
      setDark(!isDark);
      applyTheme(isDark ? cfg.dark_theme : cfg.light_theme);
      btn.innerHTML = svgUse(isDark ? 'icon-sun' : 'icon-moon');
    });
  }

  /* ================================================================ */
  /* theme_picker mode — palette button + panel                        */
  /* ================================================================ */

  function mountThemePicker() {
    var swatchesHtml = THEMES.map(function (t) {
      var cls = 'tc-swatch' + (t.id === currentTheme ? ' tc-active' : '');
      return (
        '<button class="' +
        cls +
        '" data-theme="' +
        t.id +
        '" data-label="' +
        t.label +
        '" style="background:' +
        t.color +
        '"></button>'
      );
    }).join('');

    var wrap = document.createElement('div');
    wrap.className = 'tc-wrap';
    wrap.innerHTML =
      '<button class="tc-btn" title="Theme">' +
      svgUse('icon-palette') +
      '</button>' +
      '<div class="tc-panel">' +
      '  <div class="tc-head"><span>Theme</span><button class="tc-close">&times;</button></div>' +
      '  <div class="tc-swatches">' +
      swatchesHtml +
      '</div>' +
      '  <div class="tc-row">' +
      '    <span class="tc-row-label">Dark mode</span>' +
      '    <label class="tc-toggle"><input type="checkbox" data-tc="dark"' +
      (isDark ? ' checked' : '') +
      '><span class="tc-track"></span></label>' +
      '  </div>' +
      '  <div class="tc-row">' +
      '    <span class="tc-row-label">Vivid code</span>' +
      '    <label class="tc-toggle"><input type="checkbox" data-tc="vivid"' +
      (isVivid ? ' checked' : '') +
      '><span class="tc-track"></span></label>' +
      '  </div>' +
      '</div>';
    document.body.appendChild(wrap);

    var btn = wrap.querySelector('.tc-btn');
    var panel = wrap.querySelector('.tc-panel');

    btn.addEventListener('click', function (e) {
      e.stopPropagation();
      panel.classList.toggle('tc-open');
    });

    wrap.querySelector('.tc-close').addEventListener('click', function () {
      panel.classList.remove('tc-open');
    });

    document.addEventListener('click', function (e) {
      if (!wrap.contains(e.target)) panel.classList.remove('tc-open');
    });

    wrap.querySelectorAll('.tc-swatch').forEach(function (s) {
      s.addEventListener('click', function () {
        setTheme(s.getAttribute('data-theme'));
        wrap.querySelectorAll('.tc-swatch').forEach(function (b) {
          b.classList.toggle(
            'tc-active',
            b.getAttribute('data-theme') === currentTheme
          );
        });
      });
    });

    wrap
      .querySelector('[data-tc="dark"]')
      .addEventListener('change', function () {
        setDark(this.checked);
      });

    wrap
      .querySelector('[data-tc="vivid"]')
      .addEventListener('change', function () {
        setVivid(this.checked);
      });
  }

  /* ================================================================ */
  /* Docsify plugin                                                    */
  /* ================================================================ */

  function themeControlsPlugin(hook) {
    var mode = cfg.theme_controls || 'dark_toggle';
    if (mode === 'none') return;

    hook.mounted(function () {
      var style = document.createElement('style');
      style.textContent = STYLES;
      document.head.appendChild(style);

      if (mode === 'theme_picker') {
        mountThemePicker();
      } else {
        mountDarkToggle();
      }
    });
  }

  window.themeControlsPlugin = themeControlsPlugin;
})();
