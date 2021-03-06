#!/bin/bash

# uncomment to debug
# set -x

# fail on any error
set -o errexit

script_path=`dirname $0`

# defaults
if [ "$connectionID" == "" ]; then
    connectionID=db
fi

# cd to app root
cd $script_path/..
dna_path=$(pwd)/../../../dna
media_path=/files/$DATA/media

# make app config available as shell variables
cd $dna_path/../
source vendor/neam/php-app-config/shell-export.sh
cd - > /dev/null

if [ "$DATA" == "" ]; then

    echo "The environment variable DATA needs to be set"
    exit 1

fi

# dump

# configure s3cmd / s3-cli
echo "[default]
access_key = $USER_DATA_BACKUP_UPLOADERS_ACCESS_KEY
secret_key = $USER_DATA_BACKUP_UPLOADERS_SECRET
bucket_location = us-east-1
multipart_chunk_size_mb = 50
send_chunk = 40960
recv_chunk = 40960" > /tmp/.user-generated-data.s3cfg

# configure gsutil
echo "[Credentials]
gs_oauth2_refresh_token = $USER_DATA_BACKUP_UPLOADERS_GS_OAUTH2_REFRESH_TOKEN

[Boto]
https_validate_certificates = True

[GSUtil]
content_language = en
default_api_version = 2" > ~/.boto

#COPY_COMMAND="s3cmd -v --config=/tmp/.user-generated-data.s3cfg put"
#COPY_COMMAND="s3-cli --config=/tmp/.user-generated-data.s3cfg put"
COPY_COMMAND="gsutil cp"

#SYNC_COMMAND="s3cmd -v --config=/tmp/.user-generated-data.s3cfg --recursive sync"
#SYNC_COMMAND="s3-cli --config=/tmp/.user-generated-data.s3cfg --recursive sync"
SYNC_COMMAND="gsutil rsync -d -r"

DATETIME=$(date +"%Y-%m-%d_%H%M%S")
FOLDER=DATA-$DATA/ENV-$ENV

# sending --non-compact will negate the default behavior of dumping the data in a compact format. useful to be able to inspect the dumped data files, but not viable for large data dumps
if [ "$1" == "--non-compact" ]; then
    COMPACT="false"
else
    COMPACT="true"
fi

# dump schema sql

SCHEMA_FILEPATH=$FOLDER/$DATETIME/schema.sql

if [ -f $dna_path/db/$DATA.schema.sql ] ; then
    rm $dna_path/db/$DATA.schema.sql
fi
IGNORE_VIEWS_ARGUMENTS="$(cat shell-scripts/get-ignore-views-arguments.sql | mysql -s -N --no-auto-rehash --host=$DATABASE_HOST --port=$DATABASE_PORT --user=$DATABASE_USER --password=$DATABASE_PASSWORD $DATABASE_NAME)"

mysqldump --user="$DATABASE_USER" --password="$DATABASE_PASSWORD" --host="$DATABASE_HOST" --port="$DATABASE_PORT" --no-data --skip-triggers --no-create-db $IGNORE_VIEWS_ARGUMENTS $DATABASE_NAME \
 | pv > $dna_path/db/$DATA.schema.sql

if [ ! -f $dna_path/db/$DATA.schema.sql ] ; then
    echo "The mysql dump is not found at the expected location: db/$DATA.schema.sql"
    exit 1
fi

# dump data sql

DATA_FILEPATH=$FOLDER/$DATETIME/data.sql

if [ -f $dna_path/db/$DATA.data.sql ] ; then
    rm $dna_path/db/$DATA.data.sql
fi
mysqldump --user="$DATABASE_USER" --password="$DATABASE_PASSWORD" --host="$DATABASE_HOST" --port="$DATABASE_PORT" --no-create-info --skip-triggers --no-create-db $DATABASE_NAME \
 | pv > $dna_path/db/$DATA.data.sql

if [ ! -f $dna_path/db/$DATA.data.sql ] ; then
    echo "The mysql dump is not found at the expected location: db/$DATA.data.sql"
    exit 1
fi

