sed -i "s|B2B_URI|$B2B_URI|g"  /edidb/hbx_oracle/config/database.rb
sed -i "s|DB_NAME|$EDIDB_DB_NAME|g" /edidb/scripts/prepare*
