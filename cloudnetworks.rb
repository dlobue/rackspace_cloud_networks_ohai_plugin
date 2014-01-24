
require 'json'

XEN_NETWORK_PATH = "vm-data/networking"

Ohai.plugin(:RackspaceCloudNetworks) do
  provides "rackspace/cloud_networks"
  depends "rackspace"

  def get_network_interfaces
    so = shell_out("xenstore-list %s" % XEN_NETWORK_PATH)
    if so.exitstatus == 0
      so.stdout.each_line.map &:strip
    end
  rescue Ohai::Exceptions::Exec
    []
  end

  def get_interface_data(name)
    so = shell_out("xenstore-read %s/%s" % [XEN_NETWORK_PATH, name])
    if so.exitstatus == 0
      JSON.parse(so.stdout.strip)
    end
  rescue Ohai::Exceptions::Exec
    nil
  end

  def extract_interface_data(name)
    data = get_interface_data(name)
    return nil if data.nil? or !data.include? "label"
    ips = data["ips"].first
    Mash.new data["label"] => {
      :broadcast => data["broadcast"],
      :mac => data["mac"],
      :netmask => ips["netmask"],
      :ip => ips["ip"]
    }
  end


  collect_data do    
    if !rackspace.nil?
      cn = rackspace[:cloud_networks] = Mash.new
      get_network_interfaces.map do |name|
        extract_interface_data(name)
      end.compact.each do |d|
        cn.update d
      end
    end
  end
end
