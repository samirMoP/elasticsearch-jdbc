#!/bin/bash 
consul_url="10.1.9.22/v1/kv/environments/dev/pg2es-importer_localhost.json"

pg_url=$(curl -XGET "$consul_url/db_url" 2>/dev/null | awk '{split($0,a,","); print a[4]}' | cut -d":" -f2 | cut -d'"' -f2 | base64 --decode)
es_cluster_name=$(curl -XGET "$consul_url/es_cluster" 2>/dev/null | awk '{split($0,a,","); print a[4]}' | cut -d":" -f2 | cut -d'"' -f2 | base64 --decode)
es_cluster_host=$(curl -XGET "$consul_url/host" 2>/dev/null | awk '{split($0,a,","); print a[4]}' | cut -d":" -f2 | cut -d'"' -f2 | base64 --decode)
es_cluster_host2=$(curl -XGET "$consul_url/host_second" 2>/dev/null | awk '{split($0,a,","); print a[4]}' | cut -d":" -f2 | cut -d'"' -f2 | base64 --decode)
es_port=$(curl -XGET "$consul_url/port" 2>/dev/null | awk '{split($0,a,","); print a[4]}' | cut -d":" -f2 | cut -d'"' -f2 | base64 --decode)
pg_user=$(curl -XGET "$consul_url/user" 2>/dev/null | awk '{split($0,a,","); print a[4]}' | cut -d":" -f2 | cut -d'"' -f2 | base64 --decode)
pg_password=$(curl -XGET "$consul_url/password" 2>/dev/null | awk '{split($0,a,","); print a[4]}' | cut -d":" -f2 | cut -d'"' -f2 | base64 --decode)


if [ "$1" == "debug"  ]; then
  echo $pg_url
  echo $es_cluster_name
  echo $pg_user
  echo $es_port
  echo $pg_password
  echo $es_cluster_host
  echo $es_cluster_host2
fi
