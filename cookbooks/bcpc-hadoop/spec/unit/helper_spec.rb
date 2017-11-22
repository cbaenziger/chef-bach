require 'spec_helper'

describe Bcpc_Hadoop::Helper do
  describe '#hdfs_disk_type' do
    let(:dummy_class) do
      Class.new do
        include Bcpc_Hadoop::Helper
      end
    end

    # load a bcpc-hadoop recipe to test cookbook attributes cover business rules
    let(:chef_run) do
      ChefSpec::SoloRunner.new do |node|
        Fauxhai.mock(platform: 'ubuntu', version: '12.04')
        SET_ATTRIBUTES.call(node)
        node.set['filesystem'] = {
          "/dev/does_not_exist": {
            "mount": "/broken"
          },
          "/dev/sda": {
            "mount": "/disk/0"
          },
          "/dev/sdb": {
            "kb_size": "780995840",
            "kb_used": "4050140",
            "kb_available": "776945700",
            "percent_used": "1%",
            "mount": "/disk/1",
            "total_inodes": "781377536",
            "inodes_used": "73",
            "inodes_available": "781377463",
            "inodes_percent_used": "1%",
            "fs_type": "xfs",
            "mount_options": [
              "rw",
              "noatime",
              "nodiratime",
              "inode64"
            ]
          }
          "/dev/sdc": {
            "mount": "/disk/2"
          },
        }
        node.set['block_device'] = {
          "sda": {
            "vendor": "Missing Rotational Attribute"
          },
          "sdb": {
            "size": "1562758832",
            "removable": "0",
            "model": "LOGICAL VOLUME",
            "rev": "8.00",
            "state": "running",
            "timeout": "30",
            "vendor": "CrazyClay'sDiscountSSDs",
            "queue_depth": "14",
            "rotational": "0",
            "physical_block_size": "4096",
            "logical_block_size": "512"
          }
          "sdc": {
            "vendor": "CrazyClay'sDiscountHHDs",
            "rotational": "1"
          },
        }
    end
    let(:node) { chef_run.node }

    context '#hdfs_disk_type' do
      it 'reports SSDs correctly' do
        expect(dummy_class.new.hdfs_disk_type('/disk/1').to eq("SSD")
      end

      it 'reports HDDs correctly' do
        expect(dummy_class.new.hdfs_disk_type('/disk/2')}.to eq("HDD")
      end

      it 'logs for no rotational information' do
        expect(dummy_class.new.hdfs_disk_type('/disk/0')}.to eq("HDD")
        # verify log!
      end

      it 'raises for unfound mount points' do
        expect{dummy_class.new.hdfs_disk_type('/does_not_exist')}.to \
          raise_error(RuntimeError, /Failed to find a device for mount/)
      end

      it 'raises for unfound device' do
        expect{dummy_class.new.hdfs_disk_type('/broken')}.to \
          raise_error(RuntimeError, /Failed to find block device info/)
      end
    end
  end

  describe '#hwx_pkg_str' do
    let(:dummy_class) do
      Class.new do
        include Bcpc_Hadoop::Helper
      end
    end

    raw_version = '1.2.3.4-1234'
    hyphenated_version = '1-2-3-4-1234'

    context '#hwx_pkg_str' do

      it 'inserts version at end of short package name' do
        expect(dummy_class.new.hwx_pkg_str('foobar', raw_version)).to eq("foobar-#{hyphenated_version}")
      end

      it 'inserts version at frist hyphen of hyphenated package' do
        expect(dummy_class.new.hwx_pkg_str('foo-bar', raw_version)).to eq("foo-#{hyphenated_version}-bar")
      end
    end
  end

  describe '#new_dir_creation' do
    let(:run_context) { Chef::RunContext.new(Chef::Node.new(), nil, nil) }
    let(:dummy_class) do
      Class.new do
        include Bcpc_Hadoop::Helper
      end
    end
    # LDAP info to pass in
    hdfs = "hdfs://test-hdfs"
    path = "compound/directory/here"
    user = "BiffGnarley"

    context 'no directory triggers directory creation' do

      let(:testout) { double(run_command: double(exitstatus: 1) ) }
      let(:createout) { double(run_command: double(exitstatus: 0)) }
      it 'tests for the directory existence' do
        expect(Mixlib::ShellOut).to receive(:new) do |arg1, arg2|
          # we should have the directory path in the test command
          expect(arg1).to match(/^.*#{hdfs}\/#{path}.*$/)
          testout
        end
        expect(Mixlib::ShellOut).to receive(:new) do |arg1, arg2|
          # we should have the directory path in the creation command
          expect(arg1).to match(/^.*#{hdfs}\/#{path}.*$/)
          # we should have a mkdir in the creation command
          expect(arg1).to match(/^.*mkdir.*$/)
          # we should have a chown in the creation command
          expect(arg1).to match(/^.*chown.*$/)
          # we should have the user in the creation command
          expect(arg1).to match(/^.*#{user}.*$/)
          createout
        end
        # the command should not raise and should not complain
        expect(dummy_class.new.new_dir_creation(hdfs, path, user, "000", run_context)).to eq(nil)
      end
    end
  end
end
