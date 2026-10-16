# frozen_string_literal: true

require 'pathname'
require 'uri'

ROOT = Pathname.new(__dir__).join('..').expand_path
OUTPUT = ROOT.join('docs')
REQUIRED_FILES = %w[
  index.html file.API.html class_list.html css/archunit.css assets/logo-rounded.png
  assets/social-preview.png .nojekyll robots.txt sitemap.xml
].freeze

def internal_target(page, href)
  return if href.empty? || href.start_with?('#', '//') || href.match?(/\A[a-z][a-z0-9+.-]*:/i)

  relative = href.split(/[?#]/, 2).first
  return if relative.empty?

  page.dirname.join(URI::DEFAULT_PARSER.unescape(relative)).cleanpath
end

missing = REQUIRED_FILES.reject { |relative| OUTPUT.join(relative).exist? }
raise "Documentation build is missing: #{missing.join(', ')}" unless missing.empty?

pages = Dir[OUTPUT.join('**', '*.html')].map { |path| Pathname.new(path) }
broken = pages.flat_map do |page|
  content = page.binread.force_encoding(Encoding::UTF_8)
  unless content.include?('data-archunit-theme')
    raise "Custom theme is missing from #{page.relative_path_from(OUTPUT)}"
  end
  if page.basename.to_s.match?(/\A(?:class|method|file)_list\.html\z/) &&
     !content.include?('<body class="archunit-list">')
    raise "Navigation theme hook is missing from #{page.relative_path_from(OUTPUT)}"
  end

  content.scan(/\bhref=(["'])(.*?)\1/).filter_map do |(_, href)|
    target = internal_target(page, href)
    "#{page.relative_path_from(OUTPUT)} -> #{href}" if target && !target.exist?
  end
end

raise "Broken documentation links:\n#{broken.join("\n")}" unless broken.empty?

guide = OUTPUT.join('index.html').binread.force_encoding(Encoding::UTF_8)
unrendered = {
  'GitHub badge Markdown' => '[![',
  'backtick code fence' => "#{96.chr * 3}ruby"
}.filter_map { |label, marker| label if guide.include?(marker) }
raise "Documentation guide contains unrendered #{unrendered.join(' and ')}" unless unrendered.empty?

api_guide = OUTPUT.join('file.API.html').binread.force_encoding(Encoding::UTF_8)
required_api_terms = %w[
  project_files project_layers project_slices project_graph metrics CheckOptions LoggingOptions
].freeze
missing_api_terms = required_api_terms.reject { |term| api_guide.include?(term) }
unless missing_api_terms.empty?
  raise "API guide is missing public entry points: #{missing_api_terms.join(', ')}"
end

puts "Validated #{pages.length} documentation pages, public API coverage, and internal links"
