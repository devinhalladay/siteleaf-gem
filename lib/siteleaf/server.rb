module Siteleaf
  class Server
    attr_accessor :site_id
    
    def initialize(attributes = {})
      self.site_id = attributes[:site_id]
    end
    
    def resolve_template(url = "/")
      path = url.gsub(/\/\z|\A\//, '') #strip beginning and trailing slashes
      paths = path.split("/")
      templates = []
    
      if path == ""
        templates.push("index.html")
      else
        templates.push("#{paths.join('/')}.html")
        templates.push("#{paths.join('/')}/index.html")
        templates.push("#{paths.join('/')}/default.html")
        while paths.size > 0
          paths.pop
          templates.push("#{paths.join('/')}/default.html") if paths.size > 0
        end
      end
      templates.push("default.html")
      
      templates.each do |t|
        return File.read(t) if File.exists?(t)
      end
      
      return nil
    end
     
    def call(env)
      site = Siteleaf::Site.new({:id => self.site_id})
      
      url = env['PATH_INFO']
      path = url.gsub(/\/\z|\A\//, '') #strip beginning and trailing slashes
      
      if !File.directory?(path) and File.exists?(path)
        Rack::File.new(Dir.pwd).call(env)
      else
        template_data = nil
        is_asset = /(^assets|\.)/.match(path)
        
        if is_asset 
          if asset = site.resolve(url) and asset_url = asset['file']['url']
            require 'open-uri'
            output = open(asset_url)
            [200, {'Content-Type' => output.content_type}, [output.read]]
          end
        else
          if template_data = resolve_template(url)
            # compile liquid includes into a single page
            include_tags = /\{\%\s+include\s+['"]([A-Za-z0-9_\-\/]+)['"]\s+\%\}/
            while include_tags.match(template_data)
              template_data = template_data.gsub(include_tags) { |i| File.read("_#{$1}.html") }
            end
          end
        
          output = site.preview(url, template_data)
          [200, {'Content-Type' => output.headers[:content_type]}, [output]]
        end
      end
    end
  end
end