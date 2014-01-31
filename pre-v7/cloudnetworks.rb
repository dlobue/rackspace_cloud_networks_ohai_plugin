#
#   Copyright 2014 Dominic LoBue
#
#   Licensed under the Apache License, Version 2.0 (the "License");
#   you may not use this file except in compliance with the License. 
#   You may obtain a copy of the License at
#
#       http://www.apache.org/licenses/LICENSE-2.0
#
#   Unless required by applicable law or agreed to in writing, software
#   distributed under the License is distributed on an "AS IS" BASIS,
#   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. 
#   See the License for the specific language governing permissions and
#   limitations under the License.
#
#

require 'json'

XEN_NETWORK_PATH = "vm-data/networking"

provides "rackspace/cloud_networks"
require_plugin "rackspace"
require_plugin "network"

def get_network_interfaces
  status, stdout, stderr = run_command(:no_status_check => true, :command => "xenstore-list %s" % XEN_NETWORK_PATH)
  if status == 0
    stdout.each_line.map &:strip
  end
rescue Ohai::Exceptions::Exec
  Ohai::Log.warn("Unable to get list of network interfaces!")
  []
end

def get_interface_data(name)
  status, stdout, stderr = run_command(:no_status_check => true, :command => "xenstore-read %s/%s" % [XEN_NETWORK_PATH, name])
  if status == 0
    JSON.parse(stdout.strip)
  end
rescue Ohai::Exceptions::Exec
  Ohai::Log.warn("Unable to get metadata for interface #{name}!")
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
  mac_map = Hash[network[:interfaces].map do |iface,data|
    [data[:addresses].select {|addy,params|
        params['family'].eql?('lladdr')
      }.keys.first, iface]
  end]
  cn = rackspace[:cloud_networks] = Mash.new
  get_network_interfaces.map do |name|
    extract_interface_data(name)
  end.compact.each do |d|
    lbl = d.keys.first
    d[lbl][:interface] = mac_map[d[lbl][:mac]] if mac_map.has_key? d[lbl][:mac]
    cn.update d
  end
end

