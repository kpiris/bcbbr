# Bitwarden CLI Bash backup & restore

A couple of simple bash scripts to backup and restore a Bitwarden vault,
including attachments.

## Prerequisites:

  * Bitwarden cli (bw) in path

  * jq

  * Vault to backup (or to restore to) unlocked (and BW_SESSION environment
    variable correctly set).

  * gpg correctly configured with a keypair already created, and environment
    variable MYPGPKEY set to it's KEY-ID.


## Backup script:

It does an export both in json and csv formats (csv is for the case that one
would like to import the backup into another password manager).

It also retrieves attachments and stores them in a tar file (that tar file also
contains a json list of the items those attachments belong to, used when
restoring them).

It exports the personal vault and also tries to export all the organization
vaults of which the account is a confirmed owner or admin.

All of the backup files are encrypted with GPG to the key-id set in MYPGPKEY
environment variable. Those encrypted files are also signed with that same key.

IMPORTANT (about organization vault backups):

As mentioned, to be able to backup an organization vault, the account must be a
confirmed owner or admin of that organization. All organization vault items
will be exported (even if they are in a collection the account has no access
to, regardless of the organization setting “Owners and admins can manage all
collections and items”).

HOWEVER, the attachments in items belonging to any collection the account has
no access to WILL NOT BE EXPORTED, again, regardless of that organization
setting “Owners and admins can manage all collections and items”.


## Restore vault script:

Locates the latest export on the exports directory and imports it on the
currently unlocked vault. It checks that this destination vault is completely
empty before importing (to prevent duplicating items).

Also tries to import an organization export to the only organization vault the
account should be a confirmed owner or admin of.

After importing the vault(s) it tries to restore the latest attachments backup
present on the exports directory. If the account is a confirmed owner or admin
of one and only one organization, it also tries to restore the latest
organization attachments backup present in the exports directory.


## Restore attachments script:

It should be called with the files containing the attachments backups as
arguments. It imports those attachments to the items in the currently unlocked
vault.

  * It uses the items.json export to find which item in the new vault every
    attachment belongs to (note that the item_id on the export can be different
    from the item_id in the destination vault).

  * If the destination item alredy has attachments, then it does not restore
    them (to prevent duplicates).

  * To restore attachments, the account does not need to be admin or owner of
    any organization, BUT it needs to have access to the items those
    attachments belong to.


