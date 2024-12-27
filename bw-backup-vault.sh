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
export ALSO_EXPORT_CSV_FORMAT=0
while [ "${1:0:1}" == "-" ] ; do
    if [ "${1}" == "--without-attachments" ] ; then
        WITH_ATTACHMENTS=0
        shift
    elif [ "${1}" == "--nosign" ] ; then
        NO_SIGN=1
        shift
    elif [ "${1}" == "--csv" -o "${1}" == "--export-csv" ] ; then
        ALSO_EXPORT_CSV_FORMAT=1
        shift
    else
        abort "ERROR: unknown option (\`${1}')."
    fi
done

export GPG_OPTIONS_SIGN="-absu ${MYPGPKEY}"
export GPG_OPTIONS_ENCRYPT="-er ${MYPGPKEY}"

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
if [ "$(bw list items --organizationid null)" == "[]" ] ; then
    WARNING_TEXT="### WARNING: individual vault is empty. ###"
    WARNING_HEAD="$(echo "${WARNING_TEXT}" | sed 's/./#/g')"
    echo2 ""
    echo2 "${WARNING_HEAD}"
    echo2 "${WARNING_TEXT}"
    echo2 "${WARNING_HEAD}"
    echo2 ""
else
    JSON_OUTPUT_FILE="${EXPORTSDIR}/bitwarden_${USER_ID}_export_${DATE_SUFFIX}.json.gpg"
    echoprompt "bw export --format json --raw | gpg ${GPG_OPTIONS_ENCRYPT} -o '${JSON_OUTPUT_FILE}'"
    bw export --format json --raw | gpg ${GPG_OPTIONS_ENCRYPT} -o "${JSON_OUTPUT_FILE}"
    if [ ${NO_SIGN} -ne 1 ] ; then
        echoprompt "gpg ${GPG_OPTIONS_SIGN} -o '${JSON_OUTPUT_FILE}.sign' '${JSON_OUTPUT_FILE}'"
        gpg ${GPG_OPTIONS_SIGN} -o "${JSON_OUTPUT_FILE}.sign" "${JSON_OUTPUT_FILE}" || /bin/true
    fi
    if [ ${ALSO_EXPORT_CSV_FORMAT} -eq 1 ] ; then
        CSV_OUTPUT_FILE="${EXPORTSDIR}/bitwarden_${USER_ID}_export_${DATE_SUFFIX}.csv.gpg"
        echoprompt "bw export --format csv --raw | gpg ${GPG_OPTIONS_ENCRYPT} -o '${CSV_OUTPUT_FILE}'"
        bw export --format csv --raw | gpg ${GPG_OPTIONS_ENCRYPT} -o "${CSV_OUTPUT_FILE}"
        if [ ${NO_SIGN} -ne 1 ] ; then
            echoprompt "gpg ${GPG_OPTIONS_SIGN} -o '${CSV_OUTPUT_FILE}.sign' '${CSV_OUTPUT_FILE}'"
            gpg ${GPG_OPTIONS_SIGN} -o "${CSV_OUTPUT_FILE}.sign" "${CSV_OUTPUT_FILE}" || /bin/true
        fi
    fi
fi
if [ ${WITH_ATTACHMENTS} -eq 0 ] ; then
    NUM_ITEMS_WITH_ATTACHMENTS="$(bw list items --organizationid null | jq -r '.[] | select(.attachments != null) | .id' | wc -l)"
    if [ ${NUM_ITEMS_WITH_ATTACHMENTS} -gt 0 ] ; then
        WARNING_TEXT="### WARNING: individual vault contains ${NUM_ITEMS_WITH_ATTACHMENTS} items with attachments that have not been backed up. ###"
        WARNING_HEAD="$(echo "${WARNING_TEXT}" | sed 's/./#/g')"
        echo2 ""
        echo2 "${WARNING_HEAD}"
        echo2 "${WARNING_TEXT}"
        echo2 "${WARNING_HEAD}"
        echo2 ""
    fi
