#!/bin/bash
# Copyright 2018-2024 Cyface GmbH
# 
# This file is part of the Cyface Data Collector.
#
#  The Cyface Data Collector is free software: you can redistribute it and/or modify
#  it under the terms of the GNU General Public License as published by
#  the Free Software Foundation, either version 3 of the License, or
#  (at your option) any later version.
#  
#  The Cyface Data Collector is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.
#
#  You should have received a copy of the GNU General Public License
#  along with the Cyface Data Collector.  If not, see <http://www.gnu.org/licenses/>.
#
# author: Armin Schnabel

DEFAULT_API_PORT="8080"
DEFAULT_OAUTH_TENANT="rfr"
DEFAULT_OAUTH_CLIENT="collector"
DEFAULT_DATABASE_NAME="cyface"
JAR_FILE="collector-all.jar"

SERVICE_NAME="Cyface Collector API"

main() {
  loadAuthParameters
  loadApiParameters
  loadCollectorParameters
  loadConfig
  waitForDependency "mongo:27017"
  waitForDependency "$CYFACE_OAUTH_SITE"
  startApi
}

loadAuthParameters() {
  # Auth type
  if [ -z "$CYFACE_AUTH_TYPE" ]; then
    CYFACE_AUTH_TYPE="oauth"
  fi

  # Auth Configuration
  if [ "$CYFACE_AUTH_TYPE" == "oauth" ]; then

    if [ -z "$CYFACE_OAUTH_CALLBACK" ]; then
      echo "Unable to find OAuth callback url. Please set the environment variable CYFACE_OAUTH_CALLBACK to an appropriate value! API will not start!"
      exit 1
    fi

    if [ -z "$CYFACE_OAUTH_CLIENT" ]; then
      CYFACE_OAUTH_CLIENT=$DEFAULT_OAUTH_CLIENT
    fi

    if [ -z CYFACE_OAUTH_SECRET ]; then
      echo "Unable to find OAuth client secret. Please set the environment variable CYFACE_OAUTH_SECRET to an appropriate value! API will not start!"
      exit 1
    fi

    if [ -z "$CYFACE_OAUTH_SITE" ]; then
      echo "Unable to find OAuth site url. Please set the environment variable CYFACE_OAUTH_SITE to an appropriate value! API will not start!"
      exit 1
    fi

    if [ -z "$CYFACE_OAUTH_TENANT" ]; then
      CYFACE_OAUTH_TENANT=$DEFAULT_OAUTH_TENANT
    fi

    AUTH_CONFIGURATION="{\
      \"type\":\"$CYFACE_AUTH_TYPE\",\
      \"callback\":\"$CYFACE_OAUTH_CALLBACK\",\
      \"client\":\"$CYFACE_OAUTH_CLIENT\",\
      \"secret\":\"$CYFACE_OAUTH_SECRET\",\
      \"site\":\"$CYFACE_OAUTH_SITE\",\
      \"tenant\":\"$CYFACE_OAUTH_TENANT\"\
    }"

    # Don't log the whole AUTH_CONFIGURATION to not log secrets.
    echo "Using Auth type: $CYFACE_AUTH_TYPE"
    echo "Using OAuth callback $CYFACE_OAUTH_CALLBACK"
    echo "Using OAuth client $CYFACE_OAUTH_CLIENT"
    echo "Using OAuth site $CYFACE_OAUTH_SITE"
    echo "Using OAuth tenant $CYFACE_OAUTH_TENANT"

  else
    echo "Unsupported Auth Type $CYFACE_AUTH_TYPE. Please set the environment variable to an appropriate value! API will not start!"
    exit 1
  fi
}

loadApiParameters() {
  if [ -z "$CYFACE_API_STD_OUT_FILE" ]; then
    CYFACE_API_STD_OUT_FILE="/app/logs/collector-out.log"
  fi

  if [ -z "$CYFACE_API_PORT" ]; then
    CYFACE_API_PORT=$DEFAULT_API_PORT
  fi

  if [ -z "$CYFACE_API_HOST" ]; then
    CYFACE_API_HOST="localhost"
  fi

  if [ -z $CYFACE_API_ENDPOINT ]; then
    echo "Unable to find API Endpoint. Please set the environment variable CYFACE_API_ENDPOINT to an appropriate value! API will not start!"
    exit 1
  fi
}

