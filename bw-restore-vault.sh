#! /bin/bash -e

################################################################################

echo2 () {
    echo "$*" >&2
}

abort () {
    echo2 "$*"
    exit 2
}

echoprompt () {
    echo2 ""
    echo2 "$ $*"
}

################################################################################

export EXPORTSDIR="/dev/shm/"
if [ "${1}" != "" ] ; then
    EXPORTSDIR="$(realpath ${1})"
fi
if [ "${EXPORTSDIR}" == "" ] || [ ! -d "${EXPORTSDIR}" ] ; then
    exit 1
fi
export BWSTATUS="$(bw status)"
export BWSTATUS_LOGIN="$(echo "${BWSTATUS}" | jq -r '.status')"
if [ "${BWSTATUS_LOGIN}" != "unlocked" ] ; then
    abort "ERROR: a vault must be unlocked (\`${BWSTATUS}')."
fi

umask 0077
bw sync

LASTEXPORT_VAULT_PER="$(ls -1rt ${EXPORTSDIR}/bitwarden_????????-????-????-????-????????????_export_??????????????.json.gpg | tail -1)"
if [ "${LASTEXPORT_VAULT_PER}" != "" ] ; then
    if [ -e "${LASTEXPORT_VAULT_PER}.sign" ] ; then
        echoprompt "gpg --verify ${LASTEXPORT_VAULT_PER}.sign"
        gpg --verify ${LASTEXPORT_VAULT_PER}.sign
    fi
    if [ "$(bw list items --organizationid null)" != "[]" ] ; then
        echo2 "WARNING: Destination personal vault is not empty."
    else
        echo2 "INFO: personal vault is empty. OK."
        if [ "$(bw list items --organizationid null --trash)" != "[]" ] ; then
            echo2 "WARNING: Destination personal vault trash is not empty."
        else
            echo2 "INFO: personal vault trash is empty. OK."
            TMPFILE_PER="$(mktemp -p /dev/shm/ -t bw-vault2restore-personal.XXXXXX)"
            echoprompt "gpg -d ${LASTEXPORT_VAULT_PER} > ${TMPFILE_PER}"
            gpg -d ${LASTEXPORT_VAULT_PER} > ${TMPFILE_PER}
            echoprompt "bw import bitwardenjson ${TMPFILE_PER}"
            bw import bitwardenjson ${TMPFILE_PER}
            rm -vf ${TMPFILE_PER}
            LASTEXPORT_ATTACHMENTS_PER="$(ls -1rt ${EXPORTSDIR}/bitwarden_????????-????-????-????-????????????_attachments_??????????????.tar.gpg | tail -1)"
            if [ "${LASTEXPORT_ATTACHMENTS_PER}" != "" ] ; then
                echoprompt "bw-restore-attachments.sh ${LASTEXPORT_ATTACHMENTS_PER}"
                bw-restore-attachments.sh ${LASTEXPORT_ATTACHMENTS_PER}
            fi
        fi
    fi
fi

LASTEXPORT_VAULT_ORG="$(ls -1rt ${EXPORTSDIR}/bitwarden_????????-????-????-????-????????????_org_????????-????-????-????-????????????_export_??????????????.json.gpg | tail -1)"
if [ "${LASTEXPORT_VAULT_ORG}" != "" ] ; then
    if [ -e "${LASTEXPORT_VAULT_ORG}.sign" ] ; then
        echoprompt "gpg --verify ${LASTEXPORT_VAULT_ORG}.sign"
        gpg --verify ${LASTEXPORT_VAULT_ORG}.sign
    fi
    ORGANIZATION_ID="$(bw list organizations | jq -r '.[] | select (.status==2 and (.type==0 or .type==1)) | .id')"
    NUM_ORGS=0
    for TMP_ID in ${ORGANIZATION_ID} ; do
        let NUM_ORGS=${NUM_ORGS}+1
    done
    if [ ${NUM_ORGS} -ne 1 ] ; then
        echo2 "WARNING: Destination account must be owner or admin of one and only one organization."
    else
        echo2 "INFO: Destination account is owner or admin of one and only one organization. OK."
        if [ "$(bw list items --organizationid ${ORGANIZATION_ID})" != "[]" ] ; then
            echo2 "WARNING: Destination organization vault is not empty."
        else
            echo2 "INFO: organization vault is empty. OK."
            if [ "$(bw list items --organizationid ${ORGANIZATION_ID} --trash)" != "[]" ] ; then
                echo2 "WARNING: Destination organization vault trash is not empty."
            else
                echo2 "INFO: organization vault trash is empty. OK."
                if [ "$(bw list collections --organizationid ${ORGANIZATION_ID})" != "[]" ] ; then
                    echo2 "WARNING: Destination organization vault already has collections."
                else
                    echo2 "INFO: organization vault has no collections. OK."
                    TMPFILE_ORG="$(mktemp -p /dev/shm/ -t bw-vault2restore-organization.XXXXXX)"
                    echoprompt "gpg -d ${LASTEXPORT_VAULT_ORG} > ${TMPFILE_ORG}"
                    gpg -d ${LASTEXPORT_VAULT_ORG} > ${TMPFILE_ORG}
                    echoprompt "bw import --organizationid ${ORGANIZATION_ID} bitwardenjson ${TMPFILE_ORG}"
                    bw import --organizationid ${ORGANIZATION_ID} bitwardenjson ${TMPFILE_ORG}
                    rm -vf ${TMPFILE_ORG}
                    LASTEXPORT_ATTACHMENTS_ORG="$(ls -1rt ${EXPORTSDIR}/bitwarden_????????-????-????-????-????????????_org_????????-????-????-????-????????????_attachments_??????????????.tar.gpg | tail -1)"
                    if [ "${LASTEXPORT_ATTACHMENTS_ORG}" != "" ] ; then
                        echoprompt "bw-restore-attachments.sh ${LASTEXPORT_ATTACHMENTS_ORG}"
                        bw-restore-attachments.sh ${LASTEXPORT_ATTACHMENTS_ORG}
                    fi
                fi
            fi
        fi
    fi
fi
