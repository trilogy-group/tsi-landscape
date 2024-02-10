# Prompt

## Context

- Chat-GPT 4

## Transcript

https://chat.openai.com/share/bd33cd4d-8c45-4092-a5a5-24bc77b0765e

## Setup

You are an expert IT architect with deep knowledge Salesforce (aka SF), NetSuite (aka NS), Tray.io (aka Tray) and integrations between them. You have deep knowledge about the CLIs, APIs, languages, export/import methods and any other tools exposed by the mentioned platforms, such as the APEX language, SOQL, SuiteQL, RESTlets, UI tools etc.

Our production environment (called TSI-PROD) contains one NetSuite and one Salesforce deployment, which have been configured work together. Salesforce is used mostly by our sales staff, while the NetSuite is used as a core ERP and (usually) is the source of truth for the data in the system. Both platforms are supposed to maintain the same corpus of data.

Additionally, there are multiple integration workflows in effect (built over time) and also the following APIs:
- NS API: this is our main back-end API and is implemented directly in NS as a RESTlet called "main";
- Proxy API: serves a front-end application called "Self-Serve" and is built as a TypeScript/ExpressJS application;
- Portal API: serves a front-end application called "Portal UI" and is running on AWS Lambda as NodeJS functions;

I want to create a clear picture for my team, of how these platforms are working together including the mentioned APIs and apps. The result must be conscise, visual as much as possible and should serve as a great reference to any developer or future AI that will have to quickly understand and work on this environment. 

The output needs to be detailed, down to field level. We especially need to know:
- how SF Objects are map to NS Records and viceversa?
- what's the mapping between their fields (which is often not evident)?
- in which platform is a field supposed to be writable or read-only?
- how are the Objects/Records/Fields synchronized (frequency and direction) between platforms?

I accept that the result of this analysis may be split into multiple parts:
- A diagram of how the SF Objects are working together (possibly an ERD diagram).
- A diagram of how the NS Objects are working together (possibly an ERD diagram).
- A diagram or table of mapping between SF Objects and NS Records and their fields and access permissions (read/write).
- A diagram or table of the synchronization flows (SF, Tray or from code) between SF and NS.

First, I compiled the input details for analysis in the GitHub repo at: https://github.com/trilogy-group/tsi-landscape