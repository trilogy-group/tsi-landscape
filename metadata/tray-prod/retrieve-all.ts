import * as dotenv from "dotenv";
import fetch from "node-fetch";
import * as fs from "fs";
import * as path from "path";

dotenv.config();

const { TRAY_TOKEN, TRAY_WORKSPACE_ID, TRAY_API_URL, TRAY_CONCURRENCY } = process.env;
const concurrency = parseInt(TRAY_CONCURRENCY || "5", 10);

interface Workflow {
  id: string;
  name: string;
}

interface WorkflowDetails {
  // Define the structure according to the data returned by your Tray.io workflow details
  // This is a placeholder structure
  id: string;
  name: string;
  [key: string]: any; // Extend as needed
}

interface WorkflowsResponse {
  data: Workflow[];
  // Add any additional fields returned by the API
}

async function fetchWorkflows(): Promise<WorkflowsResponse> {
  const response = await fetch(`${TRAY_API_URL}/workflows?workspace_id=${TRAY_WORKSPACE_ID}`, {
    headers: { Authorization: `Bearer ${TRAY_TOKEN}` },
  });
  if (!response.ok) {
    throw new Error(`Failed to fetch workflows: ${response.statusText}`);
  }
  return response.json();
}

async function fetchWorkflowDetails(workflowId: string): Promise<WorkflowDetails> {
  const response = await fetch(`${TRAY_API_URL}/workflows/${workflowId}`, {
    headers: { Authorization: `Bearer ${TRAY_TOKEN}` },
  });
  if (!response.ok) {
    throw new Error(`Failed to fetch workflow ${workflowId}: ${response.statusText}`);
  }
  return response.json();
}

async function saveWorkflowDetails(workflow: Workflow): Promise<void> {
  const dirPath = path.join(__dirname, "data");
  if (!fs.existsSync(dirPath)) {
    fs.mkdirSync(dirPath, { recursive: true });
  }

  const dataPath = path.join(dirPath, `${workflow.name.replace(/[^a-z0-9]/gi, "_")}.json`);
  if (!fs.existsSync(dataPath)) {
    const details = await fetchWorkflowDetails(workflow.id);
    fs.writeFileSync(dataPath, JSON.stringify(details, null, 2), "utf-8");
    console.log(`Saved ${workflow.name}`);
  } else {
    console.log(`Skipping ${workflow.name}, file already exists.`);
  }
}

async function limitConcurrency<T>(tasks: (() => Promise<T>)[], limit: number): Promise<T[]> {
  const results: Promise<T>[] = [];
  const executing = new Set<Promise<any>>();

  for (const task of tasks) {
    const p = Promise.resolve().then(() => task());
    results.push(p);
    const e: any = p.then(() => executing.delete(e));
    executing.add(e);
    if (executing.size >= limit) {
      await Promise.race(executing);
    }
  }

  return Promise.all(results);
}

async function exportWorkflows(): Promise<void> {
  const { data: workflows } = await fetchWorkflows();
  const tasks = workflows.map((workflow) => () => saveWorkflowDetails(workflow));
  await limitConcurrency(tasks, concurrency);
}

exportWorkflows().catch(console.error);
