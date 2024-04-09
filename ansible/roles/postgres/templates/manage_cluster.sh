#!/bin/bash

# Default configuration
postgres_version="{{ postgres_version }}"
postgres_type="{{ postgres_type }}"
pgpool_port="9900"
pgpool_wport="9800"
BDD=$(hostname -A | cut -d' ' -f1 | cut -c12-14)
pg_user={{ postgres_user }}
pg_home="/home/{{ postgres_user }}"
bin_path="/usr/{{ (postgres_type == 'PG')|ternary('pgsql-', 'edb/as') }}{{ postgres_version.split('.')|first }}/bin"
path_log="/applis/$BDD/pgsql/logs"
log="$path_log/manage_cluster_${BDD}_$(date +'%Y%m%d%H%M').log"
data_dir="/applis/$BDD/pgsql/${postgres_version}/data"
tbs_dir="/applis/$BDD/pgsql/tbs"


# Function to print the help message
print_help() {
  cat <<HELP
Usage: $0 [options] command [arguments]

Options:
  -h, --help               Show this help message

Commands:
  pg_state OPERATION      Perform an operation (start, stop, status, restart) on PostgreSQL
  resync_standby STANDBYNODE Resynchronize the specified standby server with the master server
  show_repli               Show replication status
  show_watchdog            Show watchdog information

STANDBYNODE should be the alias of the standby node to resynchronize.
HELP
}

# Improved argument parsing
while getopts ":h" opt; do
  case $opt in
    h) print_help && exit 0 ;;
    *) echo "Invalid option: -$OPTARG" >&2 && print_help && exit 1 ;;
  esac
done
shift $((OPTIND - 1))

create_logs_folder() {
  mkdir -p "$path_log" && echo "Log directory $path_log created." | tee -a "$log"
}

purge_old_logs() {
  find "$path_log" -mtime +6 -exec rm {} \; && echo "Old logs purged." | tee -a "$log"
}

pg_state() {
  local operation="$1"
  create_logs_folder
  "${bin_path}/pg_ctl" -D "$data_dir" $operation | tee -a "$log"
}

get_master_node_ip() {
  master_ip=$(pcp_watchdog_info -h localhost -U pgpool -p "$pgpool_wport" -w | grep "LEADER" | awk '{print $4}')
  echo "$master_ip"
}

resync_standby() {
  local standbynode="$1"
  if [[ -z $standbynode ]]; then
    echo "Error: Standby node alias not provided." | tee -a "$log"
    exit 1
  fi

  local node_master=$(get_master_node_ip)
  if [[ -z $node_master ]]; then
    echo "Error: Master node IP could not be determined." | tee -a "$log"
    exit 1
  fi

  echo "Connecting to standby node $standbynode to stop PostgreSQL and clear data directory..." | tee -a "$log"
  ssh -t "{{ postgres_user }}@$standbynode" <<EOF
set -e
"${bin_path}/pg_ctl" -D "$data_dir" stop || true
rm -rf "$data_dir"/* 
rm -rf "$tbs_dir"/*
echo "Data directory cleared."
exit
EOF

  echo "Starting resynchronization with pg_basebackup from master node $node_master..." | tee -a "$log"
  ssh -t "{{ postgres_user }}@$standbynode" <<EOF
"${bin_path}/pg_basebackup" --format=p -D "$data_dir" --label=standby --host="$node_master" --username=repl --wal-method=stream -R
exit
EOF
  echo "Resynchronization complete." | tee -a "$log"

  echo "Connecting to standby node $standbynode to start PostgreSQL..." | tee -a "$log"
  ssh -t "{{ postgres_user }}@$standbynode" <<EOF
    set -e
    "${bin_path}/pg_ctl" start -D "$data_dir" 
exit
EOF

}

show_repli() {
  create_logs_folder
  psql -h {{ postgres_node_alias }} -p "$pgpool_port" -U "{{ postgres_user }}" -c "show pool_nodes" "$BDD" | tee -a "$log"
}

show_watchdog() {
  create_logs_folder
  pcp_watchdog_info -h {{ postgres_node_alias }} -U pgpool -p "$pgpool_wport" -v -w | tee -a "$log"
}

# Command execution
command="$1"
if [[ -n $command ]]; then
  shift  # Remove command from arguments list
  case "$command" in
    pg_state) pg_state "$@" ;;
    resync_standby) resync_standby "$@" ;;
    show_repli) show_repli ;;
    show_watchdog) show_watchdog ;;
    *)
      echo "Error: Unknown command '$command'" >&2 && print_help && exit 1 ;;
  esac
else
  echo "Error: No command provided." >&2 && print_help && exit 1
fi
