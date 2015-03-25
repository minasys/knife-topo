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

require_relative 'topology_helper'
require 'chef/knife/search'

class Chef
  class Knife
    class TopoSearch < Chef::Knife::Search

      banner "knife topo search [ QUERY ] (options)"
      
      option :topo,
      :long => "--topo TOPOLOGY",
      :description => "Restrict search to nodes in the specified topology"
      
      option :no_topo,
      :long => "--no-topo",
      :description => "Restrict search to nodes that are not in any topology",
      :boolean => true,
      :default => true

      # Make the base search options available on topo search
      self.options = (Chef::Knife::Search.options).merge(self.options)

      def initialize (args)
        super
        topo_query = constrain_query(@name_args[0] || config[:query], config[:topo], !config[:no_topo].nil?)

        # force a node search
        @name_args[0] = "node"

        # override any query 
        if config[:query]
          config[:query] = topo_query
        else
          @name_args[1] = topo_query          
        end

      end

      def run
        begin
          super
        rescue Exception => e
          raise if Chef::Config[:verbosity] == 2
          ui.error "Topology search for \"#{@query}\" exited with error"
          humanize_exception(e)
        end
      end

      private

      include Chef::Knife::TopologyHelper
      
      def constrain_query(query, topo_name, no_topo)
        
        # group existing query
        # workaround for strange behavior with NOTs and invalid query if put brackets round them
        group_query = query && !query.start_with?("NOT") ? "(#{query})" : query
        
        # search specific topologies or all/none
        constraint = (topo_name) ? "topo_name:" + topo_name : "topo_name:*" 
        
        # combine the grouped query and constraint
        if no_topo
          result = query ? "#{group_query} NOT #{constraint}" : "NOT #{constraint}"
        else
          result = query ? "#{constraint} AND #{group_query}" : constraint
        end
        
        result
      end
      
       
    end
  end
end