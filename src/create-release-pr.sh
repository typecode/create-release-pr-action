#!/bin/bash
set -e

echo "Testing minor version bump..."
echo "Identifying PRs merged between $TARGET_BRANCH and $SOURCE_BRANCH..."

# Get the date of the last merge to the target branch
echo "Fetching the last merge date to $TARGET_BRANCH..."
LAST_TARGET_MERGE_DATE=$(gh pr list --base $TARGET_BRANCH --state merged --limit 1 --json mergedAt --jq '.[0].mergedAt')
echo "Last merge to $TARGET_BRANCH was at: $LAST_TARGET_MERGE_DATE"

if [ -z "$LAST_TARGET_MERGE_DATE" ]; then
  echo "No previous merges found to $TARGET_BRANCH. Using a date from 30 days ago."
  LAST_TARGET_MERGE_DATE=$(date -d "30 days ago" -u +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || date -v-30d -u +"%Y-%m-%dT%H:%M:%SZ")
fi

echo "Fetching all merged PRs to $SOURCE_BRANCH..."
# Fetch all PRs with their merge timestamps
PRS_JSON=$(gh pr list --base $SOURCE_BRANCH --state merged --json number,title,body,mergedAt --limit 1000)

# Debug: Print all merged PRs to see what we're working with
echo "All merged PRs (with merge dates):"
echo "$PRS_JSON" | jq -r '.[] | "PR #\(.number): \(.title) - Merged at: \(.mergedAt)"'

# Extract PR numbers for PRs merged after the last merge to target branch
echo "Filtering PRs merged after $LAST_TARGET_MERGE_DATE..."
PRS=$(echo "$PRS_JSON" | jq -r --arg date "$LAST_TARGET_MERGE_DATE" '.[] | select(.mergedAt > $date) | .number')
echo "PRs found after filtering by merge date: $PRS"

ALL_CLOSES=""
PRS_FOUND=false
for PR_NUMBER in $PRS
do
  PRS_FOUND=true
  echo "Checking PR #$PR_NUMBER"
  PR_INFO=$(echo "$PRS_JSON" | jq -r ".[] | select(.number == $PR_NUMBER)")
  PR_TITLE=$(echo "$PR_INFO" | jq -r .title)
  PR_BODY=$(echo "$PR_INFO" | jq -r .body)
  
  echo "PR #$PR_NUMBER:"
  echo "  Title: $PR_TITLE"
  echo "  Body:"
  echo "$PR_BODY"
  
  # Debug: Print exact raw body content
  echo "Raw PR body (for debugging):"
  echo "$PR_BODY" | cat -A
  
  echo "Searching for closes in PR title and body..."
  COMBINED_TEXT="$PR_TITLE $PR_BODY"
  echo "Combined text being searched:"
  echo "$COMBINED_TEXT" | cat -A
  
  # More permissive regex that covers various formats
  PR_CLOSES=$(echo "$COMBINED_TEXT" | grep -oP '(?i)(?:close\s+|closes\s+|fix\s+|fixes\s+|resolve\s+|resolves\s+)([A-Za-z]+-[0-9]+(?:,\s*[A-Za-z]+-[0-9]+)*)' | grep -oP '[A-Za-z]+-[0-9]+' || true)
  echo "Closes found in PR #$PR_NUMBER: $PR_CLOSES"
  
  if [ -n "$PR_CLOSES" ]; then
    ALL_CLOSES+="$PR_CLOSES "
  fi
  
  echo "Current ALL_CLOSES: $ALL_CLOSES"
  echo "----------------------------------------"
done

echo "All closes before processing: $ALL_CLOSES"

SORTED_CLOSES=$(echo $ALL_CLOSES | tr ' ' '\n' | sort -u | tr '\n' ' ' | awk '{$1=$1};1')
CLOSES="$SORTED_CLOSES"
echo "Final sorted and unique closes: $CLOSES"

if [ "$PRS_FOUND" = false ] || [ -z "$CLOSES" ]; then
  echo "WARNING: No PRs or closes found automatically."
  echo "Continuing anyway with a manual placeholder..."
  # Add a placeholder so the workflow doesn't fail
  CLOSES="ELE-MANUAL"
fi

# Create Pull Request
PR_TITLE="Merge $SOURCE_BRANCH into $TARGET_BRANCH"
PR_BODY="Automated PR for $RELEASE_TYPE"
FORMATTED_CLOSES=$(echo $CLOSES | sed 's/ /, /g')
PR_BODY+=$'\n\ncloses '"$FORMATTED_CLOSES"
echo "PR Body:"
echo "$PR_BODY"
PR_URL=$(gh pr create --base $TARGET_BRANCH --head $SOURCE_BRANCH --title "$PR_TITLE" --body "$PR_BODY")
echo "Created PR: $PR_URL"
echo "Pull Request creation completed."
echo "Included closes: closes $CLOSES"