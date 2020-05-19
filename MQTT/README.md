# How to setup TLS on MQTT Broker using Mosquitto and Securely Connect with ESP8266

#### Motivation behind this guide
After looking online for serval hours for tutorials on this, it became apparent to me that it was not going to be as easy as I had hoped
for. Many of the tutorials I found varied in their implementations, some were blatenly wrong or lacked sufficent documentation, and 
others were outdated. Out of the box Mosquttio does not supply any security features. It is easy to setup a username and password requirement,
but your traffic is still sent in cleartext. Setting up security on your IoT devices should not be as difficult as this was for me. Anybody
who finds this, I hope this can cut down on the amount of time it takes you to implement this level of security on your devices and prevents
some migrains from occuring.

## Certificates
Starting from the beginning, we need to create a certificate chain with a self-signed CA certificate, server certificate, and our client
certificate. This can all be done using `OpenSSL`. Inside this folder will be two bash scripts. One for creating the CA cert and the other for creating the server and client certs. If you want to run the commands by hand instead they will be documented below.

### CA Certificate
This command creates a new certificate and key which we will use to sign the rest of our certificates with. Feel free to change the parameters around to your liking. The content within the `subj` parameter is not super important for the CA cert but will be later on when making the other ones.

`openssl req -new -x509 -days 3650 -extensions v3_ca -keyout mqtt_ca.key -out mqtt_ca.crt -subj "/CN=MQTT CA/O=PrestigeWorldWide/OU=generate-CA/emailAddress=nobody@example.net"`

### Server Certificate
Create an RSA server private key

`openssl genrsa -out mosq_serv.key 2048`

Create a Certificate Signing Request (CSR) using the newly generate private key. A CSR is an intermidate step to allow you to ask the CA for a certificate and supple necessary information for the certificate.

**CN must equal the hostname of the node you are running your mosquitto broker on**

`openssl req -new -out mosq_serv.csr -key mosq_serv.key -subj "/CN=SERVER_HOSTNAME/O=YourOrg/OU=Server-CA/emailAddress=nobody@example.net"`

Before running this last command create a new file which should contain something similar to this and pass the filename as the parameter to `extfile` (using the bash script will do this for you). Make sure to change the first entry in `subjectAltName` to your hostname and if you have a static IP for your server you can add it onto the end following the same syntax as the previous two.

```
[ MQTTextensions ]
basicConstraints		= critical,CA:false
subjectAltName 			= DNS:YOUR_HOST_NAME,DNS:localhost,IP:127.0.0.1,IP:::1
keyUsage			= nonRepudiation, digitalSignature, keyEncipherment
extendedKeyUsage		= serverAuth
nsComment			= "MQTT Broker Cert"
```

`openssl x509 -req -in mosq_serv.csr -CA mqtt_ca.crt -CAkey mqtt_ca.key -CAcreateserial -CAserial mqtt_ca.srl -out mosq_serv.crt -days 3650 -extfile YOUR_EXTENSION_FILE -extensions MQTTextensions`

Now you should have a certificate for your server signed by your CA certificate!

### Knowledge Check

Before moving onto making the client cert, we will first check to make sure everything is working properly by loading the CA and server cert onto our Mosquitto broker. Add the following to your `mosquitto.conf` file and restart the service.

```
port 8883

cafile /path/to/your/ca/file
certfile /path/to/your/server_crt/file
keyfile /path/to/your/server_key/file
```
Port can be any port of your choosing but 8883 seems to be the norm for TLS on Mosquitto. 

Now in a terminal on your server run the following command

`mosquitto_sub -h localhost -p 8883 --cafile /path/to/ca/file -t test`

In a seperate tab run this command

`mosquitto_pub -h localhost -p 8883 --cafile /path/to/ca/file -t test -m "Hello"`

You should see `Hello` on your first tab. If any errors occured go through the steps up to this point and make sure you did everything correctly. Make sure your certs have the correct permissions to allow the server to read them. If your permissions are correct and still having errors, make sure the hostnames you supplied for the server `CN` and `subjectAltName` parameters are correct. 

### Client Certificate

These commands are almost identical to the server ones

`openssl genrsa -out esp8266-cli.key 2048`

`openssl req -new -out esp8266-cli.csr -key esp8266-cli.key -subj "/CN=esp8266-cli/O=YourOrg/OU=Client-CA/emailAddress=nobody@example.net"`

`openssl x509 -req -in esp8266-cli.csr -CA mqtt_ca.crt -CAkey mqtt_ca.key -CAcreateserial -out esp8266-cli.crt -days 3650 -extfile YOUR_EXTENTION_FILE -extensions MQTTextensions`

Extension file for client should look like this:

```
[ MQTTextensions ]
basicConstraints		= critical,CA:false
subjectAltName 			= DNS:esp8266-cli,DNS:esp8266-cli.local
keyUsage			= nonRepudiation, digitalSignature, keyEncipherment
extendedKeyUsage		= clientAuth
nsComment			= "MQTT Client Cert"
```

Again if you plan on putting a static IP on your ESP8266 feel free to add it to the `subjectAltName`. The thing to note here as well is that `extendedKeyUsage' changed to `clientAuth`. I'm not sure if this is necessary but this is what worked for me.

Add this line to your `mosquitto.conf` file and restart the service again

`require_certificate true`

Now everytime a device tries to connect to your server they must supply a certificate and key which has been signed by your CA certificate.
