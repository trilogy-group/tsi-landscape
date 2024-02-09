# Context

- Chat-GPT 4

# Prompt

---

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

As a first task, I want to provide you with the input data to analyze for the above goal.
This should contain:
- the SF data schema and existing Workflows and code;
- the NS data schema and existing events, triggers and RESTlets;
- the Tray.io workflows;
- the source code of the 3 APIs mentioned above (which reside in a single GitHub repo);
- anything else you think might be important.

Let's take them one by one, and advise me on how to best provide this information to you.

---

To create a comprehensive and clear picture of how Salesforce (SF), NetSuite (NS), Tray.io, and the mentioned APIs and applications work together, we'll need to gather and analyze detailed information from each component of your ecosystem. Here's how we can approach this task step by step:

1. Salesforce (SF) Data Schema, Workflows, and Code
SF Data Schema: A detailed export of the SF data schema, including objects and their fields, is essential. This can usually be obtained through Salesforce Schema Builder or by querying the Salesforce Metadata API.
SF Workflows and Code: Information about any Apex code, Visualforce pages, Lightning components, and workflow rules. This can be accessed through the Salesforce Setup menu or by using Salesforce DX (SFDX) CLI tools to pull the metadata and source code.
2. NetSuite (NS) Data Schema, Events, Triggers, and RESTlets
NS Data Schema: Similar to SF, we need a detailed export of the NS data schema, including records and their fields. This can be obtained through SuiteAnalytics Workbook, SuiteBuilder, or by querying the NetSuite Schema Browser.
NS Events, Triggers, and RESTlets: Details about SuiteScripts (including RESTlets), workflows (SuiteFlows), and any other custom code that interacts with NS data or external systems.
3. Tray.io Workflows
Workflow Details: Export or detailed descriptions of the Tray.io workflows that integrate SF and NS. This includes the triggers, actions, and logic used within each workflow.
4. Source Code of the APIs
Since the source code of the Proxy API, Portal API, and the NS API (implemented as a RESTlet) resides in a single GitHub repository, please provide the URL of this repository. We can then analyze the code to understand how these APIs facilitate interaction between SF, NS, and the front-end applications.
5. Additional Information
Any documentation on field mappings, synchronization logic, or integration patterns already in place would be highly beneficial. This includes any existing diagrams, spreadsheets, or documents that describe the data flow and integration architecture.
How to Provide the Information
For Salesforce and NetSuite data schemas, workflows, and code, you can export the relevant metadata and files, then share them through a secure file-sharing service if they're too large to be directly sent. For the GitHub repository, please provide the URL directly.

Given the complexity and sensitivity of this information, ensure that any shared data complies with your organization's security and privacy policies.

Once I have the necessary details, especially the GitHub repository URL for the APIs' source code, I can proceed with a more detailed analysis and help create the visual representations and mappings you've requested.