#!/bin/bash 

ES_SERVER=$1
INDEX_NAME=$2

test_counter=0

status=$(curl -XGET "http://$ES_SERVER:9200/_cat/indices?v" 2>/dev/null | grep "$INDEX_NAME" | awk '{print $1}')
doc_count=$(curl -XGET "http://$ES_SERVER:9200/_cat/indices?v" 2>/dev/null | grep "$INDEX_NAME" | awk '{print $6}')

search_test=$(curl -s -o /dev/null -w "%{http_code}"  "http://$ES_SERVER:9200/$INDEX_NAME/_search")
echo $status
echo $doc_count
echo $search_test


if [ "$status" = "green" ] || [ "$status" = "yellow"  ]; then
  echo "Index status OK"
  test_counter=$(($test_counter + 1))
fi

if [ $doc_count > 10000 ]; then
  echo "Doc count OK"
  test_counter=$(($test_counter + 1))
fi

if [ $search_test = 200 ]; then
  echo "Test search return 200"
  test_counter=$(($test_counter + 1))
fi

if [ $test_counter = 3 ]; then
  echo "All tests OK"
  exit 0
else 
  exit -1
fi
