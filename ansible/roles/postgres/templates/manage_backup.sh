#!/bin/bash

app=$(hostname -A | cut -d' ' -f1 | cut -c12-14)
PATH_LOG="/applis/${app}/pgsql/logs"
LOG_FILE="${PATH_LOG}/manage_backup_$(date +'%Y%m%d%H%M%S').log"

# Création du dossier de logs si inexistant
if [ ! -d "$PATH_LOG" ]; then
   mkdir -p "$PATH_LOG"
   echo "Dossier de logs créé : $PATH_LOG" | tee -a "$LOG_FILE"
fi

# Fonction d'aide
help() {
   echo "Aide du script manage_backup.sh"
   echo ""
   echo "Ce script permet de gérer les backups d'une base de données PostgreSQL avec pgBackRest."
   echo ""
   echo "Options:"
   echo " -h          Afficher ce message d'aide."
   echo " -b <stanza> <type> Lancer un backup. Types possibles : full, diff, incr."
   echo " -r <stanza> <type> [<option>] Lancer une restauration. Types possibles : immediate, time, latest. Options possibles : --target-timeline."
   echo " -s <stanza> <action> Gérer les stanzas. Actions possibles : create, drop."
   echo " -t <stanza> Afficher le statut de pgBackRest pour la stanza spécifiée."
   echo ""
}

# Fonction pour vérifier si le script est exécuté sur le nœud master PostgreSQL
is_master() {
   psql -t -c "SELECT pg_is_in_recovery();" | grep -q "f"

}

# Fonction pour lancer un backup
backup() {
   stanza=$1
   type=$2
   if is_master; then
      echo "Lancement d'un backup $type pour le stanza $stanza" | tee -a "$LOG_FILE"
      pgbackrest --stanza=$stanza --type=$type backup --log-level-console=info --log-level-file=detail --log-path=$PATH_LOG
   else
      echo "Les backups ne peuvent être effectués que sur le nœud master PostgreSQL." | tee -a "$LOG_FILE"
      exit 1
   fi
}

# Fonction pour lancer une restauration
restore() {
   stanza=$1
   type=$2
   option=$3
   echo "Lancement d'une restauration $type pour le stanza $stanza" | tee -a "$LOG_FILE"
   pgbackrest --stanza=$stanza --type=$type $option restore --log-level-console=info --log-level-file=detail --log-path=$PATH_LOG
}

# Fonction pour gérer les stanzas
manage_stanza() {
   stanza=$1
   action=$2
   echo "Gestion du stanza $stanza avec l'action $action" | tee -a "$LOG_FILE"
   pgbackrest --stanza=$stanza stanza-$action --log-level-console=info --log-level-file=detail --log-path=$PATH_LOG
}

# Fonction pour afficher le statut
status() {
   stanza=$1
   echo "Affichage du statut de pgBackRest pour la stanza $stanza" | tee -a "$LOG_FILE"
   pgbackrest info --stanza=$stanza --log-level-console=info --log-level-file=detail --log-path=$PATH_LOG
}

# Parsing des options
while getopts ":hb:r:s:t:" opt; do
   case $opt in
      h)
         help
         exit 0
         ;;
      b)
         stanza=$OPTARG
         type=$3
         backup $stanza $type
         ;;
      r)
         stanza=$OPTARG
         type=$3
         option=$4
         restore $stanza $type "$option"
         ;;
      s)
         stanza=$OPTARG
         action=$3
         manage_stanza $stanza $action
         ;;
      t)
         stanza=$OPTARG
         status $stanza
         ;;
      \?)
         echo "Option invalide : -$OPTARG" >&2
         help
         exit 1
         ;;
   esac
done

if [ $OPTIND -eq 1 ]; then
   echo "Aucune option spécifiée."
   help
   exit 1
fi
