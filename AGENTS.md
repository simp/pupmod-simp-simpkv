# AGENTS.md

This file provides guidance to AI agents when working with code in this repository.

## What this module does

`simp-simpkv` is SIMP's **abstract key/value store API** for Puppet. It gives
manifests a small, backend-agnostic set of Puppet functions
(`simpkv::put`/`simpkv::get`/`simpkv::delete`/`simpkv::exists`/`simpkv::list`/
`simpkv::deletetree`) for storing and retrieving arbitrary data, while the
actual storage is provided by a **pluggable backend** selected at catalog
compile time. The module ships two backends — a local-filesystem `file` plugin
(`lib/puppet_x/simpkv/file_plugin.rb`) and an `ldap` plugin
(`lib/puppet_x/simpkv/ldap_plugin.rb`) — and any other module can contribute
more by dropping a `*_plugin.rb` under its own `lib/puppet_x/simpkv/`.

This is a **pure library module**: there are no manifests, classes, defines,
types, `data/`, or `templates/` (`ls` of the repo root — the only code lives
under `lib/`). Everything is Ruby: the public API is a set of Puppet functions
in `lib/puppet/functions/simpkv/`, and the framework/adapter machinery is in
`lib/puppet_x/simpkv/`.

There is **no `simp_options` seam** in this module. Unlike most SIMP modules,
`simpkv` performs no `simplib::lookup('simp_options::*', …)` calls — there are
no `simp_options::` references anywhere in the source (verified: `grep -rn
'simp_options::'` over `*.pp`/`*.rb`/`*.yaml` returns nothing). Configuration is
read from the `simpkv::options` Hiera key instead (see below).

### Business logic

The public API is six Puppet functions, each a thin, uniform wrapper. Using
`simpkv::get` as the template (`lib/puppet/functions/simpkv/get.rb`), every
function does the same three-step dance (`get.rb`):

1. **Validate the key** — `call_function('simpkv::support::key::validate', key)`
   (`get.rb`).
2. **Load the adapter** — `call_function('simpkv::support::load')`
   (`get.rb`), which attaches a `simpkv` adapter object to the catalog if
   one is not already present.
3. **Merge + validate config, then delegate** — build `merged_options` via
   `simpkv::support::config::merge` (`get.rb`) and call the
   corresponding method on `catalog.simpkv` (`get.rb`), unwrapping the
   `{ :result, :err_msg }` results Hash.

The public functions and their signatures / return contracts:

- **`simpkv::put`** (`put.rb`) — `(String[1] key, NotUndef value, [Hash
  metadata], [Hash options])` → `Boolean`. Serializes `value`+`metadata` and
  stores them. Returns `true` on success; `false` only when the op failed *and*
  `softfail` is set (`put.rb`).
- **`simpkv::get`** (`get.rb`) — `(String[1] key, [Hash options])` →
  `Enum[Hash,Undef]`. Returns `{ 'value' => …, 'metadata' => … }` (the
  `'metadata'` key is omitted when empty, `get.rb`); `Undef` on a
  soft-failed op.
- **`simpkv::delete`** (`delete.rb`) — `(String[1] key, [Hash options])` →
  `Boolean`.
- **`simpkv::deletetree`** (`deletetree.rb`) — `(String[1] keydir, [Hash
  options])` → `Boolean`. Removes a whole key folder.
- **`simpkv::exists`** (`exists.rb`) — `(String[1] key, [Hash options])`
  → `Enum[Boolean,Undef]`. `Undef` when existence could not be determined and
  `softfail` is set.
- **`simpkv::list`** (`list.rb`) — `(String[1] keydir, [Hash options])`
  → `Enum[Hash,Undef]`. Returns `{ 'keys' => {…}, 'folders' => [...] }` for the
  folder; **non-recursive** (`list.rb`).

The `options` Hash is the same across all six functions (documented identically
in each docstring, e.g. `get.rb`):

- **`app_id`** — fuzzy backend selector. When `backend` is absent, the adapter
  picks the backend whose name exactly matches `app_id`, else the longest
  backend name that is a prefix of `app_id`, else `default`
  (`support/config/merge.rb`).
- **`backend`** — definitive backend name; takes precedence over `app_id`. Must
  be a key in `backends` or the call fails.
- **`backends`** — Hash of backend configs; each entry needs a `type` (which
  plugin) and an `id` (unique instance name of that plugin type).
