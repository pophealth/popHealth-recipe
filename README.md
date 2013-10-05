## About

This recipe is designed to make it easier to deploy popHealth in a safe way. It enables SSL Encryption by default. While it uses a self signed certificate it is fairly simple to replace this certificate with an actual one. 

### What it doesn't do:
- It will not download and import the measure bundle (see section on Importing Measure Bundle below)
- It will not set up proxy settings
- Does not configure networking 
- Does not create any users

## Installation Options
This recipe can be used to build an instance of popHealth in a couple ways. 

### Chef-Solo
Chef-Solo is branch of Chef that is designed to run only on a local machine. The easiest method of installation is to use our installer script:

    curl -L https://raw.github.com/rbclark/popHealth-recipe/multiple-branch-pull/install.sh > popHealth-install.sh
    chmod +x popHealth-install.sh
    sudo ./popHealth-install.sh

This will install chef-solo, along with popHealth and any additional dependencies.

If you need to check out a different branch of the popHealth code, then instead of the final command above, run:

    sudo ./popHealth-install.sh -b <name-of-branch>

### Chef-Client

If you have a chef-server set up on your network this recipe makes it fairly simple to deploy an instance of popHealth. Simply add all of the dependencies above as recipes for your chef-server (ask whoever manages your chef-server to do this) and ensure they are uploaded. Then you can bootstrap a node for popHealth using

    knife bootstrap -x [user] --sudo -N popHealth -r "apt,git,ruby-build,mongodb-10gen,popHealth" --no-host-key-verify [IP or FQDN]

You will be prompted for a password (you may also pass a -i with a path to an ssh key) and it will deploy. 

