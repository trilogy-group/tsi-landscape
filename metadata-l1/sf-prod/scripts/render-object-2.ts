import fs from "fs";
import yaml from "js-yaml";
import xml2js from "xml2js";

// Define target object;
const object = 'Opportunity';

// Define the input folder path
const inputFolderPath = `../../metadata/sf-prod/force-app/main/default/objects/${object}`;

// Define the output YAML file path
const outputYamlFilePath = `../output/${object}.yaml`;

// Get all the XML files in the input folder
const files = fs.readdirSync(inputFolderPath);

// Initialize the output YAML object
let outputYaml = {
    object_name: "Opportunity",
    fields: [],
    layouts: [],
    other_information: [],
    additional_notes: [],
};

// Iterate over the XML files in the input folder
files.forEach((file) => {
    // Read the file contents
    const fileContents = fs.readFileSync(`${inputFolderPath}/${file}`, "utf8");

    // Parse the XML file contents to JSON
    xml2js.parseString(fileContents, (err, jsonObject) => {
        if (err) {
            throw err;
        }

        // Get the object name from the JSON object
        const objectName = jsonObject.CustomObject.fullName;

        // Get the fields from the JSON object
        const fields = jsonObject.CustomObject.fields.field;

        // Get the layouts from the JSON object
        const layouts = jsonObject.CustomObject.layouts.layout;

        // Get the other information from the JSON object
        const otherInformation = jsonObject.CustomObject.otherInformation;

        // Get the additional notes from the JSON object
        const additionalNotes = jsonObject.CustomObject.additionalNotes;

        // Add the fields to the output YAML object
        outputYaml.fields = fields;

        // Add the layouts to the output YAML object
        outputYaml.layouts = layouts;

        // Add the other information to the output YAML object
        outputYaml.other_information = otherInformation;

        // Add the additional notes to the output YAML object
        outputYaml.additional_notes = additionalNotes;

        // Merge the object name into the output YAML object
        outputYaml = { ...outputYaml, object_name: objectName };
    });
});

// Convert the output YAML object to a YAML string
const yamlString = yaml.dump(outputYaml);

// Write the YAML string to the output YAML file
fs.writeFileSync(outputYamlFilePath, yamlString);

console.log("YAML file generated successfully!");