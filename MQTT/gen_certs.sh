#!/bin/bash

usage="
	./gen_serv_cli_cert.sh ca
	./gen_serv_cli_cert.sh server HOSTNAME PATH/TO/CA_CERT PATH/TO/CA_KEY
	./gen_serv_cli_cert.sh client HOSTNAME PATH/TO/CA_CERT PATH/TO/CA_KEY"

if [ $# = 1 ] && [ "$1" = "ca" ]; then
	# CA CERT
	CA_DN="/CN=MQTT CA/O=PrestigeWorldWide/OU=generate-CA/emailAddress=nobody@example.net"
	openssl req -new -x509 -nodes -days 3650 -extensions v3_ca -keyout mqtt_ca.key -out mqtt_ca.crt -subj "${CA_DN}"
	# nameopt option which determines how the subject or issuer names are displayed.
	openssl x509 -in mqtt_ca.crt -nameopt multiline -subject -noout
	echo "Created CA certificate"
	openssl x509 -in mqtt_ca.crt -out mqtt_ca.crt.der -outform DER
	echo "Created copy of CA in DER format"
	exit
fi

if [ $# -ne 4 ]; then
	echo "Usage:$usage"
	exit
fi

if [ "$1" != "server" ] && [ "$1" != "client" ]; then
	echo "Usage:$usage" 
	exit
fi


if [ "$1" = "server" ]; then

	type="serverAuth"

else 

	type="clientAuth"

fi

DN="/CN="$2"/O=YourOrg/OU="$2"-CA/emailAddress=nobody@example.net"
CNF="[ MQTTextensions ]
basicConstraints		= critical,CA:false
subjectAltName 			= \"DNS:${2},DNS:${2}.local,DNS:localhost,IP:127.0.0.1,IP:::1\"
keyUsage			= nonRepudiation, digitalSignature, keyEncipherment
extendedKeyUsage		= "$type"
nsComment			= \"MQTT Client Cert\""


openssl genrsa -out "$2".key 2048
openssl req -new -out "$2".csr -key "$2".key -subj "${DN}" 
openssl x509 -req  \
	-in "$2".csr \
	-CA $3 \
	-CAkey $4 \
	-CAcreateserial \
	-out "$2".crt \
	-days 3650 \
	-extfile <(printf "$CNF") \
	-extensions MQTTextensions

if [ "$1" = "client" ]; then
	openssl rsa -in "$2".key -out "$2".key.der -outform DER
	openssl x509 -in "$2".crt -out "$2".crt.der -outform DER
	echo "Created copies of client cert and key in DER format"
fi
