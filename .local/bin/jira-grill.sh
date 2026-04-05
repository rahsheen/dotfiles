#!/bin/bash

# Usage: ./jira-grill.sh PROJ-123
TICKET_ID=$1

if [ -z "$TICKET_ID" ]; then
    echo "Usage: jira-grill <TICKET-ID>"
    exit 1
fi

# 1. Fetch the ticket info using Jira CLI
# We use --plain to get a clean text format for the LLM
echo "Fetching ticket $TICKET_ID..."
TICKET_DATA=$(jira issue view "$TICKET_ID" --plain)

# 2. Initialize (or prepend to) plan.md
# We put the ticket info at the top so it's part of Aider's "editable" context
echo -e "# Implementation Plan: $TICKET_ID\n\n## Jira Ticket Context\n$TICKET_DATA\n\n---\n## Technical Design\n" > plan.md

# 3. Prepare the activation prompt
INIT_PROMPT="I want to work on Jira ticket $TICKET_ID. I've added the details to plan.md. Use the 'grill-me' skill to stress-test this logic. Ask me questions one at a time. Once we reach a shared understanding, summarize the final architecture and tasks into the 'Technical Design' section of plan.md."

echo "✅ plan.md initialized with ticket data."
echo "🚀 Launching Aider in /ask mode..."

# 4. Launch Aider
# --read: Loads your external skill (Zero-footprint in repo)
# --chat-mode ask: Ensures no code is written during the grill
# --message: Seeds the conversation with the activation prompt directly
# plan.md: Added as the target for the final plan
aider --read ~/.agents/skills/grill-me/SKILL.md plan.md --chat-mode ask --message "$INIT_PROMPT"

