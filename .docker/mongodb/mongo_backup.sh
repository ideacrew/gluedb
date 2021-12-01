#!/bin/bash -x

current_time=$(date "+%Y%m%d_%H%M%S")
zip_file_name=$DB_NAME"_"$current_time.zip

rm -rf dump
mongodump -d $DB_NAME --host $DB_HOST --authenticationDatabase admin -u admin -p $DB_ADMIN_PASSWORD

zip -P $DB_ZIP_PASSWORD -r $zip_file_name dump

#/usr/local/bin/
aws s3 cp $zip_file_name s3://$BACKUP_BUCKET

if [ "$BACKUP_TO_DR" == "true" ]
then
  aws s3 cp $zip_file_name s3://$DR_BACKUP_BUCKET
fi

rm -rf dump