fi
for ORGANIZATION_ID in ${ORGANIZATION_IDS_TO_BACKUP} ; do
    if [ "$(bw list items --organizationid ${ORGANIZATION_ID})" == "[]" ] ; then
        WARNING_TEXT="### WARNING: organization \`${ORGANIZATION_ID}' vault is empty. ###"
        WARNING_HEAD="$(echo "${WARNING_TEXT}" | sed 's/./#/g')"
        echo2 ""
        echo2 "${WARNING_HEAD}"
        echo2 "${WARNING_TEXT}"
        echo2 "${WARNING_HEAD}"
        echo2 ""
    else
        JSON_ORG_OUTPUT_FILE="${EXPORTSDIR}/bitwarden_${USER_ID}_org_${ORGANIZATION_ID}_export_${DATE_SUFFIX}.json.gpg"
        echoprompt "bw export --organizationid ${ORGANIZATION_ID} --format json --raw | gpg ${GPG_OPTIONS_ENCRYPT} -o '${JSON_ORG_OUTPUT_FILE}'"
        bw export --organizationid ${ORGANIZATION_ID} --format json --raw | gpg ${GPG_OPTIONS_ENCRYPT} -o "${JSON_ORG_OUTPUT_FILE}"
        if [ ${NO_SIGN} -ne 1 ] ; then
            echoprompt "gpg ${GPG_OPTIONS_SIGN} -o '${JSON_ORG_OUTPUT_FILE}.sign' '${JSON_ORG_OUTPUT_FILE}'"
            gpg ${GPG_OPTIONS_SIGN} -o "${JSON_ORG_OUTPUT_FILE}.sign" "${JSON_ORG_OUTPUT_FILE}" || /bin/true
        fi
        if [ ${ALSO_EXPORT_CSV_FORMAT} -eq 1 ] ; then
            CSV_ORG_OUTPUT_FILE="${EXPORTSDIR}/bitwarden_${USER_ID}_org_${ORGANIZATION_ID}_export_${DATE_SUFFIX}.csv.gpg"
            echoprompt "bw export --organizationid ${ORGANIZATION_ID} --format csv --raw | gpg ${GPG_OPTIONS_ENCRYPT} -o '${CSV_ORG_OUTPUT_FILE}'"
            bw export --organizationid ${ORGANIZATION_ID} --format csv --raw | gpg ${GPG_OPTIONS_ENCRYPT} -o "${CSV_ORG_OUTPUT_FILE}"
            if [ ${NO_SIGN} -ne 1 ] ; then
                echoprompt "gpg ${GPG_OPTIONS_SIGN} -o '${CSV_ORG_OUTPUT_FILE}.sign' '${CSV_ORG_OUTPUT_FILE}'"
                gpg ${GPG_OPTIONS_SIGN} -o "${CSV_ORG_OUTPUT_FILE}.sign" "${CSV_ORG_OUTPUT_FILE}" || /bin/true
            fi
        fi
        if [ ${WITH_ATTACHMENTS} -eq 0 ] ; then
            NUMORG_ITEMS_WITH_ATTACHMENTS="$(bw list items --organizationid ${ORGANIZATION_ID} | jq -r '.[] | select(.attachments != null) | .id' | wc -l)"
            if [ ${NUMORG_ITEMS_WITH_ATTACHMENTS} -gt 0 ] ; then
                WARNING_TEXT="### WARNING: organization \`${ORGANIZATION_ID}' vault contains ${NUMORG_ITEMS_WITH_ATTACHMENTS} items with attachments that have not been backed up. ###"
                WARNING_HEAD="$(echo "${WARNING_TEXT}" | sed 's/./#/g')"
                echo2 ""
                echo2 "${WARNING_HEAD}"
                echo2 "${WARNING_TEXT}"
                echo2 "${WARNING_HEAD}"
                echo2 ""
            fi
        fi
    fi
done

