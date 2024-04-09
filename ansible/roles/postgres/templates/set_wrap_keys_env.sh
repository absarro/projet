#!/bin/bash
# Usage  ./setup.sh keyname


# Verifier les arguments

if [ $# -ne 3 ]
 then
	echo "Usage: $0  keyname path_to_get_key_uid_script path_to_kmip_conf"
	exit 1
fi
key_name=$1
path_to_get_key_uid_script=$2
path_to_kmip_conf=$3
echo "Inputs parameters"
echo "Kay name: $key_name"
echo "chemin du spirt python pour récupérer l'UID de la clé: $path_to_get_key_uid_script"
echo "Chemin du  fichier de configuration PyKMIP: $path_to_kmip_conf"

key_id=$($path_to_get_key_uid_script $key_name $path_to_kmip_conf)

export PGDATAKEYWRAPCMD="python3 /usr/edb/kmip/client/edb_tde_kmip_client.py encrypt --pykmip-config-file=$path_to_kmip_conf --key-uid=$key_id  --out-file=%p --variant=thales"
export PGDATAKEYUNWRAPCMD="python3 /usr/edb/kmip/client/edb_tde_kmip_client.py decrypt --pykmip-config-file=$path_to_kmip_conf --key-uid=$key_id  --in-file=%p --variant=thales"

echo "export PGDATAKEYWRAPCMD=$PGDATAKEYWRAPCMD"
echo "export PGDATAKEYUNWRAPCMD=$PGDATAKEYUNWRAPCMD"
