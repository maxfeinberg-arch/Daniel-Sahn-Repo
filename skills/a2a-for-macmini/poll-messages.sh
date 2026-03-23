#!/bin/bash
# RESILIENCE: Don't use set -e - we handle errors explicitly to keep running
set -uo pipefail

# A2A Message Broker Polling Script
# Polls the broker for messages, forwards to OpenClaw, sends responses back
# NO DELETE calls - messages persist for audit and are cleaned by TTL worker
# 
# RESILIENCE FEATURES:
# - Continues running through network errors and API failures
# - Exponential backoff on connection failures
# - Graceful signal handling (SIGTERM, SIGINT)
# - Individual message processing failures don't crash the poller
# - Exits cleanly only on explicit shutdown signals

# Colors for logging
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() {
  echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1"
}

log_success() {
  echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} ✓ $1"
}

log_warn() {
  echo -e "${YELLOW}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} ⚠ $1"
}

log_error() {
  echo -e "${RED}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} ✗ $1"
}

# Load config
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/config.json"

if [[ ! -f "$CONFIG_FILE" ]]; then
  log_error "Config file not found: $CONFIG_FILE"
  exit 1
fi

log_info "Loading config from $CONFIG_FILE"
BROKER_URL=$(jq -r '.brokerUrl' "$CONFIG_FILE")
AGENT_ID=$(jq -r '.agentId' "$CONFIG_FILE")
POLL_TIMEOUT=$(jq -r '.pollTimeout' "$CONFIG_FILE")
OPENCLAW_URL=$(jq -r '.openclawApiUrl' "$CONFIG_FILE")
TOKEN_PATH=$(jq -r '.openclawTokenPath' "$CONFIG_FILE")
OPENCLAW_AGENT=$(jq -r '.openclawAgent // "main"' "$CONFIG_FILE")

# Expand ~ in token path
TOKEN_PATH="${TOKEN_PATH/#\~/$HOME}"

log_info "Broker: $BROKER_URL"
log_info "Agent: $AGENT_ID"
log_info "OpenClaw: $OPENCLAW_URL (agent: $OPENCLAW_AGENT)"

# Check dependencies (fatal - can't run without these)
FATAL_ERROR=0
for cmd in curl jq; do
  if ! command -v "$cmd" &> /dev/null; then
    log_error "Required command not found: $cmd"
    FATAL_ERROR=1
  fi
done

# Check token file (fatal - can't authenticate without it)
if [[ ! -f "$TOKEN_PATH" ]]; then
  log_error "OpenClaw token file not found: $TOKEN_PATH"
  FATAL_ERROR=1
fi

if [[ $FATAL_ERROR -eq 1 ]]; then
  log_error "Fatal configuration errors - cannot start poller"
  exit 1
fi

