FROM node:18-alpine

RUN apk add gettext python3 build-base
EXPOSE 3301
# clone and move into Get5API folder
WORKDIR /Get5API
COPY . .
RUN yarn
RUN yarn build
# set config with env variables, run migrations, and run application.
# - db:create is allowed to fail (|| true) because managed providers like
#   Railway pre-create the database and the app user often can't CREATE DATABASE.
# - pm2-runtime keeps the process in the foreground, which is what container
#   platforms (Railway, Docker) expect for the main process.
CMD envsubst < /Get5API/config/production.json.template > /Get5API/config/production.json  && \
    sed -i "s/db:create get5$/db:create $DATABASE/" /Get5API/package.json && \
    { yarn migrate-create-prod || true; } && \
    yarn migrate-prod-upgrade && \
    yarn pm2-runtime start ./prodrun.json
