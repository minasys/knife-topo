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

require_relative 'topology_loader'
require_relative 'topology_helper'
require 'chef/knife/cookbook_create'

module KnifeTopo
  # knife topo cookbook create
  class TopoCookbookCreate < Chef::Knife
    deps do
      Chef::Knife::CookbookCreate.load_deps
    end

    banner 'knife topo cookbook create TOPOLOGY_FILE (options)'

    option(
      :data_bag,
      short: '-D DATA_BAG',
      long: '--data-bag DATA_BAG',
      description: 'The data bag the topologies are stored in'
    )

    # Make the base cookbook create options available on topo cookbook
    self.options = (Chef::Knife::CookbookCreate.options).merge(
      TopoCookbookCreate.options)

    include Chef::Knife::TopologyLoader
    include Chef::Knife::TopologyHelper

    def initialize(args)
      super
      @cookbook_create_args  = initialize_cmd_args(args, %w(cookbook create))

      # All called commands need to accept union of options
      Chef::Knife::CookbookCreate.options = options
    end

    def run
      validate_args

      data = load_topo_from_file_or_exit(@topo_file)

      # create the topology cookbooks
      cookbooks = data['cookbook_attributes'] || []
      create_cookbooks(cookbooks)
    end

    def validate_args
      unless @name_args[0]
        show_usage
        ui.fatal('You must specify a topology JSON file')
        exit 1
      end
      @topo_file = @name_args[0]
    end

    def run_create_cookbook(cookbook_name)
      @cookbook_create_args[2] = cookbook_name
      begin
        command = run_cmd(Chef::Knife::CookbookCreate, @cookbook_create_args)
      rescue StandardError => e
        raise if Chef::Config[:verbosity] == 2
        ui.warn "Create of cookbook #{cookbook_name} exited with error"
        humanize_exception(e)
      end

      # Store the cookbook config for use later
      store_cookbook_config(command)
    end

    def store_cookbook_config(command)
      @cookbook_path = File.expand_path(Array(
        command.config[:cookbook_path]).first)
      @copyright = command.config[:cookbook_copyright] || 'YOUR_COMPANY_NAME'
    end

    def create_cookbooks(cookbook_specs)
      cb_names = []
      cookbook_specs.each do |entry|
        cb_name = entry['cookbook']
        run_create_cookbook(cb_name) unless cb_names.include?(cb_name)
        cb_names << cb_name
        filename = entry['filename'] + '.rb'
        create_attr_file(@cookbook_path, cb_name, filename, entry)
      end
    end

    def create_attr_file(dir, cookbook_name, filename, attrs)
      ui.info("** Creating attribute file #{filename}")

      open(File.join(dir, cookbook_name, 'attributes', filename), 'w') do |file|
        file.puts <<-EOH
#
# THIS FILE IS GENERATED BY KNIFE TOPO - MANUAL CHANGES WILL BE OVERWRITTEN
#
# Cookbook Name:: #{cookbook_name}
# Attribute File:: #{filename}
#
# Copyright #{Time.now.year}, #{@copyright}
#
        EOH

        # Process the attributes not needing qualification
        print_priority_attrs(file, attrs)
        file.puts

        # Process attributes that need to be qualified
        print_qualified_attrs(file, attrs['conditional'])
      end
    end

    # Print out attribute line
    def print_attr(file, lhs, value1)
      if value1.is_a?(Hash)
        value1.each do |key, value2|
          print_attr(file, "#{lhs}['#{key}']", value2)
        end
      else
        ruby_str = value1.nil? ? 'nil' : Chef::JSONCompat.to_json(value1)
        file.write "#{lhs} = #{ruby_str}  \n"
      end
    end

    # Print out attributes hashed by priority
    def print_priority_attrs(file, attrs, indent = 0)
      priorities = %w(default force_default normal override force_override)
      priorities.each do |priority|
        next unless attrs[priority]
        lhs = ''
        indent.times { lhs += ' ' }
        lhs += priority
        print_attr(file, lhs, attrs[priority])
      end
    end

    # Print out qualified attributes
    def print_qualified_attrs(file, cond_attrs)
      return unless cond_attrs
      cond_attrs.each do |qattrs|
        file.puts "# Attributes for specific #{qattrs['qualifier']}"
        print_qualified_attr(file, qattrs)
      end
    end

    def print_qualified_attr(file, qhash)
      file.puts "if node['topo'] && node['topo']['#{qhash['qualifier']}']" \
       " == \"#{qhash['value']}\""
      print_priority_attrs(file, qhash, 2)
      file.puts 'end'
    end
  end
end
