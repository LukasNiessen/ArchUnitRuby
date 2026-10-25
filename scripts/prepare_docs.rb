# frozen_string_literal: true

require 'fileutils'
require 'pathname'

ROOT = Pathname.new(__dir__).join('..').expand_path
OUTPUT = ROOT.join('docs')
STYLESHEET = OUTPUT.join('css', 'archunit.css')
LOGO = OUTPUT.join('assets', 'logo-rounded.png')
SOCIAL_PREVIEW = OUTPUT.join('assets', 'social-preview.png')
SITE_URL = 'https://lukasniessen.github.io/ArchUnitRuby/'
SOURCE_URL = 'https://github.com/LukasNiessen/ArchUnitRuby/blob/main/'
SOURCE_DOCUMENTS = %w[
  LICENSE AGENTS.md CONTRIBUTING.md SECURITY.md SUPPORT.md CODE_OF_CONDUCT.md
].freeze
NAVIGATION = <<~HTML
  <div class="archunit-topbar" role="navigation" aria-label="Documentation">
    <a class="archunit-brand" href="%<guide>s">
      <img src="%<logo>s" alt=""> ArchUnitRuby
    </a>
    <div class="archunit-links">
      <a href="%<guide>s">Guide</a>
      <a href="%<api_guide>s">API guide</a>
      <a href="%<reference>s">Reference</a>
      <a href="https://github.com/LukasNiessen/ArchUnitRuby">GitHub</a>
      <a href="https://github.com/TristanKruse/ArchUnitRuby-TestRepo-RAG">Example</a>
    </div>
  </div>
HTML
PAGE_HEAD = <<~HTML
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <meta name="theme-color" content="#0b0e14">
  <meta name="description" content="ArchUnitRuby architecture testing documentation and API reference">
  <meta property="og:title" content="ArchUnitRuby — Architecture testing for Ruby">
  <meta property="og:description" content="Define and enforce architecture rules as ordinary Ruby tests.">
  <meta property="og:image" content="%<site_url>sassets/social-preview.png">
  <meta property="og:type" content="website">
  <meta property="og:url" content="%<site_url>s">
  <meta name="twitter:card" content="summary_large_image">
  <link rel="icon" type="image/png" href="%<logo>s">
  <link rel="stylesheet" href="%<stylesheet>s" data-archunit-theme>
HTML

def relative_href(target, page)
  target.relative_path_from(page.dirname).to_s.tr('\\', '/')
end

def navigation(page)
  guide = relative_href(OUTPUT.join('index.html'), page)
  api_guide = relative_href(OUTPUT.join('file.API.html'), page)
  reference = relative_href(OUTPUT.join('class_list.html'), page)
  logo = relative_href(LOGO, page)
  format(NAVIGATION, guide:, api_guide:, reference:, logo:)
end

def page_head(page)
  stylesheet = relative_href(STYLESHEET, page)
  logo = relative_href(LOGO, page)
  format(PAGE_HEAD, site_url: SITE_URL, logo:, stylesheet:)
end

def rewrite_source_links(content)
  SOURCE_DOCUMENTS.each do |document|
    content.gsub!("href=\"#{document}\"", "href=\"#{SOURCE_URL}#{document}\"")
  end
end

def prepare_page(path)
  page = Pathname.new(path)
  content = page.binread.force_encoding(Encoding::UTF_8)

  rewrite_source_links(content)
  if page.basename.to_s.match?(/\A(?:class|method|file)_list\.html\z/)
    content.sub!('<body>', '<body class="archunit-list">')
  end
  content.sub!('</head>', "#{page_head(page)}</head>")
  content.sub!(/(<div id="main"[^>]*>)/, "\\1#{navigation(page)}")
  page.binwrite(content)
end

FileUtils.mkdir_p(LOGO.dirname)
FileUtils.cp(ROOT.join('assets', 'logo-rounded.png'), LOGO)
FileUtils.cp(ROOT.join('assets', 'social-preview.png'), SOCIAL_PREVIEW)

raise 'YARD did not generate the documentation stylesheet' unless STYLESHEET.file?
raise 'YARD did not copy the documentation logo' unless LOGO.file?

pages = Dir[OUTPUT.join('**', '*.html')]
raise 'YARD did not generate any documentation pages' if pages.empty?

pages.each { |page| prepare_page(page) }
OUTPUT.join('.nojekyll').write('')
OUTPUT.join('robots.txt').write("User-agent: *\nAllow: /\nSitemap: #{SITE_URL}sitemap.xml\n")
sitemap_urls = pages.map do |page|
  relative = Pathname.new(page).relative_path_from(OUTPUT).to_s.tr('\\', '/')
  "  <url><loc>#{SITE_URL}#{relative}</loc></url>"
end
OUTPUT.join('sitemap.xml').write(
  "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n" \
  "<urlset xmlns=\"http://www.sitemaps.org/schemas/sitemap/0.9\">\n" \
  "#{sitemap_urls.join("\n")}\n</urlset>\n"
)

puts "Prepared #{pages.length} documentation pages in #{OUTPUT}"
