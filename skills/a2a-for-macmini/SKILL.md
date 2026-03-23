---
name: a2a-for-macmini
description: Bridge OpenClaw with the A2A message broker for agent-to-agent communication.
author: ai-platform-squad
version: 0.1.0
---

# A2A Message Broker Skill

Bridge OpenClaw with the A2A message broker for agent-to-agent communication.

## Overview

This skill enables OpenClaw to receive and respond to messages from other agents via the A2A message broker. It runs a persistent background process that polls for incoming messages, processes them through OpenClaw's local API, and sends responses back.

**Key Features:**
- Persistent background polling managed by OpenClaw
- Long-polling (60s timeout) for efficient message retrieval
- Thread-based session isolation (separate context per conversation)
- In-memory `since` tracking to prevent duplicate processing
- JSON-RPC 2.0 request/response handling
- Automatic TTL-based message cleanup (no manual deletion)

## Architecture

This skill operates in **dual mode**:

### 🔄 Dual Mode Operation

**Sending Mode (Client)** - Immediate responses via RPC:
```
You → send-rpc.sh → POST /a2a/{agent_id}/rpc
                       ↓ (blocks, waits)
                   Agent processes
                       ↓
                   Response (immediate)
```

**Receiving Mode (Server)** - Background polling:
```
A2A Broker
    ↓ 
poll-messages.sh (background process)
    ↓
Long-poll for messages (60s timeout, continuous loop)
    ↓
Extract thread_id + message
    ↓
Forward to http://localhost:18789/v1/chat/completions
    with x-openclaw-session-key: agent:main:a2a:thread:<thread_id>
    ↓
OpenClaw processes with context
    ↓
Send JSON-RPC response back through broker
    ↓
Loop back to poll again
```

**Both modes work together:**
- **Send messages**: Use `./send-rpc.sh` for immediate, blocking RPC calls
- **Receive messages**: Background `./poll-messages.sh` handles incoming messages

## Health Checks

The A2A broker monitors agent health using different mechanisms based on agent type:

### Service Agents (Backend Services)

Service agents are monitored via Consul health checks. The broker queries Consul every 60 seconds to check service health status.

### Personal Agents (OpenClaw Instances)

Personal agents are monitored via **ping/pong messaging**:

1. Every 30 seconds, the broker sends a ping message:
   ```json
   {
     "jsonrpc": "2.0",
     "method": "ping",
     "params": {},
     "id": "ping-1708678800123"
   }
   ```

2. The OpenClaw skill **automatically detects** ping messages and responds with pong:
   ```json
   {
     "jsonrpc": "2.0",
     "result": "pong",
     "id": "ping-1708678800123"
   }
   ```

3. If no pong response is received within 10 seconds, the agent is marked as unavailable.

**Important:** 
- Ping messages are **NOT forwarded** to OpenClaw chat completions
- Ping messages are **NOT shown** to the user
- Pong responses are **automatic** - no user action required
- This ensures the broker can monitor your agent's health without interrupting conversations

**Health Status:** You can check if your agent is marked as available by querying:

```bash
curl -s http://a2a-discovery.query.prod.telnyx.io:4000/v1/agents/your:agent:id | jq '.available'
```

## Session Mapping (A2A Protocol Compliant)

Messages are routed to isolated OpenClaw sessions based on A2A `contextId`:

| contextId present? | Session Key | Behavior |
|-------------------|-------------|----------|
| Yes | `agent:main:a2a:context:<contextId>` | Reuses existing conversation context |
| No | `agent:main:a2a:context:<generated>` | Agent generates new contextId |

**A2A Protocol Compliance:**
- **Server-generated contextId**: When a message arrives without `contextId`, the agent generates one and includes it in the response
- **Client-provided contextId**: When a message includes `contextId`, the agent reuses it to maintain conversation continuity
- **Multi-turn conversations**: All messages with the same `contextId` share the same OpenClaw session

**Example:**
- Message 1 without `contextId` → Agent generates `ctx-1234`, session: `agent:main:a2a:context:ctx-1234`
- Message 2 with `contextId: "ctx-1234"` → Same session (context maintained)
- Message 3 with `contextId: "ctx-5678"` → Different session (isolated context)

## Installation

### 1. Prerequisites

```bash
# Ensure required commands are available
which curl jq
# Should return paths to both commands

# Verify OpenClaw gateway is running
curl -s http://localhost:18789/health
```

### 2. Configuration

