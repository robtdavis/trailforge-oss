#!/bin/bash
# ============================================================================
# TrailForge Data Export Commands
# ============================================================================
# Run these commands to export sample data from your org into JSON seed files.
# 
# Prerequisites:
#   - Salesforce CLI installed
#   - Org authorized (update ORG_ALIAS below)
#
# Usage:
#   chmod +x data/export-commands.sh
#   ./data/export-commands.sh
#
# After export, run: node data/fix-references.js
# to convert Salesforce IDs to portable reference IDs.
# ============================================================================

# Configuration - UPDATE THIS to your org alias
ORG_ALIAS="FiveTips"

# Output directory
DATA_DIR="data"

echo "=== TrailForge Data Export ==="
echo "Exporting from org: $ORG_ALIAS"
echo ""

# ----------------------------------------------------------------------------
# 1. Export Courses (root object)
# ----------------------------------------------------------------------------
echo "1. Exporting Courses..."
sf data export tree \
  --query "SELECT Id, Name, Description__c, Estimated_Duration__c, Thumbnail_URL__c, Active__c, Difficulty__c, Passing_Score__c, Archived__c FROM Course__c WHERE Archived__c = false" \
  --output-dir "$DATA_DIR" \
  --prefix "Course__c" \
  --target-org "$ORG_ALIAS"
mv "$DATA_DIR/Course__c-Course__c.json" "$DATA_DIR/Course__c.json" 2>/dev/null

# ----------------------------------------------------------------------------
# 2. Export Modules with Course reference
# ----------------------------------------------------------------------------
echo "2. Exporting Modules..."
sf data export tree \
  --query "SELECT Id, Name, Course__c, Order__c, Summary__c, Archived__c FROM Module__c WHERE Archived__c = false" \
  --output-dir "$DATA_DIR" \
  --prefix "Module__c" \
  --target-org "$ORG_ALIAS"
mv "$DATA_DIR/Module__c-Module__c.json" "$DATA_DIR/Module__c.json" 2>/dev/null

# ----------------------------------------------------------------------------
# 3. Export Quizzes with Course reference
# ----------------------------------------------------------------------------
echo "3. Exporting Quizzes..."
sf data export tree \
  --query "SELECT Id, Name, Course__c, Active__c, Allow_Retakes__c, Instructions__c, Level__c, Max_Attempts__c, Max_Score__c, Modal_Size__c, Mode__c, Passing_Score__c, Shuffle_Questions__c, Sort_Order__c, Time_Limit_Minutes__c, Archived__c FROM Quiz__c WHERE Archived__c = false" \
  --output-dir "$DATA_DIR" \
  --prefix "Quiz__c" \
  --target-org "$ORG_ALIAS"
mv "$DATA_DIR/Quiz__c-Quiz__c.json" "$DATA_DIR/Quiz__c.json" 2>/dev/null

# ----------------------------------------------------------------------------
# 4. Export Lessons with Module reference
# ----------------------------------------------------------------------------
echo "4. Exporting Lessons..."
sf data export tree \
  --query "SELECT Id, Name, Module__c, Order__c, Content_Type__c, Content__c, Content_Body__c, Duration_Minutes__c, External_URL__c, Modal_Size__c, Show_Complete_Button__c, Quiz__c, Archived__c FROM Lesson__c WHERE Archived__c = false" \
  --output-dir "$DATA_DIR" \
  --prefix "Lesson__c" \
  --target-org "$ORG_ALIAS"
mv "$DATA_DIR/Lesson__c-Lesson__c.json" "$DATA_DIR/Lesson__c.json" 2>/dev/null

# ----------------------------------------------------------------------------
# 5. Export Quiz Questions with Quiz reference
# ----------------------------------------------------------------------------
echo "5. Exporting Quiz Questions..."
sf data export tree \
  --query "SELECT Id, Name, Quiz__c, Question_Text__c, Question_Type__c, Points__c, Required__c, Sort_Order__c, Explanation__c FROM Quiz_Question__c" \
  --output-dir "$DATA_DIR" \
  --prefix "Quiz_Question__c" \
  --target-org "$ORG_ALIAS"
mv "$DATA_DIR/Quiz_Question__c-Quiz_Question__c.json" "$DATA_DIR/Quiz_Question__c.json" 2>/dev/null

# ----------------------------------------------------------------------------
# 6. Export Quiz Answer Options with Question reference
# ----------------------------------------------------------------------------
echo "6. Exporting Quiz Answer Options..."
sf data export tree \
  --query "SELECT Id, Name, Quiz_Question__c, Answer_Text__c, Is_Correct__c, Is_Active__c, Sort_Order__c FROM Quiz_Answer_Option__c WHERE Is_Active__c = true" \
  --output-dir "$DATA_DIR" \
  --prefix "Quiz_Answer_Option__c" \
  --target-org "$ORG_ALIAS"
mv "$DATA_DIR/Quiz_Answer_Option__c-Quiz_Answer_Option__c.json" "$DATA_DIR/Quiz_Answer_Option__c.json" 2>/dev/null

# Clean up plan files (we use our own combined plan)
rm -f "$DATA_DIR"/*-plan.json 2>/dev/null

echo ""
echo "=== Export Complete ==="
echo "Files created in: $DATA_DIR/"
echo ""
echo "Next step: Run 'node data/fix-references.js' to convert IDs to references."
