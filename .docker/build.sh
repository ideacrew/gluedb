# cp Gemfile Gemfile.tmp
cp app/models/exchange_information.rb app/models/exchange_information.rb.tmp
cp config/environments/production.rb config/environments/production.rb.tmp
cp config/initializers/devise.rb config/initializers/devise.rb.tmp
cp config/mongoid.yml config/mongoid.yml.tmp
cp config/unicorn.rb config/unicorn.rb.tmp

# cp .docker/config/Gemfile .
cp .docker/config/exchange_information.rb app/models/
cp .docker/config/production.rb config/environments/
cp .docker/config/mongoid.yml config/
cp .docker/config/unicorn.rb config/
cp .docker/config/secrets.yml config/

# cp -r ../designmodo-flatuipro-rails .
# cp -r ../edi_codec .

docker pull ruby:2.1.7
docker build --build-arg BUNDLER_VERSION_OVERRIDE='1.17.3' \
             --build-arg EDIDB_DB_HOST='host.docker.internal' \
             --build-arg EDIDB_DB_PORT="27017" \
             --build-arg EDIDB_DB_NAME="edidb_prod" \
             --build-arg EDIDB_FQDN="localhost" \
             --build-arg RECEIVER_ID="000000001" \
             --build-arg RABBITMQ_URL="amqp://guest:guest@host.docker.internal:5672" \
             --build-arg EDIDB_DEVISE_SECRET_KEY="4949641a374994854c0529feb329a81885867f044eb6c23102892e38bb32da437a94ee27eb4086b196f7273868d4b06c682948f5ced62385c548ba2d96898e20" \
             --build-arg EDIDB_SECRET_KEY_BASE="c8d2b9b204fbac78081a88a2c29b28cfeb82e6ccd3664b3948b813463b5917b315dbbd3040e8dffcb5b68df427099db0ce03e59e2432dfe5d272923b00755b82" \
             --build-arg GEM_OAUTH_TOKEN=$GEM_OAUTH_TOKEN \
             -f .docker/production/Dockerfile --target base -t $2:$1 .
docker push $2:$1

# mv Gemfile.tmp Gemfile
mv app/models/exchange_information.rb.tmp app/models/exchange_information.rb
mv config/environments/production.rb.tmp config/environments/production.rb
mv config/initializers/devise.rb.tmp config/initializers/devise.rb
mv config/mongoid.yml.tmp config/mongoid.yml
mv config/unicorn.rb.tmp config/unicorn.rb
rm config/secrets.yml
#rm -rf designmodo-flatuipro-rails 
#rm -rf edi_codec
