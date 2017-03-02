= Contributing =

To propose changes to Chef-BACH, please fork the [GitHub repo](https://github.com/bloomberg/chef-bach)
and issue a pull request with your proposed change.

= automated_install =

Our full integration test is run via [tests/automated_install.sh](./tests/automated_install.sh). The following user-modifiable settings are available:
* BOOTSTRAP_VM_MEM -- Quantitiy of memory to offer the bootstrap (infrastructure) VM
* BOOTSTRAP_VM_CPUs -- Quantitiy of virtual CPU's to offer the bootstrap (infrastructure) VM
* CLUSTER_VM_MEM -- Quantitiy of memory to offer each cluster VM
* CLUSTER_VM_CPUs -- Quantitiy of virtual CPU's to offer each cluster VM
* CLUSTER_TYPE -- The cluster type to build: `Hadoop` or `Kafka`

The automated_install process has the following workflow:
# Copy stub files into a cluster directory (NOTE: this lives one directory below the Git repository in a directory called `cluster`)
# From our [vbox_create.sh](./vbox_create.sh) library
  # `download_VM_files` -- necessary Vagrant files to start bootstrap VM
  # `create_bootstrap_VM` -- start-up and install the bootstrap VM to have a working Chef, PXE-boot server
  # `create_cluster_VMs` -- build each VirtaulBox VM and all virtual networks for our VM installation
  # `install_cluster` -- this largely runs our [boostrap_chef.sh](./bootstrap_chef.sh) script and coarsely verifies success:
    # `rsync`'s the repositories files to the bootstrap VM (including the `cluster` directory of Chef environment, roles and cluster.txt)
    # Runs our [build_bins.sh](./build_bins.sh) script which:
      # Downloads and installs ChefDK on the bootstrap VM
      # Run's the [bach_repository](./cookbooks/bach_repository/README.md) cookbook
    # Runs our [setup_chef_server.sh](./setup_chef_server.sh) script which:
      # Adds a local apt repository created by `build_bins.sh`
      # Installs the Chef client Debian package from the loacl repository
      # Installs the Chef server Debian package from the loacl repository
      # Configures `/etc/chef-server/chef-server.rb`
      # Copies the `vagrant` user SSH `authorized_keys` file to `root`'s
    # Runs our [setup_chef_cookbooks.sh](./setup_chef_cookbooks.sh) script which:
      # Creates and populates our `~vagrant/chef-bcpc/.chef/knife.rb` file
      # Runs Berkshelf to populate `~vagrant/chef-bcpc/vendor/cookbooks`
    # Uploads the Chef cookbooks, environment and roles to the Chef Server
    # Runs our [setup_chef_bootstrap_node.sh](./setup_chef_bootstrap_node.sh) script which:
      # Creates the bootstrap VM Chef client and node objects (and makes it a Chef admin)
      # Runs `recipe[`[`bcpc::apache-mirror`](./cookbooks/bcpc/recipes/apache-mirror.rb)`]`
      # Runs `recipe[`[`bcpc::chef_vault_install`](./cookbooks/bcpc/recipes/chef_vault_install.rb)`]`
      # Runs `recipe[`[`bcpc::chef_poise_install`](./cookbooks/bcpc/recipes/chef_poise_install.rb)`]`
      # Runs `role[`[`BCPC-Bootstrap`](./stub-environment/roles/BCPC-Bootstrap.json)`]`
      # Runs `recipe[`[`bach_repository::apt`](./cookbooks/bach-repository/recipes/apt.rb)`]`
# Then we populate inital Gems from our [GEMFILE](./GEMFILE) using `bundler`
# We snapshot all VM's at this point in snapshot `Shoe-less`
# See further steps under the [Snapshots](#Snapshots) section

== Snapshots ==
Snapshots are created as the system is setup to allow for rolling back to the last successful step for one to try a modification and re-run. Snapshots are:
=== Shoe-less ===
This snapshot is created once we have setup the bootstrap node to have all necessary pre-built and stashed binaries, a working Chef-Server and via Chef has a working PXE boot server to install the OS on the cluster VM's.
=== Post-Cobble ===
This snapshot is once the cluster VM's have been enrolled in Cobbler and have been installed with a blank OS -- no Chef objects have been created for them yet.
=== Post-Basic ===
This is after the `cluster-assign-roles.sh <environment> basic` operation has completed. No Hadoop components should be installed at this stage. Initial OS configuration and Chef object creation is all that should have been done at this phase.
=== Post-Bootstrap ===
This is after the `cluster-assign-roles.sh <environment> bootstrap` operation has completed. Here Hadoop head nodes have been setup. However, no services are yet usable. This is a shim-step to allow us to go directly into an HA HDFS cluster without having to go through an intermediate non-HA HDFS deployment.
=== Post-Install ===
This is after the `cluster-assign-roles.sh <environment> <cluster type>` operation has completed. Here all services have been deployed and should be running on all VM's.

= Tests =
There are many tests in Chef-BACH. We have unit-tests, functional tests and integration tests -- yet as with all codebases we don't have enough tests! Here's how to run some of our tests:

This process is to run tests using ChefDK. It is also possible to run using purely Gems potentially too. (Some day we will even have a Rakefile for all this...)

== Rspec/ChefSpec ==
* Run the following on the bootstrap VM or install necessary Debian packages to install all necessary Gems (e.g. mysql, augeas, etc.)
* `export PATH=/opt/chefdk/embedded/bin:$PATH`
* `export PKG_CONFIG_PATH=/usr/lib/pkgconfig:/usr/lib/x86_64-linux-gnu/pkgconfig:/usr/share/pkgconfig`
* `cd ~vagrant/chef-bcpc`
* `source proxy_setup.sh`
* `bundler install --path vendor/bundle`
* `bundler exec rspec`
* `for c in cookbooks/*; do pushd $c; bundler install --path vendor/bundle && bundler exec rspec || echo "Failed in $c" 1>&2 ; popd; done`

== Test-Kitchen ==
* `export PATH=/opt/chefdk/embedded/bin:$PATH`
* `kitchen verify`
* `for c in cookbooks/*; do pushd $c; kitchen verify || echo "Failed in $c" 1>&2 ; popd; done

== Integration Tests ==
Run `tests/automated_install.sh` for both `Hadoop` and `Kafka` cluster types

= Style Idioms =

Libraries:
* [Chef Library Recommendations](https://www.chef.io/blog/2014/03/12/writing-libraries-in-chef-cookbooks/)

All Chef Code:
* [TomDoc](http://tomdoc.org/)

Static Code Analysis:
* Warnings not increased:
  * [RuboCop](http://batsov.com/rubocop/)
  * [Foodcritic](http://acrmp.github.io/foodcritic/)
    * [Etsy rules](https://github.com/etsy/foodcritic-rules)
    * [CustomInk rules](https://github.com/customink-webops/foodcritic-rules)
* Markup Verified With:
  * JSON: `python -m json.tool <json files>`
  * XML: `xmllint --format <xml files>`
  * ERB: `erb -P -x -T '-' <erb file> | ruby -c`

Otherwise generally follow [bbatsov/ruby-style-guide](https://github.com/bbatsov/ruby-style-guide)

For shell scripts:
* Do not write shell scripts
* If you must, please try to follow [Google's Shell Style Guide](https://google.github.io/styleguide/shell.xml)

The GitHub workflow we follow is captured below:
![Flow Chart of GitHub Workflow from Issue or PR created to PR in progress and Code Review to Issue or PR resolved][gh_workflow]

[gh_workflow]: https://github.com/bloomberg/chef-bach/blob/pages/readme-images/GitHub%20Workflow.png "GitHub process captured in yWorks yEd flow-chart"
[bach_deployments]: https://github.com/bloomberg/chef-bach/blob/pages/readme-images/BACH%20Deployment%20Types.png "BACH deployment options in yWorks y
