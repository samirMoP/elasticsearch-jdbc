#!/bin/bash

source ./get_consul_vars.sh
if [ "$#" -lt 1 ]; then
    echo "Are you sure what are you doing :) ? This will trigger actfees full reindex."
    echo "Usage: $0 [YES] [single|dist]"
    exit -1
fi
confirm=$1
shift
mode=$1
shift
case $mode in
(dist)
  mode="dist"
  ;;
  (*)
  mode="single"
  ;;
esac

prev_timestamp=$(cat af_last_version | cut -d"_" -f2)
prev_version_pid=$(pgrep -f ".*af_config_$prev_timestamp.json")
prev_version=$(cat af_last_version)
echo "Previous version pid $prev_version_pid"
timestamp=$(date +%s)

echo "Writting feeds_$timestamp as current index"
echo "feeds_$timestamp" > af_last_version

definition=$'{
    "type" : "jdbc",
    "jdbc" : {
        "metrics" : {
           "enabled" : true,
           "interval" : "1m",
           "logger" : {
             "plain" : true,
             "json" : false
       }},
        "sql" : [
                {
                 "statement":"select activity_id as _id, (case when last_update_date is null then creation_date else last_update_date end) as last_update_date, placeholder_data->\'terminal_id\' as terminal_id, activity_id, additional_data, advertisement_id, comments, contest_id, creation_date, deep_link, dislikes, event, expiration_date, is_pinned, likes, message, message_1, message_2, object_type, object_url, order_id, placeholder, placeholder_1, placeholder_2, placeholder_data, publication_date, signal_id, symbol, terminal_type, user_id1, user_id2, (select to_jsonb((select array(select row_to_json((select d from(select u.user_name, al.user_id, al.creation_date) d)) as data from sx_activity_likes al join sx_users u on al.user_id= u.user_id  where al.activity_id=af.activity_id order by al.creation_date desc limit 100)))) as recent_likers, (select xl.creation_date from sx_activity_likes xl where xl.activity_id = af.activity_id and xl.status = \'LIKE\' order by xl.creation_date desc limit 1) as last_like_date, (select to_jsonb( array(select xc.user_id from sx_activity_comments xc where xc.activity_id =af.activity_id order by xc.comment_id desc limit 50))) as recent_commenters, (select to_jsonb((select array(select row_to_json((select d from(select u.user_name, ac.user_id, ac.comment, ac.creation_date) d)) as data from sx_activity_comments ac join sx_users u on ac.user_id= u.user_id  where ac.activity_id=af.activity_id order by ac.creation_date desc limit 100)))) as user_commenters  from sx_activity_feed af where af.creation_date >?::timestamp with time zone - \'00:00:3\'::interval or af.last_update_date >?::timestamp with time zone - \'00:00:3\'::interval",
                 "parameter" : ["$metrics.lastexecutionstart", "$metrics.lastexecutionstart"]
               }
               ],
         "elasticsearch" : {
                      "cluster" : "'$es_cluster_name'",
                      "host" : ["'$es_cluster_host'"],
                      "port" : '$es_port' },
        "index" : "feeds_'$timestamp'",
        "statefile" : "af_statefile_'$timestamp'.json",
        "url" : "'$pg_url'",
        "user" : "'$pg_user'",
        "password" : "'$pg_password'",
        "type" : "feed",
        "schedule" : "0/5 * * ? * *",
        "detect_json" : false,
	"mode": "'$mode'"
    }
}'
def_file="af_config_$timestamp.json"

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
bin=${DIR}/../bin
lib=${DIR}/../lib

echo "Previous index version $prev_version"
echo "Writting new config file"
echo "$definition" > "$def_file"
echo "Done. New config file $def_file"

echo "Rolling new index feeds_$timestamp"
echo "Configurning mappings..."

curl -XPUT  "$es_cluster_host:9200/feeds_$timestamp?pretty=true" -d'
  {
      "mappings": {
         "feed": {
            "properties": {
               "event": {
                  "type": "string",
                  "index": "not_analyzed"
               }
            }
         }
      }
   }'

echo "Starting pg2esimporter process..."

java \
    -cp "${lib}/*" \
    -Dlog4j.configurationFile=${bin}/log4j2.xml \
    org.xbib.tools.Runner \
    org.xbib.tools.JDBCImporter "$def_file" &>af_import_"$timestamp".log &

sleep 10
echo "Checking pg2es imorter process status"
if pgrep -f ".*$def_file" >/dev/null
then
  echo "pg2es importer is running"
else
  echo "process FAILED to start exiting"
  exit -1
fi

echo "Waiting for initial indexint to finish"
sleep 30

echo "Switching index alias to new version..."

curl -XPOST  "$es_cluster_host:9200/_aliases?pretty=true" -d'
{
   "actions": [
      {
         "remove": {
            "index": "'$prev_version'",
            "alias": "actfeeds"
         }
      },
      {
         "add": {
            "index": "feeds_'$timestamp'",
            "alias": "actfeeds"
         }
      }
   ]
}'
echo "Termnating previous indexer process with pid $prev_version_pid"
kill -TERM "$prev_version_pid"
echo "Writting feeds_$timestamp as current index"
echo "feeds_$timestamp" > af_last_version
echo "DONE!"
