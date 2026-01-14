import { describe, expect, test, afterEach } from "bun:test"
import { mkdirSync, writeFileSync, rmSync, existsSync } from "node:fs"
import { join } from "node:path"
import { findNearestMessageWithFields } from "./injector"
import { tmpdir } from "node:os"

describe("findNearestMessageWithFields", () => {
  const tmpDir = join(tmpdir(), "injector-test-" + Date.now())

  afterEach(() => {
    if (existsSync(tmpDir)) {
      rmSync(tmpDir, { recursive: true, force: true })
    }
  })

  test("should merge model from older message when newer message lacks it", () => {
    // #given
    mkdirSync(tmpDir, { recursive: true })

    const msg1 = {
      agent: "Sisyphus",
      model: { providerID: "anthropic", modelID: "claude-opus" }
    }
    writeFileSync(join(tmpDir, "msg_1.json"), JSON.stringify(msg1))

    const msg2 = {
      agent: "Sisyphus"
    }
    writeFileSync(join(tmpDir, "msg_2.json"), JSON.stringify(msg2))

    // #when
    const result = findNearestMessageWithFields(tmpDir)

    // #then
    expect(result).not.toBeNull()
    expect(result?.agent).toBe("Sisyphus")
    expect(result?.model).toEqual(msg1.model)
  })

  test("should prioritize newer fields", () => {
    // #given
    mkdirSync(tmpDir, { recursive: true })

    const msg1 = {
      agent: "OldAgent",
      model: { providerID: "old", modelID: "old-model" }
    }
    writeFileSync(join(tmpDir, "msg_1.json"), JSON.stringify(msg1))

    const msg2 = {
      agent: "NewAgent"
    }
    writeFileSync(join(tmpDir, "msg_2.json"), JSON.stringify(msg2))

    // #when
    const result = findNearestMessageWithFields(tmpDir)

    // #then
    expect(result).not.toBeNull()
    expect(result?.agent).toBe("NewAgent")
    expect(result?.model).toEqual(msg1.model)
  })

  test("should preserve model when newer message has null model", () => {
    // #given
    mkdirSync(tmpDir, { recursive: true })

    const msg1 = {
      agent: "AgentA",
      model: { providerID: "anthropic", modelID: "claude-opus" }
    }
    writeFileSync(join(tmpDir, "msg_1.json"), JSON.stringify(msg1))

    const msg2 = {
      agent: "AgentA",
      model: null
    }
    writeFileSync(join(tmpDir, "msg_2.json"), JSON.stringify(msg2))

    // #when
    const result = findNearestMessageWithFields(tmpDir)

    // #then
    expect(result).not.toBeNull()
    expect(result?.agent).toBe("AgentA")
    expect(result?.model).toEqual(msg1.model)
  })

  test("should stop searching when all fields are found", () => {
    // #given
    mkdirSync(tmpDir, { recursive: true })

    const msg1 = {
      agent: "Agent1",
      model: { providerID: "p1", modelID: "m1" },
      tools: { tool1: "allow" }
    }
    writeFileSync(join(tmpDir, "msg_3.json"), JSON.stringify(msg1))
    
    const msg0 = {
      agent: "Agent0", 
      model: { providerID: "p0", modelID: "m0" }
    }
    writeFileSync(join(tmpDir, "msg_0.json"), JSON.stringify(msg0))

    // #when
    const result = findNearestMessageWithFields(tmpDir)

    // #then
    expect(result?.agent).toBe("Agent1")
    expect(result?.model).toEqual(msg1.model)
  })
})
