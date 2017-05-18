## Read me

###### Purpose of the project

The aim of this prototype is to test RADIUS dynamic discovery. Indeed, communication between two radius servers typically needs static configuration (IP, common secret, port).

In this prototype, dynamic discovery is carried out by the radsecproxy server.

The radsecproxy server receives the eap request on port 1812, checks the user name and sees if it matches the domain name for which the freeradius server is authoritative. If it matches, the server will forward the request to the freeradius listening on the port 1814. If it is not, it will run a script to try to discover the coordinates of the authoritative radius.

To do so, it will perform a series of dig requests (NAPTR, then SRV), and then contact the authoritative radius via radsec.

### Installation and configuration

You must begin by cloning the project / copying the files. If you're using a VM snapshot provided by us, it will be in `/opt`. The following procedure will install a freeradius server, a radsecproxy and a bind server, as well as other tools required. It will then configure them.

##### Ansible Installation

To begin with one must install ansible :

```
$ sudo apt-get install software-properties-common
$ sudo apt-add-repository ppa:ansible/ansible
$ sudo apt-get update
$ sudo apt-get install ansible
```
The script was developped and tested under ansible 2.3.0.0.

Then, one must configure the Ansible inventory (basically, in which hosts the ansible playbooks should be run).

To run it in localhost, in `/etc/ansible/hosts`, add the following line :

`test ansible_connection=local ansible_host=localhost`

To run in a distant server, add :

`test ansible_port=22 ansible_host=10.10.10.10`

Where `ansible_host` is the IP of the server and `ansible_port` the ssh port.

To run the script on a distant server, add your rsa public key to the server's `authorized_keys`. The scripts should be run as root, so you can either add the key to the root's ~/.ssh, or add it to another user's and use the privilege escalation ansible config.
To use privilege escalation, add the following in `/etc/ansible/ansible.cfg` :

```
[privilege_escalation]
become=Yes
become_method=sudo
become_user=root
become_ask_pass=True
```

This will activate a prompt during the scripts' execution to ask for the user's password in order to sudo su.

You'll need a DNS pointing to the virtual machine's IP. We'll refer to it as our "realm".

Now configure the parameters in `parameters.yml` and modify the defaults to suit your identity :

```
realm: "openroaming.org" #dns pointing towards the virtual machine
country_code: "FR"
region: "Ile-de-France"
locality: "Paris"
organization: "Open Dynamic Roaming"
org_unit: "IT"
dns_ip_address: 20.20.20.20
radius_ip_address: 20.20.20.20
```

`dns_ip_address` corresponds to the  DNS server IP address that will be used. By default, use the machine's which will allow you to use our configuration.

`radius_ip_address` corresponds to the radsecproxy's IP address. You should put the machine's.

Then, go into the `playbooks` folder and run the first playbook as follows :

If you're running ansible in localhost, become root then run :

`ansible-playbook install-playbook.yml`

If you're running ansible on a distant server, you need to run the run the command :

`ansible-playbook install-playbook.yml -u user`

...where user is the user whose home contains your computer's authorized key.
It can be root, or another user if you're using privilege escalation.

This script will install the basic programs needed to run the prototype [see further section].

Then, run :

`ansible-playbook configure-main-playbook.yml` or `ansible-playbook install-playbook.yml -u user` in very much the same manner.

##### Testing your deployment

You must then configure your AP. The request are on the port 1812 and the shared secret can be configured in the radsec_apsecret paremeter.

In order to test whether the installation was successful, you can use bob, the default user via EAP-TTLS from your phone or computer.

```
EAP-method : TTLS
username : bob@realm
password : hello
Phase2 authentication : None
CA certificate : Do not validate
```

The authentication for bob uses the freeradius' files module, and is located in `/etc/freeradius/mods-config/files` :

```
bob	 		Cleartext-Password := "hello"
				Reply-Message := "Hello, %{User-Name}"
```

Users can be added to the files module by adding lines in a similar fashion, and reloading the configuration with `service freeradius reload`.

##### Generating user certificates

In order to test EAP-TLS you need to generate user certificates by signing them the intermediate certificate associated to your realm. Here's how to do it:

```
cd /etc/ssl/private
./client-cert.sh <username>
```

This will ask you a password and generate .pfx (located) in intermediate/certs/user@realm.pfx. You may download it to your phone or computer and install it, with the password, to test EAP-TLS :


```
EAP-method : TLS
username : username@realm
CA certificate : [The one you just downloaded]
domain : realm
```

##### Certificate chain

```
                                                  +-------------------------------------------------------------+
                                                   |                                                             |
                                                   |                Root OpenRoaming certificate                 |
                                                   |                                                             |
                                                   +-+-------------------------------+-------------------------+-+
                                                     |                               |                         |
                                                     |                               |                         |
                                                 +---+                               |                         +---------------+
                                                 |                                   |                                         |
                                                 |                                   |                                         |
                                  +--------------v-------------+      +--------------v-------------+            +--------------v-------------+
                                  |  Realm 1                   |      |  Realm 2                   |            |  Realm N                   |
                                  |  Intermediate certificate  |      |  Intermediate certificate  |            |  Intermediate certificate  |
                                  +-+-----------+-----------+--+      +----------------------------+            +----------------------------+
                                    |           |           |
                                    |           |           |
              +---------------------+           |           +---------+
              |                                 |                     |
+-------------v--------------+  +---------------v------+  +-----------v----------+
|Server certificate          |  |Server certificate    |  |Client certificate    |
|Authenticate on EAP-TLS/TTLS|  |Authenticate on Radsec|  |Authenticate on Radsec|
+----------------------------+  +----------------------+  +----------------------+
```

### Server certificate

A web server is used to sign the intermediate certificate. A post request with curl is executed in the configure-ssl-request to post the certificate via https to the sign-server. The sign-server is specified by default in parameters.yml in the `sign_server` parameter but you may change it to specify your own server.

##### Installing your own sign server

In order to install your own sign server, you'll need to install Node. The server was tested with Node 7. To install it, run :

```
curl -sL https://deb.nodesource.com/setup_7.x | sudo -E bash -
sudo apt-get install -y nodejs
```
Once node has been installed, go to the sign-server folder and run `npm install` to install the necessary modules.

Then, if needed, you must create the root key and certificate. to sign intermediate certificates with. From the sign-server folder :

```
cd root/ca
mkdir crl newcerts private certs
chmod 700 private

# create the key :
openssl genrsa -aes256 -out private/ca.key.pem 4096

# create the root cert :
openssl req -config openssl.cnf \
      -key private/ca.key.pem \
      -new -x509 -days 7300 -sha256 -extensions v3_ca \
      -out certs/ca.cert.pem
```
Then to configure the server you must copy the contents of `cofig.json.template` to `config.json` and indicate the paths to the newly created certificate and key in the `CACert` and `CAKey` fields.

To read more about openssl and setting up certificates, check : https://jamielinux.com/docs/openssl-certificate-authority/.

Last step is to set DNS configuration and to create the necessary certificates for https. We used let's encrypt.

Indicate the path to the necessary keys and certificate, in config.json, in the `ServerCert` and `ServerKey` fields.

By now, it should be good to go. In the sign-server folder, get the server running the command `node app.js`.
