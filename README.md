Before you release a new version make sure you:

* Update `JAR_VERSION` in `.github/workflows/publish-docker.yml`

To release a new version:

* Use the default branching model
* Increase the version in `.github/workflows/publish-docker.yml`
* Create and push a new tag
* Wait until the CI automatically builds & publishes the Docker Images and marks the tags as a release in Github
