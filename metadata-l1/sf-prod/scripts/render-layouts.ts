import * as fs from 'fs';
import * as path from 'path';
import * as xml2js from 'xml2js';
import * as yaml from 'js-yaml';

const metadataDir = path.resolve(__dirname, '../../../metadata/sf-prod/force-app/main/default/objects');
const outputDir = path.resolve(__dirname, '../output');

// To do.