# Process a single message
# Returns 0 on success, 1 on failure (but doesn't exit - caller continues)
process_message() {
  local msg="$1"
  
  # Extract fields with error handling
  MESSAGE_ID=$(echo "$msg" | jq -r '.message_id' 2>/dev/null || echo "unknown")
  FROM=$(echo "$msg" | jq -r '.from' 2>/dev/null || echo "unknown")
  METHOD=$(echo "$msg" | jq -r '.message.method // "unknown"' 2>/dev/null || echo "unknown")
  RPC_ID=$(echo "$msg" | jq -r '.message.id' 2>/dev/null || echo "unknown")
  REQUEST_ID=$(echo "$msg" | jq -r '.request_id // empty' 2>/dev/null || echo "")
  CORRELATION_ID=$(echo "$msg" | jq -r '.correlation_id // empty' 2>/dev/null || echo "")
  
  if [[ "$MESSAGE_ID" == "unknown" ]]; then
    log_error "Failed to parse message - skipping"
    return 1
  fi
  
  # === PING DETECTION AND AUTO-PONG ===
  # Detect ping messages and auto-respond without forwarding to OpenClaw
  if [[ "$METHOD" == "ping" ]]; then
    log_info "Received ping from $FROM (id: $RPC_ID, request_id: $REQUEST_ID) - auto-responding with pong"
    
    # Send pong response as proper RPC response (message_type: response, request_id)
    PONG_PAYLOAD=$(jq -n \
      --arg to "$FROM" \
      --arg from "$AGENT_ID" \
      --arg rpc_id "$RPC_ID" \
      --arg request_id "$REQUEST_ID" \
      '{
        to: $to,
        from: $from,
        message: {
          jsonrpc: "2.0",
          result: "pong",
          id: $rpc_id
        },
        message_type: "response",
        request_id: $request_id
      }' 2>/dev/null)
    
    if [[ -z "$PONG_PAYLOAD" ]]; then
      log_error "Failed to build pong payload - skipping"
      return 1
    fi
    
    PONG_RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$BROKER_URL/v1/messages" \
      -H "Content-Type: application/json" \
      -d "$PONG_PAYLOAD" 2>&1 || echo -e "\nERROR")
    
    HTTP_CODE=$(echo "$PONG_RESPONSE" | tail -n1)
    
    if [[ "$HTTP_CODE" == "ERROR" ]]; then
      log_error "Network error sending pong - broker may be unreachable"
      return 1
    elif [[ "$HTTP_CODE" -eq 200 || "$HTTP_CODE" -eq 201 ]]; then
      log_success "Pong sent successfully"
      return 0
    else
      log_error "Failed to send pong (HTTP $HTTP_CODE)"
      return 1
    fi
  fi
  # === END PING DETECTION ===
  
  # Extract contextId from A2A Message structure (server-generated or client-provided)
  CONTEXT_ID=$(echo "$msg" | jq -r '.message.params.message.contextId // empty' 2>/dev/null)
  
  # Generate contextId if not present (A2A spec: agent must generate if missing)
  # Track whether this is a new session so we can include a system prompt on
  # the first message to help OpenClaw handle agent-forwarded messages.
  IS_NEW_SESSION="false"
  if [[ -z "$CONTEXT_ID" ]]; then
    CONTEXT_ID="ctx-$(date +%s%3N)-$(openssl rand -hex 8)"
    IS_NEW_SESSION="true"
    log_info "Generated new contextId: $CONTEXT_ID (new session)"
  else
    log_info "Using existing contextId: $CONTEXT_ID"
  fi
  
  # Extract message text from A2A Message parts
  # Use jq -j (join) to preserve multiline text content within each part.
  # We take only the first text part (limit(1; ...)) to avoid concatenating
  # multiple parts together.
  USER_MSG=$(echo "$msg" | jq -j '
    [.message.params.message.parts[]?
     | select(.text != null)
     | .text] | first // empty
  ' 2>/dev/null)
  
  if [[ -z "$USER_MSG" ]]; then
    # No text content (e.g. file-only message). Must still send a response back
    # so the broker's PendingRPCManager doesn't hang waiting forever.
    log_warn "No text content in message from $FROM - responding without OpenClaw"
    REPLY="I can only process text messages. This message contained no text content."
  else
    log_info "Processing message $MESSAGE_ID from $FROM (contextId: $CONTEXT_ID)"

    # Escape message for JSON
    USER_MSG_ESCAPED=$(echo "$USER_MSG" | jq -Rs . 2>/dev/null)
    if [[ -z "$USER_MSG_ESCAPED" ]]; then
      log_error "Failed to escape message - skipping"
      return 1
    fi

    # Forward to OpenClaw
    # Use contextId as the OpenClaw session key so multi-turn conversations
    # retain memory. OpenClaw manages conversation history server-side via
    # the session key.
    SESSION="agent:${OPENCLAW_AGENT}:a2a:context:$CONTEXT_ID"
    OPENCLAW_TIMEOUT=${OPENCLAW_TIMEOUT:-60}  # seconds, configurable via env

  log_info "Forwarding to OpenClaw (session: $SESSION)"

  # On new sessions (no prior contextId), prepend a system message so OpenClaw
  # knows how to handle messages forwarded by other agents (e.g. AIDA wraps
  # user requests in a Dispatch Context envelope with thread history).
  if [[ "$IS_NEW_SESSION" == "true" ]]; then
    log_info "New session - including agent relay system prompt"
    SYSTEM_PROMPT="You are agent \"${AGENT_ID}\". You are receiving messages through an agent-to-agent relay. If you see a message that references you or is directed to \"${AGENT_ID}\" (including URLs containing your agent ID), that message has already been delivered to you — you are the intended recipient. Do not try to forward, relay, or re-send it. Instead, read the message content and respond to it directly. Messages may be wrapped in structured context from a dispatch agent (e.g. a \"Dispatch Context\" with thread history and a \"User Request\" section). If so, focus on the actual user request within the wrapper and respond naturally. Do not comment on or repeat the dispatch metadata."
    SYSTEM_PROMPT_ESCAPED=$(echo "$SYSTEM_PROMPT" | jq -Rs . 2>/dev/null)
    OPENCLAW_PAYLOAD=$(jq -n \
      --argjson msg "$USER_MSG_ESCAPED" \
      --argjson sys "$SYSTEM_PROMPT_ESCAPED" \
      '{
        model: "openclaw",
        messages: [
          {role: "system", content: $sys},
          {role: "user", content: $msg}
        ]
      }' 2>/dev/null)
  else
    OPENCLAW_PAYLOAD=$(jq -n \
      --argjson msg "$USER_MSG_ESCAPED" \
      '{
        model: "openclaw",
        messages: [{role: "user", content: $msg}]
      }' 2>/dev/null)
  fi

  if [[ -z "$OPENCLAW_PAYLOAD" ]]; then
    log_error "Failed to build OpenClaw payload - skipping"
    return 1
  fi

  # Call OpenClaw with error handling and timeout to prevent hangs
  OPENCLAW_RESPONSE=$(curl -s -k -w "\n%{http_code}" --max-time "$OPENCLAW_TIMEOUT" \
    -X POST "$OPENCLAW_URL/v1/chat/completions" \
    -H "Authorization: Bearer $(cat "$TOKEN_PATH")" \
    -H "x-openclaw-session-key: $SESSION" \
    -H "Content-Type: application/json" \
    -d "$OPENCLAW_PAYLOAD" 2>&1 || echo -e "\nERROR")

  HTTP_CODE=$(echo "$OPENCLAW_RESPONSE" | tail -n1)
  BODY=$(echo "$OPENCLAW_RESPONSE" | sed '$d')

  if [[ "$HTTP_CODE" == "ERROR" ]]; then
    log_error "Network error calling OpenClaw - may be unreachable"
    REPLY="Error: Network error - OpenClaw may be unreachable"
  elif [[ "$HTTP_CODE" -ne 200 ]]; then
    log_error "OpenClaw API error (HTTP $HTTP_CODE): ${BODY:0:200}"
    REPLY="Error: OpenClaw returned HTTP $HTTP_CODE"
  else
    REPLY=$(echo "$BODY" | jq -r '.choices[0].message.content // "Error: No response from OpenClaw"' 2>/dev/null)
    if [[ -z "$REPLY" ]]; then
      log_error "Failed to parse OpenClaw response"
      REPLY="Error: Failed to parse OpenClaw response"
    else
      log_success "Got response from OpenClaw (${#REPLY} chars)"
    fi
  fi  # end OpenClaw if/elif/else
  fi  # end text vs no-text

  # Escape reply for JSON
  REPLY_ESCAPED=$(echo "$REPLY" | jq -Rs . 2>/dev/null)
  if [[ -z "$REPLY_ESCAPED" ]]; then
    log_error "Failed to escape reply - using fallback"
    REPLY_ESCAPED='"Error: Failed to process reply"'
  fi
  
  # Send response back to broker (NO DELETE)
  log_info "Sending response back to broker"
  
  # Check if this is an RPC request (has request_id) for correlation
  if [[ -n "$REQUEST_ID" ]]; then
    # This is an RPC request - include correlation fields
    log_info "Including correlation fields (request_id: $REQUEST_ID, correlation_id: $CORRELATION_ID)"
    
    # Generate a unique message ID for the response
    RESPONSE_MSG_ID="msg-$(date +%s%3N)-$(openssl rand -hex 4)"
    
    # Build A2A-compliant message structure with contextId
    # Include correlation_id if present (links response to async task)
    if [[ -n "$CORRELATION_ID" ]]; then
      RESPONSE_PAYLOAD=$(jq -n \
        --arg to "$FROM" \
        --arg from "$AGENT_ID" \
        --arg msg_id "$RESPONSE_MSG_ID" \
        --argjson text "$REPLY_ESCAPED" \
        --arg rpc_id "$RPC_ID" \
        --arg request_id "$REQUEST_ID" \
        --arg correlation_id "$CORRELATION_ID" \
        --arg context_id "$CONTEXT_ID" \
        '{
          to: $to,
          from: $from,
          message: {
            jsonrpc: "2.0",
            result: {
              kind: "message",
              messageId: $msg_id,
              role: "agent",
              contextId: $context_id,
              parts: [
                {
                  kind: "text",
                  text: $text
                }
              ],
              metadata: {}
            },
            id: $rpc_id
          },
          message_type: "response",
          request_id: $request_id,
          correlation_id: $correlation_id
        }' 2>/dev/null)
    else
      # No correlation_id (blocking request)
      RESPONSE_PAYLOAD=$(jq -n \
        --arg to "$FROM" \
        --arg from "$AGENT_ID" \
        --arg msg_id "$RESPONSE_MSG_ID" \
        --argjson text "$REPLY_ESCAPED" \
        --arg rpc_id "$RPC_ID" \
        --arg request_id "$REQUEST_ID" \
        --arg context_id "$CONTEXT_ID" \
        '{
          to: $to,
          from: $from,
          message: {
            jsonrpc: "2.0",
            result: {
              kind: "message",
              messageId: $msg_id,
              role: "agent",
              contextId: $context_id,
              parts: [
                {
                  kind: "text",
                  text: $text
                }
              ],
              metadata: {}
            },
            id: $rpc_id
          },
          message_type: "response",
          request_id: $request_id
        }' 2>/dev/null)
    fi
  else
    # No request_id - shouldn't happen for messages via /rpc, but handle gracefully
    log_warn "Message has no request_id - cannot send response via POST /v1/messages"
    log_warn "All messages should come through /a2a/{agent_id}/rpc which includes request_id"
    return 1
  fi
  
  if [[ -z "$RESPONSE_PAYLOAD" ]]; then
    log_error "Failed to build response payload - cannot send reply"
    return 1
  fi
  
  SEND_RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$BROKER_URL/v1/messages" \
    -H "Content-Type: application/json" \
    -d "$RESPONSE_PAYLOAD" 2>&1 || echo -e "\nERROR")
  
  HTTP_CODE=$(echo "$SEND_RESPONSE" | tail -n1)
  BODY=$(echo "$SEND_RESPONSE" | sed '$d')
  
  if [[ "$HTTP_CODE" == "ERROR" ]]; then
    log_error "Network error sending response - broker may be unreachable"
    return 1
  elif [[ "$HTTP_CODE" -eq 200 || "$HTTP_CODE" -eq 201 ]]; then
    log_success "Response sent successfully (message persists for audit)"
    return 0
  else
    log_error "Failed to send response (HTTP $HTTP_CODE): ${BODY:0:200}"
    return 1
  fi
}

# Main polling loop with exponential backoff and comprehensive error handling
# This function never exits unless the entire script is terminated by a signal
poll_messages() {
  local retry_delay=1
  local max_retry_delay=60
  local next_since=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
  local consecutive_errors=0
  local max_consecutive_errors=10
  
  log_info "Starting infinite polling loop (Ctrl+C or SIGTERM to stop)"
  
  while true; do
    # Poll for messages (with since parameter to avoid duplicates)
    POLL_URL="$BROKER_URL/v1/messages?agent_id=$AGENT_ID&timeout=$POLL_TIMEOUT"
    if [[ -n "$next_since" ]]; then
      POLL_URL="$POLL_URL&since=$next_since"
    fi
    
    log_info "Polling for messages (timeout: ${POLL_TIMEOUT}s)..."
    
    # Call broker with error handling - capture both success and failure
    POLL_RESPONSE=$(curl -s -w "\n%{http_code}" "$POLL_URL" 2>&1 || echo -e "\nERROR")
    HTTP_CODE=$(echo "$POLL_RESPONSE" | tail -n1)
    BODY=$(echo "$POLL_RESPONSE" | sed '$d')
    
    # Handle network/connection errors
    if [[ "$HTTP_CODE" == "ERROR" || ! "$HTTP_CODE" =~ ^[0-9]+$ ]]; then
      consecutive_errors=$((consecutive_errors + 1))
      log_error "Failed to connect to broker (attempt $consecutive_errors/$max_consecutive_errors)"
      
      # If too many consecutive errors, increase backoff significantly
      if [[ $consecutive_errors -ge $max_consecutive_errors ]]; then
        log_warn "Too many consecutive errors - using max backoff delay"
        retry_delay=$max_retry_delay
      fi
      
      log_warn "Retrying in ${retry_delay}s..."
      sleep "$retry_delay"
      
      # Exponential backoff
      retry_delay=$((retry_delay * 2))
      [[ $retry_delay -gt $max_retry_delay ]] && retry_delay=$max_retry_delay
      continue
    fi
    
    # Handle successful responses
    if [[ "$HTTP_CODE" -eq 200 ]]; then
      retry_delay=1  # Reset backoff on success
      consecutive_errors=0  # Reset error counter
      
      # Parse message count with error handling
      MESSAGE_COUNT=$(echo "$BODY" | jq '.messages | length' 2>/dev/null || echo "0")
      
      if [[ ! "$MESSAGE_COUNT" =~ ^[0-9]+$ ]]; then
        log_error "Failed to parse broker response - skipping this poll"
        continue
      fi
      
      if [[ "$MESSAGE_COUNT" -eq 0 ]]; then
        log_info "No messages (timeout reached)"
      else
        log_success "Received $MESSAGE_COUNT message(s)"
        
        # Process each message individually - don't let one failure stop others
        local processed=0
        local failed=0
        
        while IFS= read -r msg; do
          if [[ -n "$msg" ]]; then
            if process_message "$msg"; then
              processed=$((processed + 1))
            else
              failed=$((failed + 1))
              log_warn "Message processing failed - continuing with next message"
            fi
          fi
        done < <(echo "$BODY" | jq -c '.messages[]?' 2>/dev/null || true)
        
        log_info "Processed: $processed succeeded, $failed failed"
        
        # Update next_since to avoid re-processing messages
        NEXT_SINCE=$(echo "$BODY" | jq -r '.next_since // empty' 2>/dev/null || echo "")
        if [[ -n "$NEXT_SINCE" ]]; then
          next_since="$NEXT_SINCE"
          log_info "Updated since marker: $next_since"
        fi
      fi
      
    # Handle "not modified" (no new messages since last poll)
    elif [[ "$HTTP_CODE" -eq 304 ]]; then
      retry_delay=1
      consecutive_errors=0
      log_info "No new messages"
      
    # Handle other HTTP errors (4xx, 5xx, etc.)
    else
      consecutive_errors=$((consecutive_errors + 1))
      log_error "Broker returned HTTP $HTTP_CODE (attempt $consecutive_errors/$max_consecutive_errors)"
      
      # Show response body for debugging (truncated)
      if [[ -n "$BODY" ]]; then
        log_error "Response: ${BODY:0:200}"
      fi
      
      log_warn "Retrying in ${retry_delay}s..."
      sleep "$retry_delay"
      
      # Exponential backoff
      retry_delay=$((retry_delay * 2))
      [[ $retry_delay -gt $max_retry_delay ]] && retry_delay=$max_retry_delay
    fi
    
    # Small delay between polls to prevent tight loops on rapid errors
    sleep 0.1
  done
}

# Signal handling for graceful shutdown
SHUTDOWN_REQUESTED=0

cleanup_and_exit() {
  local signal=$1
  log_warn "Received $signal signal - shutting down gracefully..."
  SHUTDOWN_REQUESTED=1
  
  # Give any in-flight operations a moment to complete
  sleep 1
  
  log_success "Poller stopped cleanly"
  exit 0
}

# Trap common termination signals
trap 'cleanup_and_exit SIGINT' SIGINT
trap 'cleanup_and_exit SIGTERM' SIGTERM
trap 'cleanup_and_exit SIGHUP' SIGHUP

# Start
log_success "========================================="
log_success "A2A Message Broker Poller Starting"
log_success "========================================="
log_info "Agent: $AGENT_ID (must be pre-registered with broker)"
log_info "Broker: $BROKER_URL"
log_info "OpenClaw: $OPENCLAW_URL"
log_info "Poll timeout: ${POLL_TIMEOUT}s"
log_info "Messages persist for audit - cleaned by broker TTL worker"
log_info ""
log_info "Resilience features enabled:"
log_info "  ✓ Automatic retry with exponential backoff"
log_info "  ✓ Individual message failures don't crash poller"
log_info "  ✓ Network errors handled gracefully"
log_info "  ✓ Graceful shutdown on SIGTERM/SIGINT/SIGHUP"
log_info ""
log_info "Press Ctrl+C to stop"
log_success "========================================="

# Start the polling loop - this never returns unless signaled
poll_messages

# Should never reach here unless something goes very wrong
log_error "Polling loop exited unexpectedly!"
exit 1