if [ ${WITH_ATTACHMENTS} -eq 1 ] ; then
    ATTACHMENTS_PARENT_TEMP_DIR="/dev/shm"
    ITEMS_WITH_ATTACHMENTS="$(bw list items --organizationid null | jq '.[] | select(.attachments != null)' || /bin/true)"
    if [ "${ITEMS_WITH_ATTACHMENTS}" == "" ] || [ "${ITEMS_WITH_ATTACHMENTS}" == "[]" ] ; then
        WARNING_TEXT="### WARNING: no attachments found to export in individual vault. ###"
        WARNING_HEAD="$(echo "${WARNING_TEXT}" | sed 's/./#/g')"
        echo2 ""
        echo2 "${WARNING_HEAD}"
        echo2 "${WARNING_TEXT}"
        echo2 "${WARNING_HEAD}"
        echo2 ""
    else
        DOWNLOAD_ATTACHMENTS_COMMANDS="$(echo "${ITEMS_WITH_ATTACHMENTS}" | jq -r '. as $parent | .attachments[] | "bw get attachment \(.id) --itemid \($parent.id) --output \"./\($parent.id)/\(.fileName)\""')"
        ATTACHMENTS_OUTPUT_FILE="${EXPORTSDIR}/bitwarden_${USER_ID}_attachments_${DATE_SUFFIX}.tar.gpg"
        ATTACHMENTS_TEMP_DIR="$(mktemp -d -p "${ATTACHMENTS_PARENT_TEMP_DIR}" bw-backup-vault-attachments.XXXXXXXX)"
        pushd "${ATTACHMENTS_TEMP_DIR}" >/dev/null
        echo "${ITEMS_WITH_ATTACHMENTS}" > ./items.json
        echoprompt "${DOWNLOAD_ATTACHMENTS_COMMANDS}"
        echo "${DOWNLOAD_ATTACHMENTS_COMMANDS}" | bash -e
        tar -v -c . | gpg ${GPG_OPTIONS_ENCRYPT} -o "${ATTACHMENTS_OUTPUT_FILE}"
        popd >/dev/null
        if [ "${ATTACHMENTS_PARENT_TEMP_DIR}" == "" ] || [ "${ATTACHMENTS_TEMP_DIR}" == "" ] || [ "${ATTACHMENTS_TEMP_DIR:0:$((${#ATTACHMENTS_TEMP_DIR}-8))}" != "${ATTACHMENTS_PARENT_TEMP_DIR}/bw-backup-vault-attachments." ] ; then abort "ERROR: wrong value of ATTACHMENTS_TEMP_DIR (\`${ATTACHMENTS_TEMP_DIR}')" ; fi
        rm -R "${ATTACHMENTS_TEMP_DIR}"
        if [ ${NO_SIGN} -ne 1 ] ; then
            echoprompt "gpg ${GPG_OPTIONS_SIGN} -o '${ATTACHMENTS_OUTPUT_FILE}.sign' '${ATTACHMENTS_OUTPUT_FILE}'"
            gpg ${GPG_OPTIONS_SIGN} -o "${ATTACHMENTS_OUTPUT_FILE}.sign" "${ATTACHMENTS_OUTPUT_FILE}" || /bin/true
        fi
    fi
    for ORGANIZATION_ID in ${ORGANIZATION_IDS_TO_BACKUP} ; do
        ORGITEMIDS_EXPORTED="$(bw export --organizationid ${ORGANIZATION_ID} --format json --raw | jq -r '.items[] .id' | sort)"
        ORGITEMIDS_READ="$(bw list items --organizationid ${ORGANIZATION_ID} | jq -r '.[] .id' | sort)"
        if [ "${ORGITEMIDS_EXPORTED}" == "${ORGITEMIDS_READ}" ] ; then
            /bin/true
        else
            NUMORGITEMIDS_EXPORTED="$(echo "${ORGITEMIDS_EXPORTED}" | wc -l)"
            NUMORGITEMIDS_READ="$(echo "${ORGITEMIDS_READ}" | wc -l)"
            WARNING_TEXT="### WARNING: exported (${NUMORGITEMIDS_EXPORTED}) and read (${NUMORGITEMIDS_READ}) items for organization \`${ORGANIZATION_ID}' are not the same. You should check unassigned items and collections permissions. ###"
            WARNING_HEAD="$(echo "${WARNING_TEXT}" | sed 's/./#/g')"
            echo2 ""
            echo2 "${WARNING_HEAD}"
            echo2 "${WARNING_TEXT}"
            echo2 "${WARNING_HEAD}"
            echo2 ""
        fi
        ITEMS_WITH_ATTACHMENTS_ORG="$(bw list items --organizationid ${ORGANIZATION_ID} | jq '.[] | select(.attachments != null)' || /bin/true)"
        if [ "${ITEMS_WITH_ATTACHMENTS_ORG}" == "" ] || [ "${ITEMS_WITH_ATTACHMENTS_ORG}" == "[]" ] ; then
            WARNING_TEXT="### WARNING: no attachments found to export in organization \`${ORGANIZATION_ID}' vault. ###"
            WARNING_HEAD="$(echo "${WARNING_TEXT}" | sed 's/./#/g')"
            echo2 ""
            echo2 "${WARNING_HEAD}"
            echo2 "${WARNING_TEXT}"
            echo2 "${WARNING_HEAD}"
            echo2 ""
        else
            DOWNLOAD_ATTACHMENTS_ORG_COMMANDS="$(echo "${ITEMS_WITH_ATTACHMENTS_ORG}" | jq -r '. as $parent | .attachments[] | "bw get attachment --organizationid '${ORGANIZATION_ID}' \(.id) --itemid \($parent.id) --output \"./\($parent.id)/\(.fileName)\""')"
            ATTACHMENTS_ORG_OUTPUT_FILE="${EXPORTSDIR}/bitwarden_${USER_ID}_org_${ORGANIZATION_ID}_attachments_${DATE_SUFFIX}.tar.gpg"
            ATTACHMENTS_ORG_TEMP_DIR="$(mktemp -d -p "${ATTACHMENTS_PARENT_TEMP_DIR}" bw-backup-vault-org-attachments.XXXXXXXX)"
            pushd "${ATTACHMENTS_ORG_TEMP_DIR}" >/dev/null
            echo "${ITEMS_WITH_ATTACHMENTS_ORG}" > ./items.json
            echoprompt "${DOWNLOAD_ATTACHMENTS_ORG_COMMANDS}"
            echo "${DOWNLOAD_ATTACHMENTS_ORG_COMMANDS}" | bash -e
            tar -v -c . | gpg ${GPG_OPTIONS_ENCRYPT} -o "${ATTACHMENTS_ORG_OUTPUT_FILE}"
            popd >/dev/null
            if [ "${ATTACHMENTS_PARENT_TEMP_DIR}" == "" ] || [ "${ATTACHMENTS_ORG_TEMP_DIR}" == "" ] || [ "${ATTACHMENTS_ORG_TEMP_DIR:0:$((${#ATTACHMENTS_ORG_TEMP_DIR}-8))}" != "${ATTACHMENTS_PARENT_TEMP_DIR}/bw-backup-vault-org-attachments." ] ; then abort "ERROR: wrong value of ATTACHMENTS_ORG_TEMP_DIR (\`${ATTACHMENTS_ORG_TEMP_DIR}')" ; fi
            rm -R "${ATTACHMENTS_ORG_TEMP_DIR}"
            if [ ${NO_SIGN} -ne 1 ] ; then
                echoprompt "gpg ${GPG_OPTIONS_SIGN} -o '${ATTACHMENTS_ORG_OUTPUT_FILE}.sign' '${ATTACHMENTS_ORG_OUTPUT_FILE}'"
                gpg ${GPG_OPTIONS_SIGN} -o "${ATTACHMENTS_ORG_OUTPUT_FILE}.sign" "${ATTACHMENTS_ORG_OUTPUT_FILE}" || /bin/true
            fi
        fi
    done
fi
