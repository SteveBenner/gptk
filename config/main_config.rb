module GPTK
  CONFIG = {
    # Typically something like /path-to-app/views/main/index.html.erb
    rails_files_1: %W[
      #{ENV['HOME']}/bitbucket/scriptoria-web/app/views/main/index.html.erb
      #{ENV['HOME']}/bitbucket/scriptoria-web/app/assets/stylesheets/application.css.sass
    ].concat(Dir.glob("#{ENV['HOME']}/bitbucket/scriptoria-web/app/assets/javascripts/**/*.coffee")),
    rails_files_2: %W[
      #{ENV['HOME']}/bitbucket/scriptoria-web-1/app/views/main/index.html.erb
      #{ENV['HOME']}/bitbucket/scriptoria-web-1/app/assets/stylesheets/application.css.sass
    ].concat(Dir.glob("#{ENV['HOME']}/bitbucket/scriptoria-web-1/app/assets/javascripts/**/*.coffee")),
    rails_files_3: %W[
      #{ENV['HOME']}/bitbucket/scriptoria-web-2/app/views/main/index.html.erb
      #{ENV['HOME']}/bitbucket/scriptoria-web-2/app/assets/stylesheets/application.css.sass
    ].concat(Dir.glob("#{ENV['HOME']}/bitbucket/scriptoria-web-2/app/assets/javascripts/**/*.coffee"))
  }.freeze
end
