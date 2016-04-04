require 'pathname'

module Jekyll
  class PagesDirGenerator < Generator
    def generate(site)
      #puts site.static_files.inspect
      # TODO: Add nav.
      puts "Notes plugin loading." # DEBUG
      pages_dir = site.config['pages'] || './_pages'
      all_files = Dir["#{pages_dir}/**/*"]
      # Get valid page extensions.
      exts = site.config["markdown_ext"].split(",") + ["htm", "html"]
      # Filter out non-page files.
      document_paths = all_files.select { |p| exts.include? File.extname(p)[1..-1] }
      pages_for_nav = []
      document_paths.each do |f|
        if File.file?(File.join(site.source, '/', f))
          filename = f.match(/[^\/]*$/)[0]
          clean_filepath = f.gsub(/^#{pages_dir}\//, '')
          clean_dir = extract_directory(clean_filepath)

          page = PagesDirPage.new(site,
                                         site.source,
                                         clean_dir,
                                         filename,
                                         pages_dir)
          pages_for_nav << page
          site.pages << page
          #break # DEBUG; for debugging, only 1 page.
        end
      end

      # Create navigation in site.data.sidebar
      pages_for_nav.select! { |p| p.get_type == :lecture }
      units = {}
      pages_for_nav.each do |f|
        unit = f.get_unit
        units[unit] = [] if !units[unit]
        units[unit] << f
      end
      units.each_value {|v| v.sort! {|a,b| a.get_lecture <=> b.get_lecture }}
      site.data["sidebar"]["folders"] = units.keys.sort.map do |i|
        {
          "title" => "Unit #{i}",
          "output" => "web",
          "folderitems" => units[i].map do |lecture|
            {
              "title" => "Lec #{lecture.get_lecture} - #{lecture.get_page_name}",
              "url" => lecture.get_nice_dest,
              "output" => "web"
            }
          end
        }
      end
    end

    def extract_directory(filepath)
      dir_match = filepath.match(/(.*\/)[^\/]*$/)
      if dir_match
        return dir_match[1]
      else
        return ''
      end
    end
  end

  class PagesDirPage < Page
    def initialize(site, base, dir, name, pagesdir)
      @site = site
      @base = base
      @dir = dir
      @name = name
      @_pages_dir = pagesdir

      process(name)
      read_yaml(File.join(base, pagesdir, dir), name)

      data.default_proc = proc do |hash, key|
        site.frontmatter_defaults.find(File.join(dir, name), type, key)
      end

      # Start non-default constructor
      puts "Processing #{site}"
      self.data["layout"] = 'page'

      # MathJax added to the page.
      self.data["math"] = true

      # TODO: set title
      process_images
      # End non-default constructor
      Jekyll::Hooks.trigger :pages, :post_init, self
    end

    # Get pretty name of page for nav.
    def get_page_name
      # TODO: Get from content.
      @name.match(/.*?-(.+)\./)[1]
    end

    def get_nice_dest
      p = Pathname.new('/')
      p.join(@dir, File.basename(@name, File.extname(@name))).to_s
    end

    def get_unit
      m = @name.match(/unit(\d+)/)[1]
      m.to_i
    end

    def get_type
      if @name =~ /unit\d+lec\d+/
        :lecture
      end
    end

    def get_lecture
      m = @name.match(/lec(\d+)/)[1]
      m.to_i
    end

    # Identify relative images and move to site assets folder.
    def process_images
      # Split "![alt text](url)" into ["![alt text](", "url", ")"]
      # TODO: handle properly escaped values, escaped ) and surrounded by <>
      imgRE = /(!\[.*?\]\()(.+?)(\))/
      new_content = ""
      pos = 0
      source_dir = Pathname.new(@dir)
      out_dir = Pathname.new("images")
      base_url = Pathname.new("{{site.baseurl}}")
      images = []
      while !(i = self.content.index(imgRE, pos)).nil?
        match = self.content.match(imgRE, i)
        url = match[2]
        path = Pathname.new(url)
        # Only replace relative URLs
        next if !path.relative?
        images << path
        new_url = base_url.join(out_dir, source_dir, url).cleanpath.to_s
        # TODO: normalize path to forward-slashes.
        new_image_link = match[1] + new_url + match[3]
        new_content += self.content[pos...i] + new_image_link
        
        pos = i + match[0].length
      end
      # Get any post-URL end content.
      new_content += match.post_match
      self.content = new_content

      file_source = Pathname.new(@_pages_dir).join(source_dir)
      # Add images to static files.
      images.each do |path|
        site.static_files << NoteImageFile.new(@site,
                                               @base,
                                               file_source.join(path).dirname.to_s,
                                               path.basename.to_s,
                                               out_dir.join(source_dir, path).dirname.to_s)
      end
    end
  end

  # Image file with custom out dir.
  class NoteImageFile < StaticFile
    def initialize(site, base, dir, name, dest)
      @_dest_dir = dest
      super(site, base, dir, name)
    end

    # Use our destination dir.
    def destination_rel_dir
      @_dest_dir
    end
  end
end
