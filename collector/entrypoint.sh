#!/bin/bash
# Copyright 2018-2023 Cyface GmbH
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
# Version 1.3.0

DEFAULT_API_PORT="8080"
JAR_FILE="collector-all.jar"
SERVICE_NAME="Cyface Collector API"

main() {
  loadAuthParameters
  loadApiParameters
  loadCollectorParameters
  loadConfig
  waitForDependency "mongo" 27017
  startApi
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
}

loadAuthParameters() {
  if [ -z "$CYFACE_AUTH_TYPE" ]; then
    CYFACE_AUTH_TYPE="oauth"
  fi
  if [ -z "$CYFACE_OAUTH_CALLBACK" ]; then
    CYFACE_OAUTH_CALLBACK="http://localhost:8080/callback"
  fi
  if [ -z "$CYFACE_OAUTH_CLIENT" ]; then
    CYFACE_OAUTH_CLIENT="collector"
  fi

  if [ -z CYFACE_OAUTH_SECRET ]; then
    echo "Unable to find OAuth client secret. Please set the environment variable CYFACE_OAUTH_SECRET to an appropriate value! API will not start!"
    exit 1
  fi

  if [ -z "$CYFACE_OAUTH_SITE" ]; then
    CYFACE_OAUTH_SITE="https://auth.cyface.de:8443/realms/{tenant}"
  fi
  if [ -z "$CYFACE_OAUTH_TENANT" ]; then
    CYFACE_OAUTH_TENANT="rfr"
  fi

  echo "Using Auth type: $CYFACE_AUTH_TYPE"
  echo "Using OAuth callback $CYFACE_OAUTH_CALLBACK"
  echo "Using OAuth client $CYFACE_OAUTH_CLIENT"
  echo "Using OAuth site $CYFACE_OAUTH_SITE"
  echo "Using OAuth tenant $CYFACE_OAUTH_TENANT"
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
      \"collection-name\":\"$STORAGE_COLLECTION_NAME\"\
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
          \"db_name\":\"cyface\",\
          \"connection_string\":\"mongodb://mongo:27017\",\
          \"data_source_name\":\"cyface\"\
      },\
      \"http.port\":$CYFACE_API_PORT,\
      \"http.host\":\"$CYFACE_API_HOST\",\
      \"metrics.enabled\":$METRICS_ENABLED,\
	    \"upload.expiration\":$UPLOAD_EXPIRATION_TIME_MILLIS,\
	    \"measurement.payload.limit\":$MEASUREMENT_PAYLOAD_LIMIT_BYTES,\
      \"storage-type\":$STORAGE_CONFIGURATION,\
      \"auth-type\":\"$CYFACE_AUTH_TYPE\",
      \"oauth.callback\":\"$CYFACE_OAUTH_CALLBACK\",\
      \"oauth.client\":\"$CYFACE_OAUTH_CLIENT\",\
      \"oauth.secret\":\"$CYFACE_OAUTH_SECRET\",\
      \"oauth.site\":\"$CYFACE_OAUTH_SITE\",\
      \"oauth.tenant\":\"$CYFACE_OAUTH_TENANT\"\
  }"
}

# Parameter 1: Name of the Docker Container of the dependency to wait for
# Parameter 2: Internal Docker port of the dependency to wait for
waitForDependency() {
  local service="$1"
  local port="$2"
  echo && echo "Waiting for $service:$port to start..."

  local attempts=0
  local max_attempts=10
  local sleep_duration=5s

  while [ "$attempts" -lt "$max_attempts" ]; do
    ((attempts++))
    echo "Attempt $attempts"

    if nc -z "$service" "$port" > /dev/null 2>&1; then
      echo "$service is up!"
      return 0
    else
      sleep "$sleep_duration"
    fi
  done

  echo "Unable to find $service:$port after $max_attempts attempts! API will not start."
  exit 1
}

startApi() {
  echo
  echo "Starting $SERVICE_NAME at $CYFACE_API_HOST:$CYFACE_API_PORT"
  java -Dvertx.cacheDirBase=/tmp/vertx-cache \
      -Dlogback.configurationFile=/app/logback.xml \
      -jar $JAR_FILE \
      -conf "$CONFIG" \
      &> $CYFACE_API_STD_OUT_FILE
  echo "API started or failed. Checking logs might give more insights."
}

main "$@" # $@ allows u to access the command-line arguments withing the main function