- **`global`** — `false` (default) namespaces the key under the node's Puppet
  environment; `true` namespaces it globally (`simpkv.rb`).
- **`softfail`** — `false` (default) makes a failed backend op raise; `true`
  downgrades it to a `Puppet.warning` and a benign return value.

Support functions (`lib/puppet/functions/simpkv/support/`):

- **`simpkv::support::key::validate`** (`support/key/validate.rb`) — the
  key spec. Keys may contain only `[a-z0-9._:\-/]` (`validate.rb`), may not
  contain whitespace (`validate.rb`), and may not contain `/./` or `/../`
  sequences (`validate.rb`). Raises `ArgumentError` on violation.
- **`simpkv::support::config::merge`** (`support/config/merge.rb`) —
  deep-merges the caller's `options` **on top of** the `simpkv::options` Hiera
  Hash (`merge.rb`), resolves `backend` from `app_id` (`merge.rb`),
  defaults `softfail`/`global` to `false` (`merge.rb`), injects the
  internal `environment` option from the compiler
  (`merge.rb`), and — **when no `backends` are configured at all** — injects
  a single `default` backend of `type => 'file', id => 'auto_default'`
  (`merge.rb`). Then validates.
- **`simpkv::support::config::validate`** (`support/config/validate.rb`) —
  asserts `backend`/`backends` are present and well-formed, that the selected
  backend's `type` has a loaded plugin (`validate.rb`), and that any two
  backend entries sharing a `<type>/<id>` pair have *identical* config
  (`validate.rb`).
- **`simpkv::support::load`** (`support/load.rb`) — see the adapter note
  below.

### The adapter / plugin architecture (the interesting part)

The framework goes to unusual lengths to avoid cross-Puppet-environment Ruby
contamination in a long-lived puppetserver, and to allow new plugin code to load
without a puppetserver restart. Understand this before touching `lib/puppet_x/`:

- **The adapter is attached to the catalog, not to a Ruby constant.**
  `simpkv::support::load` (`support/load.rb`) checks whether the catalog
  already `respond_to?(:simpkv)`; if not, it `instance_eval`s
  `lib/puppet_x/simpkv/loader.rb` **in the context of the catalog object**.
- **`loader.rb`** (`loader.rb`) defines `simpkv`/`simpkv=` singleton
  accessors on the catalog, `instance_eval`s `simpkv.rb` to obtain an
  **anonymous** adapter `Class`, and stores a fresh instance on the catalog.
  Everything is anonymous classes loaded via `instance_eval` on purpose
  (`loader.rb`) — that is what isolates environments.
- **`simpkv.rb`** (`simpkv.rb`) is the adapter. On construction
  (`simpkv.rb`) it globs **every module's**
  `*/lib/puppet_x/simpkv/*_plugin.rb` (`simpkv.rb`), `instance_eval`s each
  to get an anonymous `plugin_class` (`simpkv.rb`), and registers it by
  **plugin type = the base filename minus `_plugin.rb`** (`simpkv.rb`).
  **Only the first plugin found for a given type wins**; a second is skipped with
  a warning (`simpkv.rb`).
- **Per-catalog, per-`<type>/<id>` plugin instances.** `plugin_instance`
  (`simpkv.rb`) lazily constructs and caches one plugin instance per
  `<type>/<id>` name and calls its `configure(options)` once
  (`simpkv.rb`).
- **Key namespacing happens in the adapter, not the plugin.** `normalize_key`
  (`simpkv.rb`) prefixes keys with `globals/` for global keys or
  `environments/<env>/` otherwise, then `Pathname#cleanpath`s away redundant
  slashes. The adapter adds the prefix before calling the plugin and strips it
  from `list` results (`simpkv.rb`).
- **Serialization is the adapter's job, not the plugin's.** Plugins only ever
  see/return **Strings** (`plugin_template.rb`). The adapter serializes
  value+metadata to JSON on `put` (`simpkv.rb`) and deserializes on
  `get`/`list` (`simpkv.rb`), including base64-encoding binary
  (ASCII-8BIT) strings (`simpkv.rb`).
- **The plugin contract** is spelled out in `lib/puppet_x/simpkv/plugin_template.rb`
  — the canonical starting point for a new backend. Required instance methods:
  `initialize(name)`, `configure(options)`, `name`, and
  `delete`/`deletetree`/`exists`/`get`/`list`/`put`, each returning a
  `{ :result, :err_msg }` Hash (`plugin_template.rb`).

