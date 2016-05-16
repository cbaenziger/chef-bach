module Hannibal
  module Helper

    require 'net/http'
    require 'open-uri'
    require 'timeout'
    require 'uri'
    require 'builder'

    def wait_until_ready(endpoint, timeout)
      Timeout.timeout(timeout) do
        begin
          open(endpoint)
        rescue SocketError,
               Errno::ECONNREFUSED,
               Errno::ECONNRESET,
               Errno::ENETUNREACH,
               OpenURI::HTTPError => e
          Chef::Log.debug("Hannibal is not accepting requests - #{e.message}")
          sleep(10)
          retry
        end
      end
      rescue Timeout::Error
        raise "Hannibal service at #{endpoint} has not " \
              "become ready in #{timeout} seconds."
    end

    def hbase_site_xml
      xml = Builder::XmlMarkup.new(indent: 2)
      xml.instruct! :xml, encoding: 'ASCII'
      xml.configuration do |c|
        c.property do |p|
          p.name 'hbase.rootdir'
          p.value "hdfs://#{node.chef_environment}"
        end
        c.property do |p|
          p.name 'hbase.zookeeper.quorum'
          p.value node[:hannibal][:zookeeper_quorum].map{ |s|
            float_host(s[:hostname]) +
            ":#{node[:bcpc][:hadoop][:zookeeper][:port]}"
          }.join(',')
        end
        c.property do |p|
          p.name 'hbase.cluster.distributed'
          p.value 'true'
        end
        c.property do |p|
          p.name 'hbase.regionserver.info.port'
          p.value node[:hannibal][:hbase_rs][:info_port]
        end
        node[:hannibal][:hbase_site_xml_additions].each do |key, value|
          c.property do |p|
            p.name key.to_s
            p.value value.to_s
          end
        end
      end
    end

  end
end
