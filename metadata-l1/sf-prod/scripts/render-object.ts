import * as fs from 'fs';
import * as path from 'path';
import * as xml2js from 'xml2js';
import * as yaml from 'js-yaml';

const parser = new xml2js.Parser();

async function parseSFObjectMetadata(objectName: string) {
    const metadataDir = path.join(__dirname, '../../../metadata/sf-prod/force-app/main/default/objects', objectName);
    const files = fs.readdirSync(metadataDir);

    const objectMetadata: any = {
        last_updated: new Date().toISOString().split('T')[0],
        api_name: objectName,
        title: objectName,
        link: `https://trilogy-sales.lightning.force.com/lightning/setup/ObjectManager/${objectName}/Details/view`,
        description: '',
        access_rules: 'No data available',
        fields: [],
        layouts: []
    };

    for (const file of files) {
        const filePath = path.join(metadataDir, file);
        const xml = fs.readFileSync(filePath, 'utf8');

        const result = await parser.parseStringPromise(xml);
        const metadata = result.CustomObject || result.CustomField || result.CompactLayout;

        if (metadata.fullName) {
            objectMetadata.fields.push({
                api_name: metadata.fullName[0],
                title: metadata.label ? metadata.label[0] : '',
                link: `https://trilogy-sales.lightning.force.com/lightning/setup/ObjectManager/${objectName}/FieldsAndRelationships/${metadata.fullName[0]}/view`,
                description: metadata.description ? metadata.description[0] : '',
                access_rules: 'No data available'
            });
        }

        if (metadata.fields) {
            objectMetadata.layouts.push({
                api_name: metadata.fullName[0],
                title: metadata.label ? metadata.label[0] : '',
                description: ''
            });
        }
    }

    const yamlStr = yaml.dump(objectMetadata);
    fs.writeFileSync(`./metadata-l1/SF-Object-${objectName}.yaml`, yamlStr, 'utf8');
}

parseSFObjectMetadata('Opportunity');