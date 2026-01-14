import { existsSync, readdirSync, readFileSync } from "fs"
import { join, basename } from "path"
import { homedir } from "os"
import type { AgentConfig } from "@opencode-ai/sdk"
import type {
  AgentPromptMetadata,
  AgentCategory,
  AgentCost,
  DelegationTrigger,
} from "../../agents/types"
import { parseFrontmatter } from "../../shared/frontmatter"
import { isMarkdownFile } from "../../shared/file-utils"
import { log } from "../../shared/logger"

/**
 * Nested omo_agent metadata structure in frontmatter
 * Presence of this key enables loading + contains AgentPromptMetadata
 */
interface OmoAgentMetadata {
  category?: AgentCategory
  cost?: AgentCost
  promptAlias?: string
  keyTrigger?: string
  triggers?: DelegationTrigger[]
  useWhen?: string[]
  avoidWhen?: string[]
}

interface AgentFrontmatter {
  name?: string
  description?: string
  model?: string
  tools?: unknown  // Can be string, array, or object
  omo_agent?: OmoAgentMetadata
}

type AgentScope = "opencode" | "opencode-project"

export interface LoadedOpencodeAgent {
  name: string
  path: string
  config: AgentConfig
  metadata: AgentPromptMetadata
  scope: AgentScope
}

function parseToolsConfig(toolsValue?: unknown): Record<string, boolean> | undefined {
  if (!toolsValue) return undefined

  // Handle string format: "read,write,bash"
  if (typeof toolsValue === "string") {
    const tools = toolsValue
      .split(",")
      .map((t) => t.trim())
      .filter(Boolean)
    if (tools.length === 0) return undefined
    return Object.fromEntries(tools.map((t) => [t.toLowerCase(), true]))
  }

  // Handle array format: ["read", "write", "bash"]
  if (Array.isArray(toolsValue)) {
    const tools = toolsValue
      .filter((t): t is string => typeof t === "string")
      .map((t) => t.trim())
      .filter(Boolean)
    if (tools.length === 0) return undefined
    return Object.fromEntries(tools.map((t) => [t.toLowerCase(), true]))
  }

  // Handle object format: { read: true, write: true }
  if (typeof toolsValue === "object" && toolsValue !== null) {
    return toolsValue as Record<string, boolean>
  }

  return undefined
}

function loadAgentsFromDir(agentsDir: string, scope: AgentScope): LoadedOpencodeAgent[] {
  if (!existsSync(agentsDir)) return []

  const entries = readdirSync(agentsDir, { withFileTypes: true })
  const agents: LoadedOpencodeAgent[] = []

  for (const entry of entries) {
    if (!isMarkdownFile(entry)) continue

    const agentPath = join(agentsDir, entry.name)
    const agentName = basename(entry.name, ".md")

    try {
      const content = readFileSync(agentPath, "utf-8")
      const { data, body, hadFrontmatter, parseError } = parseFrontmatter<AgentFrontmatter>(content)

      if (!hadFrontmatter || parseError || !data.omo_agent) continue

      const name = data.name ?? agentName
      const omo = data.omo_agent

      const config: AgentConfig = {
        description: data.description ?? "",
        mode: "subagent",
        prompt: body.trim(),
        model: data.model,
        tools: parseToolsConfig(data.tools),
      }

      const metadata: AgentPromptMetadata = {
        category: omo.category ?? "utility",
        cost: omo.cost ?? "CHEAP",
        promptAlias: omo.promptAlias ?? name,
        keyTrigger: omo.keyTrigger,
        triggers: omo.triggers ?? [],
        useWhen: omo.useWhen ?? [],
        avoidWhen: omo.avoidWhen ?? [],
      }

      agents.push({ name, path: agentPath, config, metadata, scope })
    } catch (error) {
      const errorMessage = error instanceof Error ? error.message : String(error)
      log(`[opencode-agent-loader] Error loading ${agentName}: ${errorMessage}`)
      continue
    }
  }

  return agents
}

export function loadOpencodeGlobalAgents(): LoadedOpencodeAgent[] {
  const agentsDir = join(homedir(), ".config", "opencode", "agent")
  return loadAgentsFromDir(agentsDir, "opencode")
}

export function loadOpencodeProjectAgents(): LoadedOpencodeAgent[] {
  const agentsDir = join(process.cwd(), ".opencode", "agent")
  return loadAgentsFromDir(agentsDir, "opencode-project")
}

export function loadAllOpencodeAgents(): LoadedOpencodeAgent[] {
  return [...loadOpencodeGlobalAgents(), ...loadOpencodeProjectAgents()]
}
