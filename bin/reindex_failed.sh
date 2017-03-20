#!/bin/bash

source ./get_consul_vars.sh

log_file=logs/pg2es.log

a=$(grep "queued tasks = 50" "$log_file" | awk '{print $7}' | cut -d"[" -f2 | cut -d"]" -f1 | tr "\n", ",")
failed_idxs=$(echo "{${a%?}}")
echo "$failed_idxs"
if [ "$failed_idxs" == "{}" ]; then
  echo "No failed docs"
  exit 1
fi

timestamp=$(cat af_last_version | cut -d"_" -f2)
prev_version=$(cat af_last_version)
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
                 "statement":"select activity_id as _id, (case when last_update_date is null then creation_date else last_update_date end) as last_update_date, placeholder_data->\'terminal_id\' as terminal_id, activity_id, additional_data, advertisement_id, comments, contest_id, creation_date, deep_link, dislikes, event, expiration_date, is_pinned, likes, message, message_1, message_2, object_type, object_url, order_id, placeholder, placeholder_1, placeholder_2, placeholder_data, publication_date, signal_id, symbol, terminal_type, user_id1, user_id2, (select to_jsonb((select array(select row_to_json((select d from(select u.user_name, al.user_id, al.creation_date) d)) as data from sx_activity_likes al join sx_users u on al.user_id= u.user_id  where al.activity_id=af.activity_id order by al.creation_date desc limit 100)))) as recent_likers, (select xl.creation_date from sx_activity_likes xl where xl.activity_id = af.activity_id and xl.status = \'LIKE\' order by xl.creation_date desc limit 1) as last_like_date, (select to_jsonb( array(select xc.user_id from sx_activity_comments xc where xc.activity_id =af.activity_id order by xc.comment_id desc limit 50))) as recent_commenters, (select to_jsonb((select array(select row_to_json((select d from(select u.user_name, ac.user_id, ac.comment, ac.creation_date) d)) as data from sx_activity_comments ac join sx_users u on ac.user_id= u.user_id  where ac.activity_id=af.activity_id order by ac.creation_date desc limit 100)))) as user_commenters  from sx_activity_feed af where activity_id=any(?::bigint[])",
                 "parameter" : [ "'$failed_idxs'" ]
               }
               ],
         "elasticsearch" : {
                      "cluster" : "'$es_cluster_name'",
                      "host" : ["'$es_cluster_host'"],
                      "port" : '$es_port' },
        "index" : "feeds_'$timestamp'",
        "url" : "'$pg_url'",
        "user" : "'$pg_user'",
        "password" : "'$pg_password'",
        "type" : "feed",
        "detect_json" : false
    }
}'
def_file="af_fix_config_$timestamp.json"

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
bin=${DIR}/../bin
lib=${DIR}/../lib

echo "Writting new config file"
echo "$definition" > "$def_file"
echo "Done. New config file $def_file"
echo "Starting pg2esimporter process..."

java \
    -cp "${lib}/*" \
    -Dlog4j.configurationFile=${bin}/log4j2.xml \
    org.xbib.tools.Runner \
    org.xbib.tools.JDBCImporter "$def_file"
#    org.xbib.tools.JDBCImporter "$def_file" &>af_fix_"$timestamp".log &
echo "Removing error lines"
sed -i '' /RemoteTransportException/d "$log_file"
sed -i '' /ERROR/d/ "$log_file"
echo "DONE"
