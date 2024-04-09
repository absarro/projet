#!/bin/bash
# Usage  ./rotate_key.sh old_key_name new_key_name


# Verifier les arguments

if [ $# -ne 4 ]
 then
	echo "Usaege: $0 old_key_name new_key_name path_to_get_key_id_script path_to_kmip_conf"
	exit 1
fi
	

old_key_name=$1
new_key_name=$2
path_to_get_key_uid_script=$3
path_to_kmip_conf=$4

echo "Inputs parameters"
echo "Old Key name: $old_key_name"
echo "New Key name: $new_key_name"
echo "chemin du spirt python pour récupérer l'UID de la cle: $path_to_get_key_uid_script"
echo "Chemin du  fichier de configuration PyKMIP: $path_to_kmip_conf"


echo "Test de déchiffremnt de la clé bdd avec la CMK"
python3 /usr/edb/kmip/client/edb_tde_kmip_client.py decrypt --in-file=$PGDATA/pg_encryption/key.bin --pykmip-config-file=$path_to_kmip_conf --key-uid=$($path_to_get_key_uid_script $old_key_name $path_to_kmip_conf) --variant=thales  
if [ $? -eq 0 ]
 then
	echo "    Resultat du test OK"
        echo "Dechiffrement de $PGDATA/pg_encryption/key.bin avec l'ancienne Master Key $old_key_name"
	echo "Reencryption de la clé déchiffrée avec la nouvelle Master Key $new_key_name vers le fichier $PGDATA/pg_encryption/key.bin.new"
        python3 /usr/edb/kmip/client/edb_tde_kmip_client.py decrypt --in-file=$PGDATA/pg_encryption/key.bin --pykmip-config-file=$path_to_kmip_conf --key-uid=$($path_to_get_key_uid_script $old_key_name $path_to_kmip_conf) --variant=thales  | python3 /usr/edb/kmip/client/edb_tde_kmip_client.py encrypt --out-file=$PGDATA/pg_encryption/key.bin.new --pykmip-config-file=$path_to_kmip_conf  --key-uid=$($path_to_get_key_uid_script $new_key_name $path_to_kmip_conf) --variant=thales


	echo "Renommage du fichier  $PGDATA/pg_encryption/key.bin.new vers $PGDATA/pg_encryption/key.bin"
	mv  $PGDATA/pg_encryption/key.bin.new  $PGDATA/pg_encryption/key.bin

	echo "Modification  de la nouvelle valeur key_uid sur le fichier  $PGDATA/postgresql.conf"
	sed -i  "s/$($path_to_get_key_uid_script $old_key_name $path_to_kmip_conf)/$($path_to_get_key_uid_script $new_key_name $path_to_kmip_conf)/g" $PGDATA/postgresql.conf
 
	export PGDATAKEYWRAPCMD="python3 /usr/edb/kmip/client/edb_tde_kmip_client.py encrypt --pykmip-config-file=$path_to_kmip_conf --key-uid=$($path_to_get_key_uid_script $new_key_name $path_to_kmip_conf)  --out-file=%p --variant=thales"
        export PGDATAKEYUNWRAPCMD="python3 /usr/edb/kmip/client/edb_tde_kmip_client.py decrypt --pykmip-config-file=$path_to_kmip_conf --key-uid=$($path_to_get_key_uid_script $new_key_name $path_to_kmip_conf)  --in-file=%p --variant=thales"

	echo "export PGDATAKEYWRAPCMD=$PGDATAKEYWRAPCMD"
	echo "export PGDATAKEYUNWRAPCMD=$PGDATAKEYUNWRAPCMD"
   
 else
	echo "resultat du test KO"
	echo "Le dechiffrememnt n'a pas pu etre effectué avec la master key fournie $old_key_name"
fi
