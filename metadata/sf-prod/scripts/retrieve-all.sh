#!/bin/bash -ue

# Define variables
orgAlias=$1 # Replace with your Salesforce org alias
apiVersion="54.0" # Replace with the desired API version
sfProject="$( cd "$( dirname "${BASH_SOURCE[0]}" )/.." && pwd )"
packageXml="${sfProject}/manifest/package.xml"

# Check if logged-in
if sfdx auth:list | grep -q $orgAlias; then
  echo "===> Logged in to ${orgAlias}."
else
  echo "===> Run `sf login org` to login first!"
  abort
fi


pushd $sfProject

# Start the package.xml file with header and opening Package tag
cat > $packageXml <<EOL
<?xml version="1.0" encoding="UTF-8"?>
<Package xmlns="http://soap.sforce.com/2006/04/metadata">
EOL

# Start the CustomObject types section
echo "    <types>" >> $packageXml

# Retrieve all sObject names and append each as a member to the package.xml
sfdx force:schema:sobject:list -c all --target-org "$orgAlias" | while read objectName
do
    echo "        <members>$objectName</members>" >> $packageXml
done

# Close the CustomObject types section and add the API version
cat >> $packageXml <<EOL
        <name>CustomObject</name>
    </types>
    <types>
        <members>*</members>
        <name>ApexClass</name>
    </types>
    <types>
        <members>*</members>
        <name>ApexTrigger</name>
    </types>
    <types>
        <members>*</members>
        <name>ApexPage</name>
    </types>
    <types>
        <members>*</members>
        <name>ApexComponent</name>
    </types>
    <types>
        <members>*</members>
        <name>Flow</name>
    </types>
    <types>
        <members>*</members>
        <name>Workflow</name>
    </types>
    <version>$apiVersion</version>
</Package>
EOL

echo "===> ${packageXml} has been generated."

sf project retrieve start -x ./manifest/package.xml --target-org "${orgAlias}"

echo "===> Metadata was retrieved."

popd