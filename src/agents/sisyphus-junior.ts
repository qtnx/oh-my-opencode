import type { AgentConfig } from "@opencode-ai/sdk";
import { isGptModel } from "./types";
import type { CategoryConfig } from "../config/schema";
import {
  createAgentToolRestrictions,
  migrateAgentConfig,
} from "../shared/permission-compat";

const SISYPHUS_JUNIOR_PROMPT_BASE = `<Role>
Sisyphus-Junior - Focused executor from OhMyOpenCode.
Execute tasks directly. NEVER delegate or spawn other agents.
</Role>

<Critical_Constraints>
BLOCKED ACTIONS (will fail if attempted):
- task tool: BLOCKED
- sisyphus_task tool: BLOCKED`;

const SISYPHUS_JUNIOR_PROMPT_CALL_OMO_BLOCKED = `
- call_omo_agent tool: BLOCKED`;

const SISYPHUS_JUNIOR_PROMPT_TAIL = `

You work ALONE. No delegation. No background tasks. Execute directly.
</Critical_Constraints>`;

const SISYPHUS_JUNIOR_PROMPT_REST = `

<Todo_Discipline>
TODO OBSESSION (NON-NEGOTIABLE):
- 2+ steps → todowrite FIRST, atomic breakdown
- Mark in_progress before starting (ONE at a time)
- Mark completed IMMEDIATELY after each step
- NEVER batch completions

No todos on multi-step work = INCOMPLETE WORK.
</Todo_Discipline>

<Verification>
Task NOT complete without:
- lsp_diagnostics clean on changed files
- Build passes (if applicable)
- All todos marked completed
</Verification>

<Style>
- Start immediately. No acknowledgments.
- Match user's communication style.
- Dense > verbose.
</Style>`;

function buildSisyphusJuniorPrompt(
  allowCallOmoAgent: boolean,
  promptAppend?: string,
): string {
  const base = allowCallOmoAgent
    ? SISYPHUS_JUNIOR_PROMPT_BASE + SISYPHUS_JUNIOR_PROMPT_TAIL
    : SISYPHUS_JUNIOR_PROMPT_BASE +
      SISYPHUS_JUNIOR_PROMPT_CALL_OMO_BLOCKED +
      SISYPHUS_JUNIOR_PROMPT_TAIL;

  const fullPrompt = base + SISYPHUS_JUNIOR_PROMPT_REST;
  if (!promptAppend) return fullPrompt;
  return fullPrompt + "\n\n" + promptAppend;
}

// Core tools that Sisyphus-Junior must NEVER have access to
const BLOCKED_TOOLS = ["task", "sisyphus_task", "call_omo_agent"];

// Prompt append for GPT models to suggest using omo agents for faster exploration
const GPT_OWO_AGENT_HINT = `
<OmoAgentHint>
You have access to call_omo_agent tool. Use it to spawn specialized agents for faster work:
- explore: Blazing fast codebase exploration (contextual grep). Fire multiple in parallel for broad searches.
- librarian: Multi-repo analysis, official docs lookup, GitHub examples. Use for unfamiliar libraries.

Example:
call_omo_agent(subagent_type="explore", prompt="Find all auth implementations", run_in_background=true)
call_omo_agent(subagent_type="librarian", prompt="How does NextAuth handle JWT refresh?", run_in_background=true)

Fire them in background (run_in_background=true) and continue your work. Collect results with background_output when needed.
</OmoAgentHint>`;

export function createSisyphusJuniorAgent(
  categoryConfig: CategoryConfig,
  promptAppend?: string,
): AgentConfig {
  const model = categoryConfig.model;

  // For GPT models: allow call_omo_agent and append usage hint
  const isGpt = isGptModel(model);
  const blockedTools = isGpt
    ? BLOCKED_TOOLS.filter((t) => t !== "call_omo_agent")
    : [...BLOCKED_TOOLS];

  // Build prompt: GPT models get call_omo_agent unblocked + usage hint
  const effectivePromptAppend = isGpt
    ? promptAppend
      ? `${promptAppend}\n${GPT_OWO_AGENT_HINT}`
      : GPT_OWO_AGENT_HINT
    : promptAppend;
  const prompt = buildSisyphusJuniorPrompt(isGpt, effectivePromptAppend);

  const baseRestrictions = createAgentToolRestrictions(blockedTools);
  const mergedConfig = migrateAgentConfig({
    ...baseRestrictions,
    ...(categoryConfig.tools ? { tools: categoryConfig.tools } : {}),
  });

  const base: AgentConfig = {
    description:
      "Sisyphus-Junior - Focused task executor. Same discipline, no delegation.",
    mode: "subagent" as const,
    model,
    maxTokens: categoryConfig.maxTokens ?? 64000,
    prompt,
    color: "#20B2AA",
    ...mergedConfig,
  };

  if (categoryConfig.temperature !== undefined) {
    base.temperature = categoryConfig.temperature;
  }
  if (categoryConfig.top_p !== undefined) {
    base.top_p = categoryConfig.top_p;
  }

  if (categoryConfig.thinking) {
    return { ...base, thinking: categoryConfig.thinking } as AgentConfig;
  }

  if (categoryConfig.reasoningEffort) {
    return {
      ...base,
      reasoningEffort: categoryConfig.reasoningEffort,
      textVerbosity: categoryConfig.textVerbosity,
    } as AgentConfig;
  }

  if (isGptModel(model)) {
    return { ...base, reasoningEffort: "medium" } as AgentConfig;
  }

  return {
    ...base,
    thinking: { type: "enabled", budgetTokens: 32000 },
  } as AgentConfig;
}
