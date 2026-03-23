#!/bin/bash
set -euo pipefail

# A2A RPC Client - Send message and get immediate response
# Context is automatically tracked per agent in contexts.json
# Usage: ./send-rpc.sh <agent_id> <message>

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/config.json"
CONTEXTS_FILE="$SCRIPT_DIR/contexts.json"

if [[ ! -f "$CONFIG_FILE" ]]; then
  echo "Error: Config file not found: $CONFIG_FILE" >&2
  exit 1
fi

# Check arguments
if [[ $# -lt 2 ]]; then
  echo "Usage: $0 <agent_id> <message>" >&2
  echo "" >&2
  echo "Examples:" >&2
  echo "  $0 ai.platform.squad:a2a:test \"What is your purpose?\"" >&2
  echo "  $0 ai.platform.squad:a2a:test \"Follow-up question\"" >&2
  echo "" >&2
  echo "Note: Conversation context is tracked automatically per agent" >&2
  exit 1
fi

BROKER_URL=$(jq -r '.brokerUrl' "$CONFIG_FILE")
AGENT_ID="$1"
MESSAGE="$2"

# Load stored contextId for this agent (if exists)
CONTEXT_ID=""
if [[ -f "$CONTEXTS_FILE" ]]; then
  CONTEXT_ID=$(jq -r --arg agent_id "$AGENT_ID" '.[$agent_id] // empty' "$CONTEXTS_FILE" 2>/dev/null || echo "")
fi

if [[ -n "$CONTEXT_ID" ]]; then
  echo "📎 Continuing conversation (contextId: $CONTEXT_ID)" >&2
fi

# Generate unique message ID
MESSAGE_ID="msg-$(date +%s)-$$"

# Build the A2A Message structure
MESSAGE_PAYLOAD=$(jq -n \
  --arg message_id "$MESSAGE_ID" \
  --arg message "$MESSAGE" \
  --arg context_id "$CONTEXT_ID" \
  '{
    kind: "message",
    messageId: $message_id,
    role: "user",
    parts: [
      {
        kind: "text",
        text: $message
      }
    ],
    metadata: {}
  } + if $context_id != "" then {contextId: $context_id} else {} end')

# Generate unique RPC ID
RPC_ID="rpc-$(date +%s)-$$"

# Prepare A2A-compliant JSON-RPC request
RPC_PAYLOAD=$(jq -n \
  --arg rpc_id "$RPC_ID" \
  --argjson message "$MESSAGE_PAYLOAD" \
  '{
    "jsonrpc": "2.0",
    "method": "message/send",
    "params": {
      "message": $message
    },
    "id": $rpc_id
  }')

# Make blocking RPC call
RESPONSE=$(curl -s -w "\n%{http_code}" \
  -X POST "$BROKER_URL/a2a/$AGENT_ID/rpc" \
  -H "Content-Type: application/json" \
  -d "$RPC_PAYLOAD" 2>&1 || echo -e "\nERROR")

HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
BODY=$(echo "$RESPONSE" | sed '$d')

if [[ "$HTTP_CODE" == "ERROR" ]]; then
  echo "Error: Network error - broker may be unreachable" >&2
  exit 1
elif [[ "$HTTP_CODE" -eq 200 ]]; then
  # Success - extract contextId and response
  RESPONSE_CONTEXT_ID=$(echo "$BODY" | jq -r '.result.contextId // empty' 2>/dev/null)
  
  # Extract text from parts
  RESPONSE_TEXT=$(echo "$BODY" | jq -r '
    if .result.kind == "message" then
      .result.parts[]? | select(.kind == "text") | .text
    else
      .result
    end
  ' 2>/dev/null)
  
  # Display response
  if [[ -n "$RESPONSE_TEXT" ]]; then
    echo "$RESPONSE_TEXT"
  else
    # Fallback: show full result
    echo "$BODY" | jq -r '.result // .error.message // .'
  fi
  
  # Store contextId for future conversations with this agent
  if [[ -n "$RESPONSE_CONTEXT_ID" ]]; then
    # Create/update contexts.json with file locking to prevent race conditions
    LOCK_FILE="$CONTEXTS_FILE.lock"
    (
      flock -w 5 200 || { echo "Warning: Could not acquire lock on contexts.json" >&2; exit 0; }

      if [[ ! -f "$CONTEXTS_FILE" ]]; then
        echo "{}" > "$CONTEXTS_FILE"
      fi

      # Update contextId for this agent
      jq --arg agent_id "$AGENT_ID" --arg context_id "$RESPONSE_CONTEXT_ID" \
        '.[$agent_id] = $context_id' "$CONTEXTS_FILE" > "$CONTEXTS_FILE.tmp" && \
        mv "$CONTEXTS_FILE.tmp" "$CONTEXTS_FILE"
    ) 200>"$LOCK_FILE"
    
    # Show feedback only if this is a new context
    if [[ "$CONTEXT_ID" != "$RESPONSE_CONTEXT_ID" ]]; then
      echo "" >&2
      echo "💾 Context saved for $AGENT_ID" >&2
      echo "   Future messages will automatically continue this conversation" >&2
    fi
  fi
  
  exit 0
elif [[ "$HTTP_CODE" -eq 504 ]]; then
  echo "Error: Request timed out (agent didn't respond within 30s)" >&2
  exit 1
elif [[ "$HTTP_CODE" -eq 404 ]]; then
  echo "Error: Agent not found or not registered: $AGENT_ID" >&2
  exit 1
else
  echo "Error: HTTP $HTTP_CODE - $BODY" >&2
  exit 1
fi
