module GPTK
  CONFIG = {
    # Typically something like /path-to-app/views/main/index.html.erb
    rails_files: %W[
      #{ENV['HOME']}/bitbucket/scriptoria-web/app/views/main/index.html.erb
      #{ENV['HOME']}/bitbucket/scriptoria-web/app/assets/stylesheets/application.css.sass
    ].concat(Dir.glob("#{ENV['HOME']}/bitbucket/scriptoria-web/app/assets/javascripts/**/*.coffee"))
  }.freeze
end
