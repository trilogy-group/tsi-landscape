import * as fs from 'fs';
import * as path from 'path';
import * as xml2js from 'xml2js';
import * as yaml from 'js-yaml';

const metadataDir = path.resolve(__dirname, '../../../metadata/sf-prod/force-app/main/default/objects');
const outputDir = path.resolve(__dirname, '../output');

// Ensure the output directory exists
if (!fs.existsSync(outputDir)) {
    fs.mkdirSync(outputDir, { recursive: true });
}

// Helper function to read and parse XML file
const parseXmlFile = (filePath: string): Promise<any> => {
    return new Promise((resolve, reject) => {
        fs.readFile(filePath, (err, data) => {
            if (err) {
                return reject(err);
            }
            xml2js.parseString(data, (err, result) => {
                if (err) {
                    return reject(err);
                }
                resolve(result);
            });
        });
    });
};

// Initialize an object to hold all YAML contents
const allObjectsYamlContent: Record<string, any> = {};

// Helper function to determine the type of relationship
const getRelationshipType = (fieldData: any): string | null => {
    if (fieldData.type?.[0] === 'Lookup' || fieldData.type?.[0] === 'MasterDetail') {
        return fieldData.referenceTo ? fieldData.referenceTo[0] : null;
    }
    return null;
};

// Process each object
fs.readdir(metadataDir, async (err, objectFolders) => {
    if (err) {
        console.error('Error reading metadata directory:', err);
        return;
    }

    for (const objectFolder of objectFolders) {
        const objectDirPath = path.join(metadataDir, objectFolder);
        const objectMetaFilePath = path.join(objectDirPath, `${objectFolder}.object-meta.xml`);

        try {
            const objectMeta = await parseXmlFile(objectMetaFilePath);
            const objectData = objectMeta.CustomObject;
            const fieldsDirPath = path.join(objectDirPath, 'fields');
            let fieldFiles: string[] = [];
            try {
                fieldFiles = fs.readdirSync(fieldsDirPath);
            } catch (error: any) {
                if (error.code !== 'ENOENT') {
                    throw error; // Rethrow the error if it's not due to the directory not existing
                }
                // If the directory does not exist, fieldFiles remains an empty array
            }
            const fields = [];

            for (const fieldFile of fieldFiles) {
                if (path.extname(fieldFile) === '.xml') {
                    const fieldMetaFilePath = path.join(fieldsDirPath, fieldFile);
                    const fieldMeta = await parseXmlFile(fieldMetaFilePath);
                    const fieldData = fieldMeta.CustomField;
                    fields.push({
                        api_name: fieldData.fullName ? fieldData.fullName[0] : 'No API name available',
                        label: fieldData.label ? fieldData.label[0] : 'No label available',
                        type: fieldData.type ? fieldData.type[0] : 'No type available',
                        description: fieldData.description ? fieldData.description[0] : 'No description available',
                        required: fieldData.required ? fieldData.required[0] === 'true' : false,
                        // Add relationship details if present
                        relationship: getRelationshipType(fieldData)
                    });
                }
            }

            // Add to the allObjectsYamlContent object
            allObjectsYamlContent[objectFolder] = {
                last_updated: new Date().toISOString().slice(0, 10),
                api_name: objectFolder,
                title: objectData.label ? objectData.label[0] : objectFolder,
                link: `https://trilogy-sales.lightning.force.com/lightning/setup/ObjectManager/${objectFolder}/Details/view`,
                description: objectData.description ? objectData.description[0] : 'No description available',
                access_rules: objectData.sharingModel ? objectData.sharingModel[0] : 'No data available',
                fields: fields
            };
        } catch (error) {
            console.error(`Error processing object ${objectFolder}:`, error);
        }
    }

    // Convert the aggregated content to YAML format
    const aggregatedYamlContent = yaml.dump(allObjectsYamlContent);

    // Write the aggregated YAML content to a single file
    const outputFilePath = path.join(outputDir, 'SF-Objects.yaml');
    fs.writeFileSync(outputFilePath, aggregatedYamlContent);
    console.log('Aggregated YAML file generated for all objects');
});