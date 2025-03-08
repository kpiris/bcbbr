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

IFS="$(echo -en "\n\b")"

export BWSTATUS="$(bw status)"
export BWSTATUS_LOGIN="$(echo "${BWSTATUS}" | jq -r '.status')"
if [ "${BWSTATUS_LOGIN}" != "unlocked" ] ; then
    abort "ERROR: a vault must be unlocked (\`${BWSTATUS}')."
fi

umask 0077
bw sync
DESTINATION_VAULT_ITEMS="$(bw list items)"

if [ "${DESTINATION_VAULT_ITEMS}" == "[]" ] ; then abort "ERROR: destination vault is empty" ; fi

while [ "${1}" != "" ] ; do
    FLE="$(realpath ${1})"
    if [ ! -e "${FLE}.sign" ] ; then
        echo -n "WARNING: \`${FLE}' is not signed. Press <INTRO> to continue or Ctrl+c to abort :" >&2 ; read dummy
    else
        echoprompt "gpg --verify ${FLE}.sign"
        gpg --verify ${FLE}.sign
    fi
    ATTACHMENTS_PARENT_TEMP_DIR="/dev/shm"
    ATTACHMENTS_TEMP_DIR="$(mktemp -d -p "${ATTACHMENTS_PARENT_TEMP_DIR}" bw-vault-attachments2restore.XXXXXXXX)"
    pushd "${ATTACHMENTS_TEMP_DIR}" >/dev/null
    echoprompt "cat ${FLE} | gpg -d | tar -xv"
    cat ${FLE} | gpg -d | tar -xv
    EXPORTED_ITEMS="$(cat ./items.json)"
    if [ "${EXPORTED_ITEMS}" == "" ] ; then
        echo2 "WARNING: cannot find items.json in \`${FLE}."
    else
        for EXPORTED_ITEM_ID in $(echo "${EXPORTED_ITEMS}" | jq -r '.id') ; do
            pushd "${ATTACHMENTS_TEMP_DIR}/${EXPORTED_ITEM_ID}" >/dev/null
            EXPORTED_ITEM_FIELDS="$(echo "${EXPORTED_ITEMS}" | jq -c 'select(.id == "'${EXPORTED_ITEM_ID}'") | [.name, .type, .object, .login.username]')"
            DESTINATION_ITEM_ID="$(echo "${DESTINATION_VAULT_ITEMS}" | jq -r '.[] | select([.name, .type, .object, .login.username] == '${EXPORTED_ITEM_FIELDS}') | .id')"
            ITEMS_COUNT=0
            for TMP_ITEMID in ${DESTINATION_ITEM_ID} ; do
                let ITEMS_COUNT=${ITEMS_COUNT}+1
            done
            if [ ${ITEMS_COUNT} -eq 0 ] ; then
                echo2 "WARNING: item not found in destination vault (\`${DESTINATION_ITEM_ID}/${EXPORTED_ITEM_FIELDS}')."
            elif [ ${ITEMS_COUNT} -ne 1 ] ; then
                echo2 "WARNING: too many items found in destination vault (\`${DESTINATION_ITEM_ID}/${EXPORTED_ITEM_FIELDS}')."
            else
                DESTINATION_ITEM_ID_WITH_ATTACHMENTS_ALREADY="$(echo "${DESTINATION_VAULT_ITEMS}" | jq '.[] | select(.id == "'${DESTINATION_ITEM_ID}'" and .attachments != null)')"
                if [ "${DESTINATION_ITEM_ID_WITH_ATTACHMENTS_ALREADY}" != "" ] ; then
                    echo2 "WARNING: item \`${DESTINATION_ITEM_ID}/${EXPORTED_ITEM_FIELDS}' already has attachments."
                else
                    for ATTACHMENT_FILE in */* * ; do
                        if [ -f "${ATTACHMENT_FILE}" ] ; then
                            echoprompt "bw create attachment --file '${ATTACHMENT_FILE}' --itemid ${DESTINATION_ITEM_ID}"
                            bw create attachment --file "${ATTACHMENT_FILE}" --itemid ${DESTINATION_ITEM_ID}
                            rm -vf "${ATTACHMENT_FILE}"
                        elif [ -d "${ATTACHMENT_FILE}" ] ; then
                            rmdir -v --ignore-fail-on-non-empty "${ATTACHMENT_FILE}"
                        else
                            echo2 "WARNING: attachment \`${ATTACHMENT_FILE}' from item \`${EXPORTED_ITEM_ID}' is not a file or a directory (SHOULD_NOT_HAPPEN)."
                        fi
                    done
                fi
            fi
            popd >/dev/null
            rmdir -v "${ATTACHMENTS_TEMP_DIR}/${EXPORTED_ITEM_ID}" || /bin/true
        done
    fi
    rm -vf ./items.json
    popd >/dev/null
    rmdir -v "${ATTACHMENTS_TEMP_DIR}" || /bin/true
    shift
done
