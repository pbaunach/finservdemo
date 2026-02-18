# frozen_string_literal: true

require 'pathname'

# Export the app as static HTML. Uses relative paths so you can open docs/index.html directly.
#
# Option A - With server running (recommended):
#   1. Start server with base path: RAILS_RELATIVE_URL_ROOT=/finservdemo rails s
#   2. In another terminal: rake static:export
#
# Option B - Fetch from running server at root (paths will be rewritten):
#   rails s
#   rake static:export STATIC_EXPORT_URL=http://127.0.0.1:3000
#
# Option C - In-process (no server): STATIC_EXPORT=1 rake static:export IN_PROCESS=1
#   Requires assets precompiled. STATIC_EXPORT=1 skips CSRF so Rack::Test can fetch pages.
#
# Custom: rake static:export BASE=/myapp OUT=build

namespace :static do
  BASE_PATH = ENV.fetch('BASE', '/finservdemo').sub(%r{/+$}, '')
  OUT_DIR   = ENV.fetch('OUT', 'docs')
  BASE_URL  = ENV.fetch('STATIC_EXPORT_URL', 'http://127.0.0.1:3000')
  IN_PROCESS = ENV['IN_PROCESS'] == '1' || ENV['IN_PROCESS'] == 'true'
  NS = self

  # In static (file:// or GitHub Pages), Turbolinks intercepts links and breaks navigation.
  # This patch makes Turbolinks.visit do a full page load so links work.
  TURBOLINKS_STATIC_PATCH = <<~SCRIPT.strip
    <script>(function(){function p(){if(window.Turbolinks&&typeof window.Turbolinks.visit==="function"){window.Turbolinks.visit=function(u){window.location.href=u;}}}if(document.readyState==="loading"){document.addEventListener("DOMContentLoaded",p);}else{p();}window.addEventListener("load",p);})();</script>
  SCRIPT

  ROUTES = [
    ['', 'index.html'],
    ['welcome/index', 'welcome/index.html'],
    ['today/today', 'today/today/index.html'],
    ['sales/leadlist', 'sales/leadlist/index.html'],
    ['wm/bob', 'wm/bob/index.html'],
    ['wm/profile', 'wm/profile/index.html'],
    ['cb/profile', 'cb/profile/index.html'],
    ['mc/journey', 'mc/journey/index.html'],
    ['mobile/demo', 'mobile/demo/index.html'],
    ['mobile/ipad', 'mobile/ipad/index.html'],
    ['mobile/ins', 'mobile/ins/index.html'],
    ['ins/community', 'ins/community/index.html']
  ].freeze

  def self.rewrite_base(html, base_path)
    return html if base_path.empty? || base_path == '/'
    # Only rewrite absolute paths that don't already have the base
    html.gsub(%r{(href|src|xlink:href)="(/)(?![a-z]+:)(?!#{Regexp.escape(base_path)}/)}, "\\1=\"#{base_path}/")
  end

  desc 'Export static site to docs/ for GitHub Pages'
  task export: :environment do
    Rails.application.config.relative_url_root = BASE_PATH
    Rails.application.routes.default_url_options[:script_name] = BASE_PATH

    FileUtils.mkdir_p(OUT_DIR)

    if IN_PROCESS
      ENV['STATIC_EXPORT'] = '1'
      ApplicationController.allow_forgery_protection = false
      puts "Exporting in-process (base=#{BASE_PATH}, out=#{OUT_DIR})..."
      require 'rack/test'
      include Rack::Test::Methods
      def app
        Rails.application
      end
      begin
        ROUTES.each do |route_path, file_path|
          path_info = route_path.empty? ? '/' : "/#{route_path}"
          get path_info
          if last_response.status != 200
            puts "  [SKIP] #{path_info} -> #{last_response.status}"
            next
          end
          html = NS.rewrite_base(last_response.body, BASE_PATH)
          out_file = File.join(OUT_DIR, file_path)
          FileUtils.mkdir_p(File.dirname(out_file))
          File.write(out_file, html, mode: 'wb')
          puts "  [OK]   #{BASE_PATH}#{path_info == '/' ? '' : path_info} -> #{out_file}"
        end
      ensure
        ApplicationController.allow_forgery_protection = true
      end
    else
      # HTTP: fetch from running server
      puts "Exporting from #{BASE_URL} (base=#{BASE_PATH}, out=#{OUT_DIR})..."
      require 'net/http'
      require 'uri'
      ROUTES.each do |route_path, file_path|
        # Fetch from server at root; we'll rewrite paths to include BASE_PATH in the HTML
        path = route_path.empty? ? '/' : "/#{route_path}"
        url = "#{BASE_URL}#{path}"
        html = begin
          uri = URI(url)
          Net::HTTP.get(uri)
        rescue StandardError => e
          puts "  [SKIP] #{path} -> #{e.message}"
          next
        end
        if html.to_s.strip.empty? || html.include?('InvalidAuthenticityToken')
          puts "  [SKIP] #{path} -> empty or error"
          next
        end
        html = NS.rewrite_base(html, BASE_PATH)
        out_file = File.join(OUT_DIR, file_path)
        FileUtils.mkdir_p(File.dirname(out_file))
        File.write(out_file, html, mode: 'wb')
        puts "  [OK]   #{path} -> #{out_file}"
      end
    end

    # Copy assets to docs/assets (so relative paths work when opening index.html directly)
    assets_src = Rails.public_path.join('assets')
    assets_dst = File.join(OUT_DIR, 'assets')
    if Dir.exist?(assets_src)
      FileUtils.mkdir_p(File.dirname(assets_dst))
      FileUtils.rm_rf(assets_dst)
      FileUtils.cp_r(assets_src, assets_dst)
      puts "  [OK]   copied assets -> #{assets_dst}"
    else
      puts "  [WARN] Run 'rake assets:precompile' first."
    end

    # Fix asset links: use production CSS/JS filenames and make all paths relative
    # so you can open docs/index.html directly in the browser (file:// or drag-and-drop).
    if Dir.exist?(assets_dst)
      # Strip Salesforce Sans @font-face from copied CSS so webfont 404s don't occur (use fallbacks).
      Dir[File.join(assets_dst, 'application-*.css')].each do |css_path|
        css = File.read(css_path, encoding: 'UTF-8')
        css = css.gsub(FONT_FACE_PATTERN, '')
        File.write(css_path, css, mode: 'wb')
      end
      prod_css = Dir[File.join(assets_dst, 'application-*.css')].first
      prod_js  = Dir[File.join(assets_dst, 'application-*.js')].first
      if prod_css && prod_js
        prod_css_name = File.basename(prod_css)
        prod_js_name  = File.basename(prod_js)
        base_asset = "#{BASE_PATH}/assets/"
        out_dir_abs = File.expand_path(OUT_DIR)
        Dir[File.join(OUT_DIR, '**', '*.html')].each do |html_path|
          html = File.read(html_path, encoding: 'UTF-8')
          # Replace block of stylesheet/script with single production CSS/JS (still with base path for now)
          one_css = %{<link rel="stylesheet" href="#{base_asset}#{prod_css_name}" media="all" />}
          one_js  = %{<script src="#{base_asset}#{prod_js_name}"></script>\n#{TURBOLINKS_STATIC_PATCH}}
          html = html.gsub(%r{(<link[^>]*rel=["']stylesheet["'][^>]*href="#{Regexp.escape(base_asset)}[^"]+\.css[^"]*"[^>]*/>\s*)+}, one_css)
          html = html.gsub(%r{(<script[^>]*src="#{Regexp.escape(base_asset)}[^"]+\.js[^"]*"[^>]*>\s*</script>\s*)+}, one_js)
          # Convert to relative paths so opening index.html directly works
          html_dir_abs = File.expand_path(File.dirname(html_path))
          rel_dir = Pathname.new(html_dir_abs).relative_path_from(Pathname.new(out_dir_abs))
          depth = rel_dir.each_filename.to_a.reject { |n| n == '.' }.size
          rel_prefix = depth.zero? ? '' : ('../' * depth)
          html = html.gsub(%r{(href|src|xlink:href)="#{Regexp.escape(BASE_PATH)}/assets/}, "\\1=\"#{rel_prefix}assets/")
          html = html.gsub(%r{(href|src|xlink:href)="#{Regexp.escape(BASE_PATH)}/?([^"]*)"}) do
            attr = Regexp.last_match(1)
            full = Regexp.last_match(2)
            path = full.sub(/\?.*/, '').sub(%r{/+$}, '')
            path = (path.empty? ? 'index.html' : "#{path}/index.html") if path !~ /\.(html|css|js|png|jpg|gif|svg|ico|woff2?|ttf|eot)\b/
            path = 'index.html' if path.empty?
            query = full.include?('?') ? full[full.index('?')..] : ''
            "#{attr}=\"#{rel_prefix}#{path}#{query}\""
          end
          html = html.gsub(%r{<meta name="apple-mobile-web-app-capable"}, '<meta name="mobile-web-app-capable"')
          html = html.gsub(%r{<img\s+href=}, '<img src=')
          File.write(html_path, html, mode: 'wb')
        end
        puts "  [OK]   relative asset/page links (open docs/index.html directly)"
      end
    end

    puts "Done. Static site is in #{OUT_DIR}/ — open #{OUT_DIR}/index.html in a browser to preview."
  end

  desc 'Make existing docs use relative paths (move assets to docs/assets, rewrite links). Run after export to open index.html directly.'
  task make_relative: :environment do
    old_assets = File.join(OUT_DIR, BASE_PATH.sub(%r{^/}, ''), 'assets')
    new_assets = File.join(OUT_DIR, 'assets')
    out_dir_abs = File.expand_path(OUT_DIR)
    if Dir.exist?(old_assets) && !Dir.exist?(new_assets)
      FileUtils.mv(old_assets, new_assets)
      puts "  [OK]   moved assets to #{new_assets}"
    end
    unless Dir.exist?(new_assets)
      puts "No assets at #{new_assets}. Run rake static:export first."
      next
    end
    prod_css = Dir[File.join(new_assets, 'application-*.css')].first
    prod_js  = Dir[File.join(new_assets, 'application-*.js')].first
    unless prod_css && prod_js
      puts "Production application.css/js not found."
      next
    end
    prod_css_name = File.basename(prod_css)
    prod_js_name  = File.basename(prod_js)
    base_asset = "#{BASE_PATH}/assets/"
    count = 0
        Dir[File.join(OUT_DIR, '**', '*.html')].each do |html_path|
          html = File.read(html_path, encoding: 'UTF-8')
          html_dir_abs = File.expand_path(File.dirname(html_path))
          rel_dir = Pathname.new(html_dir_abs).relative_path_from(Pathname.new(out_dir_abs))
      depth = rel_dir.each_filename.to_a.reject { |n| n == '.' }.size
      rel_prefix = depth.zero? ? '' : ('../' * depth)
      one_css = %{<link rel="stylesheet" href="#{rel_prefix}assets/#{prod_css_name}" media="all" />}
      one_js  = %{<script src="#{rel_prefix}assets/#{prod_js_name}"></script>\n#{TURBOLINKS_STATIC_PATCH}}
      html = html.gsub(%r{(<link[^>]*rel=["']stylesheet["'][^>]*href="#{Regexp.escape(BASE_PATH)}/assets/[^"]+"[^>]*/>\s*)+}, one_css)
      html = html.gsub(%r{(<script[^>]*src="#{Regexp.escape(BASE_PATH)}/assets/[^"]+\.js[^"]*"[^>]*>\s*</script>\s*)+}, one_js)
      html = html.gsub(%r{(href|src|xlink:href)="#{Regexp.escape(BASE_PATH)}/?([^"]*)"}) do
        attr = Regexp.last_match(1)
        full = Regexp.last_match(2)
        path = full.sub(/\?.*/, '').sub(%r{/+$}, '')
        path = (path.empty? ? 'index.html' : "#{path}/index.html") if path !~ /\.(html|css|js|png|jpg|gif|svg|ico|woff2?|ttf|eot)\b/
        path = 'index.html' if path.empty?
        query = full.include?('?') ? full[full.index('?')..] : ''
        "#{attr}=\"#{rel_prefix}#{path}#{query}\""
      end
      html = html.gsub(%r{<meta name="apple-mobile-web-app-capable"}, '<meta name="mobile-web-app-capable"')
      html = html.gsub(%r{<img\s+href=}, '<img src=')
      File.write(html_path, html, mode: 'wb')
      count += 1
    end
    puts "Made #{count} HTML file(s) use relative paths. Open #{OUT_DIR}/index.html in a browser."
  end

  desc 'Patch existing docs: disable Turbolinks so links work when opening index.html directly.'
  task patch_turbolinks: :environment do
    count = 0
    Dir[File.join(OUT_DIR, '**', '*.html')].each do |html_path|
      html = File.read(html_path, encoding: 'UTF-8')
      # Replace script tag that loads application-*.js (with or without data-turbolinks-track) with same + patch
      next unless html.include?('application-') && html.include?('.js')
      old_script = html.match(%r{<script\s+src="([^"]+application-[^"]+\.js)"[^>]*>\s*</script>})
      if old_script
        new_block = %{<script src="#{old_script[1]}"></script>\n#{TURBOLINKS_STATIC_PATCH}}
        html = html.sub(%r{<script\s+src="([^"]+application-[^"]+\.js)"[^>]*>\s*</script>}, new_block)
        html = html.gsub(%r{<meta name="apple-mobile-web-app-capable"}, '<meta name="mobile-web-app-capable"')
        html = html.gsub(%r{<img\s+href=}, '<img src=')
        File.write(html_path, html, mode: 'wb')
        count += 1
      end
    end
    puts "Patched #{count} HTML file(s) for static (Turbolinks disabled)."
  end

  # Remove Salesforce Sans @font-face from CSS in docs/assets so webfont 404s go away (use fallbacks).
  FONT_FACE_PATTERN = /@font-face\{[^}]*font-family:\s*["']Salesforce Sans["'][^}]*\}/

  desc 'Strip Salesforce Sans @font-face from docs/assets/*.css (stops webfont 404s).'
  task strip_css_fonts: :environment do
    Dir[File.join(OUT_DIR, 'assets', 'application-*.css')].each do |path|
      s = File.read(path, encoding: 'UTF-8')
      before = s.size
      s = s.gsub(FONT_FACE_PATTERN, '')
      File.write(path, s, mode: 'wb')
      puts "  #{path}: removed #{before - s.size} chars"
    end
    puts "Done. Salesforce Sans @font-face removed from docs CSS."
  end
end
