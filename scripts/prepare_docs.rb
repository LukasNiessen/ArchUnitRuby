# frozen_string_literal: true

require 'pathname'

ROOT = Pathname.new(__dir__).join('..').expand_path
OUTPUT = ROOT.join('docs')
STYLESHEET = OUTPUT.join('css', 'archunit.css')
SITE_URL = 'https://lukasniessen.github.io/ArchUnitRuby/'
SOURCE_URL = 'https://github.com/LukasNiessen/ArchUnitRuby/blob/main/'
NAVIGATION = <<~HTML
  <div class="archunit-topbar" role="navigation" aria-label="Documentation">
    <a class="archunit-brand" href="%<guide>s">
      <span aria-hidden="true">AU</span> ArchUnitRuby
    </a>
    <div class="archunit-links">
      <a href="%<guide>s">Guide</a>
      <a href="%<api>s">API reference</a>
      <a href="https://github.com/LukasNiessen/ArchUnitRuby">GitHub</a>
      <a href="https://github.com/TristanKruse/ArchUnitRuby-TestRepo-RAG">Example</a>
    </div>
  </div>
HTML

def relative_href(target, page)
  target.relative_path_from(page.dirname).to_s.tr('\\', '/')
end

def navigation(page)
  guide = relative_href(OUTPUT.join('index.html'), page)
  api = relative_href(OUTPUT.join('class_list.html'), page)
  format(NAVIGATION, guide: guide, api: api)
end

def page_head(page)
  stylesheet = relative_href(STYLESHEET, page)
  <<~HTML
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <meta name="theme-color" content="#0b0e14">
    <meta name="description" content="ArchUnitRuby architecture testing documentation and API reference">
    <link rel="stylesheet" href="#{stylesheet}" data-archunit-theme>
  HTML
end

def prepare_page(path)
  page = Pathname.new(path)
  content = page.binread.force_encoding(Encoding::UTF_8)

  content.gsub!('href="LICENSE"', "href=\"#{SOURCE_URL}LICENSE\"")
  content.gsub!('href="AGENTS.md"', "href=\"#{SOURCE_URL}AGENTS.md\"")
  if page.basename.to_s.match?(/\A(?:class|method|file)_list\.html\z/)
    content.sub!('<body>', '<body class="archunit-list">')
  end
  content.sub!('</head>', "#{page_head(page)}</head>")
  content.sub!(/(<div id="main"[^>]*>)/, "\\1#{navigation(page)}")
  page.binwrite(content)
end

raise 'YARD did not generate the documentation stylesheet' unless STYLESHEET.file?

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
