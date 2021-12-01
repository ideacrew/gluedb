sed -i "s|B2B_URI|$B2B_URI|g"  /edidb/hbx_oracle/config/database.rb
sed -i "s|DB_NAME|$EDIDB_DB_NAME|g" /edidb/scripts/prepare*
sed -i "s|ENV_NAME|$ENV_NAME|g" /edidb/scripts/glue_update.sh
sed -i "s|DB_HOST|$EDIDB_DB_HOST|g" /edidb/scripts/glue_update.sh
sed -i "s|DB_PASSWORD|$EDIDB_DB_PASSWORD|g" /edidb/scripts/glue_update.sh
sed -i "s|B2B_HOST|$B2B_HOST|g"  /edidb/scripts/glue_update.sh
sed -i "s|B2B_SERVICE_PASSWORD|$B2B_SERVICE_PASSWORD|g" /edidb/scripts/glue_update.sh
