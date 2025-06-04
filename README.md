# Bitwarden CLI Bash backup & restore

A couple of simple bash scripts to backup and restore a Bitwarden vault,
including attachments.

## Prerequisites:

  * Bitwarden cli (bw) in path

  * jq

  * Vault to backup (or to restore to) unlocked (and BW_SESSION environment
    variable properly set).

  * gnupg correctly configured with a keypair already created, and environment
    variable MYPGPKEY set to it's KEY-ID.


## Backup script:

It does an export in json and, optionally, csv formats (csv could be useful in
case that one would like to import it into another password manager).

It also retrieves attachments and stores them in a tar file (that tar file also
contains a json list of the items those attachments belong to, used when
restoring them).

It exports the personal vault and also all the organization vaults of which the
account is a confirmed owner or admin.

All of the backup files are encrypted with GPG to the key-id set in MYPGPKEY
environment variable. Those encrypted files are also signed with that same key
(there is an option not to sign them, in case the secret key is not available
atm.).

### About **organization** vault backups:

> [!IMPORTANT]
As mentioned, to be able to backup an organization vault, the account must be a
confirmed owner or admin of that organization. All organization vault items
will be exported (even if they are in a collection the account has no access
to, regardless of the organization setting “_Owners and admins can manage all
collections and items_”).

> [!WARNING]
**HOWEVER**, the attachments in organization items the account has NO access
to, **WILL NOT BE BACKED UP**; again, regardless of that organization setting
“_Owners and admins can manage all collections and items_”. Attachments from
items that are not assigned to any collection (the ones that can be found in
the "Unassigned" collection on the admin console) **ALSO WILL NOT BE BACKED
UP**.

> [!TIP]
To guarantee that the backup will be 100% complete, the account should have
access to ALL the collections in the organization(s), besides being an owner or
admin of that(those) organization(s). And any item in the "Unassigned"
collection should not have attachments.

Credit: Attachments export part _based on_
[ckabalan / bitwarden-attachment-exporter](https://github.com/ckabalan/bitwarden-attachment-exporter/).


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

> [!TIP]
If one should need to restore more than one organization vault, a manual import
via the admin console can be done. After that, the restore vault attachments
script can be run with all the attachments backup files as arguments.

> [!WARNING]
While folders and items belonging to them are fully exported in the json file,
there is an important caveat to take into account regarding organization items
included in folders: When you import an exported vault into an organization
vault, all items should be fully imported; **HOWEVER**, the imported items will
not be included into the folders they belonged to when they were exported.


## Restore attachments script:

It should be called with the files containing the attachments backups as
arguments. It uploads those attachments to the items in the currently unlocked
vault.

  * It uses the items.json file to find which item in the new vault every
    attachment belongs to (note that the item_id on the export can be different
    from the item_id in the destination vault).

  * If the destination item alredy has attachments, then it does not restore
    them (to prevent duplicates).

  * To restore attachments, the account does not need to be admin or owner of
    any organization, BUT it does need to have access to the items those
    attachments belong to.


## TODO:

Bitwarden CLI, since version 2025.5.0, supports exporting in zip format; that
includes attachments in the exported zip file.

I plan on adding support for this new format to these scripts (on backup and
also on restore). But I will probably wait after Bitwarden releases a CLI
version that includes [this
PR](https://github.com/bitwarden/clients/pull/14400).

And, **maybe**, also until the export zip format is supported on organization
vaults.
