module GPTK
  CONFIG = {
    rails: { # MUST be absolute file paths
      # Typically something like /path-to-app/views/main/index.html.erb
      erb_file_path: "#{ENV['HOME']}/bitbucket/scriptoria-web/app/views/main/index.html.erb",
      sass_file_path: "#{ENV['HOME']}/bitbucket/scriptoria-web/app/assets/stylesheets/application.css.sass",
      coffeescript_file_path: "#{ENV['HOME']}/bitbucket/scriptoria-web/app/assets/javascripts/application.js.coffee"
    }
  }.freeze
end
