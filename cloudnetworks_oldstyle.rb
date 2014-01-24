
require 'json'

XEN_NETWORK_PATH = "vm-data/networking"

provides "rackspace/cloud_networks"
require_plugin "rackspace"

def get_network_interfaces
  status, stdout, stderr = run_command(:no_status_check => true, :command => "xenstore-list %s" % XEN_NETWORK_PATH)
  if status == 0
    stdout.each_line.map &:strip
  end
rescue Ohai::Exceptions::Exec
  []
end

def get_interface_data(name)
  status, stdout, stderr = run_command(:no_status_check => true, :command => "xenstore-read %s/%s" % [XEN_NETWORK_PATH, name])
  if status == 0
    JSON.parse(stdout.strip)
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


if !rackspace.nil?
  cn = rackspace[:cloud_networks] = Mash.new
  get_network_interfaces.map do |name|
    extract_interface_data(name)
  end.compact.each do |d|
    cn.update d
  end
end

