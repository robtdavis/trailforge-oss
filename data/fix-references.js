/**
 * TrailForge Data Reference Fixer
 * 
 * Converts hardcoded Salesforce IDs to reference IDs (@RefXxx) 
 * for portable sf data tree import.
 * 
 * Usage: node data/fix-references.js
 */

const fs = require('fs');
const path = require('path');

const DATA_DIR = __dirname;

// ID mappings from the FiveTips org (queried via sf data query)
// Map: Salesforce ID -> Reference ID (matched by Name)
const ID_MAPPINGS = {
    // Courses
    'a02Hr00001SDdqLIAT': '@Course__cRef1',
    
    // Modules (matched by Name from export vs query)
    'a05Hr00001afXRSIA2': '@Module__cRef1',  // Module 1 - Protecting Company Information
    'a05Hr00001afXRwIAM': '@Module__cRef4',  // Module 2 - Making Good AI Decisions at Work
    'a05Hr00001afXS6IAM': '@Module__cRef2',  // Module 3 - Governance, Escalation, and Responsible Use
    'a05Hr00001afXS7IAM': '@Module__cRef3',  // Module 4 - Building Good AI Habits Over Time
    
    // Quizzes
    'a0BHr00000VSfN9MAL': '@Quiz__cRef1',
    
    // Quiz Questions (matched by Name QQ-XXXXX)
    'a09Hr00000kAizsIAC': '@Quiz_Question__cRef7',   // QQ-00003
    'a09Hr00000kAizxIAC': '@Quiz_Question__cRef2',   // QQ-00004
    'a09Hr00000kAj02IAC': '@Quiz_Question__cRef6',   // QQ-00005
    'a09Hr00000kAj07IAC': '@Quiz_Question__cRef3',   // QQ-00006
    'a09Hr00000kAj08IAC': '@Quiz_Question__cRef4',   // QQ-00007
    'a09Hr00000kAj0CIAS': '@Quiz_Question__cRef8',   // QQ-00008
    'a09Hr00000kAj0DIAS': '@Quiz_Question__cRef9',   // QQ-00009
    'a09Hr00000kAj0HIAS': '@Quiz_Question__cRef10',  // QQ-00010
    'a09Hr00000kAj0MIAS': '@Quiz_Question__cRef5',   // QQ-00011
    'a09Hr00000kAj0RIAS': '@Quiz_Question__cRef1'    // QQ-00012
};

// Files to process with their lookup fields
const FILES_TO_FIX = [
    { file: 'Module__c.json', fields: ['Course__c'] },
    { file: 'Quiz__c.json', fields: ['Course__c'] },
    { file: 'Lesson__c.json', fields: ['Module__c', 'Quiz__c'] },
    { file: 'Quiz_Question__c.json', fields: ['Quiz__c'] },
    { file: 'Quiz_Answer_Option__c.json', fields: ['Quiz_Question__c'] }
];

/**
 * First pass: Build mapping of Salesforce ID -> referenceId by reading all files
 */
function buildMappingFromFiles() {
    const mapping = {};
    
    // Read each source file and map IDs to referenceIds
    const sourceFiles = [
        'Course__c.json',
        'Module__c.json', 
        'Quiz__c.json',
        'Quiz_Question__c.json'
    ];
    
    for (const file of sourceFiles) {
        const filePath = path.join(DATA_DIR, file);
        if (!fs.existsSync(filePath)) continue;
        
        // We need to know what Salesforce ID corresponds to each referenceId
        // But the exported files don't include the SF ID... 
        // We need to query the org or use the lookup values from child records
    }
    
    return mapping;
}

/**
 * Build mapping by correlating lookup IDs in child records with parent referenceIds
 */
