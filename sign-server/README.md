# Signer des certificats à partir d'un CA root

Ce projet a pour objectif de créer un serveur permettant de recevoir des demandes de signatures, et de signer des certificats à partir d'un CA root à la suite d'une validation utilisateur.

Il faut tout d'abord configurer le root certificat dans le config.json en entrant le certificat, sa clé et le password de la clé.

Ensuite, il faut poster un fichier csr sur la "/signCertificat" dans un formulaire de type "file" avec le nom "csr".

Il est possible de récupérer le CA root sur "/rootCA".

Commande pour uploader avec curl : curl -v -F key1=value1 -F upload=@localfilename URL