### Gotchas / non-obvious details

- **No `simp_options` seam.** Do not add `simplib::lookup('simp_options::*')`
  calls or invent a config table — this module reads only `simpkv::options`
  Hiera (`merge.rb`). (Contrast with most SIMP modules.)
- **No default dependency on `simp/simplib`.** The only declared dependency is
  `puppetlabs/stdlib` (`metadata.json`). The heavy lifting is plain Ruby.
- **`file` is the implicit fallback backend.** With no `backends` configured,
  every op silently uses a local-filesystem `file` backend named
  `file/auto_default` (`merge.rb`) — data may land on the *puppetserver's*
  filesystem without any explicit config.
- **Plugin type is derived from the filename**, and only the first of a given
  type loads (`simpkv.rb`). Two modules shipping `file_plugin.rb` will
  collide; the second is ignored with a warning.
- **Everything under `lib/puppet_x/simpkv/` is anonymous-class-by-design.** You
  cannot use Ruby constants or class methods inside a plugin's anonymous class
  (`plugin_template.rb`) — they attach to the `Class` object, not the
  instance. This trips up normal-looking Ruby.
- **`softfail` changes the return type, not just the log level.** On a failed op
  with `softfail => true`, `get`/`exists`/`list` return `Undef` and
  `put`/`delete`/`deletetree` return `false`, rather than aborting compilation
  (`get.rb`, `put.rb`). Callers must handle the sentinel.
- **`serialize`/`deserialize` are explicitly "limited, prototype-grade."** The
  code carries `FIXME`s to switch to Puppet's own (de)serialization
  (`simpkv.rb`); binary data nested inside Hash/Array values is
  not reliably handled (`simpkv.rb`).
- **`list` is non-recursive** (`list.rb`) — it returns only the immediate
  keys and sub-folder names of one folder.

## The `simp_options` / `simplib::lookup` seam

**N/A for this module.** simpkv has no `simp_options::*` lookups (verified by
grep — no matches in any `.pp`/`.rb`/`.yaml`). Its only tunable is the
`simpkv::options` Hiera Hash, read once in
`simpkv::support::config::merge` (`merge.rb`) and deep-merged under the
per-call `options` argument. Do not add a `simp_options` seam here.

## Dependencies

Module dependency (from `metadata.json`) — the **only** one:

- `puppetlabs/stdlib` `>= 8.0.0 < 10.0.0`.

There are **no optional dependencies** (no `simp.optional_dependencies` in
`metadata.json`) and, notably, **no runtime dependency on `simp/simplib`**.

Runtime requirement (from `metadata.json` `requirements`): `puppet
>= 7.0.0 < 9.0.0` — this is an older baseline than most current SIMP modules and
names **puppet** (not `openvox`). (SIMP is migrating Puppet → OpenVox; when
`metadata.json` switches this to `openvox`, update this line to match.)

Supported OS matrix (from `metadata.json`): CentOS 7/8/9; RedHat 7/8/9;
Rocky 8/9; AlmaLinux 8/9; OracleLinux 8/9.

## Repository layout

- `lib/puppet/functions/simpkv/*.rb` — the six public API functions
  (`get`, `put`, `delete`, `deletetree`, `exists`, `list`).
- `lib/puppet/functions/simpkv/support/` — internal support functions:
  `load.rb`, `config/merge.rb`, `config/validate.rb`, `key/validate.rb`.
- `lib/puppet_x/simpkv/simpkv.rb` — the anonymous adapter class (plugin
  loading, key normalization, JSON (de)serialization, delegation).
- `lib/puppet_x/simpkv/loader.rb` — attaches the adapter to the catalog via
  `instance_eval` (environment-isolation shim).
- `lib/puppet_x/simpkv/plugin_template.rb` — the copy-me template documenting
  the backend plugin contract.
- `lib/puppet_x/simpkv/file_plugin.rb` — local-filesystem backend.
- `lib/puppet_x/simpkv/ldap_plugin.rb` — LDAP backend.
- `spec/functions/simpkv/…` — rspec-puppet unit tests for every public and
  support function.
- `spec/unit/puppet_x/simpkv/…` — unit tests for the adapter and the two
  plugins (`simpkv_spec.rb`, `file_plugin_spec.rb`, `ldap_plugin_spec.rb`).
