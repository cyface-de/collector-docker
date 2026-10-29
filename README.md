# Cyface Collector Docker

Docker packaging for the Cyface Data Collector. There is no application code here: the `data-collector` repo builds the collector JAR, and the CI downloads it. This repo provides:

- `collector/Dockerfile` -- packages the fat JAR into an image based on `eclipse-temurin:21-jre`. The container runs as the unprivileged user `user` (id 9999) and exposes port 8080.
- `collector/entrypoint.sh` -- shell script that assembles a JSON config from environment variables, waits for the dependencies (MongoDB, OAuth provider), then starts the Vert.x collector with `exec java`.
- `.github/workflows/publish-docker.yml` -- CI workflow that downloads the JAR from GitHub Packages, builds the Docker image and publishes it on tags.

## Building

There is no local build system. To build locally, put `collector-all.jar` into `collector/`:

```bash
# Requires collector-all.jar in collector/ (manually downloaded or copied from data-collector build)
cd collector && docker build -t collector-docker .
```

The JAR version is pinned in `.github/workflows/publish-docker.yml` as `JARS_VERSION`.

## CI Workflow

`publish-docker.yml` has two jobs:

- `test` -- runs on pushes and pull requests to `main` and `release-*`. Downloads the JAR and builds the image without a push. This is the required status check of `main`. Pull requests from forks are skipped.
- `publish` -- runs only on version tags. Builds and pushes the image to `ghcr.io/cyface-de/collector-docker/collector-docker:<tag>` (no `latest` tag), then creates the GitHub release.

Rules of the workflow (hardening of CY-6748):

- Do not use `${{ github.ref_name }}` or other event values directly in a `run:` script. Pass them through `env:` (for example `TAG`) and use `"$TAG"`.
- Pass secrets through `env:` of the step that needs them, not through the script text.
- Third-party actions (`docker/*`) are pinned to a commit SHA with the version as a comment.
- The runner is pinned to `ubuntu-26.04`, not `ubuntu-latest`.

Old image versions are deleted by the organization-wide cleanup in `cyface-de/production` (`.github/workflows/registry_cleanup.yml`). A version that a deployment file names stays.

## Release Process

1. Update `JARS_VERSION` in `.github/workflows/publish-docker.yml` to match the data-collector release.
2. Create an annotated tag with a semantic version (for example `3.7.0`) and push it. The CI builds and publishes the Docker image.
3. The body of the tag message becomes the release notes.
4. A tag with a suffix (for example `3.7.0-beta1`) becomes a pre-release.

## Entrypoint Configuration

The entrypoint assembles a Vert.x JSON config from environment variables. Two auth modes and two storage backends are supported:

**Auth modes** (`CYFACE_AUTH_TYPE`):
- `oauth` (default) -- requires `CYFACE_OAUTH_CALLBACK`, `CYFACE_OAUTH_SECRET`, `CYFACE_OAUTH_SITE`; optional `CYFACE_OAUTH_CLIENT` (default: `collector`), `CYFACE_OAUTH_TENANT` (default: `rfr`)
- `jwt` -- requires `CYFACE_JWKS` (JSON array) or `CYFACE_JWK` (single JSON object)

**Storage backends** (`STORAGE_TYPE`):
- `gridfs` -- requires `STORAGE_UPLOADS_FOLDER`
- `google` -- requires `STORAGE_PROJECT_IDENTIFIER`, `STORAGE_BUCKET_NAME`, `STORAGE_CREDENTIALS_FILE`, `STORAGE_COLLECTION_NAME`

**MongoDB** -- `MONGO_HOSTS` and `MONGO_PORTS` (comma-separated for replica sets), optional `MONGO_REPLICA_SET` name. A single port value is broadcast to all hosts.

**API** -- `CYFACE_API_ENDPOINT` is required (the collector does not start without it). Optional: `CYFACE_API_HOST` (default: `localhost`), `CYFACE_API_PORT` (default: `8080`), `UPLOAD_EXPIRATION_TIME_MILLIS` (default: `60000`), `MEASUREMENT_PAYLOAD_LIMIT_BYTES` (default: `104857600`), `METRICS_ENABLED` (default: `false`).

**Shutdown** -- the entrypoint starts the JVM with `exec`, so that the JVM is PID 1 and gets `SIGTERM` directly. Keep the `exec`: without it, a rolling update kills the node without a clean shutdown of the clustered Vert.x event bus.

## Licensing
Copyright 2018-2026 Cyface GmbH

This file is part of the Cyface Data Collector.

The Cyface Data Collector is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

The Cyface Data Collector is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with the Cyface Data Collector.  If not, see http://www.gnu.org/licenses/.
