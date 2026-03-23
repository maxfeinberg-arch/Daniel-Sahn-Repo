#!/bin/bash
set -euo pipefail

# A2A Agent Discovery Script
# Query the broker to find agents by capability, skill, or tool

# Load config
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/config.json"

if [[ ! -f "$CONFIG_FILE" ]]; then
  echo "Error: Config file not found: $CONFIG_FILE"
  exit 1
fi

BROKER_URL=$(jq -r '.brokerUrl' "$CONFIG_FILE")

# Parse arguments
QUERY=""
SKILL=""
TOOL=""
TAG=""
SQUAD=""
FUZZY="true"

usage() {
  cat <<EOF
Usage: $0 [OPTIONS] [QUERY]

Find agents by capability, skill, tool, or natural language query.

OPTIONS:
  --skill SKILL      Search by skill name (fuzzy matching by default)
  --tool TOOL        Search by tool name (fuzzy matching by default) 
  --tag TAG          Search by skill tag
  --squad SQUAD      Filter by squad
  --exact            Disable fuzzy matching (exact partial match)
  -h, --help         Show this help

EXAMPLES:
  # Natural language search (searches skills, tools, tags)
  $0 "search knowledge base"
  $0 "payment processing"
  
  # Specific skill search
  $0 --skill "document search"
  
  # Tool-based search
  $0 --tool retrieve
  
  # Tag-based search
  $0 --tag rag
  
  # Combined filters
  $0 --skill query --squad ai.platform.squad
  
  # Exact matching (no typo tolerance)
  $0 --exact --skill payment
EOF
  exit 0
}

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    -h|--help)
      usage
      ;;
    --skill)
      SKILL="$2"
      shift 2
      ;;
    --tool)
      TOOL="$2"
      shift 2
      ;;
    --tag)
      TAG="$2"
      shift 2
      ;;
    --squad)
      SQUAD="$2"
      shift 2
      ;;
    --exact)
      FUZZY="false"
      shift
      ;;
    *)
      QUERY="$1"
      shift
      ;;
  esac
done

# Build query URL
build_query_url() {
  local url="$BROKER_URL/v1/agents?"
  local params=()
  
  # Natural language query - search across skills, tools, and tags
  if [[ -n "$QUERY" ]]; then
    # Try skill first
    params+=("skill=$(echo "$QUERY" | jq -sRr @uri)")
  fi
  
  # Specific filters
  [[ -n "$SKILL" ]] && params+=("skill=$(echo "$SKILL" | jq -sRr @uri)")
  [[ -n "$TOOL" ]] && params+=("tool=$(echo "$TOOL" | jq -sRr @uri)")
  [[ -n "$TAG" ]] && params+=("tags=$(echo "$TAG" | jq -sRr @uri)")
  [[ -n "$SQUAD" ]] && params+=("squad=$(echo "$SQUAD" | jq -sRr @uri)")
  [[ "$FUZZY" == "false" ]] && params+=("fuzzy=false")
  
  # Join params
  local IFS='&'
  echo "${url}${params[*]}"
}

QUERY_URL=$(build_query_url)

echo "🔍 Searching for agents..."
echo ""

# Query the broker
RESPONSE=$(curl -s "$QUERY_URL")

# Check if we got results
AGENT_COUNT=$(echo "$RESPONSE" | jq '.data | length')

if [[ "$AGENT_COUNT" -eq 0 ]]; then
  echo "❌ No agents found matching your query."
  echo ""
  echo "Try:"
  echo "  - Using broader search terms"
  echo "  - Searching by tag instead of skill name"
  echo "  - Running without --exact for fuzzy matching"
  exit 1
fi

echo "✓ Found $AGENT_COUNT agent(s):"
echo ""

# Format results
echo "$RESPONSE" | jq -r '.data[] | 
  "┌─ \(.agent_card.name) [\(.agent_type)]",
  "│  Agent ID: \(.agent_id)",
  "│  Description: \(.agent_card.description // "N/A")",
  (if .agent_card.skills then
    "│  Skills: " + ([.agent_card.skills[].name] | join(", "))
  else
    "│  Skills: N/A"
  end),
  (if .agent_card.skills then
    "│  Tags: " + ([.agent_card.skills[].tags[]?] | unique | join(", "))
  else
    "│  Tags: N/A"
  end),
  (if .tools and (.tools | length > 0) then
    "│  Tools: " + ([.tools[].name] | join(", "))
  else
    "│  Tools: N/A"
  end),
  "│  Available: \(.available)",
  "│  Squad: \(.squad)",
  "│",
  "│  💬 To message: Message \(.agent_id) \"your message\"",
  "└─"
'

echo ""
echo "Tip: Message an agent by saying: Message <agent_id> \"your message\""
