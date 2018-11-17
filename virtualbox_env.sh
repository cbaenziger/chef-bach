#!/bin/bash
# Source this file at the top of your script when needing VBoxManage or Vagrant
# e.g.,
# source ./virtualbox_env.sh

# A function to check two versions and determine if one is equal to or higher than
# another
# Arguments:
#   MIN_VERSiON - a minimum semantic version string
#   CHECK_VERSION - the semantic version string to check
# Note: Versions should be parseable by RubyGem's Gem::Version
# Returns:
#   Will print to standard out if version string is less than the minimum

function check_version {
  local min_version=$1
  local my_version=$2
  local version_check=$(ruby -e "puts Gem::Version.new('$my_version') >= Gem::Version.new('$min_version')")

  if ! $version_check
  then
    echo "ERROR: $my_version is less than $min_version.x!\n"
    echo "  Only versions >= $min_version.x are officially supported."
  fi
}

# A function to check that Vagrant is installed as expected
# Will return 1 on failure
# Will set $VBM to the VBoxManage binary on success
function check_vagrant {
  if ! command -v vagrant >& /dev/null; then
    echo "vagrant not found!" >&2
    echo "  Please ensure vagrant is installed and vagrant is on your PATH." >&2
    return 1 
  fi

  local my_version=$(vagrant --version | sed 's/.* //')
  local version_check=$(check_version 2 $my_version 2>&1)
  if [[ -n "$version_check" ]]; then
    echo 'Vagrant version check failed!' >&2
    echo -e "$version_check" >&2
    return 1
  fi

  export VAGRANT=vagrant
}

# A function to check that VirtualBox is installed as expected
# Will return 1 on failure
# Will set $VAGRANT to the vagrant binary on success
function check_virtualbox {
  if ! command -v VBoxManage >& /dev/null; then
    echo "VBoxManage not found!" >&2
    echo "  Please ensure VirtualBox is installed and VBoxManage is on your PATH." >&2
    return 1
  fi

  local my_version=$(VBoxManage --version | perl -ne 'm/(\d\.\d)\./; print "$1"')

  local version_check=$(check_version 4.3 $my_version 2>&1)
  if [[ -n "$version_check" ]]; then
    echo 'VirtualBox version check failed!' >&2
    echo -e "$version_check" >&2
    return 1
  fi

  export VBM=VBoxManage
}

if [[ -z "$VAGRANT" ]]; then
  check_vagrant
fi

if [[ -z "$VBM" ]]; then
  check_virtualbox
fi

unset -f check_version check_vagrant check_virtualbox
