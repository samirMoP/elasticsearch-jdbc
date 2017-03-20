#!/bin/bash

usage="Usage: $0 [init_start|start|stop|restart|status|clear_logs]"

if [ $# -ne 1 ]; then
  echo $usage
  exit 1
fi
startStop=$1
shift

source ./get_consul_vars.sh

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
bin=${DIR}/../bin
lib=${DIR}/../lib
current_timestamp=$(cat af_last_version | cut -d"_" -f2)
current_version_pid=$(pgrep -f ".*af_config_$current_timestamp.json")
current_version=$(cat af_last_version)

waitForProcessEnd() {
  pidKilled=$1
  commandName=$2
  processedAt=`date +%s`
  while kill -0 $pidKilled > /dev/null 2>&1;
   do
     echo -n "."
     sleep 1;
     # if process persists more than  (default 10 sec) no mercy
     if [ $(( `date +%s` - $processedAt )) -gt 10 ]; then
       break;
     fi
   done
  # process still there : kill -9
  if kill -0 $pidKilled > /dev/null 2>&1; then
    echo -n force stopping $commandName with kill -9 $pidKilled
    $JAVA_HOME/bin/jstack -l $pidKilled > stop_log 2>&1
    kill -9 $pidKilled > /dev/null 2>&1
  fi
  # Add a CR after we're done w/ dots.
  echo
}

clear_logs () {
  rm -rf logs/pg2es-*.log
}

importer_status () {
  if kill -0 $current_version_pid > /dev/null 2>&1
  then 
    echo "Importer tool is runnung with pid $current_version_pid" 
    echo "Current config file af_config_$current_timestamp.json"
  else 
    echo "Importer tool is stoped."
  fi 
}

importer_stop () {
  echo "Stoping importer process"
  kill -TERM $current_version_pid > /dev/null 2>&1
  waitForProcessEnd $current_version_pid "stop"
  sleep 3
  importer_status
  
}



init_start () {
  if [  "$current_timestamp" == "first" ]; then
    echo "Running import tool for first time"
    echo "Creating mappings for $current_version"
    curl -XPUT "$es_cluster_host:9200/$current_version?pretty=true" -d'
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
        "index" : "feeds_'$current_timestamp'",
        "statefile" : "af_statefile_'$current_timestamp'.json",
        "url" : "'$pg_url'",
        "user" : "'$pg_user'",
        "password" : "'$pg_password'",
        "type" : "feed",
        "schedule" : "0/5 * * ? * *",
        "detect_json" : false
    }
   }'
   echo "$definition" > af_config_first.json  
   importer_start
   echo "Creating initial alias actfeeds"
   curl -XPUT "$es_cluster_host:9200/$current_version/_alias/actfeeds"
  
  else
    echo "This $current_timestamp is not first timestamp. User regular start command."
    exit 1
  fi
}

importer_start () {
  if kill -0 $current_version_pid > /dev/null 2>&1
  then
    echo "Import tool is already running with pid $current_version_pid. Stop it first."
    exit 1
  fi 

 
  java \
      -cp "${lib}/*" \
      -Dlog4j.configurationFile=${bin}/log4j2.xml \
      org.xbib.tools.Runner \
      org.xbib.tools.JDBCImporter "af_config_$current_timestamp.json" &>"af_import$current_timestamp.log" &
  sleep 5
  new_pid=$(pgrep -f ".*af_config_$current_timestamp.json")
  if kill -0 $new_pid > /dev/null 2>&1
  then
    echo "Import tool is started with pid $new_pid"
  else
    echo "Import tool FAILED to start. Please check log."
  fi
}

case $startStop in
(status)
  importer_status
;;

(stop)
  importer_stop
;;

(start)
  importer_start
;;

(restart)
  importer_stop
  importer_start
;;
(init_start)
  init_start
;;
(clear_logs)
  clear_logs
;;

(*)
  echo $usage
  exit 1
  ;;
esac