function buildMappingByCorrelation() {
    console.log('\n--- Analyzing files to build ID mapping ---\n');
    
    // Read Module__c.json to get the Course__c IDs used
    const modulePath = path.join(DATA_DIR, 'Module__c.json');
    if (fs.existsSync(modulePath)) {
        const data = JSON.parse(fs.readFileSync(modulePath, 'utf8'));
        const courseIds = new Set();
        data.records.forEach(r => {
            if (r.Course__c) courseIds.add(r.Course__c);
        });
        console.log('Course IDs referenced in Modules:', [...courseIds]);
    }
    
    // Read Lesson__c.json to get the Module__c IDs used
    const lessonPath = path.join(DATA_DIR, 'Lesson__c.json');
    if (fs.existsSync(lessonPath)) {
        const data = JSON.parse(fs.readFileSync(lessonPath, 'utf8'));
        const moduleIds = new Set();
        data.records.forEach(r => {
            if (r.Module__c) moduleIds.add(r.Module__c);
        });
        console.log('Module IDs referenced in Lessons:', [...moduleIds]);
    }
    
    // Read Quiz_Question__c.json to get Quiz IDs
    const questionPath = path.join(DATA_DIR, 'Quiz_Question__c.json');
    if (fs.existsSync(questionPath)) {
        const data = JSON.parse(fs.readFileSync(questionPath, 'utf8'));
        const quizIds = new Set();
        data.records.forEach(r => {
            if (r.Quiz__c) quizIds.add(r.Quiz__c);
        });
        console.log('Quiz IDs referenced in Questions:', [...quizIds]);
    }
    
    // Read Quiz_Answer_Option__c.json to get Question IDs
    const answerPath = path.join(DATA_DIR, 'Quiz_Answer_Option__c.json');
    if (fs.existsSync(answerPath)) {
        const data = JSON.parse(fs.readFileSync(answerPath, 'utf8'));
        const questionIds = new Set();
        data.records.forEach(r => {
            if (r.Quiz_Question__c) questionIds.add(r.Quiz_Question__c);
        });
        console.log('Question IDs referenced in Answers:', [...questionIds]);
    }
}

/**
 * Fix references in a single file using the pre-built mapping
 */
function fixFile(config) {
    const filePath = path.join(DATA_DIR, config.file);
    
    if (!fs.existsSync(filePath)) {
        console.log(`  ⚠️  Skipping ${config.file} - file not found`);
        return;
    }
    
    const data = JSON.parse(fs.readFileSync(filePath, 'utf8'));
    let fixedCount = 0;
    let notFoundIds = new Set();
    
    for (const record of data.records) {
        for (const field of config.fields) {
            const sfId = record[field];
            
            // Skip if null/undefined or already a reference
            if (!sfId || sfId.startsWith('@')) continue;
            
            // Check if it's a Salesforce ID (15 or 18 chars)
            if (sfId.match(/^[a-zA-Z0-9]{15,18}$/)) {
                const refId = ID_MAPPINGS[sfId];
                
                if (refId) {
                    record[field] = refId;
                    fixedCount++;
                } else {
                    notFoundIds.add(sfId);
                }
            }
        }
    }
    
    // Write back
    fs.writeFileSync(filePath, JSON.stringify(data, null, 4));
    
    console.log(`  ✓ ${config.file}: Fixed ${fixedCount} reference(s)`);
    
    if (notFoundIds.size > 0) {
        console.log(`    ⚠️  ${notFoundIds.size} ID(s) not found in mapping:`);
        notFoundIds.forEach(id => console.log(`       - ${id}`));
    }
}

/**
 * Main function
 */
function main() {
    console.log('=== TrailForge Data Reference Fixer ===\n');
    
    // First show what we're working with
    buildMappingByCorrelation();
    
    console.log('\n--- Fixing references ---\n');
    
    for (const config of FILES_TO_FIX) {
        fixFile(config);
    }
    
    console.log('\n✅ Done! Files updated with reference IDs.');
    console.log('\nTo import this data into a fresh org:');
    console.log('  sf data import tree -p data/trailforge-seed-plan.json -o <org-alias>\n');
}

// Run
main();
