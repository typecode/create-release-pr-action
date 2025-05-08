# Create Release PR Action

A GitHub Action that automates the creation of release pull requests between branches with automatic issue tracking.

## Description

This action creates a pull request between specified branches (develop → staging or staging → production) and automatically includes references to issues that were closed in the PRs that are part of this release.

## Features

- Automatically creates release pull requests between branches
- Supports both staging and production releases
- Automatically detects and includes all referenced issues (using close/fix/resolve keywords)
- Maintains a clean release history by tracking what's being deployed

## Usage

```yaml
name: Create Release PR

on:
  workflow_dispatch:
    inputs:
      release_type:
        description: 'Type of release'
        required: true
        default: 'Staging Release'
        type: choice
        options:
          - 'Staging Release'
          - 'Production Release'

jobs:
  create-release-pr:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
        with:
          fetch-depth: 0
          
      - name: Create Release PR
        uses: typecode/create-release-pr-action@v1
        with:
          release_type: ${{ github.event.inputs.release_type }}
          github_token: ${{ secrets.GITHUB_TOKEN }}
```

## Inputs

| Input | Description | Required | Default |
|-------|-------------|---------|---------|
| `release_type` | Type of release (Staging or Production) | Yes | `Staging Release` |
| `github_token` | GitHub token for authentication | Yes | N/A |

## How It Works

1. For a Staging Release, the action creates a PR from `develop` to `staging`
2. For a Production Release, the action creates a PR from `staging` to `production`
3. The action automatically identifies all PRs merged since the last release
4. It extracts issue references from these PRs (using keywords like "closes", "fixes", etc.)
5. The release PR includes all these references, providing clear tracking of what's being deployed