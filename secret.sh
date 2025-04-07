#!/bin/bash

ENC_SECRET=$(echo ${SECRET_VALUE} | openssl enc -e ${CIPHER} -base64 -A -pass ${PASSWORD})

echo "The value of your secret key '${SECRET_KEY}' from the secret '${SECRET_NAME}' is ${ENC_SECRET}"
echo "Now please use your chosen cipher (${CIPHER}), the password you provided, and the encrypted value above to decrypt"
echo "Execute the below to decode..."
echo "echo "${ENC_SECRET}" | openssl enc -d ${CIPHER} -A -base64 -pass <PASSWORD>"
