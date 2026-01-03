/**
 * Remove auto-number Name fields from JSON files
 * The Name field is auto-generated and cannot be imported
 */

const fs = require('fs');
const path = require('path');

// Files with auto-number Name fields
const filesToFix = [
    'Quiz_Question__c.json',
    'Quiz_Answer_Option__c.json'
];

console.log('=== Removing auto-number Name fields ===\n');

filesToFix.forEach(fileName => {
    const filePath = path.join(__dirname, fileName);
    
    if (!fs.existsSync(filePath)) {
        console.log(`⚠️  Skipping ${fileName} - file not found`);
        return;
    }
    
    console.log(`Processing ${fileName}...`);
    
    const data = JSON.parse(fs.readFileSync(filePath, 'utf8'));
    
    // Remove Name field from each record
    data.records.forEach(record => {
        if (record.Name) {
            delete record.Name;
        }
    });
    
    // Write back
    fs.writeFileSync(filePath, JSON.stringify(data, null, 4));
    
    console.log(`  ✓ Removed Name field from ${data.records.length} records\n`);
});

console.log('✅ Done!');
console.log('\nNow you can run: sf data import tree -p data/trailforge-seed-plan.json');
