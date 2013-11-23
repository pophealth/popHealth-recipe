#!/bin/bash 

if [ "$(id -u)" != "0" ]; then
  echo "Please run again with sudo privileges." 1>&2
  exit 1
fi

usage() { echo "Usage: $0 [-b <branch>]" 1>&2; exit 1; }

while getopts ":b:h:" o; do
  case "${o}" in
    b)
      branch=${OPTARG}
      ;;
    *)
      usage
     ;;
  esac
done

cd /tmp

# First, check to see if the command chef solo exists, if not download and install chef.
if ! command -v chef-solo >/dev/null 2>&1; then
  echo "Chef not found, downloading and installing now..."
  curl -L https://opscode.com/chef/install.sh > chef-install.sh
  chmod +x chef-install.sh
  ./chef-install.sh
fi

if command -v git >/dev/null 2>&1; then
  echo "Git is installed, nothing to do here!"
elif command -v apt-get >/dev/null 2>&1; then
  echo "Installing git via apt..."
  apt-get install -y git
elif command -v yum >/dev/null 2>&1; then
  echo "Installing git via yum..."
  yum install -y git
else
  echo "Git is not installed and we do not know how to install it for your platform. Please install git and run this program again." 1>&2
  exit 1
fi

if [ ! -d "/tmp/cookbooks" ]; then # We will not clone recipes again if the cookbooks directory already exists.
  mkdir /tmp/cookbooks
  cd /tmp/cookbooks
  
  git clone https://github.com/opscode-cookbooks/build-essential.git
  git clone https://github.com/opscode-cookbooks/dmg.git
  git clone https://github.com/opscode-cookbooks/runit.git
  git clone https://github.com/opscode-cookbooks/windows.git
  git clone https://github.com/opscode-cookbooks/chef_handler.git
  git clone https://github.com/higanworks-cookbooks/mongodb-10gen.git
  git clone https://github.com/opscode-cookbooks/apt.git
  git clone https://github.com/opscode-cookbooks/git.git
  git clone https://github.com/fnichol/chef-rvm.git rvm
  git clone https://github.com/opscode-cookbooks/sudo.git
  git clone https://github.com/hw-cookbooks/chef_gem.git
  git clone https://github.com/opscode-cookbooks/yum.git
  git clone https://github.com/opscode-cookbooks/fail2ban.git
  git clone https://github.com/opscode-cookbooks/firewall.git
  git clone https://github.com/opscode-cookbooks/apache2.git
  git clone https://github.com/opscode-cookbooks/unicorn.git
  git clone https://github.com/opscode-cookbooks/logrotate.git
  git clone https://github.com/schreiaj/popHealth-recipe.git popHealth # remove this when debugging the recipe
  # cp -r /vagrant /tmp/cookbooks/popHealth # Use for debugging with Vagrant
fi

cd /tmp

tar -cvzf cookbooks.tar.gz cookbooks/

if [ $branch ]; then
  echo '{"popHealth":{"branch" : "'$branch'"}}' > node.json
  chef-solo -r /tmp/cookbooks.tar.gz -o "apt,git,popHealth" -j /tmp/node.json
else
  chef-solo -r /tmp/cookbooks.tar.gz -o "apt,git,popHealth"
fi