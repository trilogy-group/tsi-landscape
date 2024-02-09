# Instructions for exporting the metadata

These scripts need only be executed when a metadata update is required.

## NetSuite
```sh
cd metadata/ns-prod
cp .env.template .env
# Edit .env file filling the correct tokens.

# Only run this next command if you want a FULL re-sync!
# rm -rf ./data/records.json ./data/records/*.json 

npm run retrieve-all
```

## Salesforce
```sh
cd metadata/sf-prod
sf login org # This can be automated with tokens if needed.
./scripts/retrieve-all.sh 'Org alias or username (email).'
```

## Tray.io

This script is designed to do the full retrieval but has not yet been tested since our accounts don't have access to the Tray.io API.

```sh
cd metadata/ns-prod
cp .env.template .env
# Edit .env file filling the correct tokens.
npm run retrieve-all
```

