# TSI-Landscape

This repo is intended for AI work.

## The Goal

The goal is to build comprehensive "map", called "The TSI Landscape" of the data models and integrations between NetSuite, Salesforce, Tray.io, APIs and Apps.
We want to create a clear picture for the team, of how these platforms are working together including the mentioned APIs and apps. The result must be conscise, visual as much as possible and should serve as a great reference to any developer or future AI that will have to quickly understand and produce actual code for this environment.

## Folders for AI analysis input

These folders are meant to serve as input for AI analysis:

- `./metadata/`: metadata files extracted (idempotently) from sub-systems (NS, SF, Tray) and stored in this repo;
    - `ns-prod/data`: NetSuite metadata exported using the NS REST API;
    - `sf-prod` Salesforce data retrieved using the SF CLI tool (this is a SF DX project folder);
    - `tray-prod/data`: Tray.io metadata as JSON files exported manually (for now).

- `./documents/`: contains documents with relevant information about the system's architecture;

- `./apis`: available OpenAPI specifications;
    - `api.yml`: Proxy API specification from [si-billing-api repo](https://github.com/trilogy-group/si-billing-api/blob/main/app/server/src/common/api.yml);
    - `portalOpenApi.yml`: Portal API specification from [si-billing-api repo](https://github.com/trilogy-group/si-billing-api/blob/main/app/portal/api-explorer/apiSpec/portalOpenApi.yml);

- `./codebases`: ZIP files with the source code of the main projects relevant to the TSI ecosystem:
    - `si-billing-api-main.zip`: this project contains codes for Proxy-API, Portal-API and the main back-end API implemented as a NetSuite RESTlet;
    - `tsi-netsuite-salesforce-integration-main.zip`: this project contains exported Tray.io flows and various scripts used in the NS-SF integration (saved manually; these are not as accurate as the exported data under the `metadata` folder);

## Archival folders
These folders contain archived information, to keep a history of this effort.
They should be ignored by AI analysis!

- `./prompts`: archive of AI prompts to be tried/used for reaching the The Goal;

