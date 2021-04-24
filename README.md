# authkeys

This is intended to be used as an `AuthorizedKeysCommand` for OpenSSH. LDAP connection options are read from
`sssd.conf`. `authkeys` talks directly to LDAP and thus is not subject to the `sssd` caching policies from which
`sss_ssh_authorizedkeys` suffers. If you don't have an existing `sssd.conf` a sample is provided containing the minimal options needed by `authkeys` which should be modified and specified with the `-c` option.

Only sssd configuration file format version 2 is supported, and only the following options are
read:

  * `id_provider` (must be `ldap`)
  * `ldap_uri`
  * `ldap_search_base`
  * `ldap_access_filter`
  * `ldap_user_ssh_public_key`
  * `ldap_id_use_start_tls`
  * `ldap_default_bind_dn`
  * `ldap_default_authtok`
  * `ldap_search_timeout`

`ldap://`, `ldaps://` and `ldap://`-with-STARTTLS connections are supported. (Although note that `sssd` does not support `ldap://` connections without STARTTLS.) If an `ldaps://` URI is given then `ldap_id_use_start_tls` is ignored.

In particular this means that `ldap_default_authtok_type` is ignored and thus the `obfuscated_password` type is
not supported. `ldap_search_timeout` is used to set various connection timeouts.

To build first [install Crystal](https://crystal-lang.org/install/) then install dependencies and build in one step:

    shards build --release

The binary will be output to `bin/authkeys`. Copy this somewhere sensible (for example `/usr/sbin/authkeys`)
then add this line to `/etc/ssh/sshd_config`:

    AuthorizedKeysCommand /usr/sbin/authkeys

With the exception of the `--help` option, `authkeys` outputs only SSH keys to standard output, and nothing to standard error (except when it crashes, in which case please report a bug). Errors, if any, are sent to syslog, even when run at the command line. If errors result in a failure to fetch SSH keys then `authkeys` outputs nothing.

Initially written as a programming language comparison challenge/demonstration. LDAP access provided by
[this Shard](https://github.com/spider-gazelle/crystal-ldap).
