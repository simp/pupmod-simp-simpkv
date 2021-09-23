#### Table of Contents

<!-- vim-markdown-toc GFM -->

* [Module Description](#module-description)
* [Usage](#usage)
* [Limitations](#limitations)
* [Reference](#reference)

## Module Description

This is a module to test the simpkv function API. It uses Puppet manifests
to exercise all the simpkv functions and to verify the values stored in
each backend are correct. Specifically, it provides manifests that

* store keys using `simpkv::put`
* remove keys using `simpkv::delete`
* remove folders using `simpkv::deletetree`
* verify the existence of key/folder names using `simpkv::exists`
* verify keys can be retrieved using `simpkv::get` and that the retrieved
  key data is correct
* verify folder listings can be retrieved using `simpkv::list` and that the
  retrieved list data is correct

## Usage

Usage of this module is fairly straight forward:

* Include `simpkv_test::store_keys`, `simpkv_test::remove_keys`, or
  `simpkv_test::remove_folders` to modify the state of one or more backends

  * These manifests use `simpkv::put`, `simpkv::delete`, and
    `simpkv::deletetree`, respectively.

* Include `simpkv_test::verify_keys_exist` and `simpkv_test::verify_folders_exist`
  to verify that keys/folders are present or absent after the backend state
  has been modified.

  * These manifests use `simpkv::exists`.

* Include `simpkv_test::retrieve_and_verify_keys` and
  `simpkv_test::retrieve_and_verify_folders` to retrieve and verify the
  keys/folders information after the backend state has been modified.

  * These manifests use `simpkv::get` and `simpkv::list`, respectively.

All key/folder information required by the manifests is driven by hieradata.

For each key, this may include:

* The key's name
* The key's value or a file containing its binary value
* The key's metadata
* The `app_id` to be used in the `simpkv::*` function calls for this key
  or '' when no `app_id` is to be specified.
* Whether the keyis is a Puppet-environment key or a global key.

For each folder, this may include:

* The folder's name
* The key information for each key in the folder
* The list of subfolder names
* The `app_id` to be used in the `simpkv::*` function calls for this folder
  or '' when no `app_id` is to be specified.
* Whether the folder is is a Puppet-environment folder or a global folder.

IMPORTANT:
`simpkv::*` functions map `app_id` to the configured backend, or select the
'default' backend when no `app_id` is specified. To ensure uniqueness of test
keys, the data structures in this module are designed **assuming**, each
configured backend is uniquely mapped to the `app_id`.

If your test setup violates this assumption, you use the same key name and
global status for different `app_ids`, and those `app_ids` map to the same
backend, the *last operation executed for that key name will determine its
state*.

## Limitations

* This test module verifies the simpkv function API is self-consistent, but
  does not verify that the key data is actually stored in the correct location
  in the desired backends.

  * The `simp-simpkv` module's acceptance test infrastructure uses
    plugin-specific verification, in addition to the verifiction provided by
    this module for full plugin verification!

* This module only supports validation of Binary key data in `simpkv::get`
  function call results.  It does not support validation of Binary key data
  in `simpkv::list` function call results.

## Reference

See [REFERENCE.md](./REFERENCE.md) for reference documentation.
