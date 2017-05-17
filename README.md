## Read me

###### Purpose of the project

The aim of this prototype is to test RADIUS dynamic discovery. Indeed, communication between two radius servers typically needs static configuration (IP, common secret, port).

In this prototype, dynamic discovery is carried out by the radsecproxy server.

The radsecproxy server receives the eap request on port 1812, checks the user name and sees if it matches the domain name for which the freeradius server is authoritative. If it matches, the server will forward the request to the freeradius listening on the port 1814. If it is not, it will run a script to try to discover the coordinates of the authoritative radius.

To do so, it will perform a series of dig requests (NAPTR, then SRV), and then contact the authoritative radius via radsec.

### Installation and configuration

You must begin by cloning the project / copying the files. The following procedure will install a freeradius server, a radsecproxy and a bind server, as well as other tools required. It will then configure them.

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
```

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
openssl genrsa -aes256 -out intermediate/private/username@realm.key.pem 2048
openssl req -config intermediate/openssl.cnf \
      -key intermediate/private/username@realm.key.pem \
      -new -sha256 -out intermediate/csr/username@realm.csr.pem
```
Of course, do remember to change the username and realm.

You will be promted to enter the user information. You can use defaults *except* for the Common Name *which must be unique* and *must be of the form username@realm*. Indeed, the realm will be used to perform a DNS request to discover the user's radius server's IP.
This will create the Certificate Signing Request. In order to sign it :

```
openssl ca -config intermediate/openssl.cnf \
      -extensions usr_cert -days 375 -notext -md sha256 \
      -in intermediate/csr/username@realm.csr.pem \
      -out intermediate/certs/username@realm.cert.pem
```

This will create the certificate. However, in order to install it on a phone, you must create a .pfx :

```
openssl pkcs12 -export -out intermediate/certs/user@realm.pfx \
  -inkey intermediate/private/user@realm.key.pem \
  -in  intermediate/certs/user@realm.cert.pem \
  -certfile intermediate/certs/ca-chain.cert.pem
```

The generated .pfx (located) in intermediate/certs/user@realm.pfx. You may download it to your phone or computer and install it to test EAP-TLS :


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

### Scripts overview
