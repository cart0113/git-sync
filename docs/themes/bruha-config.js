window.__docsifyExtConfig = {
  light_theme: 'parchment',
  dark_theme: 'near-midnight',
  theme_controls: 'dark_toggle',
  dark_mode_default: false,
  code_highlighter: 'vivid',
  document_inline_sidebar_selector: true,
  document_header_depth: 3,
  top_level_folders_as_top_control: true,
  hamburger_menu: false,
  github_corner: false,
  content_folder: 'src',
  folder_chevron: true,
  page_section_collapsible: true,
  search_style: 'magnify-glass',
  sidebar_indent: '1em',
  site_icon: 'assets/git-sync-icon.svg',
  social_links: {
    github: 'https://github.com/cart0113/git-sync',
  },
  style: 'code-one',
  site_name: 'git-sync',
  site_description: 'Compose independent git repos into a pseudo-monorepo',
  og_image: 'assets/og-image.svg',
  home_path: 'overview/overview',
  prism_languages: ['python', 'bash', 'markdown', 'yaml', 'javascript', 'json'],
};
(function (c) {
  document.documentElement.classList.add('theme-' + c.light_theme);
  if (!c.hamburger_menu)
    document.documentElement.classList.add('ext-no-hamburger');
  if (!c.github_corner)
    document.documentElement.classList.add('ext-no-github-corner');
  document.documentElement.classList.add('ext-has-top-nav');
  if (c.folder_chevron)
    document.documentElement.classList.add('ext-folder-chevron');
  if (c.document_inline_sidebar_selector)
    document.documentElement.classList.add('ext-inline-sidebar');
  if (c.sidebar_indent)
    document.documentElement.style.setProperty(
      '--t-sidebar-indent',
      c.sidebar_indent,
    );
  if (c.style) document.documentElement.classList.add('style-' + c.style);
})(window.__docsifyExtConfig);
