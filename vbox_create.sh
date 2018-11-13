#!/bin/bash -e

# bash imports
source ./virtualbox_env.sh

set -x

if !hash ruby 2> /dev/null ; then
  echo 'No ruby in path!'
  exit 1
fi

if [[ -f ./proxy_setup.sh ]]; then
  . ./proxy_setup.sh
fi
# CURL is exported by proxy_setup.sh
if [[ -z "$CURL" ]]; then
  echo 'CURL is not defined'
  exit 1
fi

# BOOTSTRAP_NAME is exported by automated_install.sh
if [[ -z "$BOOTSTRAP_NAME" ]]; then
  echo 'BOOTSTRAP_NAME is not defined'
  exit 1
fi

# Bootstrap VM Defaults (these need to be exported for Vagrant's Vagrantfile)
export BOOTSTRAP_VM_MEM=${BOOTSTRAP_VM_MEM-2048}
export BOOTSTRAP_VM_CPUs=${BOOTSTRAP_VM_CPUs-1}
# Use this if you intend to make an apt-mirror in this VM (see the
# instructions on using an apt-mirror towards the end of bootstrap.md)
# -- Vagrant VMs do not use this size --
#BOOTSTRAP_VM_DRIVE_SIZE=120480

# Is this a Hadoop or Kafka cluster?
# (Kafka clusters, being 6 nodes, will require more RAM.)
export CLUSTER_TYPE=${CLUSTER_TYPE:-Hadoop}

# Cluster VM Defaults
export CLUSTER_VM_MEM=${CLUSTER_VM_MEM-2048}
export CLUSTER_VM_CPUs=${CLUSTER_VM_CPUs-1}
export CLUSTER_VM_DRIVE_SIZE=${CLUSTER_VM_DRIVE_SIZE-20480}

# Gather override_attribute bcpc/cluster_name or an empty string
environments=( ./environments/*.json )
if (( ${#environments[*]} > 1 )); then
  echo 'Need one and only one environment in environments/*.json; got: ' \
       "${environments[*]}" >&2
  exit 1
fi

# The root drive on cluster nodes must allow for a RAM-sized swap volume.
CLUSTER_VM_ROOT_DRIVE_SIZE=$((CLUSTER_VM_DRIVE_SIZE + CLUSTER_VM_MEM - 2048))

VBOX_DIR="`dirname ${BASH_SOURCE[0]}`/vbox"
[[ -d $VBOX_DIR ]] || mkdir $VBOX_DIR
VBOX_DIR_PATH=`python -c "import os.path; print os.path.abspath(\"${VBOX_DIR}/\")"`

# Populate the VM list array from cluster.txt
code_to_produce_vm_list="
require './lib/cluster_data.rb';
include BACH::ClusterData;
cp=ENV.fetch('BACH_CLUSTER_PREFIX', '');
cp += '-' unless cp.empty?;
vms = parse_cluster_txt(File.readlines('cluster.txt'))
puts vms.map{|e| cp + e[:hostname]}.join(' ')
"
export VM_LIST=( $(/usr/bin/env ruby -e "$code_to_produce_vm_list") )

######################################################
# Function to download files necessary for VM stand-up
#
function download_VM_files {
  pushd $VBOX_DIR_PATH

  # Can we create the bootstrap VM via Vagrant
  if [[ ! -f xenial-server-cloudimg-amd64-vagrant-disk1.box ]]; then
    $CURL -o xenial-server-cloudimg-amd64-vagrant-disk1.box http://cloud-images.ubuntu.com/xenial/current/xenial-server-cloudimg-amd64-vagrant.box
  fi
  popd
}

################################################################################
# Function to snapshot VirtualBox VMs
# Argument: name of snapshot to take
# Post-Condition: If snapshot did not previously exist for VM: VM snapshot taken
#                 If snapshot previously exists for that VM: Nothing for that VM
function snapshotVMs {
  local snapshot_name="$1"
  printf "Snapshotting ${snapshot_name}\n"
  for vm in ${VM_LIST[*]} ${BOOTSTRAP_NAME}; do
    $VBM snapshot $vm list --machinereadable | grep -q "^SnapshotName.*=\"${snapshot_name}\"\$" || \
      $VBM snapshot $vm take "${snapshot_name}" &
  done
  wait && printf "Done Snapshotting\n"
}

################################################################################
# Function to enumerate VirtualBox hostonly interfaces
# in use from VM's.
# Argument: name of an associative array defined in calling context
# Post-Condition: Updates associative array provided by name with keys being
#                 all interfaces in use and values being the number of VMs on
#                 each network
function discover_VBOX_hostonly_ifs {
  # make used_ifs a typeref to the passed-in associative array
  local -n used_ifs=$1
  for net in $($VBM list hostonlyifs | grep '^Name:' | sed 's/^Name:[ ]*//'); do
    used_ifs[$net]=0
  done
  for vm in $($VBM list vms | sed -e 's/^[^{]*{//' -e 's/}$//'); do
    ifs=$($VBM showvminfo --machinereadable $vm | \
      egrep '^hostonlyadapter[0-9]*' | \
      sed -e 's/^hostonlyadapter[0-9]*="//' -e 's/"$//')
    for interface in $ifs; do
      used_ifs[$interface]=$((${used_ifs[$interface]} + 1))
    done
  done
}

###################################################################
# Function to create the bootstrap VM
#
function create_bootstrap_VM {
  pushd $VBOX_DIR_PATH

  echo "Vagrant detected - using Vagrant to initialize bcpc-bootstrap VM"
  cp ../Vagrantfile .

  if [[ -f ../Vagrantfile.local.rb ]]; then
      cp ../Vagrantfile.local.rb .
  fi

  if [[ ! -f insecure_private_key ]]; then
    # Ensure that the private key has been created by running vagrant at least once
    $VAGRANT status
    cp $HOME/.vagrant.d/insecure_private_key .
  fi
  $VAGRANT up
  popd
}

###################################################################
# Function to create the BCPC cluster VMs
#
function create_cluster_VMs {
  # update cluster.txt to include BACH_CLUSTER_PREFIX in cluster.txt
  ./vm-to-cluster.sh

  $VAGRANT status
  pushd $VBOX_DIR_PATH
  for vm in ${VM_LIST[*]}; do
    $VAGRANT up $vm &
  done
  wait
  popd
}

###################################################################
# Function to setup the bootstrap VM
# Assumes cluster VMs are created
#
function install_cluster {
  environment=${1-Test-Laptop}
  ip=${2-10.0.100.3}
  echo "Bootstrap complete - setting up Chef server"
  echo "N.B. This may take approximately 30-45 minutes to complete."
  $VAGRANT ssh -c 'sudo rm -f /var/chef/cache/chef-stacktrace.out'
  ./bootstrap_chef.sh --vagrant-remote $ip $environment
  if $VAGRANT ssh -c 'sudo egrep -i "LoadError: cannot load such file -- cluster_def|no_lazy_load|404 \"Not Found\"" /var/chef/cache/chef-stacktrace.out'; then
      $VAGRANT ssh -c 'sudo rm /var/chef/cache/chef-stacktrace.out' 
  elif $VAGRANT ssh -c 'test -e /var/chef/cache/chef-stacktrace.out' || \
      ! $VAGRANT ssh -c 'test -d /etc/chef-server'; then
    echo '========= Failed to Chef!' >&2
    exit 1
  fi
}

# only execute functions if being run and not sourced
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  download_VM_files
  create_bootstrap_VM
  create_cluster_VMs
  install_cluster
fi
