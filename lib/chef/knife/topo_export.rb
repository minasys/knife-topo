#
# Author:: Christine Draper (<christine_draper@thirdwaveinsights.com>)
# Copyright:: Copyright (c) 2014 ThirdWave Insights LLC
# License:: Apache License, Version 2.0
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

require 'chef/knife'

require_relative 'topology_helper'

# NOTE: This command exports to stdout - do not add ui messages (other than fatal) to this command

class Chef
  class Knife
    class TopoExport < Chef::Knife

      deps do
      end

      banner "knife topo export [ TOPOLOGY [ NODE ... ]] (options)"

      option :data_bag,
      :short => '-D DATA_BAG',
      :long => "--data-bag DATA_BAG",
      :description => "The data bag the topologies are stored in"

      def run

        @bag_name = topo_bag_name(config[:data_bag])

        @topo_name = @name_args[0]
        @node_names = @name_args[1..-1]
        
        if @topo_name
          if topo = load_from_server(@bag_name, @topo_name)
            export = topo.raw_data
          else
            export = empty_topology
          end

          # merge in data for nodes that user explicitly specified
          @node_names.each do |node_name|
            merge_node_properties!(export['nodes'], node_name)
          end

        else
          # export all topologies
          export = []
          if dbag = load_from_server(@bag_name)
            dbag.keys.each do |topo_name|
               if topo = load_from_server(@bag_name, topo_name)
                export << topo.raw_data
              end
            end
          end
        end

        output(Chef::JSONCompat.to_json_pretty(export))
      end

      # give user a template to get started
      def empty_topology
        {
          "id" => @topo_name || "topo1",
          "name" => @topo_name || "topo1",
          "chef_environment" => "_default",
          "tags" => [ ],
          "normal" => { },
          "nodes" => [
          "node1" => empty_node("node1")
          ],
          "cookbook_attributes" => [{
            "cookbook" =>  @topo_name || "topo1",
            "filename" => "topology"
          }]
        }
      end

      def empty_node(name)
        {
          "name" => name,
          "run_list" => [],
          "ssh_host" => name,
          "ssh_port" => "22",
          "normal" => {},
          "tags" => []
        }
      end

      # get actual node properties for export
      def node_export (node_name)

        node_data = {}

        begin
          node = Chef::Node.load(node_name)
          
          node_data['name'] = node.name
          node_data['tags'] = node.tags
          node_data['chef_environment'] = node.chef_environment
          node_data['normal'] = node.normal
          node_data['run_list'] = node.run_list
          
        rescue Net::HTTPServerException => e
          raise unless e.to_s =~ /^404/
          node = empty_node(node_name)
        end
        
        node_data
      end

      # merge hash properties with the actual node properties
      def merge_node_properties!(nodes, node_name)
        # find out if the node is already in the array
        found = nodes.index{|n| n["name"] == node_name }
        if found
          nodes[found] = node_export(node_name)
        else
          nodes.push(node_export(node_name))
        end
      end

      include Chef::Knife::TopologyHelper

    end
  end
end