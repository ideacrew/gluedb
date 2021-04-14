mkdir -p ../enroll_config
rm -f config/credentials*
rm -f config/master*
#echo -n "810a215f358279cf15bb8b4cb924a393" > config/master.key
#echo -n "AOzTKLrtUuV3mVNilStDE+Q8FCyfVQCFhxkbF542r7/4gW/R/9WfF75ONkwMFgctdkH2Li0R/YCSgKIW76Uom5904KlwIAoHOdg097WIc3uVjOp7k5I8FsUWNNJ9Wb/sjrh2GN9sxgPBVzGKoC6w2er0QBf4tiL1TTJ1cuKZp2IBj9mzBv70FLIirD1q3Pky03Yp2xX3EbgqX/13zx8RH+Nupm9lpIIeqWjzlnHmrPXYpOhYk6rc0BlpPMDZ0wiswRP/8/8SrSIhs1KQCR+8H+oQIOp5O9hbA67xXhJp6UUwSCBVjuu8NsAb3jJSJ6PkfQwHVrDAy74U/h03kmllDDfFiIb0gCWfhWa9/y80IaAXfDBNa0KwobuP+neSIa+jjskafWq7gvCrbcUOHfJxwuh4RWNtSOCKmUJn--IEbN8amhPLk/N/7s--i1pSabGELr7TZv6nK0HPlA==" > config/credentials.yml.enc
#cp config/master.key ../enroll_config
#cp config/credentials* ../enroll_config
#rm -f config/symmetric-encryption.yml && rm -rf .symmetric-encryption

echo "before app\n"
docker build --build-arg BUNDLER_VERSION_OVERRIDE='2.0.1' \
             --build-arg DB_HOST='host.docker.internal' \
             --build-arg DB_PORT="27017" \
             --build-arg DB_DATABASE="enroll_production" \
             --build-arg RABBITMQ_URL="amqp://guest:guest@host.docker.internal:5672" \
             --build-arg SECRET_KEY_BASE="c8d2b9b204fbac78081a88a2c29b28cfeb82e6ccd3664b3948b813463b5917b315dbbd3040e8dffcb5b68df427099db0ce03e59e2432dfe5d272923b00755b82" \
             -f .docker/production/Dockerfile --target app -t $2:$1 .
docker push $2:$1
