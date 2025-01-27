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
    echo2 "$*"
}

showwarning () {
    WARNING_TEXT="$*"
    WARNING_HEAD="$(echo "${WARNING_TEXT}" | sed 's/./#/g')"
    echo2 ""
    echo2 "${WARNING_HEAD}"
    echo2 "${WARNING_TEXT}"
    echo2 "${WARNING_HEAD}"
    echo2 ""
}

################################################################################

export EXPORTSDIR="."
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

USER_ID="$(echo "${BWSTATUS}" | jq -r '.userId')"
ORGANIZATION_IDS_TO_BACKUP="$(bw list organizations | jq -r '.[] | select (.status==2 and (.type==0 or .type==1)) | .id')"

DATE_SUFFIX="$(date '+%Y%m%d%H%M%S')"
if [ "$(bw list items --organizationid null)" == "[]" ] ; then
    showwarning "### WARNING: individual vault is empty. ###"
else
    JSON_OUTPUT_FILE="${EXPORTSDIR}/bitwarden_${USER_ID}_encrypted_export_${DATE_SUFFIX}.json"
    echoprompt "bw export --format encrypted_json --output '${JSON_OUTPUT_FILE}'"
    bw export --format encrypted_json --output "${JSON_OUTPUT_FILE}"
    NUM_ITEMS_WITH_ATTACHMENTS="$(bw list items --organizationid null | jq -r '.[] | select(.attachments != null) | .id' | wc -l)"
    if [ ${NUM_ITEMS_WITH_ATTACHMENTS} -gt 0 ] ; then
        showwarning "### WARNING: individual vault contains ${NUM_ITEMS_WITH_ATTACHMENTS} items with attachments that have not been backed up. ###"
    fi
fi

for ORGANIZATION_ID in ${ORGANIZATION_IDS_TO_BACKUP} ; do
    if [ "$(bw list items --organizationid ${ORGANIZATION_ID})" == "[]" ] ; then
        showwarning "### WARNING: organization \`${ORGANIZATION_ID}' vault is empty. ###"
    else
        JSON_ORG_OUTPUT_FILE="${EXPORTSDIR}/bitwarden_${USER_ID}_org_${ORGANIZATION_ID}_encrypted_export_${DATE_SUFFIX}.json"
        echoprompt "bw export --organizationid ${ORGANIZATION_ID} --format encrypted_json --output '${JSON_ORG_OUTPUT_FILE}'"
        bw export --organizationid ${ORGANIZATION_ID} --format encrypted_json --output "${JSON_ORG_OUTPUT_FILE}"
        NUMORG_ITEMS_WITH_ATTACHMENTS="$(bw list items --organizationid ${ORGANIZATION_ID} | jq -r '.[] | select(.attachments != null) | .id' | wc -l)"
        if [ ${NUMORG_ITEMS_WITH_ATTACHMENTS} -gt 0 ] ; then
            showwarning "### WARNING: organization \`${ORGANIZATION_ID}' vault contains ${NUMORG_ITEMS_WITH_ATTACHMENTS} items with attachments that have not been backed up. ###"
        fi
    fi
done
