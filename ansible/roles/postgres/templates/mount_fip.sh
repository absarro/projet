#!/bin/bash
IP="{{ (postgres_cluster_nodes_fips_map|dict2items|selectattr("key", "match", "postgres-fip-"~pgpool_node_id~"-.*")|list|first).value }}/21"
DEV="ens3"
LABEL="ens3:99"

/sbin/ip addr add $IP dev $DEV label $LABEL
