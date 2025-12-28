/**
 * Script to add MIT license headers to XML files in TrailForge
 */
const fs = require('fs');
const path = require('path');

const XML_HEADER = `<!--
SPDX-License-Identifier: MIT
TrailForge — Open Source under the MIT License
Copyright (c) 2025 Robert Davis
See the LICENSE file in the project root for full license text.
-->
`;

const XML_LICENSE_PATTERNS = [
    /^<!--\s*\n?\s*SPDX-License-Identifier[\s\S]*?-->\s*\n?/,
];

function addXmlHeader(filePath) {
    let content = fs.readFileSync(filePath, 'utf8');
    
    // Skip if already has our header
    if (content.includes('SPDX-License-Identifier: MIT')) {
        console.log('  [SKIP] Already has header:', path.basename(filePath));
        return false;
    }
    
    // For XML files, insert after the XML declaration if present
    const xmlDeclMatch = content.match(/^(<\?xml[^?]*\?>\s*\n?)/);
    
    if (xmlDeclMatch) {
        // Insert header after XML declaration
        const xmlDecl = xmlDeclMatch[1];
        const rest = content.slice(xmlDecl.length);
        content = xmlDecl + XML_HEADER + rest;
    } else {
        // No XML declaration, add header at the top
        content = XML_HEADER + content;
    }
    
    fs.writeFileSync(filePath, content);
    console.log('  [ADD] Added header:', path.basename(filePath));
    return true;
}

function walkDir(dir, extension) {
    const files = [];
    const entries = fs.readdirSync(dir, { withFileTypes: true });
    for (const entry of entries) {
        const fullPath = path.join(dir, entry.name);
        if (entry.isDirectory() && !entry.name.startsWith('.')) {
            files.push(...walkDir(fullPath, extension));
        } else if (entry.isFile() && entry.name.endsWith(extension)) {
            files.push(fullPath);
        }
    }
    return files;
}

// Main
const baseDir = process.cwd();
const lwcDir = path.join(baseDir, 'force-app/main/default/lwc');

console.log('=== Adding MIT License Headers to XML Files ===\n');

// Process LWC metadata XML files
console.log('Processing LWC metadata XML files (.js-meta.xml)...');
const xmlFiles = walkDir(lwcDir, '.js-meta.xml');
xmlFiles.forEach(f => addXmlHeader(f));

console.log('\n=== Complete ===');
