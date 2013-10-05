user_home = "/home/" + node[:popHealth][:user]
ruby_version = node[:popHealth][:ruby_version]
rails_app_path = "/opt/popHealth"

package "libxml2-dev" do
  action :install
end

package "libxslt1-dev" do
  action :install
end

package "unison" do
  action :install
end

directory "/opt/popHealth" do
  owner node[:popHealth][:user]
  group node[:popHealth][:user]
  mode 755
  action :create
  recursive true
end

git "popHealth #{node[:popHealth][:branch]}" do
  repository "https://github.com/pophealth/popHealth.git"
  destination "/opt/popHealth"
  revision node[:popHealth][:branch]
  action :sync
end

directory "/data/db" do
  owner "ubuntu"
  group "ubuntu"
  mode 755
  action :create
  recursive true
end

ruby_block "setup-environment" do
  block do    
    ENV['RUBY_VERSION'] = "#{ruby_version}"
    ENV['RUBY_PATH'] = user_home + "/local/" + ENV['RUBY_VERSION']
    ENV['RUBY_BIN_PATH'] = ENV['RUBY_PATH'] + '/bin'
    ENV['RAILS_ENV'] = "production"
    ENV['PATH'] = ENV['RUBY_BIN_PATH'] + ":" + ENV['PATH']
  end
end



# Install make and compiler required by passenger-install
package "build-essential" do
  action :install
end

bash "setup-ruby" do
  user node[:popHealth][:user]
  cwd rails_app_path
  code <<-EOF
    ruby-build $RUBY_VERSION $RUBY_PATH
    echo "export PATH=\"$RUBY_BIN_PATH:\\$PATH\"" >> #{user_home}/.bashrc
    sudo chown #{node['popHealth']['user']} . -R
    gem install bundler --no-rdoc --no-ri
    gem install passenger -v #{node[:popHealth]['passenger-version']} --no-rdoc --no-ri
    gem install rake --no-ri --no-rdoc
  EOF
end

bash "setup-popHealth" do
  user node[:popHealth][:user]
  cwd rails_app_path
  code <<-EOH
    bundle install --deployment --without development test
    bundle exec rake db:create
    bundle exec rake db:schema:load
    bundle exec rake db:seed
    bundle exec rake assets:precompile
    rm -f db/seeds.rb
  EOH
end

# Required for passenger-install-nginx-module
package "libcurl4-openssl-dev" do
  action :install
end

bash "passenger-install-nginx-module" do
  user "root"
  cwd user_home
  code <<-EOH
    passenger-install-nginx-module --auto --auto-download --prefix=/opt/nginx
  EOH
end

bash "setup-ssl" do
  user "root"
  cwd "/opt/nginx/conf"
  code <<-EOH
    # generate the keys 
    ssh-keygen -q -t rsa -N "" -f popHealth.key

    openssl req -new -key popHealth.key -batch -out popHealth.csr
    openssl x509 -req -days 365 -in popHealth.csr -signkey popHealth.key -out popHealth.crt
    
    # remove csr
    rm popHealth.csr
    sudo chmod 600 /opt/nginx/conf/popHealth.{key,crt}
  EOH
end

ruby_block "create /opt/nginx/conf/nginx.conf from template" do
  block do
    res = Chef::Resource::Template.new "/opt/nginx/conf/nginx.conf", run_context
    res.source "nginx.conf.erb"
    res.cookbook cookbook_name.to_s
    res.variables(
      passenger_root: "#{ENV["RUBY_PATH"]}/lib/ruby/gems/1.9.1/gems/passenger-#{node[:popHealth]["passenger-version"]}",
      passenger_ruby: "#{ENV["RUBY_PATH"]}/bin/ruby",
      root: "#{rails_app_path}/public"
    )
    res.run_action :create
  end
end

bash "setup_ssh_config" do
  user node[:popHealth][:user]
  cwd user_home
  code "echo 'StrictHostKeyChecking no' >> .ssh/config"
end


cookbook_file "/etc/init.d/nginx" do
  source "init_d_script"
  mode 0755
end

cookbook_file "/etc/logrotate.d/popHealth" do
  source "logrotate"
  owner "root"
  group "root"
  mode 0644
end

service "nginx" do
  supports :start => true, :stop => true, :restart => true
  action [:enable, :start]
end

service "mongod" do
  supports :start => true, :stop => true, :restart => true
  action [:enable, :start]
end