- `spec/acceptance/` — beaker suites: `default` (file plugin), `ldap_plugin`,
  and `multiple_plugins`, plus shared examples and helper modules under
  `spec/support/modules/` (including deliberately broken test plugins under
  `test_plugins1`/`test_plugins2`).
- `spec/acceptance/nodesets/` — **4** top-level nodeset files: `centos7.yml`,
  `default.yml`, `oel7.yml`, `oel.yml` (each acceptance suite also carries its
  own `nodesets/`).
- `docs/` — design and LDAP-backend documentation, plus the plugin development
  guide (`docs/simpkv_plugin_development_guide.md`).
- `README.md` / `REFERENCE.md` — user docs and the generated Puppet Strings
  reference.
- `metadata.json` — dependency (`stdlib` only), OS matrix, Puppet requirement.
- No `manifests/`, `types/`, `data/`, or `templates/` — this is a pure Ruby
  library module with no Puppet classes, defines, custom data types, module
  data, or templates.
- **Acceptance does NOT run in CI.** `.github/workflows/pr_tests.yml` runs only
  the 6 standard jobs — Puppet Syntax, Puppet Style, Ruby Style, File checks,
  RELENG checks, and Puppet Spec (unit) — with no `acceptance` job. Run the
  beaker suites locally.

## Common commands

```sh
# Install dependencies
bundle install

# Run all unit tests (functions + puppet_x adapter/plugins)
bundle exec rake spec

# Run a single function's spec
bundle exec rspec spec/functions/simpkv/get_spec.rb

# Run the adapter unit spec
bundle exec rspec spec/unit/puppet_x/simpkv/simpkv_spec.rb

# Puppet lint
bundle exec rake lint

# Ruby lint
bundle exec rake rubocop

# Regenerate REFERENCE.md from puppet-strings docstrings
bundle exec puppet strings generate --format markdown --out REFERENCE.md

# Run a beaker acceptance suite (NOT run in CI — run locally)
bundle exec rake beaker:suites[default]
bundle exec rake beaker:suites[ldap_plugin]
bundle exec rake beaker:suites[multiple_plugins]
```

Relevant gem pins (from `Gemfile`): the Puppet gem is installed **on its own**
via `gem 'puppet', puppet_version` (`Gemfile`) with `puppet_version`
defaulting to `['>= 7', '< 9']` (`Gemfile`) — this module installs the
`puppet` gem, not `openvox`. Other pins: `rubocop ~> 1.88.0` (`Gemfile`),
`puppetlabs_spec_helper ~> 8.0.0` (`Gemfile`), `simp-rake-helpers ~> 5.24.0`
(`Gemfile`), `simp-beaker-helpers ~> 2.0.0` (`Gemfile`).
`spec/spec_helper.rb` requires `puppetlabs_spec_helper/module_spec_helper`.

## Conventions

- **Preserve the puppet-strings docstrings** on every function — the `@param`,
  `@option`, `@return`, `@raise`, and `@example` blocks drive `REFERENCE.md`.
  Regenerate `REFERENCE.md` after changing any docstring or signature.
- **Keep the `options` documentation identical across all six public
  functions** — the `app_id`/`backend`/`backends`/`global`/`softfail` option
  block is duplicated verbatim in each (e.g. `get.rb`, `put.rb`);
  update them together.
- **Route new business logic through the support functions**, mirroring the
  validate-key → load → merge-config → delegate pattern used by every public
  function (`get.rb`); don't reach into the adapter directly.
- **New backends go in `lib/puppet_x/simpkv/<type>_plugin.rb`** and must follow
  `plugin_template.rb` exactly: an anonymous `plugin_class`, no constants/class
  methods, String-only key values, `{ :result, :err_msg }` returns, and its own
  exception handling / retry / timeout logic.
- **Do not add a `simp_options` seam or a `simp/simplib` dependency.** This
  module intentionally has neither.
- Several baseline files carry a **puppetsync** notice — e.g. `Gemfile`, `spec/spec_helper.rb`, `.github/workflows/pr_tests.yml`, and the `.gitignore`/`.pdkignore` dotfiles — so they are baseline-managed and the next sync overwrites local edits. Check each file's header for the notice rather than treating this list as exhaustive; push changes to any such file upstream to the baseline, not here.
- Match the existing Ruby style enforced by the pinned `rubocop` (`.rubocop.yml`).
