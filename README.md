# authkeys

This is intended to be used as an `AuthorizedKeysCommand` for OpenSSH. LDAP connection options are read from
`sssd.conf`. Only sssd configuration file format version 2 is supported, and only the following options are
read:

  * `ldap_uri`
  * `ldap_search_base`
  * `ldap_access_filter`
  * `ldap_id_use_start_tls`

Unencrypted, STARTTTLS and SIMPLE_TLS are supported.

In particular this means that `ldap_default_bind_dn`, `ldap_default_authtok_type` and `ldap_default_authtok` are
currently unsupported and thus only anonymous bind works. SSH keys are expected to be in the attribute `sshPublicKey`.

Initially written as a programming language comparison challenge/demonstration. LDAP access provided by
[this Shard](https://github.com/spider-gazelle/crystal-ldap).

To build first [install Crystal](https://crystal-lang.org/install/) then install dependencies and build in one step:

    shards build --release

The binary will be output to `bin/authkeys`.
