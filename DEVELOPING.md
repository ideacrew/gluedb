# Developing GlueDB with Docker

1. Get yourself a Github Personal Access Token
2. Update the `docker-compose.dev.yml` file with your personal access token - add it on the `GEM_OAUTH_TOKEN` line
3. Start developing interactively with: `docker-compose -f docker-compose.dev.yml run --service-ports edidb bash`
   1. It will take a while to run the first time
   2. You can run any rails or other commands you would like
   3. Any files you edit locally will be updated inside the image automatically - you don't need to run an editor inside the image
