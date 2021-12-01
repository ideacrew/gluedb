#!/bin/bash -xe
#set -e
## Global Vars

cd /edidb

if [ -z "$1" ]
then
  DAYS=2
else
  DAYS=$1
fi

ENV="ENV_NAME"
START_DATE=`date --date="$DAYS days ago" +%Y%m%d`

##App Server Vars
PARSER_DIRECTORY='/edidb/ediparser'
GLUEDB_DIRECTORY='/edidb'
UPDATER_DIRECTORY='/edidb/hbx_oracle'

## Mongo Server Vars
HOST_MONGO_SERVER="DB_HOST"
#MONGO_USER=""
#MONGO_PASS=""
MONGO_DB_PRODUCTION="edidb_${ENV}"
MONGO_DB_DEVELOPMENT="${MONGO_DB_PRODUCTION}_dev"

##cleanup files
rm -f ${GLUEDB_DIRECTORY}/todays_data.zip
rm -f ${GLUEDB_DIRECTORY}/db/data/all_json.csv
rm -f ${PARSER_DIRECTORY}/*.csv
rm -f ${UPDATER_DIRECTORY}/*.csv

mongo --host ${HOST_MONGO_SERVER} --authenticationDatabase 'admin' -u 'admin' -p 'DB_PASSWORD' < ~/scripts/prepare_dev.js

#cd ${UPDATER_DIRECTORY}
#padrino r scripts/gateway_transmissions.rb --start $START_DATE
curl -H "X-API-Key: B2B_SERVICE_PASSWORD" http://B2B_HOST:8001/openhbx_b2b_x12_web/b2b_messages?start=$START_DATE > b2b_edi.csv
cp b2b_edi.csv ${PARSER_DIRECTORY}
cat ${PARSER_DIRECTORY}/b2b_edi.csv | ${PARSER_DIRECTORY}/dist/build/InterchangeTest/InterchangeTest > ${PARSER_DIRECTORY}/all_json.csv
mkdir -p ${GLUEDB_DIRECTORY}/db/data
cp ${PARSER_DIRECTORY}/all_json.csv ${GLUEDB_DIRECTORY}/db/data/

cd ${GLUEDB_DIRECTORY}
#echo -e '\ngem "rubycritic"' >> Gemfile
#bundle install
RAILS_ENV=development bundle exec rake edi:import:all
RAILS_ENV=development rails r script/queries/set_authority_members.rb
#head -n -1 Gemfile > Gemfile.tmp
#mv Gemfile.tmp Gemfile

mongo --host ${HOST_MONGO_SERVER} --authenticationDatabase 'admin' -u 'admin' -p 'DB_PASSWORD' < ~/scripts/prepare_prod.js

