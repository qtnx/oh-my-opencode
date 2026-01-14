# Custom OpenCode Agents Guide

This guide explains how to create custom agents that integrate with Oh-My-OpenCode's orchestration system, including `orchestrator-sisyphus`.

## Overview

Custom OpenCode agents are markdown files with YAML frontmatter containing the `omo_agent` key. When this key is present, the agent is loaded and made available to the orchestrator.

## File Locations

Agents can be placed in two locations:

| Location | Scope | Priority |
|----------|-------|----------|
| `~/.config/opencode/agent/*.md` | Global (all projects) | Lower |
| `.opencode/agent/*.md` | Project-specific | Higher (overrides global) |

## Agent File Format

```markdown
---
name: my-custom-agent        # Optional, defaults to filename
description: Agent description shown in orchestrator table
model: anthropic/claude-sonnet-4  # Optional model override
tools: "read,write,bash"     # Optional tool whitelist (string, array, or object)

omo_agent:                   # REQUIRED - presence enables loading
  category: specialist       # exploration | specialist | advisor | utility
  cost: CHEAP               # FREE | CHEAP | EXPENSIVE
  promptAlias: My Agent     # Display name in prompts
  keyTrigger: "When X"      # Key trigger shown in orchestrator Phase 0

  triggers:                 # Delegation triggers for orchestrator
    - domain: "Domain Name"
      trigger: "When to delegate to this agent"

  useWhen:                  # When orchestrator should use this agent
    - "Complex custom tasks"
    - "Specialized processing"

  avoidWhen:                # When NOT to use this agent
    - "Simple operations"
---

Your agent system prompt goes here.

This is the content that will be used as the agent's system prompt.
```

## Fields Reference

### Top-level Fields

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `name` | string | No | Agent name (defaults to filename without .md) |
| `description` | string | Yes | Short description shown in orchestrator table |
| `model` | string | No | Model override (e.g., `anthropic/claude-sonnet-4`) |
| `tools` | string/array/object | No | Tool whitelist for the agent |

### omo_agent Fields (AgentPromptMetadata)

| Field | Type | Required | Default | Description |
|-------|------|----------|---------|-------------|
| `category` | string | No | `utility` | Agent category: `exploration`, `specialist`, `advisor`, `utility` |
| `cost` | string | No | `CHEAP` | Cost tier: `FREE`, `CHEAP`, `EXPENSIVE` |
| `promptAlias` | string | No | agent name | Display name in orchestrator prompts |
| `keyTrigger` | string | No | - | Key trigger for Phase 0 decision making |
| `triggers` | array | No | `[]` | Array of `{domain, trigger}` for delegation table |
| `useWhen` | array | No | `[]` | List of scenarios when this agent should be used |
| `avoidWhen` | array | No | `[]` | List of scenarios when this agent should NOT be used |

### Tools Configuration

The `tools` field supports three formats:

```yaml
# String format (comma-separated)
tools: "read,write,bash"

# Array format
tools:
  - read
  - write
  - bash

# Object format (for explicit enable/disable)
tools:
  read: true
  write: true
  bash: true
  task: false
```

## Category Types

| Category | Description | Typical Use |
|----------|-------------|-------------|
| `exploration` | Codebase exploration, search | Finding code, patterns |
| `specialist` | Domain-specific expertise | Frontend, backend, testing |
| `advisor` | Consultation, review | Architecture, debugging |
| `utility` | General-purpose helper | Various tasks |

## Cost Tiers

| Cost | When to Use |
|------|-------------|
| `FREE` | No API cost (local tools only) |
| `CHEAP` | Low-cost operations (Sonnet, Haiku) |
| `EXPENSIVE` | High-cost operations (Opus, o1) |

## Example: Full Agent Configuration

```markdown
---
name: api-designer
description: API design expert for REST and GraphQL endpoints
model: anthropic/claude-sonnet-4
tools:
  - read
  - grep
  - glob

omo_agent:
  category: specialist
  cost: CHEAP
  promptAlias: API Designer
  keyTrigger: "API design or endpoint architecture needed"

  triggers:
    - domain: "API Design"
      trigger: "When designing REST or GraphQL endpoints"
    - domain: "Schema Design"
      trigger: "When defining request/response schemas"

  useWhen:
    - "New API endpoint design"
    - "API refactoring or versioning"
    - "Schema validation patterns"

  avoidWhen:
    - "Simple CRUD implementation"
    - "Frontend-only changes"
---

You are an API Design Expert specializing in RESTful and GraphQL APIs.

## Your Expertise
- RESTful API design principles
- GraphQL schema design
- OpenAPI/Swagger specifications
- Request/response validation
- API versioning strategies

## Guidelines
1. Follow REST conventions (proper HTTP methods, status codes)
2. Design for backwards compatibility
3. Use consistent naming conventions
4. Document all endpoints clearly
```

## How It Works

1. When OpenCode starts, the agent loader scans:
   - `~/.config/opencode/agent/*.md` (global)
   - `.opencode/agent/*.md` (project)

2. Only files with the `omo_agent` key in frontmatter are loaded

3. Loaded agents are passed to `orchestrator-sisyphus` and appear in:
   - Agent Selection table
   - Decision Matrix
   - Phase 0 Key Triggers

4. The orchestrator can then delegate tasks to your custom agent via:
   ```typescript
   sisyphus_task(agent="my-custom-agent", prompt="...")
   ```

## Debugging

If your agent isn't appearing:

1. Check logs: `tail -f /tmp/oh-my-opencode.log | grep opencode-agent`
2. Verify frontmatter has `omo_agent:` key (not just `omo_agent: true`)
3. Ensure YAML syntax is valid (proper indentation, colons)
4. Restart OpenCode after adding/modifying agents

## Best Practices

1. **Keep descriptions short** - First sentence is used in tables
2. **Be specific with triggers** - Help orchestrator make good decisions
3. **Set appropriate cost** - Affects orchestrator's budget decisions
4. **Use meaningful categories** - Helps with agent selection
5. **Test locally first** - Verify agent loads before relying on it