Before starting, you need a registered A2A agent ID. If you don't have one, register your agent through the A2A broker's registration process first.

**What is your registered A2A agent_id?**

When the user provides their agent_id:

1. Verify it exists by making a GET request to `$brokerUrl/v1/agents/$agent_id`
2. If the request returns 200 OK, the agent is registered - proceed
3. If the request returns 404 or other error, tell the user:
   > "That agent_id either doesn't exist or isn't registered with the broker. Please check your agent_id or register it first."

Once verified, update `config.json`:

```json
{
  "brokerUrl": "http://a2a-discovery.query.prod.telnyx.io:4000",
  "agentId": "verified:agent:id",
  "pollTimeout": 60,
  "openclawApiUrl": "http://localhost:18789",
  "openclawTokenPath": "~/.openclaw/gateway-token.txt"
}
```

**Required fields:**
- `brokerUrl` - A2A broker base URL
- `agentId` - Your **already registered** agent ID (format: `{squad}:{service}:{name}`)
- `openclawApiUrl` - Local OpenClaw gateway URL (default: http://localhost:18789)
- `openclawTokenPath` - Path to OpenClaw auth token (default: ~/.openclaw/gateway-token.txt)
- `pollTimeout` - Long-poll timeout in seconds (default: 60)

### 3. Enable OpenClaw Chat Completions Endpoint

Add to `~/.openclaw/openclaw.json`:

```json
{
  "gateway": {
    "http": {
      "endpoints": {
        "chatCompletions": {
          "enabled": true
        }
      }
    }
  }
}
```

Then restart OpenClaw gateway:

```bash
openclaw gateway restart
```

### 4. Run Setup Script

```bash
./setup.sh
```

The setup script will:
- Validate configuration and dependencies
- Test broker and OpenClaw connectivity
- Verify agent is registered
- Make scripts executable

## Usage

### Start A2A messaging

Tell OpenClaw to start the background poller:

> Start A2A messaging

This will spawn `poll-messages.sh` as a persistent background process. OpenClaw manages its lifecycle.

**What it does:**
- Starts continuous long-polling loop
- Receives messages from broker
- Routes to appropriate OpenClaw sessions
- Sends responses back
- Runs until stopped

### Find agents by capability

Discover agents using natural language queries. The user can just ask:

> Find me an agent that can answer questions about billing

> What agents can help with document search?

> Is there an agent for payment processing?

Behind the scenes, use `./find-agent.sh` to search:

```bash
./find-agent.sh "billing questions"
```

### What agents are available to message?

List all registered agents in the broker:

> What agents are available to message?

This will query the broker's `/v1/agents` endpoint and show you all available agent_ids you can message.

### Send a message to another agent

The user can ask to message another agent in natural language:

> Message ai.platform.squad:a2a:test "Hi, what can you help me with?"

> Send a message to the billing agent and ask about my account balance

Behind the scenes, use `./send-rpc.sh` to send the message:

```bash
./send-rpc.sh <agent_id> "your message here"
```

**What happens:**
1. Script checks `contexts.json` for stored `contextId` for this agent
2. Message sent via `POST /a2a/{agent_id}/rpc` with A2A-compliant Message structure
3. **Blocks and waits** for response (up to 30s)
4. Response returned immediately
5. `contextId` from response saved to `contexts.json` for next message

**Automatic Context Tracking:**
- **First message**: Script sends without `contextId`, agent generates one
- **Follow-up messages**: Script automatically includes stored `contextId`
- **Per-agent isolation**: Each agent has its own conversation context
- **Context reset**: If server times out context, it generates a new one (handled transparently)

**Context Management:**
- Contexts stored in: `contexts.json` (format: `{"agent_id": "contextId"}`)
- To reset context: Delete the agent's entry from `contexts.json`
- To start fresh conversation: `rm contexts.json` (resets all)

**Response time:** 
- Service agents: <1 second
- Personal agents: 1-10 seconds (depends on their poll interval)

### Stop A2A messaging

To stop the background poller:

> Stop A2A messaging

This will terminate the running `poll-messages.sh` process.

### Is A2A messaging running?

Check the status:

> Is A2A messaging running?

Shows whether the poller is active, its process details, and recent log output so you can see activity.

## Sending Messages (Client Mode)

To send a message to another agent and get an **immediate response**, use the RPC endpoint:

```bash
./send-rpc.sh <agent_id> "your message here"
```

**Examples:**
```bash
# Message a personal agent
./send-rpc.sh ai.platform.squad:a2a:alice "What's the weather?"

# Message a service agent
./send-rpc.sh billing-agent:rpc "Get account balance for 12345"
```

**How it works:**
1. Sends JSON-RPC request to `POST /a2a/{agent_id}/rpc`
2. **Blocks** until response arrives (up to 30s timeout)
3. Prints response to stdout
4. Returns exit code 0 on success, 1 on failure

**Response time:**
- **Service agents**: <1 second (direct HTTP proxy)
- **Personal agents**: 1-10 seconds (depends on their poll interval)

**Error handling:**
- 404: Agent not found or not registered
- 504: Request timed out (agent didn't respond within 30s)
- Network errors: Broker may be unreachable

## Receiving Messages (Server Mode)

The background poller continues to run and handle incoming messages:

```bash
./poll-messages.sh
```

This runs continuously and:
1. Polls `GET /messages` for incoming messages
2. Processes messages (including auto-pong for pings)
3. Sends responses via `POST /messages`
4. Includes correlation fields (`request_id`, `message_type`) for RPC requests

### Listing Available Agents

To see all registered agents:

```bash
curl -s http://a2a-discovery.query.prod.telnyx.io:4000/v1/agents | jq
```

Response format:

```json
{
  "agents": [
    {
      "agent_id": "ai.platform.squad:a2a:mactest",
      "agent_card": {
        "name": "OpenClaw Gateway",
        "version": "1.0.0",
        "description": "OpenClaw AI agent gateway"
      },
      "registered_at": "2026-02-23T08:00:00Z"
    },
    {
      "agent_id": "ai.platform.squad:a2a:test",
      "agent_card": {
        "name": "Test Agent",
        "version": "1.0.0"
      },
      "registered_at": "2026-02-23T09:00:00Z"
    }
  ]
}
```

### Getting Agent Card

To fetch a specific agent's card:

```bash
curl -s http://a2a-discovery.query.prod.telnyx.io:4000/a2a/{agent_id} | jq
```

**Example:**
```bash
curl -s http://a2a-discovery.query.prod.telnyx.io:4000/a2a/ai.platform.squad:a2a:test | jq
```

Response format:

```json
{
  "agent_id": "ai.platform.squad:a2a:test",
  "agent_card": {
    "name": "Test Agent",
    "version": "1.0.0",
    "description": "A test agent for A2A protocol"
  },
  "available": true,
  "last_seen": "2026-02-26T06:45:00Z"
}
```

### Sending Messages via RPC (Recommended)

The **recommended way** to send messages is using the RPC endpoint for immediate responses:

```bash
./send-rpc.sh ai.platform.squad:a2a:test "Hello, how are you?"
```

This sends a JSON-RPC request to `POST /a2a/{agent_id}/rpc` and **blocks** until the agent responds (up to 30s timeout).

### Alternative: Sending via Message Queue (Legacy)

You can also send messages through the traditional message queue (requires polling for responses):

```bash
curl -X POST http://a2a-discovery.query.prod.telnyx.io:4000/v1/messages \
  -H 'Content-Type: application/json' \
  -d '{
    "to": "ai.platform.squad:a2a:test",
    "from": "ai.platform.squad:a2a:mactest",
    "message": {
      "jsonrpc": "2.0",
      "method": "chat",
      "params": {
        "message": "Hello, how are you?",
        "thread_id": "conversation-456"
      },
      "id": "msg-123"
    }
  }'
```

Then poll for the response:

```bash
curl -s "http://a2a-discovery.query.prod.telnyx.io:4000/v1/messages?agent_id=ai.platform.squad:a2a:mactest&timeout=30" | jq
```

**Note:** The RPC method (`./send-rpc.sh`) is preferred for most use cases as it provides immediate responses without polling.

### Receiving Messages (Incoming to OpenClaw)

From another agent, send a JSON-RPC message through the broker:

```bash
curl -X POST http://a2a-discovery.query.prod.telnyx.io:4000/v1/messages \
  -H 'Content-Type: application/json' \
  -d '{
    "to": "openclaw:gateway:main",
    "from": "your-agent-id",
    "message": {
      "jsonrpc": "2.0",
      "method": "chat",
      "params": {
        "message": "Hello, OpenClaw!",
        "thread_id": "conversation-123"
      },
      "id": "msg-1"
    }
  }'
```

### Receiving Responses

Poll for responses (from your agent):

```bash
curl -s "http://a2a-discovery.query.prod.telnyx.io:4000/v1/messages?agent_id=your-agent-id&timeout=30" | jq
```

Response format:

```json
{
  "messages": [
    {
      "message_id": "abc-123",
      "from": "openclaw:gateway:main",
      "to": "your-agent-id",
      "message": {
        "jsonrpc": "2.0",
        "result": "Hello! How can I help you?",
        "id": "msg-1"
      },
      "queued_at": "2026-02-19T08:00:00Z"
    }
  ],
  "next_since": "2026-02-19T08:00:00Z",
  "has_more": false
}
```

## Configuration Options

### Broker URL
```json
"brokerUrl": "http://a2a-discovery.query.prod.telnyx.io:4000"
```
- Base URL of the A2A message broker
- Must be reachable from OpenClaw host

### Agent ID
```json
"agentId": "openclaw:gateway:main"
```
- Format: `{squad}:{service}:{agent_name}`
- Must be unique in the broker registry
- Used for message routing

### Poll Timeout
```json
"pollTimeout": 60
```
- Long-poll timeout in seconds (default: 60)
- Broker holds request open for this duration waiting for messages
- Recommended: 30-120 seconds for efficiency

### OpenClaw API URL
```json
"openclawApiUrl": "http://localhost:18789"
```
- Local OpenClaw gateway endpoint
- Default port: 18789
- Must have `/v1/chat/completions` enabled

### Token Path
```json
"openclawTokenPath": "~/.openclaw/gateway-token.txt"
```
- Path to OpenClaw gateway auth token
- `~` expands to home directory
- Token is read from config: `jq -r '.gateway.auth.token' ~/.openclaw/openclaw.json`

## Files

### send-rpc.sh
Sends messages to other agents via A2A RPC endpoint with automatic context tracking.

**Features:**
- Automatic `contextId` management per agent
- Blocks until response received
- Stores and reuses context for conversation continuity
- A2A Protocol v1.0 RC compliant

### poll-messages.sh
Continuous long-running poller designed for background execution.

**Features:**
- Infinite loop with graceful shutdown on SIGTERM/SIGINT
- 60-second long-poll per iteration
- Automatic cleanup on exit
- Colored logging output
- A2A Protocol v1.0 RC compliant

**Signals:**
- `SIGTERM/SIGINT` - Graceful shutdown (waits for current poll to complete)
- `SIGKILL` - Immediate termination (not recommended)

### config.json
Configuration file (see Configuration Options above).

### contexts.json (auto-generated)
Tracks conversation `contextId` per agent for automatic context continuity.

```json
{
  "ai.platform.squad:a2a:test": "ctx-1709123456789-a1b2c3d4e5f6",
  "openclaw:gateway:main": "ctx-1709123457890-b2c3d4e5f6a7"
}
```

**Format:** `{"agent_id": "contextId"}`

**Management:**
- **Auto-created** by `send-rpc.sh` on first message
- **Auto-updated** when agent returns new contextId
- **Reset specific agent:** Delete that agent's entry
- **Reset all:** `rm contexts.json`

**Do not edit manually** - managed by `send-rpc.sh`.

## Monitoring

### Check Process Status

Use OpenClaw's process tool to monitor the background poller:

> Is A2A messaging running?

Or check manually:

```bash
ps aux | grep poll-messages.sh | grep -v grep
```

### View Logs

The background process logs to stdout/stderr. You can view logs via the process tool or check session history.

### Verify Agent Registration

```bash
curl -s http://a2a-discovery.query.prod.telnyx.io:4000/v1/agents/openclaw:gateway:main | jq
```

## Troubleshooting

### "Failed to send response (HTTP 400)"

The message payload must be valid JSON-RPC. Ensure:
- Responses have `jsonrpc`, `result` or `error`, and `id` fields
- Requests have `jsonrpc`, `method`, `params`, and `id` fields

### "Token file not found"

Create the token file:

```bash
jq -r '.gateway.auth.token' ~/.openclaw/openclaw.json > ~/.openclaw/gateway-token.txt
chmod 600 ~/.openclaw/gateway-token.txt
```

### Context not maintained across messages

Ensure:
1. Messages include the same `thread_id`
2. OpenClaw gateway has chat completions endpoint enabled
3. The header is `x-openclaw-session-key` (not `x-openclaw-session-id`)

Check session files:

```bash
ls -lt ~/.openclaw/agents/main/sessions/*.jsonl | head -5
```

### Duplicate messages

The `since` parameter is tracked in memory by the poller process. If you're seeing duplicate messages, restart the poller — it will begin receiving only new messages from the broker.

### Poller not receiving messages

1. Check if poller is running:
   > Is A2A messaging running?

2. Verify broker connectivity:
   ```bash
   curl -s http://a2a-discovery.query.prod.telnyx.io:4000/health
   ```

3. Check agent registration:
   ```bash
   curl -s http://a2a-discovery.query.prod.telnyx.io:4000/v1/agents/your:agent:id | jq
   ```

### Poller keeps restarting

If the background process exits repeatedly, check:

1. Configuration file validity:
   ```bash
   jq . config.json
   ```

2. Token file exists and is readable:
   ```bash
   cat ~/.openclaw/gateway-token.txt
   ```

3. OpenClaw gateway is running:
   ```bash
   curl -s http://localhost:18789/health
   ```

## Message Flow (A2A Protocol Compliant)

**Incoming Request:**

1. Agent sends A2A-compliant message to broker:
   ```json
   POST /v1/messages
   {
     "to": "openclaw:gateway:main",
     "from": "other-agent",
     "message": {
       "jsonrpc": "2.0",
       "method": "message/send",
       "params": {
         "message": {
           "kind": "message",
           "messageId": "msg-abc-123",
           "role": "user",
           "contextId": "ctx-conv-123",
           "parts": [
             {"kind": "text", "text": "Hello"}
           ]
         }
       },
       "id": "rpc-1"
     }
   }
   ```

2. Background `poll-messages.sh` polls broker:
   ```bash
   GET /v1/messages?agent_id=openclaw:gateway:main&timeout=60&since=...
   ```

3. Broker returns queued message

4. Script extracts `contextId` and message text, then forwards to OpenClaw:
   ```bash
   POST http://localhost:18789/v1/chat/completions
   x-openclaw-session-key: agent:main:a2a:context:ctx-conv-123
   {
     "model": "openclaw",
     "messages": [{"role": "user", "content": "Hello"}]
   }
   ```

5. OpenClaw processes in isolated session (maintains context via contextId)

6. Script sends A2A-compliant JSON-RPC response back:
   ```json
   POST /v1/messages
   {
     "to": "other-agent",
     "from": "openclaw:gateway:main",
     "message": {
       "jsonrpc": "2.0",
       "result": {
         "kind": "message",
         "messageId": "msg-def-456",
         "role": "agent",
         "contextId": "ctx-conv-123",
         "parts": [
           {"kind": "text", "text": "Hi! How can I help?"}
         ],
         "metadata": {}
       },
       "id": "rpc-1"
     },
     "message_type": "response",
     "request_id": "req-xyz"
   }
   ```

7. Script loops back to step 2 and polls again

**Key A2A Compliance Points:**
- Messages use proper A2A Message structure with `kind`, `messageId`, `role`, `parts`
- `contextId` is at Message level (not in params)
- Server generates `contextId` if not provided by client
- All subsequent messages in conversation reuse same `contextId`
- OpenClaw sessions mapped to `contextId` for conversation continuity

## Advanced

### Custom Session Routing

Modify `poll-messages.sh` to customize session mapping logic:

```bash
# Default behavior (in the script)
SESSION="agent:main:a2a:thread:$THREAD_ID"

# Route all A2A messages to a dedicated agent
SESSION="agent:a2a-handler:main"

# Use different session keys per sender
SESSION="agent:main:a2a:from:$(echo $FROM | sed 's/:/-/g')"
```

### Multiple Pollers

Run separate pollers for different agent IDs:

1. Copy the skill directory
2. Update `config.json` with different `agentId`
3. Start each poller independently

Each poller runs as a separate background process.

### Performance Tuning

**For high message volume:**
- Decrease `pollTimeout` (e.g., 30s) for more frequent polls
- Monitor process resource usage
- Consider multiple pollers with load balancing

**For low message volume:**
- Increase `pollTimeout` (e.g., 120s) to reduce API calls
- Lower resource overhead

## References

- A2A Message Broker API: See broker documentation
- OpenClaw Gateway API: `/opt/homebrew/lib/node_modules/openclaw/docs/gateway/openai-http-api.md`
- JSON-RPC 2.0 Spec: https://www.jsonrpc.org/specification
