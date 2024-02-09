# TSI-Landscape

A place to store metadata from TSI subsystems, for AI generation.

## The Goal

The higher goal is to build an AI-generated "map" of our Data Model and how
NetSuite, Salesforce, Tray.io, APIs, Apps are all working together.

## Folders

- `./prompts`: archive of AI prompts to be tried/used for reaching the The Goal;
- `./metadata`: metadata extractors for all sub-systems;

## Metadata

```sh
# Salesforce
cd metadata/sf-prod
sf login org # This can be automated with tokens btw.
./scripts/retrieve-all.sh 'Org alias or username (email).'

# NetSuite
cd metadata/ns-prod
cp .env.template .env
# Edit .env file filling the correct tokens.
npm run retrieve-all
``````
