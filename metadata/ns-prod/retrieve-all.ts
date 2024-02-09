import OAuth from "oauth-1.0a";
import crypto from "crypto-js";
import fetch, { Headers } from "node-fetch";
import { config } from "dotenv";
import * as fs from "fs";
import * as path from "path";

config();

// Configuration environment variables
const NS_ACCOUNT_ID = process.env.NS_ACCOUNT_ID || "4914352";
const NS_API_URL = process.env.NS_API_URL || "https://4914352.suitetalk.api.netsuite.com";
const NS_API_CONCURRENCY = parseInt(process.env.NS_API_CONCURRENCY || "10", 10);
const NS_CONSUMER_KEY = process.env.NS_CONSUMER_KEY;
const NS_CONSUMER_SECRET = process.env.NS_CONSUMER_SECRET;
const NS_TOKEN_ID = process.env.NS_TOKEN_ID;
const NS_TOKEN_SECRET = process.env.NS_TOKEN_SECRET;

interface MetadataCatalogResponse {
  links: Link[];
  items: RecordTypeItem[];
  count: number;
  hasMore: boolean;
  offset: number;
  totalResults: number;
}

interface Link {
  rel: string;
  href: string;
}

interface RecordTypeItem {
  name: string;
  type: string;
  links: Link[];
}

// Initialize OAuth 1.0a
const oauth = new OAuth({
  consumer: {
    key: NS_CONSUMER_KEY!,
    secret: NS_CONSUMER_SECRET!,
  },
  signature_method: "HMAC-SHA256",
  hash_function(base_string, key) {
    return crypto.HmacSHA256(base_string, key).toString(crypto.enc.Base64);
  },
});

// Function to make authenticated request
async function makeAuthenticatedRequest<T>(url: string, method: "GET" | "POST" = "GET", acceptHeader: string = "application/json"): Promise<T> {
  const token = {
    key: NS_TOKEN_ID!,
    secret: NS_TOKEN_SECRET!,
  };

  const requestData = {
    url,
    method,
  };

  const headers = new Headers();
  const oauthAuthorization = oauth.toHeader(oauth.authorize(requestData, token)).Authorization;
  headers.set("Authorization", `${oauthAuthorization}, realm="${NS_ACCOUNT_ID}"`);
  headers.set("Content-Type", "application/json");
  headers.set("Accept", acceptHeader);

  try {
    const response = await fetch(url, {
      method,
      headers,
    });
    return response.json() as T;
  } catch (error) {
    console.error("Request failed:", error);
    throw error;
  }
}

// Retrieve list of all records
async function getAllRecords(): Promise<MetadataCatalogResponse> {
  const cacheFilePath = path.join(__dirname, "data", "records.json");

  // Check if the cache file exists
  if (fs.existsSync(cacheFilePath)) {
    // Read and return the cached data
    const cachedData = fs.readFileSync(cacheFilePath, "utf-8");
    return JSON.parse(cachedData) as MetadataCatalogResponse;
  }

  // If the cache file does not exist, make the API request
  const recordsUrl = `${NS_API_URL}/services/rest/record/v1/metadata-catalog`;
  const response = await makeAuthenticatedRequest(recordsUrl);
  const responseData = response as MetadataCatalogResponse;

  // Ensure the data directory exists
  fs.mkdirSync(path.dirname(cacheFilePath), { recursive: true });

  // Cache the response data to a file
  fs.writeFileSync(cacheFilePath, JSON.stringify(responseData, null, 2), "utf-8");

  return responseData;
}

// Helper function to limit concurrency
async function limitConcurrency<T>(tasks: (() => Promise<T>)[], limit: number): Promise<T[]> {
  let index = 0;
  const results: T[] = new Array(tasks.length);
  const runningTasks: Promise<void>[] = [];

  const executeTask = async (): Promise<void> => {
    if (index >= tasks.length) return; // No more tasks to start
    const currentIndex = index++;
    const task = tasks[currentIndex];
    try {
      results[currentIndex] = await task(); // Execute task
    } catch (error) {
      console.error(`Task ${currentIndex} failed:`, error);
    }
    await executeTask(); // Start a new task as soon as one finishes
  };

  for (let i = 0; i < Math.min(limit, tasks.length); i++) {
    runningTasks.push(executeTask()); // Start initial batch of tasks
  }

  await Promise.all(runningTasks);
  return results;
}

// Enhanced function to retrieve metadata for all records with concurrency control
async function getMetadataForAllRecords() {
  const records = await getAllRecords();
  const total = records.items.length;
  const metadataTasks = records.items
    // .slice(0, 10) // (for testing)
    .map((item, index) => {
      const dataPath = path.join(__dirname, "data", "records", `${item.name}.json`);
      // Check if the file exists
      if (fs.existsSync(dataPath)) {
        console.log(`${index + 1}/${total}: Skipping ${item.name}, data already exists.`);
        return undefined; // Skip this record if the file exists
      }

      // Find the link with rel equal to "alternate"
      const link = item.links.find((link) => link.rel === "alternate");
      if (!link) {
        console.log(`No 'alternate' link found for ${item.name}`);
        return undefined; // Return undefined if no alternate link is found
      }

      console.log(`${index + 1}/${total}: Fetching and describing record ${item.name}...`);
      return async () => {
        const recordData = await makeAuthenticatedRequest(link.href, "GET", "application/schema+json");
        // Ensure the data directory exists
        fs.mkdirSync(path.dirname(dataPath), { recursive: true });
        // Save the fetched data to a file
        fs.writeFileSync(dataPath, JSON.stringify(recordData, null, 2), "utf-8");
        return recordData;
      };
    })
    .filter((task) => task !== undefined) as (() => Promise<any>)[]; // Filter out undefined values and assert the remaining as an array of tasks

  return limitConcurrency(metadataTasks, NS_API_CONCURRENCY);
}

// Run
getMetadataForAllRecords()
  .then((metadata) => console.log(`Metadata synchronized.`))
  .catch((error) => console.error(error));
