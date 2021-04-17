# authkeys

This is intended to be used as an `AuthorizedKeysCommand` for OpenSSH. LDAP connection options are read from
`sssd.conf`. `authkeys` talks directly to LDAP and thus is not subject to the `sssd` caching policies from which
`sss_ssh_authorizedkeys` suffers.

Only sssd configuration file format version 2 is supported, and only the following options are
read:

  * `ldap_uri`
  * `ldap_search_base`
  * `ldap_access_filter`
  * `ldap_user_ssh_public_key`
  * `ldap_id_use_start_tls`
  * `ldap_default_bind_dn`
  * `ldap_default_authtok`

Unencrypted, START_TLS and SIMPLE_TLS are supported. (Although note that `sssd` does not support unencrypted connections.)

In particular this means that `ldap_default_authtok_type` is ignored and thus the `obfuscated_password` type is
not supported.

Initially written as a programming language comparison challenge/demonstration. LDAP access provided by
[this Shard](https://github.com/spider-gazelle/crystal-ldap).

To build first [install Crystal](https://crystal-lang.org/install/) then install dependencies and build in one step:

    shards build --release

The binary will be output to `bin/authkeys`. Copy this somewhere sensible (for example `/usr/sbin/authkeys`)
then add this line to `/etc/ssh/sshd_config`:

    AuthorizedKeysCommand /usr/sbin/authkeys