loadCollectorParameters() {
  # Upload Expiration time
  if [ -z $UPLOAD_EXPIRATION_TIME_MILLIS ]; then
    UPLOAD_EXPIRATION_TIME_MILLIS="60000"
  fi

  echo "Setting Upload expiration time to $UPLOAD_EXPIRATION_TIME_MILLIS ms."

  # Measurement payload limit
  if [ -z $MEASUREMENT_PAYLOAD_LIMIT_BYTES ]; then
    MEASUREMENT_PAYLOAD_LIMIT_BYTES="104857600"
  fi

  echo "Setting Measurement payload limit to $MEASUREMENT_PAYLOAD_LIMIT_BYTES Bytes."

  # Storage type
  if [ -z $STORAGE_TYPE ]; then
    echo "Unable to find Storage Type. Please set the environment variable STORAGE_TYPE to an appropriate value! API will not start!"
    exit 1
  fi

  # GridFS Storage Configuration
  if [ "$STORAGE_TYPE" == "gridfs" ]; then

    if [ -z "$STORAGE_UPLOADS_FOLDER" ]; then
      echo "Unable to find Storage Uploads Folder. Please set the environment variable STORAGE_UPLOADS_FOLDER to an appropriate value! API will not start!"
      exit 1
    fi

    STORAGE_CONFIGURATION="{\
      \"type\":\"$STORAGE_TYPE\",\
      \"uploads-folder\":\"$STORAGE_UPLOADS_FOLDER\"\
    }"

  # Google Cloud Storage Configuration
  elif [ "$STORAGE_TYPE" == "google" ]; then

    if [ -z "$STORAGE_PROJECT_IDENTIFIER" ]; then
      echo "Unable to find Storage Project Identifier. Please set the environment variable STORAGE_PROJECT_IDENTIFIER to an appropriate value! API will not start!"
      exit 1
    fi

    if [ -z "$STORAGE_BUCKET_NAME" ]; then
      echo "Unable to find Storage Bucket Name. Please set the environment variable STORAGE_BUCKET_NAME to an appropriate value! API will not start!"
      exit 1
    fi

    if [ -z "$STORAGE_CREDENTIALS_FILE" ]; then
      echo "Unable to find Storage Credentials File. Please set the environment variable STORAGE_CREDENTIALS_FILE to an appropriate value! API will not start!"
      exit 1
    fi

    if [ -z "$STORAGE_COLLECTION_NAME" ]; then
      echo "Unable to find Storage Collection Name. Please set the environment variable STORAGE_COLLECTION_NAME to an appropriate value! API will not start!"
      exit 1
    fi

    STORAGE_CONFIGURATION="{\
      \"type\":\"$STORAGE_TYPE\",\
      \"project-identifier\":\"$STORAGE_PROJECT_IDENTIFIER\",\
      \"bucket-name\":\"$STORAGE_BUCKET_NAME\",\
      \"credentials-file\":\"$STORAGE_CREDENTIALS_FILE\",\
      \"collection-name\":\"$STORAGE_COLLECTION_NAME\",\
      \"buffer-size\": 500000\
    }"

  else
    echo "Unsupported Storage Type $STORAGE_TYPE. Please set the environment variable to an appropriate value! API will not start!"
    exit 1
  fi
    
  echo "Setting storage configuration to $STORAGE_CONFIGURATION"

  # Monitoring
  if [ -z $METRICS_ENABLED ]; then
    METRICS_ENABLED="false"
  fi

  echo "Enabling metrics reporting by API: $METRICS_ENABLED."
}

# Injects the database parameters
loadConfig() {
  CONFIG="{\
      \"mongo.db\":{\
          \"db_name\":\"$DEFAULT_DATABASE_NAME\",\
          \"connection_string\":\"mongodb://mongo:27017\",\
          \"data_source_name\":\"$DEFAULT_DATABASE_NAME\"\
      },\
      \"http.port\":$CYFACE_API_PORT,\
      \"http.host\":\"$CYFACE_API_HOST\",\
      \"http.endpoint\":\"$CYFACE_API_ENDPOINT\",\
      \"metrics.enabled\":$METRICS_ENABLED,\
	    \"upload.expiration\":$UPLOAD_EXPIRATION_TIME_MILLIS,\
	    \"measurement.payload.limit\":$MEASUREMENT_PAYLOAD_LIMIT_BYTES,\
      \"storage-type\":$STORAGE_CONFIGURATION,\
      \"auth\":$AUTH_CONFIGURATION\
  }"
}

# Parameter 1: URL to the service to wait for
waitForDependency() {
  local URL="$1"

  local scheme=$(echo $URL | awk -F[/:] '{print $1}')
  local host=$(echo $URL | awk -F[/:] '{if ($1 ~ /http/ || $1 ~ /https/) print $4; else print $1}')
  local port=$(echo $URL | awk -F[/:] '{if ($1 ~ /http/ || $1 ~ /https/) print $5; else print $2}')

  # Set Port to default if not specified by URL
  if [ -z "$port" ]
  then
    if [ "$scheme" == "http" ]
    then
      port=80
    elif [ "$scheme" == "https" ]
    then
      port=443
    fi
  fi

  echo && echo "Waiting for $host:$port to start..."

  local attempts=0
  local max_attempts=10
  local sleep_duration=5s

  while [ "$attempts" -lt "$max_attempts" ]; do
    attempts=$((attempts+1))
    echo "Attempt $attempts"

    if nc -z "$host" "$port" > /dev/null 2>&1; then
      echo "$host is up!"
      return 0
    else
      sleep "$sleep_duration"
    fi
  done

  echo "Unable to find $host:$port after $max_attempts attempts! API will not start."
  exit 1
}

startApi() {
  echo
  echo "Starting $SERVICE_NAME at $CYFACE_API_HOST:$CYFACE_API_PORT$CYFACE_API_ENDPOINT"
  java -Dvertx.cacheDirBase=/tmp/vertx-cache \
      -Dlogback.configurationFile=/app/logback.xml \
      -jar $JAR_FILE \
      -conf "$CONFIG" \
      &> $CYFACE_API_STD_OUT_FILE
  echo "API started or failed. Checking logs might give more insights."
}

main "$@" # $@ allows u to access the command-line arguments withing the main function
