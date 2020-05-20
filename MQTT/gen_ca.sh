#!/bin/bash

CA_DN="/CN=MQTT CA/O=PrestigeWorldWide/OU=generate-CA/emailAddress=nobody@example.net"

# CA CERT
openssl req -new -x509 -nodes -days 3650 -extensions v3_ca -keyout mqtt_ca.key -out mqtt_ca.crt -subj "${CA_DN}"
# nameopt option which determines how the subject or issuer names are displayed.
openssl x509 -in mqtt_ca.crt -nameopt multiline -subject -noout
