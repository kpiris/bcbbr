# Bitwarden CLI Bash backup & restore

A couple of simple bash scripts to backup and restore a Bitwarden vault,
including attachments.

## Prerequisites:

  * bitwarden cli (bw) in path

  * jq

  * vault to backup (or to restore to) unclocked and BW_SESSION environment
    variable correctly set.

  * gpg correctly configured with a keypair already created, and environment
    variable MYPGPKEY set to it's KEY-ID.


## Backup script:

It does an export both in json and csv formats (csv is for the case that one
would like to import the backup into another password manager).

It also retrieves attachments and stores them in a tar file (that tar file also
contains a json export of the items those attachments belong to, used when
restoring them).

It exports the personal vault and also tries to export all the organization
vaults the account has access to.

All of the backup files are encrypted with GPG to the key-id set in MYPGPKEY
environment variable. Those encrypted files are also signed with that same key.


## Restore vault script:

Locates the latest export on the exports directory and imports it on the
currently unlocked vault. It checks that this destination vault is completely
empty before importing (to prevent duplicating items).

Also tries to import an organization export to the only organization vault the
account should have access to.

After importing the vault(s) it tries to restore the attachments backups
present on that exports directory.


## Restore attachments script:

It should be called with the files containing the attachments backups as
arguments. It imports those attachments to the items in the currently unlocked
vault.

  * It uses the items json export to find which item in the new vault every
    attachment belongs to.

  * If the destionation item alredy has attachments, then it does not restore
    them (to prevent duplicates).

