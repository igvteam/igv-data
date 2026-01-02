const fs = require('fs');
const path = require('path');

// Read the file
const filePath = path.join(__dirname, '../genomes/hubs/mm10/trackDb.txt');
const fileContent = fs.readFileSync(filePath, 'utf-8');

// Split the file into objects separated by blank lines
const objects = fileContent.split(/\n\s*\n/);

// Parse each object and extract the required fields
const result = objects.map((block) => {
    const lines = block.split('\n');
    const obj = {};

    lines.forEach((line) => {
        const [key, ...valueParts] = line.split(/\s+/);
        const value = valueParts.join(' ');

        if (key === 'track') obj.id = value;
        if (key === 'shortLabel') obj.name = value;
        if (key === 'group') obj.group = value;
        if (key === 'bigDataUrl') obj.url = value;
        if (key === 'url') obj.html = value;
    });

    return obj.url ? obj : null;
}).filter(Boolean);

// Write the result to a JSON file
const outputFilePath = path.join(__dirname, 'output.json');
fs.writeFileSync(outputFilePath, JSON.stringify(result, null, 2), 'utf-8');

console.log(`Conversion complete. JSON saved to ${outputFilePath}`);
