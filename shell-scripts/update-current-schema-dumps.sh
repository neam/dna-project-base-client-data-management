#!/bin/bash

script_path=`dirname $0`
cd $script_path/..
dna_path=$(pwd)/../../../dna

# fail on any error
set -o errexit

# make app config available as shell variables
cd $dna_path/../
source vendor/neam/php-app-config/shell-export.sh
cd -

# document the current database table defaults
mysqldump --user="$DATABASE_USER" --password="$DATABASE_PASSWORD" --host="$DATABASE_HOST" --port="$DATABASE_PORT" --no-create-info --skip-triggers --no-data --databases $DATABASE_NAME > $dna_path/db/migration-results/$DATA/create-db.sql

# dump the current schema
mysqldump --user="$DATABASE_USER" --password="$DATABASE_PASSWORD" --host="$DATABASE_HOST" --port="$DATABASE_PORT" --no-data --skip-triggers --no-create-db $DATABASE_NAME \
  | pv > $dna_path/db/migration-results/$DATA/schema.sql

# dump the current data if DATA=clean-db (otherwise skip in order to save time)
if [ "$DATA" == "clean-db" ]; then
    mysqldump --user="$DATABASE_USER" --password="$DATABASE_PASSWORD" --host="$DATABASE_HOST" --port="$DATABASE_PORT" --no-create-info --skip-triggers --skip-extended-insert --complete-insert --no-create-db $DATABASE_NAME \
  | pv > $dna_path/db/migration-results/$DATA/data.sql
fi

# perform some clean-up on the dump files so that it needs to be committed less often
function cleanupdump {

    sed -i '/-- Dump completed on/d' $1
    sed -i 's/AUTO_INCREMENT=[0-9]*\b/\/\*AUTO_INCREMENT omitted\*\//' $1

}

cleanupdump $dna_path/db/migration-results/$DATA/create-db.sql
cleanupdump $dna_path/db/migration-results/$DATA/schema.sql

if [ "$DATA" == "clean-db" ]; then
    cleanupdump $dna_path/db/migration-results/$DATA/data.sql
fi

exit 0