The text below is a copy of the SIMP Project Confluence page of the same title
(created by Liz Nemsick and published on May 11, 2021). It has been preserved
here, so that it is available for interested users/developers who do not access
to that page.

# Use of LDAP as backend for simpkv

This page documents how 389DS can be used as a LDAP key/value store for simpkv.
It provides a basic overview of simpkv and then discusses Directory Information
Trees (DITs) that can be used to organize the data, an Object Identifier (OID)
tree and custom schemas to support those DITs, and the technology choices for
the implementation of the simpkv plugin interface to an 389DS instance.

#### Table of Contents

<!-- vim-markdown-toc -->

* [simpkv Overview](#simpkv-overview)
  * [Operations supported](#operations-supported)
  * [Backend logical structure](#backend-logical-structure)
  * [Backend selection](#backend-selection)
  * [simpkv plugin internals (10,000 foot view)](#simpkv-plugin-internals-10000-foot-view)
    * [Value normalization](#value-normalization)
* [LDAP Directory Information Tree design](#ldap-directory-information-tree-design)
  * [Requirements](#requirements)
  * [Design Considerations](#design-considerations)
  * [Root Tree](#root-tree)
  * [simpkv Subtree Option 1](#simpkv-subtree-option-1)
  * [simpkv Subtree Option 2](#simpkv-subtree-option-2)
  * [Recommendation](#recommendation)
* [OID Subtree Design and Custom LDAP Schema](#oid-subtree-design-and-custom-ldap-schema)
  * [SIMP OID Subtree](#simp-oid-subtree)
  * [LDAP Custom Schema](#ldap-custom-schema)
    * [simpkv DIT Option 1](#simpkv-dit-options-1)
    * [simpkv DIT Option 2](#simpkv-dit-options-2)
* [Technologies for Plugin Implementation](#technologies-for-plugin-implementation)
  * [Requirements](#requirements-1)
  * [Options Considered](#options-considered)
  * [Recommendation](#recommendaiton-1)

## simpkv Overview

The simp/simpkv module provides a library that allows Puppet to access one or
more key/value stores (aka backends), each of which, can be used to store
global keys and keys specific to Puppet environments. This section will
present an overview of simpkv. Please refer to the module
[design documentation](Design_Prototype2.md), [README](../README.md), and
[library documentation](../REFERENCE.md) for more details.

### Operations supported

The operations simpkv supports are as follows:

| Function Name        | Description                                           |
| -------------------- | ----------------------------------------------------- |
| `simpkv::delete`     | Deletes a key from a backend.                         |
| `simpkv::deletetree` | Deletes an entire folder from a backend.              |
| `simpkv::exists`     | Returns whether a key or key folder exists in a backend. |
| `simpkv::get`        | Retrieves a key’s value and any user-provided metadata from a backend. |
| `simpkv::list`       | Returns a listing of all keys and sub-folders in a folder in a backend. The list operation does *not* recurse through any sub-folders. Only information about the specified key folder is returned. |
| `simpkv::put`        | Sets a key’s value and optional, user-provided metadata in a backend. |

### Backend logical structure

Logically, keys for a specific backend are organized within global and environment
directory trees below that backend's root directory. You can visualize this tree
as a filesystem in which a leaf node is a file named for the key and whose
contents contains the value for that key. For example,

![simpkv Key/Value Tree](Use_of_LDAP_as_backend_for_simpkv/simpkv%20Key_Value%20Tree.png)


To facilitate implementations of this tree, key and  folder names are restricted
to sequences of alphanumeric, `'.'`,  `'_'`, `'-'`, and `'/'` characters, where
 `'/'` is used as the path separator. Furthermore, when a folder or key
pecification contains a path, the path cannot contain relative path subsequences
 (e.g., `'/./'` or `'/../'`).

### Backend selection

simpkv allows the user to select and configure one or more backends to be used
when `simpkv::*` functions are called in Puppet manifests during catalog
compilation. The configuration is largely made via hieradata.

* Each backend has its own configuration.
* Each backend configuration block must specify simpkv plugin type (e.g.,
  ‘file’, ‘ldap’) and a user-provided instance identifier.

  * A plugin is a backend interface that actually affects the keystore operation
    when a `simpkv::*` function is called during a Puppet catalog compilation.
    For the ‘ldap' plugin, this will be the software that modifies key/value
    pairs stored in an LDAP server.
  * The same plugin can be used for multiple backend instances.
  * The combination of plugin type and instance identifier uniquely identifies
    a backend instance.

* Each backend configuration block may specify additional, plugin-specific
  configuration (such as LDAP server URL and port, TLS configuration,...).

### simpkv plugin internals (10,000 foot view)

Internally, simpkv constructs a plugin object for each unique backend, and uses
the plugin object to interface with it corresponding backend. When a
`simpkv::*` function is called, an internal adapter calls the plugin’s
corresponding API method with normalized arguments to affect the operation.
The adapter then  (de)normalizes the results of the operation and reports them
back to the calling `simpkv::*` function.

For example, for a `simpkv::put` operation using a LDAP plugin, the sequence of
operations is notionally as follows:

![simpkv Store Operation for Non-global Key](Use_of_LDAP_as_backend_for_simpkv/simpkv%20store%20operation.png)

Then, for a `simpkv::get` operation using a LDAP plugin, the sequence of operations is notionally as follows:

![simpkv Retrieve Operation for Non-global Key](Use_of_LDAP_as_backend_for_simpkv/simpkv%20retrieve%20operation.png)

#### Value normalization

One of the normalizations done by the simpkv adapter involves the value and
optional, user-provided metadata associated with a key. In a `simpkv::put`
operation, the simpkv adapter serializes a key’s value and optional metadata
into a single JSON string and then sends that to the plugin for storage in the
backend. Then, after a key’s information has been retrieved by a plugin during
a `simpkv::get` or `simpkv::list` operation, the simpkv adapter deserializes
each JSON string back into the key’s value and metadata objects before serving
the results back to the calling function. This encoding of a key’s value an
metadata into a single string with a known, parsable format is intended to
simplify backend operations.

The table below shows a few examples of the serialization for clarification.

<!-- could not get footnotes to work as advertised for GitHub markdown, so reverted to HTML -->

| Value Type | Serialization Example |
| ---------- | --------------------- |
| Basic value<sup id="origin1">[1](#footnote1)</sup> without metadata | `{"value":"the value","metadata":{}}`<br><br>`{"value":10,"metadata":{}}` |
| Basic value with user-provided metadata<sup id="origin3">[3](#footnote3)</sup> | `{"value":true,"metadata":{"optional":"user","extra":"data"}}` |
| Complex value<sup id="origin2">[2](#footnote2)</sup> with basic sub-elements with no user-provided metadata | `{"value":[1,2,3],"metadata":{}` |
| Binary value<sup id="origin4">[4](#footnote4)</sup> transformed by simpkv with no user-provided metadata | `{"value":"<Base64 string>","encoding":"base64","original_encoding":"ASCII-8BIT","metadata":{}"}` |

<b id="footnote1">1</b>: *Basic value* refers to a string, boolean, or numeric
value.[&crarr;](#origin1)

<b id="footnote2">2</b>: *Complex value* refers to an array or hash constructed
from basic values.[&crarr;](#origin2)

<b id="footnote3">3</b>: simpkv currently only supports metadata hashes
comprised of basic values.[&crarr;](#origin3)

<b id="footnote4">4</b>: simpkv currently provides limited support for binary
data.
  * simpkv attempts to detect when the value is Puppet Binary type, transforms it into Base64 and records the transformation with ‘encoding' and 'original_encoding' attributes in the JSON. It then uses those attributes to properly deserialize back to the binary on a retrieval operation.

 * simpkv does does not support binary data in arrays, hashes, or the metadata.
   [&crarr;](#origin4)

## LDAP Directory Information Tree design

### Requirements

* There must be one LDAP backend DIT for all SIMP application data.

  * This is distinct from the DIT containing user accounts data.
  * Data to be stored must include simpkv data.

  * Data to be stored may in the future include other application data, (e.g.,
    IP firewall data).

* The simpkv data must be a subtree of the DIT.
* The simpkv subtree must support partitioning the data into LDAP backend
  instances.
* The simpkv subtree must allow storage of per-LDAP-backend-instance global and
  environment-specific key/value entries.

  * Entries may be stored in subtrees within the LDAP instance subtree.
  * Each key/value entry must be a leaf node in the LDAP instance subtree.
  * The Distinguished Name (DN) to each key/value entry throughout the entire
    DIT must be unique.

* The JSON value of the key/value entry must be stored in some form in the
  key/value entry.

  * The key/value entry may have a single attribute containing the JSON-encoded
     value.

  * The key/value entry may have multiple attributes that map to the value’s
    JSON attributes.

* The tree must support efficient `simpkv::get`, `simpkv::exists`, and
  `simpkv::list` operations.

  * Folder and/or key objects may store data in attributes to leverage LDAP
    search capabilities.

  * The simpkv LDAP plugin should not have to retrieve the entire tree or
    subtree in order to fulfill any of these operations.

* Any custom schema attributeType or objectClass will be specified with an
  Object Identifier (OID) below the official
  [SIMP Object Identifier (OID)](http://www.oid-info.com/get/1.3.6.1.4.1.47012).

### Design Considerations

At first blush, the mapping of the logical simpkv tree structure into a LDAP
DIT appears to be straight forward, because LDAP is fundamentally a tree whose
leaf nodes hold data. For example, we could design a tree as follows:

* Use Organizations or Organizational Units to represent folders in a key path
  and other grouping (e.g., environments).

* Create a custom schema element with key name and value attributes to
  represent a key/value entry.

* Construct the DN for a key/value node using each part of the key path as a
  relative DN (RDN).

So, for a key path `production/app1/key1` the key/value pair could be found at
the DN `simpkvKey=key1,ou=app1,ou=production,ou=environments,<root DN for the backend instance>`, where `simpkvKey` is an attribute of a `simpkvEntry` LDAP
object used to store the key/value pair. Visually, this subtree in the DIT
would look something like the following:

![LDAP DIT snippet](Use_of_LDAP_as_backend_for_simpkv/LDAP%20DIT%20snippet.png)

Unfortunately, there is a nuance in 389DS that complicates that simple mapping:

**__389DS instances treat DNs as case invariant strings.__**

So, the key paths `production/app1/key1` and `production/App1/Key1` both
resolve to the same DN inside of 389DS, even though from simpkv’s perspective,
they were intended to be distinct. This unexpected collision in the backend
needs to be addressed either by simpkv or within the DIT itself.

### Root Tree

The proposed root tree to hold all SIMP data in LDAP is as follows:

![LDAP DIT root](Use_of_LDAP_as_backend_for_simpkv/LDAP%20DIT%20root.png)

This trivial root tree can be expanded in the future to hold data for other
Puppet applications or even site-specific data not associated with Puppet,
if necessary.

### simpkv Subtree Option 1

The simplest design option enforces DN case invariance by requiring all the
values of all attributes used in a DN for a key/value pair to be lowercase. In
other words, change the experimental simpkv API to only allow lowercase letters,
numerals, and `'.'`, `'_'`, `'-'`, and `'/'` characters  for all key names,
folder names, and plugin instance identifiers. Then, because each key’s DN is
unique and case invariant, the simple mapping scheme described in
[Design Considerations](#design-considerations) can be used.

With this simple mapping, the proposed simpkv LDAP subtree will look nearly
like that of the logical key/value tree. It just inserts a few extra "folders"
into the tree in order to clarify the roles of the nodes beneath it. The new
"folders" are

* 'instances' under which you will find an individual subtree for each backend
  instance

* 'globals' under which you will find a subtree for global keys for a backend
  instance

* 'environments' under which you will find individual subtrees for each Puppet
  environment for a backend instance.

Below is an example of the Option 1 DIT in which simpkvEntry is a custom LDAP
object class with `simpkvKey` and `simpkvJsonValue` attributes holding the key
and value, respectively:

![Option 1 LDAP DIT](Use_of_LDAP_as_backend_for_simpkv/Option%201%20LDAP%20DIT.png)

### simpkv Subtree Option 2

The second design option enforces DN case invariance without impacting the
existing simpkv API. Its simpkv subtree has the same essential layout as that of
Option 1, including the use of the 'instances', 'globals', and .environments'
grouping "folders". However, in this design

* The LDAP plugin transforms any problematic attributes that are to be used in a
  DN for a key/value pair to an encoded representation (e.g., hexadecimal,
  Base 64) . For example, with a hexadecimal transformation, all backend
  instance identifiers, key names, and folder names would be represented in hex,
  minus the '0x' or '0X' preface. (The Puppet environment does not require
  transformation, as Puppet environment names must be lowercase.)  So, key paths
  `production/app1/key1` and `production/App1/Key1` would be mapped to
  `simpkvHexId=61707031,simpkvHexId=6b657931,ou=production,ou=environments,...`
  and
  `simpkvHexId=41707031,simpkvHexId=4b657931,ou=production,ou=environments,...`
  respectively, where `simpkvHexId` is an attribute of both an LDAP object used
  to represent backend identifiers/folders and an LDAP object used to store the
  key/value pair.

* Each node with an encoded identifier RDN includes an attribute with the raw
  identifier. Although this means a little more data must be stored in the DIT,
  this extra information will support external searches of the LDAP tree using
  the raw backend instance identifiers, key names, and folder names. In other
  words, users can search the LDAP tree without being forced to mimic the
  transformations done in `simpkv::*` functions.

Below is an example of the Option 2 DIT in which

* `simpkvFolder` is a custom LDAP object class with `simpkvHexId` and `simpkvId`
  attributes holding the transformed backend identifier/folder and raw
  identifier/folder, respectively

* `simpkvEntry` is a custom LDAP object class with `simpkvHexId`, `simpkvId`
  and `simpkvJsonValue` attributes holding the transformed key, raw key and
  JSON-formatted value, respectively.

![Option 2 LDAP DIT](Use_of_LDAP_as_backend_for_simpkv/Option%202%20LDAP%20DIT.png)

### Recommendation

Option 1 is the recommended solution for the following reasons:

* It yields a DIT that is simple to understand and navigate.
* An API change is not unexpected for `simp/simpkv`, since it is still
  experimental (version < 1.0.0) and not enabled by default.
* SIMP can help users with the transition to lowercase key names for any
  existing simpkv key paths or `simplib::passgen` password names (whether using
  legacy mode or simpkv mode).

  * Any SIMP-provided module that uses simplib::passgen can be modified to
    ensure the password names are downcased.
  * The `simplib::passgen` function that uses simpkv can be modified to downcase
    existing password names that have any uppercase letters and then to emit a
    warning.
  * The script SIMP will provide to import any existing simpkv key entries or
    `simplib::passgen` passwords into a simpkv LDAP backend can check for
    uppercase letters in the destination key paths and either skip the import
    of the problematic entries, or convert to lowercase and warn the user of
    the conversion. Then, it would be up to the user to make any adjustments to
    the corresponding manifests.

## OID Subtree Design and Custom LDAP Schema

Either option for the LDAP DIT for SIMP data requires at least one custom LDAP
object class. The LDAP object class, in turn, must be specified by a unique OID.
This section proposes a SIMP OID subtree design to support LDAP OIDs and then
uses the OIDs in schemas for the two DIT options discussed above.

### SIMP OID Subtree

SIMP has an officially registered OID, 1.3.6.1.4.1.47012, under which all OIDs
for Puppet, SNMP, etc should reside. Once an OID is in use, its definition is
not supposed to change. In other words, an OID can be deprecated, but not
removed or reassigned a different name. So, the OID tree must be designed to
allow future expansion.

Below is the proposed SIMP OID subtree showing the parent OIDs for attributes
and class objects needed for the SIMP DIT.

![SIMP OID Tree](Use_of_LDAP_as_backend_for_simpkv/SIMP%20OID%20Tree.png)

### LDAP Custom Schema

#### simpkv DIT Option 1

The proposed custom schema for the simpkv DIT option 1 is shown below. It has a
custom object class, `simpkvEntry`, that is comprised of two custom attributes,
`simpkvKey` and `simpkvJsonValue`.

* `simpkvKey` is a case-invariant string for the key (excluding path)

  * This is used as the final RDN of the DN for a key/value node.

* `simpkvJsonValue` is a case-sensitive string for the JSON-formatted value.

  * In the future, we could write a custom syntax validator for this attribute.

```
################################################################################
#
dn: cn=schema
#
################################################################################
#
attributeTypes: (
  1.3.6.1.4.1.47012.1.1.1.1.1.1
  NAME 'simpkvKey'
  DESC 'key'
  SUP name
  SINGLE-VALUE
  X-ORIGIN 'SIMP simpkv'
  )
#
################################################################################
#
attributeTypes: (
  1.3.6.1.4.1.47012.1.1.1.1.1.2
  NAME 'simpkvJsonValue'
  DESC 'JSON-formatted value'
  EQUALITY caseExactMatch
  SUBSTR caseExactSubstringsMatch
  SYNTAX 1.3.6.1.4.1.1466.115.121.1.15
  SINGLE-VALUE
  X-ORIGIN 'SIMP simpkv'
  )
#
################################################################################
#
objectClasses: (
  1.3.6.1.4.1.47012.1.1.1.1.2.1
  NAME 'simpkvEntry'
  DESC 'simpkv entry'
  SUP top
  STRUCTURAL
  MUST ( simpkvKey $ simpkvJsonValue )
  X-ORIGIN 'SIMP simpkv'
  )
```

The corresponding SIMP OID subtree is as follows:

![SIMP OID subtree option 1](Use_of_LDAP_as_backend_for_simpkv/SIMP%20OID%20subtree%20option%201.png)

#### simpkv DIT Option 2

The proposed custom schema for the simpkv DIT option 2 is shown below. It has
two custom object classes and three custom attributes.

* Classes:

  * `simpkvFolder` is an object class for a node representing a backend
    identifier or folder.
  * `simpkvEntry` is an object class for a key/value node.

* Attributes:

  * `simpkvHexId` is an attribute that is a case-invariant, hex-encoded string
    for the backend identifier, folder or key (excluding path)

    * This is used as the final RDN of the DN for a node.
    * In the future, we could write a custom syntax validator for this
      attribute.

  * `simpkvId` is an attribute that is the raw, case-sensitive string for a
    backend identifier, folder or key (excluding path)

  * `simpkvJsonValue` is an attribute that is a case-sensitive string for a
    JSON-formatted value in a key/value node.

    * In the future, we could write a custom syntax validator for this
      attribute.

```
################################################################################
#
dn: cn=schema
#
################################################################################
#
attributeTypes: (
  1.3.6.1.4.1.47012.1.1.1.1.1.1
  NAME 'simpkvHexId'
  DESC 'hex-encoded backend instance, folder, or key name'
  SUP name
  SINGLE-VALUE
  X-ORIGIN 'SIMP simpkv'
  )
#
################################################################################
#
attributeTypes: (
  1.3.6.1.4.1.47012.1.1.1.1.1.2
  NAME 'simpkvId'
  DESC 'backend instance, key or folder name'
  EQUALITY caseExactMatch
  SUBSTR caseExactSubstringsMatch
  SYNTAX 1.3.6.1.4.1.1466.115.121.1.15
  SINGLE-VALUE
  X-ORIGIN 'SIMP simpkv'
  )
#
################################################################################
#
attributeTypes: (
  1.3.6.1.4.1.47012.1.1.1.1.1.3
  NAME 'simpkvJsonValue'
  DESC 'JSON-formatted value'
  EQUALITY caseExactMatch
  SUBSTR caseExactSubstringsMatch
  SYNTAX 1.3.6.1.4.1.1466.115.121.1.15
  SINGLE-VALUE
  X-ORIGIN 'SIMP simpkv'
  )
#
################################################################################
#
objectClasses: (
  1.3.6.1.4.1.47012.1.1.1.1.2.1
  NAME 'simpkvEntry'
  DESC 'simpkv entry'
  SUP top
  STRUCTURAL
  MUST ( simpkvHexId $ simpkvId $ simpkvJsonValue )
  X-ORIGIN 'SIMP simpkv'
  )
#
################################################################################
#
objectClasses: (
  1.3.6.1.4.1.47012.1.1.1.1.2.2
  NAME 'simpkvFolder'
  DESC 'simpkv folder in which simpKvHexId represents the relative folder name in hex in the DN'
  SUP top
  STRUCTURAL
  MUST ( simpkvHexId $ simpkvId )
  X-ORIGIN 'SIMP simpkv'
  )
```

The corresponding SIMP OID subtree is as follows:

![SIMP OID subtree option 2](Use_of_LDAP_as_backend_for_simpkv/SIMP%20OID%20subtree%20option%202.png)


## Technologies for Plugin Implementation

### Requirements

* Plugins are written in Ruby and implement the simpkv plugin API.
* Plugins must be multi-thread safe.
* Plugins must be written to provide Puppet-environment isolation when executed
  on the puppetserver.
* Manifests that use `simpkv::*` functions must be able to be compiled with
  puppet agent, puppet apply or Bolt commands. This means the plugin code will
  run in JRuby in the puppetserver, run in the Ruby installed with puppet-agent,
  or run using the Bolt user’s Ruby into which the puppet gem is installed.

### Options Considered

| Option  | PROs | CONs |
| ------- | ---- | ---- |
| Tools provided by openldap-utils RPM | <ul><li>Existing, signed, vendor RPM.</li><li>Package will already be installed on host operating as the simpkv LDAP server.</li><li>Supports ldapi interface, which is faster than ldap/ldaps, while still being secure.</li></ul> | <ul><li>Requires openldap-utils RPM to be installed on host executing Bolt compiles.</li><li>To take advantage of ldapi either have to educate user on when ldapi should be configured OR create internal auto-ldapi-detection logic to use the ldapi interface when it is available <--> complexity.</li></ul> |
| net-ldap Ruby gem | User can install gem without sysadmin support, when not on isolated network. | <ul><li> Requires gem RPM packaging for use on isolated networks (e.g., simp-vendored-net-ldap RPM)</li><li> Requires gem installation into the puppetserver</li><li>Does not support ldapi.</li></ul> |
| Support both tools provided by openldap-utils and net-ldap Ruby gem, using whichever it discovers is available | More installation flexibility when not on isolated networks. | <ul><li> Increased code+test complexity.</li><li> Still has gem packaging issues on isolated systems for Bolt users.</li><li> User still needs to know when ldapi can be used, unless auto-discovery mechanism is built.</li></ul> |

### Recommendation

Option 1 without the auto-discovery mechanism is recommended for the following reasons:

* Options 2 and 3 require additional packaging in order to work on isolated
  networks for Bolt users. So, if you are going to require a Bolt user to
  install a package, anyways, might as well be an existing vendor package.
* The auto-discovery mechanism can be added after the initial implementation,
  because it is not required for the LDAP plugin to function.
