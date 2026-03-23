#!/bin/bash
set -euo pipefail

# A2A Broker Skill Setup Script
# Validates config, tests connectivity, and installs cron job

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/config.json"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $*"; }
log_success() { echo -e "${GREEN}[✓]${NC} $*"; }
log_error() { echo -e "${RED}[✗]${NC} $*"; }
log_warn() { echo -e "${YELLOW}[!]${NC} $*"; }

echo -e "${BLUE}═══════════════════════════════════════════════${NC}"
echo -e "${BLUE}  A2A Message Broker - OpenClaw Skill Setup${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════${NC}"
echo ""

# Step 1: Check dependencies
log_info "Checking dependencies..."
DEPS_OK=true

for cmd in curl jq openssl; do
  if command -v "$cmd" &> /dev/null; then
    log_success "$cmd installed"
  else
    log_error "$cmd not found"
    DEPS_OK=false
  fi
done

if [[ "$DEPS_OK" = false ]]; then
  log_error "Missing dependencies. Install with: brew install curl jq openssl"
  exit 1
fi

# Step 2: Load and validate config
log_info "Loading configuration..."

if [[ ! -f "$CONFIG_FILE" ]]; then
  log_error "Config file not found: $CONFIG_FILE"
  exit 1
fi

BROKER_URL=$(jq -r '.brokerUrl' "$CONFIG_FILE")
AGENT_ID=$(jq -r '.agentId' "$CONFIG_FILE")
OPENCLAW_URL=$(jq -r '.openclawApiUrl' "$CONFIG_FILE")
TOKEN_PATH=$(jq -r '.openclawTokenPath' "$CONFIG_FILE")
TOKEN_PATH="${TOKEN_PATH/#\~/$HOME}"

log_success "Configuration loaded"
echo "  Broker URL:    $BROKER_URL"
echo "  Agent ID:      $AGENT_ID"
echo "  OpenClaw URL:  $OPENCLAW_URL"
echo ""

# Step 3: Test broker connectivity
log_info "Testing broker connectivity..."
HEALTH_RESPONSE=$(curl -s -w "\n%{http_code}" "$BROKER_URL/health" 2>&1)
HTTP_CODE=$(echo "$HEALTH_RESPONSE" | tail -n1)

if [[ "$HTTP_CODE" =~ ^[0-9]+$ && "$HTTP_CODE" -eq 200 ]]; then
  log_success "Broker is reachable"
else
  log_error "Cannot reach broker at $BROKER_URL/health (HTTP $HTTP_CODE)"
  exit 1
fi

# Step 4: Test OpenClaw API
log_info "Testing OpenClaw API..."

if [[ ! -f "$TOKEN_PATH" ]]; then
  log_warn "Token file not found: $TOKEN_PATH"
  log_info "Creating token file from OpenClaw config..."
  
  OPENCLAW_CONFIG="$HOME/.openclaw/openclaw.json"
  if [[ -f "$OPENCLAW_CONFIG" ]]; then
    jq -r '.gateway.auth.token' "$OPENCLAW_CONFIG" > "$TOKEN_PATH"
    chmod 600 "$TOKEN_PATH"
    log_success "Token file created"
  else
    log_error "Cannot find OpenClaw config at $OPENCLAW_CONFIG"
    exit 1
  fi
fi

OPENCLAW_RESPONSE=$(curl -s -w "\n%{http_code}" "$OPENCLAW_URL/health" \
  -H "Authorization: Bearer $(cat "$TOKEN_PATH")" 2>&1)
HTTP_CODE=$(echo "$OPENCLAW_RESPONSE" | tail -n1)

if [[ "$HTTP_CODE" =~ ^[0-9]+$ && "$HTTP_CODE" -eq 200 ]]; then
  log_success "OpenClaw API is reachable"
else
  log_error "Cannot reach OpenClaw at $OPENCLAW_URL/health (HTTP $HTTP_CODE)"
  log_warn "Ensure the chat completions endpoint is enabled in OpenClaw config"
  exit 1
fi

# Step 5: Verify agent is registered
log_info "Verifying agent registration..."

AGENT_RESPONSE=$(curl -s -w "\n%{http_code}" "$BROKER_URL/v1/agents/$AGENT_ID" 2>&1)
HTTP_CODE=$(echo "$AGENT_RESPONSE" | tail -n1)
BODY=$(echo "$AGENT_RESPONSE" | sed '$d')

if [[ "$HTTP_CODE" =~ ^[0-9]+$ && "$HTTP_CODE" -eq 200 ]]; then
  log_success "Agent is registered with broker"
  echo "  Agent Name: $(echo "$BODY" | jq -r '.agent_card.name // "N/A"')"
  echo "  Version:    $(echo "$BODY" | jq -r '.agent_card.version // "N/A"')"
else
  log_error "Agent verification failed (HTTP $HTTP_CODE)"
  echo ""
  echo "That agent_id either doesn't exist or isn't registered with the broker."
  echo ""
  echo "  Agent ID: $AGENT_ID"
  echo "  Broker:   $BROKER_URL"
  echo ""
  echo "Please check your agent_id in config.json or register it with the broker first."
  exit 1
fi

# Step 6: Make scripts executable
echo ""
log_info "Making scripts executable..."
chmod +x "$SCRIPT_DIR/poll-messages.sh"
chmod +x "$SCRIPT_DIR/send-rpc.sh"
chmod +x "$SCRIPT_DIR/find-agent.sh"
log_success "Scripts marked executable"

echo ""
echo -e "${GREEN}═══════════════════════════════════════════════${NC}"
echo -e "${GREEN}  Setup Complete!${NC}"
echo -e "${GREEN}═══════════════════════════════════════════════${NC}"
echo ""
echo "Your agent is configured and ready:"
echo "  Agent ID: $AGENT_ID"
echo "  Broker:   $BROKER_URL"
echo ""
echo "Next steps:"
echo ""
echo "1. Start the message poller:"
echo "   ./poll-messages.sh"
echo ""
echo "2. Send a test message (from another terminal):"
echo "   ./send-rpc.sh '$AGENT_ID' 'Hello! This is a test message.'"
echo ""
echo "3. Discover other agents:"
echo "   ./find-agent.sh 'knowledge base'"
echo ""
log_info "The poller will run continuously and process messages in real-time"
log_info "Press Ctrl+C to stop the poller"
echo ""