echo "# Commands to run to use the dumped data and schema dumps locally:"
echo "cp '$dna_path/db/$DATA.data.sql' dna/db/migration-base/$DATA/data.sql"
echo "cp '$dna_path/db/$DATA.schema.sql' dna/db/migration-base/$DATA/schema.sql"

if [ "$1" == "--dump-only" ]; then
    exit 0;
fi

# upload schema sql

gzip -f $dna_path/db/$DATA.schema.sql
SCHEMA_FILEPATH=$SCHEMA_FILEPATH.gz
$COPY_COMMAND $dna_path/db/$DATA.schema.sql.gz "$USER_GENERATED_DATA_S3_BUCKET/$SCHEMA_FILEPATH"

echo $SCHEMA_FILEPATH > $dna_path/db/$DATA.schema.filepath

# upload data sql

gzip -f $dna_path/db/$DATA.data.sql
DATA_FILEPATH=$DATA_FILEPATH.gz
$COPY_COMMAND $dna_path/db/$DATA.data.sql.gz "$USER_GENERATED_DATA_S3_BUCKET/$DATA_FILEPATH"

echo $DATA_FILEPATH > $dna_path/db/$DATA.data.filepath

# dump and upload user media

FOLDERPATH=$FOLDER/$DATETIME/media/

if [ "$(ls $media_path/)" ]; then
    $SYNC_COMMAND $media_path/ "$USER_GENERATED_DATA_S3_BUCKET/$FOLDERPATH"
else
    echo "Warning: No media files found" | tee -a $LOG
fi
echo $FOLDERPATH > $dna_path/db/$DATA.media.folderpath

set +x

echo
echo "=== Upload finished ==="

DATA_FILEPATH=$(cat $dna_path/db/$DATA.data.filepath)
echo "User generated db schema sql dump uploaded to $USER_GENERATED_DATA_S3_BUCKET/$DATA_FILEPATH"
#echo "Set the contents of 'db/migration-base/$DATA/schema.filepath' to '$DATA_FILEPATH' in order to use this upload"

SCHEMA_FILEPATH=$(cat $dna_path/db/$DATA.schema.filepath)
echo "User generated db data sql dump uploaded to $USER_GENERATED_DATA_S3_BUCKET/$SCHEMA_FILEPATH"
#echo "Set the contents of 'db/migration-base/$DATA/data.filepath' to '$SCHEMA_FILEPATH' in order to use this upload"

FOLDERPATH=$(cat $dna_path/db/$DATA.media.folderpath)
echo "User media uploaded to $USER_GENERATED_DATA_S3_BUCKET/$FOLDERPATH"
#echo "Set the contents of 'db/migration-base/$DATA/media.folderpath' to '$FOLDERPATH' in order to use this upload"
echo
echo "=== Updating the local data refs to the recently uploaded ones ==="
echo "# Commands that have been run locally in order to set the refs to point to this user data (revert these changes if your data set is not meant to be the base of future production deployments)"

# Output to screen and log file
if [ ! -f $dna_path/db/uploaded-user-data.log ] ; then
    touch $dna_path/db/uploaded-user-data.log;
fi
echo "# $FOLDER/$DATETIME" >> $dna_path/db/uploaded-user-data.log
echo "echo '$SCHEMA_FILEPATH' > dna/db/migration-base/$DATA/schema.filepath" | tee -a $dna_path/db/uploaded-user-data.log
echo "echo '$DATA_FILEPATH' > dna/db/migration-base/$DATA/data.filepath" | tee -a $dna_path/db/uploaded-user-data.log
echo "echo '$FOLDERPATH' > dna/db/migration-base/$DATA/media.folderpath" | tee -a $dna_path/db/uploaded-user-data.log
echo "" | tee -a $dna_path/db/uploaded-user-data.log

# Set the contents by running the commands
echo $SCHEMA_FILEPATH > $dna_path/db/migration-base/$DATA/schema.filepath
echo $DATA_FILEPATH > $dna_path/db/migration-base/$DATA/data.filepath
echo $FOLDERPATH > $dna_path/db/migration-base/$DATA/media.folderpath

echo "These commands have been copied to dna/db/uploaded-user-data.log so that they can easily be copied and run on another system/deployment"

exit 0