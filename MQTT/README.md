# How to setup TLS on MQTT Broker using Mosquitto and Connect with ESP8266

#### Motivation behind post
After looking online for serval hours for tutorials on this, it became apparent to me that it was not going to be as easy as I had hoped
for. Many of the tutorials I found varied in their implementations, some were blatenly wrong or lacked sufficent documentation, and 
others were outdated. Out of the box Mosquttio does not supply any security features. It is easy to setup a username and password requirement,
but your traffic is still sent in cleartext. Setting up security on your IoT devices should not be as difficult as this was for me. Anybody
who finds this, I hope this can cut down on the amount of time it takes you to implement this level of security on your devices and prevents
some migrains from occuring.

## Certificates
Starting from the beginning, we need to create a certificate chain with a self-signed CA certificate, server certificate, and our client
certificate. This can all be done using OpenSSL.

To be continued...
