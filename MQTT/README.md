# How to setup TLS on MQTT Broker using Mosquitto and Securely Connect with ESP8266

#### Motivation behind this guide
After looking online for serval hours for tutorials on this, it became apparent to me that it was not going to be as easy as I had hoped for. Many of the tutorials I found varied in their implementations, some were blatantly wrong or lacked sufficient documentation, and others were outdated. Out of the box Mosquttio does not supply any security features. It is easy to setup a username and password requirement, but your traffic is still sent in cleartext. Setting up security on your IoT devices should not be as difficult as this was for me. Anybody who finds this, I hope this can cut down on the amount of time it takes you to implement this level of security on your devices and prevents some migraines from occurring.

## Certificates
Starting from the beginning, we need to create a certificate chain with a self-signed CA certificate, server certificate, and our client certificate. This can all be done using `OpenSSL`. Inside this folder will be two bash scripts. One for creating the CA cert and the other for creating the server and client certs. If you want to run the commands by hand instead, they will be documented below.

### CA Certificate
This command creates a new certificate and key which we will use to sign the rest of our certificates with. Feel free to change the parameters around to your liking. The content within the `subj` parameter is not super important for the CA cert but will be later when making the other ones.

`openssl req -new -x509 -days 3650 -extensions v3_ca -keyout mqtt_ca.key -out mqtt_ca.crt -subj "/CN=MQTT CA/O=PrestigeWorldWide/OU=generate-CA/emailAddress=nobody@example.net"`

### Server Certificate
Create an RSA server private key

`openssl genrsa -out mosq_serv.key 2048`

Create a Certificate Signing Request (CSR) using the newly generate private key. A CSR is an intermediate step to allow you to ask the CA for a certificate and supple necessary information for the certificate.

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

In a separate tab run this command

`mosquitto_pub -h localhost -p 8883 --cafile /path/to/ca/file -t test -m "Hello"`

You should see `Hello` on your first tab. If any errors occurred go through the steps up to this point and make sure you did everything correctly. Make sure your certs have the correct permissions to allow the server to read them. If your permissions are correct and still having errors, make sure the hostnames you supplied for the server `CN` and `subjectAltName` parameters are correct. 

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

Again if you plan on putting a static IP on your ESP8266 feel free to add it to the `subjectAltName`. The thing to note here as well is that `extendedKeyUsage` changed to `clientAuth`. I’m not sure if this is necessary but this is what worked for me.

Add this line to your `mosquitto.conf` file and restart the service again

`require_certificate true`

Now everytime a device tries to connect to your server they must supply a certificate and key which has been signed by your CA certificate.

## ESP8266

Before we can connect to our server with our ESP8266, we need to first convert the format of our CA and client certs. Right now they are in PEM format and we need them to be in DER format. Luckily, Openssl provides an easy way to do this. We will need to convert our CA cert, client cert, and client key.

`openssl x509 -in mqtt_ca.crt -out mqtt_ca.crt.der -outform DER`

`openssl x509 -in esp8266-cli.crt -out esp8266-cli.crt.der -outform DER`

`openssl rsa -in esp8266-cli.key -out esp8266-cli.key.der -outform DER`

Now it's time for the ESP8266 to connect to the Mosquitto server using the newly formatted certs. 

```C
#include <ESP8266WiFi.h>
#include <PubSubClient.h>
#include <NTPClient.h>
#include <WiFiUdp.h>

const char *TOPIC = "test";

void callback(char *msgTopic, byte *msgPayload, uint16_t msgLength);

WiFiClientSecure espClient;
PubSubClient client("mosq_serv.local", 8883, callback, espClient);
WiFiUDP ntpUDP;
NTPClient timeClient(ntpUDP, "pool.ntp.org");

void connectWiFi() {
  delay(10);

  WiFi.hostname("esp8266-cli"); // CHANGE TO YOUR HOSTNAME!!!
  WiFi.begin(WIFI_SSID, WIFI_PASS);
  while(WiFi.status() != WL_CONNECTED) {
    Serial.printf(".");
    delay(1000);
  }
  Serial.printf("Connected to %s using IP %s\n", WiFi.SSID().c_str(), WiFi.localIP().toString().c_str()); 
  
  timeClient.begin();
  while(!timeClient.update()) { timeClient.forceUpdate(); }
  espClient.setX509Time(timeClient.getEpochTime());
}
```
According to a few tutorials I found, you need to sync your device to an NTP server before connecting because of x509 specifications. I haven't checked if it works without syncing but it's easy enough to sync so I figured it wasn't worth fiddling with. 

```C
// Connect to MQTT server
void reconnect() {
  while(!client.connected()) {
    Serial.printf("Connecting to MQTT with ID: %s\n", CLIENT_ID);

    if(client.connect(CLIENT_ID)) {
      Serial.println("Connected to MQTT Server");
      client.subscribe(TOPIC);
      client.publish(TOPIC, "Hello from ESP8266 over TLS!");
    } else {
      Serial.println("Connection to MQTT Failed");
      Serial.printf("rc= %d\n", client.state());

      char buf[256];
      espClient.getLastSSLError(buf, 256);
      Serial.printf("WiFi SSL Error: %s\n", buf);
      delay(3000);
    }
  }
}
```
The returned SSL errors here are extremely helpful. The errors will be a little vague but can at least point you in the right direction. Looking at the logs on your server while trying to connect is another good way of trying to diagnose problems you may encounter `tail -f mosquitto/log/mosquitto.log`

```C
void setup() {
  Serial.begin(115200);

  if(!SPIFFS.begin()) {Serial.println("Failed to mount file system");}

  Serial.printf("Heap: %d\n", ESP.getFreeHeap());

  // Connect to Wifi
  connectWiFi();

  // Load Certs
  File clientCert = SPIFFS.open("/esp8266-cli.crt.der", "r");
  if(!clientCert) {Serial.println("Failed to read Client Cert");}
  if(espClient.loadCertificate(clientCert)) {Serial.println("Loaded Client Cert");}

  File clientPriv = SPIFFS.open("/esp8266-cli.key.der", "r");
  if(!clientPriv) {Serial.println("Failed to read Cient Privkey");}
  if(espClient.loadPrivateKey(clientPriv)) {Serial.println("Loaded Client Privkey");}

  File caCert = SPIFFS.open("/mqtt_ca.crt.der", "r");
  if(!caCert) {Serial.println("Failed to read CA Cert");}
  if(espClient.loadCACert(caCert)) {Serial.println("Loaded CA Cert");}

  Serial.printf("Heap: %d\n", ESP.getFreeHeap());
}

void loop() {
  if(!client.connected()) {
    reconnect();
  } 
  client.loop();
  delay(500);
}
```
If you still have your listener running on the `test` topic, you should hopefully see a new message now. I hope if anyone does come across this that it will be beneficial to them and save some hours of debugging and frustration. All this information came from an accumulation of other tutorials that I came across. Links for all of them will be down below.

- https://nofurtherquestions.wordpress.com/2016/03/14/making-an-esp8266-web-accessible/
- http://rockingdlabs.dunmire.org/exercises-experiments/ssl-client-certs-to-secure-mqtt
- https://hackaday.io/project/12482-garage-door-opener/log/45617-connecting-the-esp8266-with-tls
- https://raphberube.com/blog/2019/02/18/Making-the-ESP8266-work-with-AWS-IoT.html
- https://github.com/raph84/esp8266-aws_iot
- https://www.openssl.org/
