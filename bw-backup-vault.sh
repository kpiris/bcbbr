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

################################################################################

export WITH_ATTACHMENTS=1
export NO_SIGN=0
while [ "${1:0:1}" == "-" ] ; do
    if [ "${1}" == "--without-attachments" ] ; then
        WITH_ATTACHMENTS=0
        shift
    elif [ "${1}" == "--nosign" ] ; then
        NO_SIGN=1
        shift
    else
        abort "ERROR: unknown option (\`${1}')."
    fi
done

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

USER_ID="$(echo "${BWSTATUS}" | jq -r '.userId')"
ORGANIZATION_IDS_TO_BACKUP="$(bw list organizations | jq -r '.[] | select (.status==2 and (.type==0 or .type==1)) | .id')"

DATE_SUFFIX="$(date '+%Y%m%d%H%M%S')"
JSON_OUTPUT_FILE="${EXPORTSDIR}/bitwarden_${USER_ID}_export_${DATE_SUFFIX}.json.gpg"
echoprompt "bw export --format json --raw | gpg -er ${MYPGPKEY} -o '${JSON_OUTPUT_FILE}'"
bw export --format json --raw | gpg -er ${MYPGPKEY} -o "${JSON_OUTPUT_FILE}"
if [ ${NO_SIGN} -ne 1 ] ; then
    echoprompt "gpg -absu ${MYPGPKEY} -o '${JSON_OUTPUT_FILE}.sign' '${JSON_OUTPUT_FILE}'"
    gpg -absu ${MYPGPKEY} -o "${JSON_OUTPUT_FILE}.sign" "${JSON_OUTPUT_FILE}" || /bin/true
fi
CSV_OUTPUT_FILE="${EXPORTSDIR}/bitwarden_${USER_ID}_export_${DATE_SUFFIX}.csv.gpg"
echoprompt "bw export --format csv --raw | gpg -er ${MYPGPKEY} -o '${CSV_OUTPUT_FILE}'"
bw export --format csv --raw | gpg -er ${MYPGPKEY} -o "${CSV_OUTPUT_FILE}"
if [ ${NO_SIGN} -ne 1 ] ; then
    echoprompt "gpg -absu ${MYPGPKEY} -o '${CSV_OUTPUT_FILE}.sign' '${CSV_OUTPUT_FILE}'"
    gpg -absu ${MYPGPKEY} -o "${CSV_OUTPUT_FILE}.sign" "${CSV_OUTPUT_FILE}" || /bin/true
fi
for ORGANIZATION_ID in ${ORGANIZATION_IDS_TO_BACKUP} ; do
    JSON_ORG_OUTPUT_FILE="${EXPORTSDIR}/bitwarden_${USER_ID}_org_${ORGANIZATION_ID}_export_${DATE_SUFFIX}.json.gpg"
    echoprompt "bw export --organizationid ${ORGANIZATION_ID} --format json --raw | gpg -er ${MYPGPKEY} -o '${JSON_ORG_OUTPUT_FILE}'"
    bw export --organizationid ${ORGANIZATION_ID} --format json --raw | gpg -er ${MYPGPKEY} -o "${JSON_ORG_OUTPUT_FILE}"
    if [ ${NO_SIGN} -ne 1 ] ; then
        echoprompt "gpg -absu ${MYPGPKEY} -o '${JSON_ORG_OUTPUT_FILE}.sign' '${JSON_ORG_OUTPUT_FILE}'"
        gpg -absu ${MYPGPKEY} -o "${JSON_ORG_OUTPUT_FILE}.sign" "${JSON_ORG_OUTPUT_FILE}" || /bin/true
    fi
    CSV_ORG_OUTPUT_FILE="${EXPORTSDIR}/bitwarden_${USER_ID}_org_${ORGANIZATION_ID}_export_${DATE_SUFFIX}.csv.gpg"
    echoprompt "bw export --organizationid ${ORGANIZATION_ID} --format csv --raw | gpg -er ${MYPGPKEY} -o '${CSV_ORG_OUTPUT_FILE}'"
    bw export --organizationid ${ORGANIZATION_ID} --format csv --raw | gpg -er ${MYPGPKEY} -o "${CSV_ORG_OUTPUT_FILE}"
    if [ ${NO_SIGN} -ne 1 ] ; then
        echoprompt "gpg -absu ${MYPGPKEY} -o '${CSV_ORG_OUTPUT_FILE}.sign' '${CSV_ORG_OUTPUT_FILE}'"
        gpg -absu ${MYPGPKEY} -o "${CSV_ORG_OUTPUT_FILE}.sign" "${CSV_ORG_OUTPUT_FILE}" || /bin/true
    fi
done

