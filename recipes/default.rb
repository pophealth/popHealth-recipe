package "ca-certificates" do
  action [:purge, :install]
end

include_recipe "mongodb-10gen::single"
include_recipe "rvm::system_install"

user_home = "/home/" + node[:popHealth][:user]
ruby_version = node[:popHealth][:ruby_version]
rails_app_path = user_home + "/popHealth"
bundle_gem_path = "/usr/local/rvm/gems/ruby-#{node[:popHealth][:ruby_version]}"
install_params = "--deployment --without develop test" if node[:popHealth][:environment] == "production"
apache_dir = "/etc/apache2"

user node[:popHealth][:user] do
  supports :manage_home => true
  gid "rvm"
  comment "#{node[:popHealth][:user]} User"
  home "/home/" + node[:popHealth][:user]
  shell "/bin/bash"
  action :create
end

sudo node[:popHealth][:user] do
  user node[:popHealth][:user] 
  nopasswd true
end

rvm_default_ruby node[:popHealth][:ruby_version] do
  action :create
end

rvm_gem "bundler" do
  ruby_string node[:popHealth][:ruby_version]
  action :install
end

rvm_gem "chef" do
  ruby_string node[:popHealth][:ruby_version]
  action :install
end

%w{openssl libssl-dev libreadline6 libreadline6-dev curl zlib1g zlib1g-dev libyaml-dev libsqlite3-dev sqlite3 libxslt-dev autoconf libc6-dev ncurses-dev automake libtool bison subversion pkg-config libxml2-dev libxslt1-dev unison build-essential}.each do |pkg|
  package pkg do
    action :install
  end
end

# Passenger Dependencies
%w{libcurl4-openssl-dev apache2-mpm-prefork apache2-prefork-dev libapr1-dev libaprutil1-dev}.each do |pkg|
  package pkg do
    action :install
  end
end

rvm_gem "passenger" do
  ruby_string node[:popHealth][:ruby_version]
  version node[:popHealth][:passenger_version]
  action :install
end

directory rails_app_path do
  owner node[:popHealth][:user]
  group node[:popHealth][:user]
  mode 0755
  action :create
  recursive true
end

git "clone popHealth #{node[:popHealth][:branch]}" do
  user node[:popHealth][:user]
  repository node[:popHealth][:git_repository]
  destination rails_app_path
  revision node[:popHealth][:branch]
  action :sync
end

directory "/data/db" do
  owner node[:popHealth][:user]
  group node[:popHealth][:user]
  mode 0755
  action :create
  recursive true
end

rvm_shell "passenger_module" do
  code "passenger-install-apache2-module --auto"
end

# Fixes issue where changing ruby version causes bundler to throw a permissions error.
directory bundle_gem_path do
  mode 0775
end

template "#{rails_app_path}/config/popHealth.yml" do
  source "pophealth-config.yml.erb"
  variables({
    :app_config => node[:popHealth][:app_config],
    :environment => node[:popHealth][:environment]
  })
  helpers do
    def generate_yaml(config,num)
      config_elements = YAML::dump(config).split("\n") # Dump yaml and then convert into an array.
      config_elements.shift # Remove first element from the array.
      config_elements.map! { |a| " "*num + a } # Indent results.
      result = config_elements.join("\n") # Convert results back into a string.
      result.sub("!ruby/hash:Chef::Node::ImmutableMash","") # Remove unwanted text from the string and return.
    end
  end
end

rvm_shell "run bundle install" do 
  cwd rails_app_path
  ruby_string node[:popHealth][:ruby_version]
  code "RAILS_ENV=#{node[:popHealth][:environment]} bundle install --path #{bundle_gem_path} #{install_params}"
  user node[:popHealth][:user]
  group "rvm"
end

rvm_shell "seed database" do 
  cwd rails_app_path
  ruby_string node[:popHealth][:ruby_version]
  code "bundle exec rake db:seed RAILS_ENV=#{node[:popHealth][:environment]}"
  user node[:popHealth][:user]
end

template "#{apache_dir}/sites-available/pophealth" do
  source "pophealth-sites-available.conf.erb"
  variables({
    :pophealth_root => rails_app_path + "/public",
    :pophealth_env => node[:popHealth][:environment]
  })
end

link "#{apache_dir}/sites-enabled/000-default" do
  to "#{apache_dir}/sites-available/pophealth"
end

template "#{apache_dir}/mods-available/pophealth.conf" do
  source "pophealth-mods-available.conf.erb"
  variables({
    :mod_passenger => "/usr/local/rvm/gems/ruby-#{node[:popHealth][:ruby_version]}/gems/passenger-#{node[:popHealth][:passenger_version]}/buildout/apache2/mod_passenger.so",
    :passenger_root => "/usr/local/rvm/gems/ruby-#{node[:popHealth][:ruby_version]}/gems/passenger-#{node[:popHealth][:passenger_version]}",
    :passenger_ruby => "/usr/local/rvm/wrappers/ruby-#{node[:popHealth][:ruby_version]}/ruby"
  })
end

link "#{apache_dir}/mods-enabled/pophealth.conf" do
  to "#{apache_dir}/mods-available/pophealth.conf" 
end

template "#{apache_dir}/httpd.conf" do
  source "httpd.conf.erb"
  variables({
    :servername => node[:popHealth][:servername]
  })
end

rvm_shell "precompile assets" do 
  cwd rails_app_path
  ruby_string node[:popHealth][:ruby_version]
  code "bundle exec rake assets:precompile RAILS_ENV=#{node[:popHealth][:environment]}"
  user node[:popHealth][:user]
  only_if { node[:popHealth][:environment].eql? "production" }
end

service "apache2" do
  supports :start => true, :stop => true, :restart => true
  action [:enable, :restart]
end

include_recipe "popHealth::cron" if node[:popHealth][:enable_cron]
