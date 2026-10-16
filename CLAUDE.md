# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

The README is the main documentation. It describes the image, the CI workflow, the release and the configuration of the entrypoint:

@README.md

## Rules for Changes

- Keep the README current. When you change a variable of the entrypoint, the CI workflow or the release process, update the README in the same commit.
- Keep `exec java` in `collector/entrypoint.sh`. See the section "Shutdown" in the README.
- Follow the rules of the workflow in the README section "CI Workflow" for each change of `.github/workflows/`.

## Commit Style

`[TICKET-ID] Short imperative summary` (e.g., `[STAD-862] Update Data Collector to 7.5.0`).
