[![License](https://img.shields.io/:license-apache-blue.svg)](http://www.apache.org/licenses/LICENSE-2.0.html)
[![CII Best Practices](https://bestpractices.coreinfrastructure.org/projects/73/badge)](https://bestpractices.coreinfrastructure.org/projects/73)
[![Puppet Forge](https://img.shields.io/puppetforge/v/simp/simpkv.svg)](https://forge.puppetlabs.com/simp/simpkv)
[![Puppet Forge Downloads](https://img.shields.io/puppetforge/dt/simp/simpkv.svg)](https://forge.puppetlabs.com/simp/simpkv)
[![Build Status](https://travis-ci.org/simp/pupmod-simp-simpkv.svg)](https://travis-ci.org/simp/pupmod-simp-simpkv)

#### Table of Contents

<!-- vim-markdown-toc -->

* [Overview](#overview)
* [This is a SIMP module](#this-is-a-simp-module)
* [Module Description](#module-description)
* [Terminology](#terminology)
* [Usage](#usage)
  * [Single Backend Example](#single-backend-example)
  * [Multiple Backends Example](#multiple-backends-example)
  * [Binary Value Example](#binary-value-example)
  * [Global Key Example](#global-key-example)
  * [Auto-Default Backend](#auto-default-backend)
  * [Backend Folder Layout](#backend-folder-layout)
  * [simpkv Configuration Reference](#simpkv-configuration-reference)
* [File Store and Plugin](#file-store-and-plugin)
* [Limitations](#limitations)
* [Plugin Development](#plugin-development)
  * [Plugin Loading](#plugin-loading)
  * [Implementing the Store Interface API](#implementing-the-store-interface-api)
* [simpkv Development](#simpkv-development)
  * [Unit tests](#unit-tests)
  * [Acceptance tests](#acceptance-tests)

<!-- vim-markdown-toc GFM -->

## Overview

## This is a SIMP module

This module is a component of the [System Integrity Management Platform](https://simp-project.com),
a compliance-management framework built on Puppet.

If you find any issues, please submit them via [JIRA](https://simp-project.atlassian.net/).

Please read our [Contribution Guide](https://simp.readthedocs.io/en/stable/contributors_guide/index.html).

## Module Description

Provides an abstract library that allows Puppet to access one or more key/value
stores.

This module provides

* a standard Puppet language API (functions) for using key/value stores

  * The API is modeled after https://github.com/docker/libkv#interface.
  * See [REFERENCE.md](REFERENCE.md) for more details on the available
    functions.

* a configuration scheme that allows users to specify per-application use
  of different key/value store instances
* adapter software that loads and uses store-specific interface software
  provided by the simpkv module itself and other modules
* a Ruby API for the store interface software that developers can implement
  to provide their own store interface
* a file-based store on the local filesystem and its interface software.

  * Future versions of this module will provide a distributed key/value store.

If you find any issues, they may be submitted to our
[bug tracker](https://simp-project.atlassian.net/).

## Terminology

The following terminology will be used throughout this document:

* backend - A specific key/value store, e.g., files on a local filesystem,
  Consul, Etcd, Zookeeper.
* plugin - Ruby software that interfaces with a specific backend to
  affect the operations requested in simpkv Puppet functions.
* plugin instance - Instance of the plugin that handles a unique backend
  configuration.
* plugin adapter - Ruby software that loads, selects, and executes the
  appropriate plugin software for a simpkv function call.

## Usage

Using `simpkv` is simple:

* Use `simpkv` functions to store and retrieve key/value pairs in your Puppet
  code.
* Configure the backend(s) to use in Hieradata.
* Reconfigure the backend(s) in Hieradata, as your needs change.

  * No changes to your Puppet code will be required.
  * Just transfer your data from the old key/value store to the new one.

The backend configuration of `simpkv` can be as simple as you want (one backend)
or complex (multiple backends servicing different applications).  Examples of
both scenarios will be shown in this section, along with a configuration
reference.

### Single Backend Example

This example will store and retrieve host information using simpkv function
signatures that assume the default backend and hieradata that only configures
the default backend.

To store a node's hostname and IP address:

```puppet
simpkv::put("hosts/${facts['clientcert']}", $facts['ipaddress'])
```

To create a hosts file using the list of stored host information:

```puppet
$result = simpkv::list('hosts')
$result['keys'].each |$host, $info | {
  host { $host:
    ip => $info['value'],
  }
}
```

In hieradata, configure the default backend in the ``simpkv::options`` Hash.  This
example, will configure simpkv's file backend.

```yaml
simpkv::options:

  # Hash of backend configurations.
  # - We have only the required 'default' entry which will apply to
  #   all simpkv calls.
  backends:
    default:
      # This is the advertised type for simpkv's file plugin.
      type: file
      # This is a unique id for this configuration of the 'file' plugin.
      id: file

      # plugin-specific configuration
      root_path: "/var/simp/simpkv/file"
      lock_timeout_seconds: 30
```

### Multiple Backends Example

This example will store and retrieve host information using simpkv function
signatures that request a backend based on an application id and multi-backend
hieradata that supports the request.  The function signatures and hieradata are
a little more complicated, but still relatively straightforward to understand.

To store a node's hostname and IP address using the backend servicing `myapp1`:

```puppet
$simpkv_options = { 'app_id' => 'myapp1' }
$empty_metadata = {}
simpkv::put("hosts/${facts['clientcert']}", $facts['ipaddress'], $empty_metadata, $simpkv_options)
```

To create a hosts file using the list of stored host information using the
backend servicing `myapp1`:

```puppet
$simpkv_options = { 'app_id' => 'myapp1' }
$result = simpkv::list('hosts', $simpkv_options)
$result['keys'].each |$host, $info | {
  host { $host:
    ip => $info['value'],
  }
}
```

In hieradata, configure multiple backends in the ``simpkv::options`` Hash.
This example will configure multiple instances of simpkv's file backend.

```yaml
# The backend configurations here will be inserted into simpkv::options
# below via the alias function.

simpkv::backend::file_default:
  type: file
  id: default
  root_path: "/var/simp/simpkv/file"

simpkv::backend::file_myapp:
  type: file
  id: myapp
  root_path: "/path/to/myapp"

simpkv::backend::file_yourapp:
  type: file
  id: yourapp
  root_path: "/path/to/yourapp"


simpkv::options:
  # Hash of backend configurations.
  # * Includes application-specific backends and the required default backend.
  # * simpkv will use the appropriate backend for each simpkv function call.
  backends:
    # backend for specific myapp application
    "myapp_special_snowflake": "%{alias('simpkv::backend::file_default')}"

    # backend for remaining myapp* applications, including myapp1
    "myapp":                   "%{alias('simpkv::backend::file_myapp')}"

    # backend for all yourapp* applications
    "yourapp":                 "%{alias('simpkv::backend::file_yourapp')}"

    # required default backend
    "default":                 "%{alias('simpkv::backend::file_default')}"
```

In this example, we are setting the application identifier to `myapp1` in
our simpkv function calls.  simpkv selects `myapp` as the backend to use for
`myapp1` using the following simple search algorithm:

* First, it looks for a backend named for the application id.
* Next, it looks for the longest backend name matching the start of the
  application id.
* Finally, if no match is found, it defaults to a backend named `default`.

### Binary Value Example

simpkv is able to store and retrieve binary values, provided the Puppet code
uses the appropriate configuration and functions/types for binary data.

Below is an example of using simpkv for a binary value.

To store the content of a generated keytab file:

```puppet
# Load in the binary content from a file.  Returns a Binary Puppet type.
$original_binary_content = binary_file('/path/to/keytabs/app.keytab')

# Set a key/value pair with the binary content
simpkv::put('app/keytab', $original_binary_content)
```

To retrieve the keytab binary content and use it in a `file` resource:

```puppet
# Retrieve a binary value from a key/value store and set a Binary variable
$retrieved_result = simpkv::get('app/keytab')
$retrieved_binary_content = Binary.new($retrieved_result['value'], '%r')

# Persist binary data to another file
file { '/different/path/to/keytabs/app.keytab':
  content => $retrieved_binary_content
}

```

### Global Key Example

By default, the key/folder path referenced in a simpkv function is tied to
the Puppet environment of the node whose manifest is being compiled. This
ensures the data stored for one Puppet environment (e.g., 'dev') does not
corrupt the data for another Puppet environment (e.g., 'production').
Nevertheless, there are times in which you may want to store data that
is applicable to all Puppet environments, instead. simpkv supports global
data through an option in each simpkv function call.

Below is an example of using simpkv to store a node's hostname and IP address
as global data:

```puppet
$simpkv_options = { 'global' => true }
$empty_metadata = {}
simpkv::put("hosts/${facts['clientcert']}", $facts['ipaddress'], $empty_metadata, $simpkv_options)
```

To create a hosts file using the list of stored, global host information:

```puppet
$simpkv_options = { 'global' => true }
$result = simpkv::list('hosts', $simpkv_options)
$result['keys'].each |$host, $info | {
  host { $host:
    ip => $info['value'],
  }
}
```

### Auto-Default Backend

simpkv is intended to be configured via ``simpkv::options`` and any
application-specific configuration passed to the simpkv Puppet functions.
However, to facilitate rollout of simpkv capabilities, (specifically
use of simpkv internally in ``simplib::passgen``), when ``simpkv::options``
is not set in hieradata, simpkv will automatically use the simpkv file store with
the configuration that is equivalent to the following hieradata:

```yaml
simpkv::options:
  environment: "%{server_facts.environment}"
  softfail: false
  backend: default
  backends:
    default:
      type: file
      id: auto_default
```

### Backend Folder Layout

The storage in a simpkv backend can be notionally represented as a folder
tree with key files at terminal nodes. simpkv automatically sets up the
folder layout at the top level and the user specifies key files below that.
Specifically,

* simpkv stores global keys in a `globals` sub-folder of the root folder.

  * Global keys are not tied to any specific Puppet environment.
  * You must specify `'global' => true` in the options passed to
    simpkv functions in order to access global keys.

* simpkv stores all other keys in sub-folders named for the Puppet
  environment in which each key was created.

  * The parent directory for all environment folders is
    `<root folder>/environments`.

* Further sub-folder trees are allowed for global or environment-specific keys.

  * A relative paths in a key name indicates a sub-folder tree (e.g.
   'app1/keya').

* The actual representation of the root folder is backend specific.

  * For the 'file' backend, the root folder is a directory on the local file
    system of the Puppet server.

Below is an example of a folder tree for the `file` backend configured
with an `id` of `default`:

```
/var/simp/simpkv/file/default
│
├── globals/ .............. Global keys parent
│   ├── app1/ ............. Folder for 'app1' global keys
│   │    └── global_keyq .. simpkv::put('app1/global_keyq', { 'global' => true })
│   └── global_keyr ....... simpkv::put('global_keyr', { 'global'=> true })
│
├── environments/.......... Environment keys parent
│   ├── dev/ .............. Folder for 'dev' Puppet environment keys
│   │   └── app1/
│   │       └── keya ...... simpkv::put('app1/keya') for a 'dev' env node
│   │
│   └── production/ ....... Folder for 'production' Puppet environment keys
│       ├── app1/
│       │   └── keya ...... simpkv::put('app1/keya') for a 'production' env node
│       ├── app2/
│       │   ├── groupx/
│       │   │   └── keyb
│       │   └── groupy/
│       │       └── keyc .. simpkv::put('app2/groupy/keyc') in a 'production' node
│       └── keyd .......... simpkv::put('keyd') in a 'production' env node
└──
```

### simpkv Configuration Reference

The simpkv configuration used for each simpkv function call is comprised of
a merge of a function-provided options Hash, Hiera configuration specified
by the `simpkv::options` Hash, and global configuration defaults.  The merge
is executed in a fashion to ensure the function-provided options take
precedence over the `simpkv::options` Hiera values.

The merged simpkv configuration contains global and backend-specific
configurations, along with an optional application identifier. The primary
keys in this Hash are as follows:

* `app_id`: Optional String in simpkv function calls, only. Specifies an
  application name that can be used to identify which backend configuration
  to use via fuzzy name matching, in the absence of the `backend` option.
  (See [Backend Selection](#backend-selection)).

  * More flexible option than `backend`.
  * Useful for grouping together simpkv function calls found in different
    catalog resources.

* `backend`: Optional String. Specifies a definitive backend configuration
  to use.

  * Takes precedence over `app_id`.
  * When present, must match a key in `backends` and will be used unequivocally.

    * If that backend does not exist in `backends`, the simpkv function will fail.

  * When absent, the backend configuration will be selected from the set of
    entries in `backends`, using the `app_id` option if specified.
    (See [Backend Selection](#backend-selection)).

* `backends`: Required Hash. Specifies backend configurations.  Each key
  is the name of a backend configuration and its value contains the
  corresponding configuration Hash.

  * Each key is a String.
  * Must include a 'default' key.
  * More than one key can use the same backend configuration.
  * See [Backend Configuration Entries](#backend-configuration-entries)
    for more details about a backend configuration Hash.

* `global`: Optional Boolean. Set to `true` when the key being accessed
  is global. Otherwise, the key will be tied to the Puppet environment
  of the node whose manifest is being compiled.

  * Defaults to `false`.

* `softfail`: Optional Boolean. Whether to ignore simpkv operation failures.

  * When `true`, each simpkv function will return a result object even when the
    operation failed at the backend.
  * When `false`, each simpkv function will fail when the backend operation
    failed.
  * Defaults to `false` when absent.

#### Backend Configuration Entries

Each backend configuration entry in `backends` is a Hash.  The Hash must
contain `type` and `id` keys, where the (`type`,`id`) pair defines a unique
configuration.

* `type` must be unique across all backend plugins, including those
  provided by other modules.
* `id` must be unique for a each distinct configuration for a `type`.
* Other keys for configuration specific to the backend may also be present.

#### Backend Selection

The backend to use for a simpkv Puppet function call will be determined from
the merged simpkv options Hash as follows:

* If a specific backend is requested via the `backend` key in the merged simpkv
  options Hash, that backend will be selected.

  * If that backend does not exist in `backends`, the simpkv function will fail.

* Otherwise, if an `app_id` option is specified in the merged simpkv options
  Hash and it matches a key in the `backends` Hash, exactly, that backend will
  be selected.
* Otherwise, if an `app_id` option is specified in the merged simpkv options
  Hash and it starts with the key in the `backends` Hash, that backend will be
  selected.

  * When multiple backends satisfy the 'start with' match, the backend with the
    most matching characters is selected.

* Otherwise, if the `app_id` option does not match any key in in the `backends`
  Hash or is not present, the `default` backend will be selected.

## File Store and Plugin

simpkv provides a file-based key/value store and its plugin.  This file store
maintains individual key files on a **local** filesystem, has a backend type `file`,
and supports the following plugin-specific configuration parameters.

* `root_path`: Root directory path for the key files

  * Defaults to `/var/simp/simpkv/file/<id>` when that directory can be created
    or '<Puppet[:vardir]>/simp/simpkv/<name>' otherwise.

* `lock_timeout_seconds`: Maximum number of seconds to wait for an exclusive
  file lock on a file modifying operation before failing the operation.

  * Defaults to 5 seconds.

## Limitations

* SIMP Puppet modules are generally intended to be used on a Red Hat Enterprise
  Linux-compatible distribution such as EL7 and EL8.

* simpkv's file plugin is only guaranteed to work on local filesystems.  It may not
  work on shared filesystems, such as NFS.

* `simpkv` only supports the use of binary data for the value when that data is
   a Puppet `Binary`. It does not support binary data which is a sub-element of
   a more complex value type (e.g.  `Array[Binary]` or `Hash` that has a key or
   value that is a `Binary`).

## Plugin Development

### Plugin Loading

Each plugin (store interface) is written in pure Ruby and, to prevent
cross-environment contamination, is implemented as an anonymous class
that is automatically loaded by the simpkv adapter with each Puppet compile.
You do not have to do anything special to have your plugin loaded, provided
you follow the instructions in the next section.

### Implementing the Store Interface API

To create your own plugin

* Create a `lib/puppet_x/simpkv` directory within your store plugin module.
* Copy `lib/puppet_x/simpkv/plugin_template.rb` from the simpkv module into that
  directory with a name `<your plugin name>_plugin.rb`.  For example,
  `nfs_file_plugin.rb`.
* **READ** all the documentation in your plugin skeleton, paying close attention
  the `IMPORTANT NOTES` discussion.
* Implement the body of each method as identified by a `FIXME`. Be sure to
  conform to the API for the method.
* Write unit tests for your plugin, using the unit tests for simpkv's file
  plugin, `spec/unit/puppet_x/simpkv/file_plugin_spec.rb` as an example.  That
  test shows you how to instantiate an object of your plugin for testing
  purposes.
* Write acceptance tests for your plugin, using the acceptance tests for
  simpkv's file plugin in `spec/acceptances/suites/default/`,
  as an example.  That test uses a test module, `spec/support/simpkv_test`
  and a plugin-specific validator to exercise the the simpkv API and verify its
  operation with the file plugin.
* Document your plugin's type and configuration parameters in the README.md for
  your store plugin module.

## simpkv Development

Please read our [Contribution Guide] (https://simp.readthedocs.io/en/stable/contributors_guide/index.html).

### Unit tests

Unit tests, written in ``rspec-puppet`` can be run by calling:

```shell
bundle exec rake spec
```

### Acceptance tests

To run the system tests, you need [Vagrant](https://www.vagrantup.com/) installed. Then, run:

```shell
bundle exec rake beaker:suites
```

Some environment variables may be useful:

```shell
BEAKER_debug=true
BEAKER_provision=no
BEAKER_destroy=no
BEAKER_use_fixtures_dir_for_modules=yes
```

* `BEAKER_debug`: show the commands being run on the STU and their output.
* `BEAKER_destroy=no`: prevent the machine destruction after the tests finish so you can inspect the state.
* `BEAKER_provision=no`: prevent the machine from being recreated. This can save a lot of time while you're writing the tests.
* `BEAKER_use_fixtures_dir_for_modules=yes`: cause all module dependencies to be loaded from the `spec/fixtures/modules` directory, based on the contents of `.fixtures.yml`.  The contents of this directory are usually populated by `bundle exec rake spec_prep`.  This can be used to run acceptance tests to run on isolated networks.

