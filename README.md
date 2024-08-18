BitwardenCLI Bash Backup & restore

A couple of simple bash scripts to backup and restore a Bitwarden Vault, including attachments.

Prerequisites:

  * bitwarden cli (bw) in path
  * vault to backup (or to restore to) unclocked and BW_SESSION environment variable correctly set.
  * gpg correctly configured with a keypair already created, and environment variable MYPGPKEY set to it's KEY-ID.
