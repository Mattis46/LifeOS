import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import OpenAI from "openai";

const openai = new OpenAI({ apiKey: Deno.env.get("OPENAI_API_KEY")! });

type AgentRequest = {
  mode: "daily" | "goal_deep_dive" | "retro" | "chat";
  goals: Array<{
    id?: string;
    title: string;
    horizon?: "short" | "mid" | "long";
    progress?: number;
    status?: string;
  }>;
  tasks: Array<{
    id?: string;
    title: string;
    status?: string;
    due?: string | null;
    goal_id?: string | null;
  }>;
  habits: Array<{
    id?: string;
    title: string;
    streak?: number;
    goal_id?: string | null;
  }>;
  notes?: string[];
  focus_goal_id?: string | null;
  chat_history?: Array<{ role: "user" | "assistant" | "system"; content: string }>;
};

type AgentResponse = {
  insights: string[];
  today_actions: Array<{
    title: string;
    reason?: string;
    goal_id?: string | null;
    due_hint?: string | null;
  }>;
  milestones?: Array<{
    goal_id?: string | null;
    title: string;
    steps?: string[];
  }>;
  habit_suggestions?: string[];
  questions?: string[];
  ops?: Array<{
    type: "create_task" | "create_habit" | "create_goal";
    title: string;
    detail?: string;
    goal_id?: string | null;
    due_date?: string | null;
    horizon?: string | null;
    frequency?: string | null;
  }>;
  reply?: string;
};

const system = `You are LifeOS Coach (mentor+analyst+planner+operator+mirror).
Always reply valid JSON for the given schema. Be concise, actionable, motivating.
Rules:
- Max 3 insights, max 3 today_actions, max 3 questions.
- Keep steps tiny and doable; tie to goals if possible.
- ops only for low-risk create suggestions (no deletes/updates).
- Use user's wording; no apologies; no chit-chat.
- Always return AT LEAST one insight OR one today_action (prefer both). If data is sparse, still propose one small next step tied to any goal or a generic mini-step.`;

serve(async (req) => {
  try {
    const body: AgentRequest = await req.json();
    console.log("[coach] incoming mode:", body.mode, "goals:", body.goals.length, "tasks:", body.tasks.length, "habits:", body.habits.length);

    if (body.mode === "chat" && body.chat_history) {
      const completion = await openai.chat.completions.create({
        model: "gpt-4o-mini",
        messages: [
          { role: "system", content: system },
          ...body.chat_history.map((m) => ({ role: m.role, content: m.content })),
        ],
        temperature: 0.5,
      });
      const reply = completion.choices[0].message.content ?? "";
      return new Response(JSON.stringify({ reply }), {
        headers: { "Content-Type": "application/json" },
      });
    }
    const completion = await openai.chat.completions.create({
      model: "gpt-4o-mini",
      messages: [
        { role: "system", content: system },
        {
          role: "user",
          content: JSON.stringify({
            mode: body.mode,
            focus_goal_id: body.focus_goal_id,
            goals: body.goals,
            tasks: body.tasks,
            habits: body.habits,
            notes: body.notes ?? [],
          }),
        },
      ],
      response_format: { type: "json_object" },
      temperature: 0.4,
    });

    const content = completion.choices[0].message.content;
    console.log("[coach] openai tokens:", completion.usage);
    if (!content) throw new Error("Empty response from model");

    const parsed: AgentResponse = JSON.parse(content);

    return new Response(JSON.stringify(parsed), {
      headers: { "Content-Type": "application/json" },
    });
  } catch (err) {
    console.error("coach error", err);
    return new Response(
      JSON.stringify({ error: err.message ?? "coach failed" }),
      { status: 500, headers: { "Content-Type": "application/json" } },
    );
  }
});
