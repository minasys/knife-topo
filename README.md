knife topo
==========

The knife-topo plugin allows you to create and update topologies 
consisting of multiple nodes using single knife commands, based on
a JSON definition of the topology. The plugin:
* creates a data bag for the topology
* generates attribute file(s) in a topology-specific cookbook
* sets and updates the run list, chef environment and properties of nodes
* uploads the topology-specific cookbook and bootstraps nodes

You may find this plugin useful if you are 
regularly updating a system consisting of multiple nodes, and would
like to manage its dynamic configuration (e.g. changing software versions) 
through a single (json) configuration file. It may also be useful
if you are regularly bringing up multi-node systems with similar 
topologies but differences in their configuration details.

This plugin can be used in conjunction with the 
[topo cookbook](http://github.com/christinedraper/topo-cookbook)
to configure dynamically deployed topologies of nodes (e.g. in AWS).
In this approach, use knife-topo to set up the topology details.
Use the 'topo' cookbook to let nodes pull their own detailed configuration
from the topology data bag on the Chef server. 

# Changes from V1 #

## Attribute setting strategy

V2 introduces the notion of an attribute setting strategy. Instead of
specifying node attributes and cookbook attributes separately, you 
specify one set of attributes and the method by which 
they should be set on the node (e.g. 'direct_to_node' or 'via_cookbook'). 

The purpose of this change is to make it easier to support new
methods of setting attributes such as policy files, and also making it
easier to switch between methods.

## Node type

A node type can be specified for a node. The node type is used
by the 'topo' cookbook to identify the right configuration to use. It
is also used in the 'via cookbook' method to support attributes that
vary by node type.

## One topology per file

To reduce complexity, V2 no longer supports multiple topologies in a 
JSON file.

## V1 -> V2 Migration

V1 topology JSON files can be converted to V2 by importing them and
then exporting them. knife-topo will auto-detect V1 format files on 
import. You can also explicitly specify the input format using
`knife topo import sometopo.json --input-format 'topo_v1'`

# Installation #

Install knife-topo as a gem

```
  $ chef gem install knife-topo
```

# Usage #

Define each topology in a [topology file](#topology-file). Import
that file into your Chef workspace using [knife topo import](#import), 
then create the topology [knife topo create](#create), specifying
the '--bootstrap' option if you want to bootstrap all of the nodes. 

Update the topology file as the configuration changes, import those 
changes [knife topo import](#import) and run 
[knife topo update](#update) to update the topology.


# Getting Started #

Try out this plugin using a [test-repo](test-repo) provided in the knife-topo github repository.
[Download the latest knife-topo release](http://github.com/christinedraper/knife-topo/releases/latest)
and unzip it, then follow the [Instructions](test-repo/Instructions.md) for the example.

The instructions assume you have [chefDK](https://downloads.chef.io/chef-dk/)
 installed and working with Vagrant and VirtualBox. 
 
 If you're the sort of person who just wants to jump in and try it, here's some hints.
 
Generate a topology file for a topology called test1 from existing nodes node1 and node2:

  knife topo export node1 node2 --topo test1 > test1.json

Import a topology json file, generating all of the necessary artifacts in your workspace:

	knife topo import test1.json

Create the topology using existing nodes:

	knife topo create test1
	
Create the topology, bootstrapping new nodes in vagrant (you will need to add the 
host details for bootstrap to the file before importing):

	knife topo create test1 --bootstrap -xvagrant -Pvagrant --sudo 

# Topology File <a name="topology-file"></a>#

See the [example topology file](test-repo/test1.json)

The topology file contains a single topology.
Each topology has some overall properties, an array of nodes and 
an array defining topology cookbook attributes.

## Overall Topology Properties <a name="topology-properties"></a>

```
    {
        "name": "test1",
        "node_type": "appserver",
        "chef_environment": "test",
        "tags": [ "testsys" ],
        "normal": {
          "owner": {
            "name": "Christine Draper"
          }
        },
        "nodes" : [
          ...
        ]
    }
```

The `name` is how you will refer to the topology in the
`knife topo` subcommands.

The `chef-environment` and `normal` attributes defined
here will be applied to all nodes in the topology, unless alternative
values are provided for a specific node.  The `tags` 
will be added to each node. 

### Attribute setting strategy

The default strategy for setting attributes is `direct_to_node`. 
In this strategy, normal attributes are set directly on the nodes when
the topology is created, bootstrapped or updated. Attributes with
other priorities are ignored.

The `strategy` field can be set to 'via_cookbook', in which case
additional `strategy_data` can be provided to specify a cookbok
and attribute filename.
```
    {
        "name": "test1",
        ...
        "strategy" : "via_cookbook",
        "strategy_data": {
          "cookbook": "topo_test1",
          "filename": "softwareversion",
      }
    }
```

In this strategy, the cookbook and attribute file are generated
in the local workspace when the topology is imported, and uploaded
to the server when the topology is created or updated. Attributes
can have any valid priority.
    
## Node List <a name="node-list"></a>
Each topology contains a list of `nodes`.

```
    {
        "name": "test1",
        ...
        "nodes": [
           {
              "name": "buildserver01",
              "node_type" : "buildserver",
              "ssh_host": "192.168.1.201",
              "ssh_port": "2224",
              "chef_environment": "dev",
              "run_list": [ 
                "role[base-ubuntu]", 
                "ypo::db", 
                "recipe[ypo::appserver]"
              ],
              ... node attributes, see below ...,
              "tags": [ "build" ]
            },
            ...
        ]
    }
```
Within `nodes`, the `name` field is the node name that will be used in Chef.
The fields `chef_environment`, `run_list` and `tags` 
will also be applied to the node in Chef. All of these
fields are optional. 

The `node_type` sets the node attribute `normal['topo']['node_type']`.
This attribute is used in the 'via_cookbook' strategy to specify
attributes that apply to only nodes of that type. 

The `ssh_host` and `ssh_port` fields are used to
bootstrap a node.

## Node Attributes <a name="node-attributes"></a>

Each topology may have attributes that are set on each node
according to the attribute setting strategy. The attribute names and
values are specified by priority ('default', 'normal', 'override').

```
	"nodes": [
		{
      "name": "buildserver01",
			"normal": 
			{			
				"nodejs": 
				{
					"version": "0.10.40"
				},

				"testapp": 
				{
					"version": "0.0.3"
				},

				"mongodb": 
				{
					"package_version": "2.6.9"
				}
			}
		}
	]
```

# Subcommands <a name="subcommands"></a>

The main subcommands for `knife topo` are:

* [knife topo import](#import) - Import one or more into your workspace/local repo
* [knife topo create](#create) - Create and optionally bootstrap a topology of nodes
* [knife topo update](#update) - Update a topology of nodes

The additional subcommands can also be useful, depending on your
workflow:

* [knife topo bootstrap](#bootstrap)- Bootstraps a topology of nodes
* [knife export](#export) - Export data from a topology (or from nodes that you want in a topology)
* [knife topo list](#list) - List the topologies
* [knife topo search](#search) - Search for nodes that are in a topology, or in no topology
* [knife topo delete](#delete) - Delete a topology, but not the nodes in the topology

The topologies are data bag items in the 'topologies' data bag, so 
you can also use knife commands such as:

* `knife data bag show topologies test1` - Show details of the test1 topology data bag

### Common Options:

The knife topo subcommands support the following common options.

Option        | Description
------------  | -----------
-D, --data-bag DATA_BAG    | The data bag to use for the topologies. Defaults to 'topologies'.

## knife topo bootstrap <a name="bootstrap"></a>

	knife topo bootstrap TOPOLOGY

Runs the `knife bootstrap` command for each node in the topology that
has the `ssh_host` attribute. Specified options will be passed through
to `knife bootstrap` and applied to each node.

### Options:

The knife topo bootstrap  subcommand supports the following additional options.

Option        | Description
------------  | -----------
--overwrite | Re-bootstrap existing nodes
See [knife bootstrap](http://docs.opscode.com/knife_bootstrap.html)  | Options supported by `knife bootstrap` are passed through to the bootstrap command


### Examples:
The following will bootstrap nodes in the test1 topology, using a
user name of vagrant, password of vagrant, and running using sudo.

	$ knife topo bootstrap test1 -x vagrant -P vagrant --sudo
  
## knife topo create <a name="create"></a>

	knife topo create TOPOLOGY

Creates the specified topology in the chef server as an item in the 
topology data bag. Creates the chef environment associated
with the topology, if it does not already exist. Uploads the
topology cookbook, if using the 'via_cookbook' method. 
Updates existing nodes based on the topology
information. New nodes will be created if the bootstrap option is
specified.

### Options:

The knife topo create subcommand supports the following additional options.

Option        | Description
------------  | -----------
--bootstrap    | Bootstrap the topology (see [topo bootstrap](#bootstrap))
See [knife bootstrap](http://docs.opscode.com/knife_bootstrap.html)  | Options supported by `knife bootstrap` are passed through to the bootstrap command
--disable-upload   | Do not upload topology cookbooks
--overwrite | Re-bootstrap existing nodes

### Examples:
The following will create the 'test1' topology, and bootstrap it.

	$ knife topo create test1 --bootstrap

The following will create the 'test1' topology but will not bootstrap it 
or upload topology cookbooks.

	$ knife topo create test1 --disable-upload

## knife topo delete <a name="delete"></a>

	knife topo delete TOPOLOGY

Deletes the specified topology. Does not delete the nodes in the topology, but does
remove them from the topology by removing the `['topo']['name']` attribute 
which is used by `knife topo search`.

## knife topo export <a name="export"></a>

	knife topo export NODE [ NODE ... ] 

Exports the nodes into a topology JSON. 

If the topology does not already exist, 
an outline for a new topology will be exported. The exported JSON
can be used as the basis for a new topology definition.

If nodes are specified, these will be exported in addition
to any nodes that are in the topology. 

If no topology is specified, all defined topologies will be exported.

### Options:

The knife topo export subcommand supports the following additional options.

Option        | Description
------------  | -----------
--topo      | Name of the topology to export (defaults to 'topo1')
--min-priority    | Only export attributes with a priority equal or above this priority.

### Examples:

The following will export the data for nodes n1 and n2 as part of a 
topology called 'my_topo':

	$ knife topo export n1 n2 --topo my_topo > my_topo.json

	
The following will create an outline for a new topology called  
'christine_test', or export the current details if it already exists:

	$ knife topo export --topo christine_test > christine_test.json


## knife topo import <a name="import"></a>

	knife topo import [ TOPOLOGY_FILE ] 

Imports data bag items containing the topologies from a
[topology file](#topology-file) into the local repo. If no topology
file is specified, attempts to read from a file called 'topology.json'
in the current directory. Generates additional artifacts (e.g. 
topology cookbook attribute file) where needed.

### Examples:
The following will import the topology or topologies defined in the 
'topology.json' file.

	$ knife topo import topology.json

The following will import the 'test1' topology
 defined in the 'topology.json' file.

	$ knife topo import topology.json test1

## knife topo list <a name="list"></a>

	knife topo list

Lists the topologies that have been created on the server.

## knife topo search <a name="search"></a>

	knife topo search [ QUERY ]
  
Searches for nodes that are in a topology and satisfy the query. With no options,
this searches for nodes in any topology. Use `--topo=topo_name` to search
within a specific topology. Use `--no-topo` to search for nodes in no topology.

`knife topo search` uses the `['topo']['name']` attribute to identify which nodes 
are in which topology.
  
### Examples:

The following will search for nodes in any topology that have a name starting with "tst".

	$ knife topo search "name:tst*"
  
The following will search for nodes in the "prod" chef environment that are not in a topology.

	$ knife topo search "chef_environment:prod" --no-topo
  
The following will search for all nodes in the "systest" topology.

	$ knife topo search --topo=systest
  
### Options:

The knife topo search subcommand supports the following additional options.

Option        | Description
------------  | -----------
--topo    | Search for nodes in the specified topology
--no-topo | Search for nodes that are not in any topology
See [knife search](http://docs.chef.io/knife_search.html)  | Options supported by `knife search` are passed through to the search command


## knife topo update <a name="update"></a>

	knife topo update [ TOPOLOGY ] 

Updates the specified topology. Creates or updates nodes 
identified in the topology, using information specified in the 
topology for the specific node. 

If no topology is specified, all existing topologies
will be updated.

Option        | Description
------------  | -----------
--bootstrap    | Bootstrap the topology (see [topo bootstrap](#bootstrap))
See [knife bootstrap](http://docs.chef.io/knife_bootstrap.html)  | Options supported by `knife bootstrap` are passed through to the bootstrap command
--disable-upload   | Do not upload topology cookbooks

### Examples:
The following will update the 'test1' topology.

	$ knife topo update test1
	
The following will update all topologies in the 'topologies' data bag.

	$ knife topo update
	

# License #

Author:: Christine Draper (christine_draper@thirdwaveinsights.com)

Copyright:: Copyright (c) 2014-2016 ThirdWave Insights, LLC

License:: Apache License, Version 2.0

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
