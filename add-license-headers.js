/**
 * Script to add MIT license headers to all source files in TrailForge
 */
const fs = require('fs');
const path = require('path');

// License headers for different file types
const APEX_JS_HEADER = `//
// SPDX-License-Identifier: MIT
// TrailForge — Open Source under the MIT License
// Copyright (c) 2025 Robert Davis
// See the LICENSE file in the project root for full license text.
//
`;

const HTML_XML_HEADER = `<!--
SPDX-License-Identifier: MIT
TrailForge — Open Source under the MIT License
Copyright (c) 2025 Robert Davis
See the LICENSE file in the project root for full license text.
-->
`;

// Patterns to identify existing license headers
const APEX_LICENSE_PATTERNS = [
    /^\/\/\s*SPDX-License-Identifier[\s\S]*?\/\/\s*\n/,
    /^\/\*\*?\s*\n?\s*\*?\s*@license[\s\S]*?\*\/\s*\n?/,
    /^\/\*\*?\s*\n?\s*\*?\s*MIT License[\s\S]*?\*\/\s*\n?/i,
    /^\/\*\*?\s*\n?\s*\*?\s*Copyright[\s\S]*?\*\/\s*\n?/i,
];

const HTML_LICENSE_PATTERNS = [
    /^<!--\s*\n?\s*SPDX-License-Identifier[\s\S]*?-->\s*\n?/,
    /^<!--\s*\n?\s*MIT License[\s\S]*?-->\s*\n?/i,
    /^<!--\s*\n?\s*Copyright[\s\S]*?-->\s*\n?/i,
];

function removeExistingLicenseHeader(content, patterns) {
    for (const pattern of patterns) {
        content = content.replace(pattern, '');
    }
    return content.replace(/^\s*\n/, ''); // Remove leading blank lines
}

function addHeader(filePath, header, patterns) {
    let content = fs.readFileSync(filePath, 'utf8');
    
    // Check if our header is already there
    if (content.startsWith(header.trim().slice(0, 50))) {
        console.log('  [SKIP] Already has header:', filePath);
        return false;
    }
    
    // Remove any existing license header
    content = removeExistingLicenseHeader(content, patterns);
    
    // Add our header
    const newContent = header + content;
    fs.writeFileSync(filePath, newContent);
    console.log('  [ADD] Added header:', filePath);
    return true;
}

function processDirectory(dir, extension, header, patterns) {
    const files = [];
    
    function walkDir(currentDir) {
        const entries = fs.readdirSync(currentDir, { withFileTypes: true });
        for (const entry of entries) {
            const fullPath = path.join(currentDir, entry.name);
            if (entry.isDirectory() && !entry.name.startsWith('.')) {
                walkDir(fullPath);
            } else if (entry.isFile() && entry.name.endsWith(extension)) {
                files.push(fullPath);
            }
        }
    }
    
    walkDir(dir);
    return files;
}

// Main
const baseDir = process.cwd();
const forceAppDir = path.join(baseDir, 'force-app');

console.log('=== Adding MIT License Headers to TrailForge ===\n');

// Process Apex classes
console.log('Processing Apex classes (.cls)...');
const clsFiles = processDirectory(path.join(forceAppDir, 'main/default/classes'), '.cls', APEX_JS_HEADER, APEX_LICENSE_PATTERNS);
clsFiles.forEach(f => addHeader(f, APEX_JS_HEADER, APEX_LICENSE_PATTERNS));

// Process Apex triggers
console.log('\nProcessing Apex triggers (.trigger)...');
const triggerFiles = processDirectory(path.join(forceAppDir, 'main/default/triggers'), '.trigger', APEX_JS_HEADER, APEX_LICENSE_PATTERNS);
triggerFiles.forEach(f => addHeader(f, APEX_JS_HEADER, APEX_LICENSE_PATTERNS));

// Process LWC JS files
console.log('\nProcessing LWC JavaScript files (.js)...');
const jsFiles = processDirectory(path.join(forceAppDir, 'main/default/lwc'), '.js', APEX_JS_HEADER, APEX_LICENSE_PATTERNS);
jsFiles.forEach(f => addHeader(f, APEX_JS_HEADER, APEX_LICENSE_PATTERNS));

// Process LWC HTML files
console.log('\nProcessing LWC HTML files (.html)...');
const htmlFiles = processDirectory(path.join(forceAppDir, 'main/default/lwc'), '.html', HTML_XML_HEADER, HTML_LICENSE_PATTERNS);
htmlFiles.forEach(f => addHeader(f, HTML_XML_HEADER, HTML_LICENSE_PATTERNS));

console.log('\n=== Complete ===');
