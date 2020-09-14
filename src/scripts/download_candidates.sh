#!/bin/bash
TEMP_DIR="tmp"
[ ! -d "$TEMP_DIR" ] && mkdir -p "$TEMP_DIR"
curl https://csrc.nist.gov/CSRC/media/Projects/lightweight-cryptography/documents/round-2/submissions-rnd2/all-round-2-lwc-candidates.zip --output ${TEMP_DIR}/all.zip
unzip ${TEMP_DIR}/all.zip -d ${TEMP_DIR}
rm -f ${TEMP_DIR}/all.zip

CANDIDATES=$(find -path './tmp/*')
for candidate in $CANDIDATES; do
    unzip $candidate -d candidates/
    rm -f $candidate
done

rmdir tmp