if [ ${WITH_ATTACHMENTS} -eq 1 ] ; then
    ITEMS_WITH_ATTACHMENTS="$(bw list items --organizationid null | jq '.[] | select(.attachments != null)' || /bin/true)"
    if [ "${ITEMS_WITH_ATTACHMENTS}" == "" ] || [ "${ITEMS_WITH_ATTACHMENTS}" == "[]" ] ; then
        /bin/true
    else
        DOWNLOAD_ATTACHMENTS_COMMANDS="$(echo "${ITEMS_WITH_ATTACHMENTS}" | jq -r '. as $parent | .attachments[] | "bw get attachment \(.id) --itemid \($parent.id) --output \"./\($parent.id)/\(.fileName)\""')"
        ATTACHMENTS_PARENT_TEMP_DIR="/dev/shm"
        ATTACHMENTS_OUTPUT_FILE="${EXPORTSDIR}/bitwarden_${USER_ID}_attachments_${DATE_SUFFIX}.tar.gpg"
        ATTACHMENTS_TEMP_DIR="$(mktemp -d -p "${ATTACHMENTS_PARENT_TEMP_DIR}" bw-backup-vault-attachments.XXXXXXXX)"
        pushd "${ATTACHMENTS_TEMP_DIR}" >/dev/null
        echo "${ITEMS_WITH_ATTACHMENTS}" > ./items.json
        echoprompt "${DOWNLOAD_ATTACHMENTS_COMMANDS}"
        echo "${DOWNLOAD_ATTACHMENTS_COMMANDS}" | bash -e
        tar -v -c . | gpg -er ${MYPGPKEY} -o "${ATTACHMENTS_OUTPUT_FILE}"
        popd >/dev/null
        if [ "${ATTACHMENTS_TEMP_DIR:0:$((${#ATTACHMENTS_TEMP_DIR}-8))}" != "${ATTACHMENTS_PARENT_TEMP_DIR}/bw-backup-vault-attachments." ] ; then abort "ERROR: wrong value of ATTACHMENTS_TEMP_DIR (\`${ATTACHMENTS_TEMP_DIR}')" ; fi
        rm -R "${ATTACHMENTS_TEMP_DIR}"
        if [ ${NO_SIGN} -ne 1 ] ; then
            echoprompt "gpg -absu ${MYPGPKEY} -o '${ATTACHMENTS_OUTPUT_FILE}.sign' '${ATTACHMENTS_OUTPUT_FILE}'"
            gpg -absu ${MYPGPKEY} -o "${ATTACHMENTS_OUTPUT_FILE}.sign" "${ATTACHMENTS_OUTPUT_FILE}" || /bin/true
        fi
    fi
    for ORGANIZATION_ID in ${ORGANIZATION_IDS_TO_BACKUP} ; do
        ITEMS_WITH_ATTACHMENTS_ORG="$(bw list items --organizationid ${ORGANIZATION_ID} | jq '.[] | select(.attachments != null)' || /bin/true)"
        if [ "${ITEMS_WITH_ATTACHMENTS_ORG}" == "" ] || [ "${ITEMS_WITH_ATTACHMENTS_ORG}" == "[]" ] ; then
            /bin/true
        else
            DOWNLOAD_ATTACHMENTS_ORG_COMMANDS="$(echo "${ITEMS_WITH_ATTACHMENTS_ORG}" | jq -r '. as $parent | .attachments[] | "bw get attachment --organizationid '${ORGANIZATION_ID}' \(.id) --itemid \($parent.id) --output \"./\($parent.id)/\(.fileName)\""')"
            ATTACHMENTS_ORG_OUTPUT_FILE="${EXPORTSDIR}/bitwarden_${USER_ID}_org_${ORGANIZATION_ID}_attachments_${DATE_SUFFIX}.tar.gpg"
            ATTACHMENTS_ORG_TEMP_DIR="$(mktemp -d -p "${ATTACHMENTS_PARENT_TEMP_DIR}" bw-backup-vault-org-attachments.XXXXXXXX)"
            pushd "${ATTACHMENTS_ORG_TEMP_DIR}" >/dev/null
            echo "${ITEMS_WITH_ATTACHMENTS_ORG}" > ./items.json
            echoprompt "${DOWNLOAD_ATTACHMENTS_ORG_COMMANDS}"
            echo "${DOWNLOAD_ATTACHMENTS_ORG_COMMANDS}" | bash -e
            tar -v -c . | gpg -er ${MYPGPKEY} -o "${ATTACHMENTS_ORG_OUTPUT_FILE}"
            popd >/dev/null
            if [ "${ATTACHMENTS_ORG_TEMP_DIR:0:$((${#ATTACHMENTS_ORG_TEMP_DIR}-8))}" != "${ATTACHMENTS_PARENT_TEMP_DIR}/bw-backup-vault-org-attachments." ] ; then abort "ERROR: wrong value of ATTACHMENTS_ORG_TEMP_DIR (\`${ATTACHMENTS_ORG_TEMP_DIR}')" ; fi
            rm -R "${ATTACHMENTS_ORG_TEMP_DIR}"
            if [ ${NO_SIGN} -ne 1 ] ; then
                echoprompt "gpg -absu ${MYPGPKEY} -o '${ATTACHMENTS_ORG_OUTPUT_FILE}.sign' '${ATTACHMENTS_ORG_OUTPUT_FILE}'"
                gpg -absu ${MYPGPKEY} -o "${ATTACHMENTS_ORG_OUTPUT_FILE}.sign" "${ATTACHMENTS_ORG_OUTPUT_FILE}" || /bin/true
            fi
        fi
    done
fi
