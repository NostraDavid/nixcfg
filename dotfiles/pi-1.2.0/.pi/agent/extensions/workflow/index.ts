import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";
import { type Static, Type } from "typebox";
import { Value } from "typebox/value";

const Step = Type.Object({
  step: Type.String({ minLength: 1 }),
  status: Type.Union([
    Type.Literal("pending"),
    Type.Literal("in_progress"),
    Type.Literal("completed"),
  ]),
});
const State = Type.Object({
  readOnly: Type.Boolean(),
  previousTools: Type.Array(Type.String()),
  plan: Type.Array(Step),
});
const readOnlyTools = [
  "read",
  "grep",
  "find",
  "ls",
  "git_diff",
  "update_plan",
  "request_user_input",
];

export default function workflow(pi: ExtensionAPI) {
  let state: Static<typeof State> = { readOnly: false, previousTools: [], plan: [] };
  const describe = () =>
    state.plan.map(({ step, status }) =>
      `${status === "completed" ? "[x]" : status === "in_progress" ? "[>]" : "[ ]"} ${step}`
    );
  const display = (ctx: ExtensionContext) => {
    ctx.ui.setStatus("nixcfg-mode", state.readOnly ? "PLAN: read only" : undefined);
    ctx.ui.setWidget("nixcfg-plan", state.plan.length ? describe() : undefined);
  };
  const save = (ctx: ExtensionContext) => {
    pi.appendEntry("nixcfg-workflow", structuredClone(state));
    display(ctx);
  };
  const setMode = (readOnly: boolean, ctx: ExtensionContext) => {
    if (readOnly !== state.readOnly) {
      if (readOnly) state.previousTools = pi.getActiveTools();
      state.readOnly = readOnly;
      pi.setActiveTools(readOnly ? readOnlyTools : state.previousTools);
      save(ctx);
    }
  };
  const restore = (_event: unknown, ctx: ExtensionContext) => {
    const previous = state;
    state = { readOnly: false, previousTools: [], plan: [] };
    for (const entry of ctx.sessionManager.getBranch()) {
      if (
        entry.type === "custom" && entry.customType === "nixcfg-workflow"
        && Value.Check(State, entry.data)
      ) {
        state = structuredClone(entry.data);
      }
    }
    if (state.readOnly) pi.setActiveTools(readOnlyTools);
    else if (previous.readOnly) pi.setActiveTools(previous.previousTools);
    display(ctx);
  };
  pi.on("session_start", restore);
  pi.on("session_tree", restore);
  pi.on("tool_call", (event) => {
    if (state.readOnly && !readOnlyTools.includes(event.toolName)) {
      return {
        block: true,
        reason: "Plan mode: use /plan off before executing or changing anything.",
      };
    }
  });
  pi.on("before_agent_start", (event) => ({
    systemPrompt: `${event.systemPrompt}\n${
      state.readOnly
        ? "Plan mode is active. Inspect and plan only; do not change files or execute commands."
        : ""
    }\nCurrent task plan:\n${describe().join("\n") || "No plan recorded."}`,
  }));
  pi.registerCommand("plan", {
    description: "Toggle read-only planning, or use /plan on or /plan off.",
    handler: async (args, ctx) => {
      if (args && args !== "on" && args !== "off") {
        ctx.ui.notify("Usage: /plan [on|off]", "warning");
        return;
      }
      await ctx.waitForIdle();
      setMode(args ? args === "on" : !state.readOnly, ctx);
      ctx.ui.notify(state.readOnly ? "Plan mode enabled" : "Plan mode disabled", "info");
    },
  });
  pi.registerCommand("review", {
    description:
      "Review changes in read-only mode. Optional arguments describe the target or focus.",
    handler: async (args, ctx) => {
      await ctx.waitForIdle();
      setMode(true, ctx);
      pi.sendUserMessage(
        `Review ${
          args || "the uncommitted changes"
        }. Use git_diff and read the affected files, including untracked files. Report only actionable findings with severity, file locations, and evidence. Do not edit files, stage, commit, or push. State what was not verified.`,
      );
    },
  });
  pi.registerTool({
    name: "update_plan",
    label: "Task plan",
    description: "Record task steps and their progress. At most one step may be in progress.",
    parameters: Type.Object({ explanation: Type.Optional(Type.String()), plan: Type.Array(Step) }),
    executionMode: "sequential",
    async execute(_id, params, _signal, _update, ctx) {
      if (params.plan.filter((step) => step.status === "in_progress").length > 1) {
        throw new Error("At most one plan step may be in progress.");
      }
      state.plan = structuredClone(params.plan);
      save(ctx);
      return {
        content: [{ type: "text", text: describe().join("\n") || "Plan cleared." }],
        details: { plan: state.plan },
      };
    },
  });
  pi.registerTool({
    name: "request_user_input",
    label: "Ask user",
    description:
      "Ask one to three focused questions, with choices or a free-text answer. Requires interactive UI.",
    parameters: Type.Object({
      questions: Type.Array(
        Type.Object({
          id: Type.String({ minLength: 1 }),
          question: Type.String({ minLength: 1 }),
          options: Type.Optional(
            Type.Array(Type.String({ minLength: 1 }), { minItems: 2, maxItems: 5 }),
          ),
        }),
        { minItems: 1, maxItems: 3 },
      ),
    }),
    executionMode: "sequential",
    async execute(_id, params, signal, _update, ctx) {
      if (!ctx.hasUI) {
        throw new Error(
          "User input requires an interactive TUI or RPC client; no answer was assumed.",
        );
      }
      let answers: Record<string, string> = {};
      if (new Set(params.questions.map((q) => q.id)).size !== params.questions.length) {
        throw new Error("Question IDs must be unique.");
      }
      for (const question of params.questions) {
        if (signal?.aborted) throw new Error("Question cancelled.");
        let answer = question.options
          ? await ctx.ui.select(question.question, [...question.options, "Write an answer…"], {
            signal,
          })
          : await ctx.ui.input(question.question, undefined, { signal });
        if (question.options && answer === "Write an answer…") {
          answer = await ctx.ui.input(question.question, undefined, { signal });
        }
        if (answer === undefined) {
          return {
            content: [{ type: "text", text: "User cancelled; no answer or approval was assumed." }],
            details: { cancelled: true, answers },
          };
        }
        answers = { ...answers, [question.id]: answer };
      }
      return { content: [{ type: "text", text: JSON.stringify(answers) }], details: { answers } };
    },
  });
  pi.registerTool({
    name: "git_diff",
    label: "Git diff",
    description:
      "Read Git status and a diff without external diff programs or text conversion. Untracked file contents can be inspected with read.",
    parameters: Type.Object({
      target: Type.Union([Type.Literal("working"), Type.Literal("staged"), Type.Literal("base")]),
      base: Type.Optional(Type.String({ minLength: 1, pattern: "^[^-]" })),
    }),
    async execute(_id, params, signal, _update, ctx) {
      const options = { cwd: ctx.cwd, signal, timeout: 10000 };
      const status = await pi.exec(
        "git",
        ["-c", "core.fsmonitor=false", "--no-optional-locks", "status", "--short"],
        options,
      );
      const comparison = params.target === "staged"
        ? ["--cached"]
        : params.target === "base"
        ? [`${params.base || "HEAD"}...HEAD`]
        : ["HEAD"];
      const diff = await pi.exec("git", [
        "-c",
        "core.fsmonitor=false",
        "--no-optional-locks",
        "diff",
        "--no-ext-diff",
        "--no-textconv",
        ...comparison,
        "--",
      ], options);
      if (status.code !== 0 || diff.code !== 0) {
        throw new Error(status.stderr || diff.stderr || "Git inspection failed.");
      }
      const output = `${status.stdout}\n${diff.stdout}`;
      const truncated = output.length > 64000;
      return {
        content: [{
          type: "text",
          text: output.slice(0, 64000)
            + (truncated ? "\n[Diff truncated; inspect individual files with read.]" : ""),
        }],
        details: { truncated },
      };
    },
  });
}
