# TSI-Landscape

A place to store metadata from TSI subsystems, for AI generation.

## The Goal

The higher goal is to build an AI-generated "map" of our Data Model and how
NetSuite, Salesforce, Tray.io, APIs, Apps are all working together.

## Folders

- `./prompts`: archive of AI prompts to be tried/used for reaching the The Goal;
- `./metadata`: metadata extractors for all sub-systems;

## Stored metadata

The data is retrieved idempotently and stored in this repo for analysis under the following folders:

- NetSuite data under `./metadata/ns-prod/data`;
- Salesforce data under `./metadata/sf-prod` (this is a SF DX project folder);
- Tray.io data under `./metadata/tray-prod/data`;



## Retrieving the metadata

These scripts need only be executed when a data update is required.

### NetSuite
```sh
cd metadata/ns-prod
cp .env.template .env
# Edit .env file filling the correct tokens.

# Only run this next command if you want a FULL re-sync!
# rm -rf ./data/records.json ./data/records/*.json 

npm run retrieve-all
```

### Salesforce
```sh
cd metadata/sf-prod
sf login org # This can be automated with tokens if needed.
./scripts/retrieve-all.sh 'Org alias or username (email).'
```

### Tray.io

This script is designed to do the full retrieval but has not yet been tested since our accounts don't have access to the Tray.io API.

```sh
cd metadata/ns-prod
cp .env.template .env
# Edit .env file filling the correct tokens.
npm run retrieve-all
```

