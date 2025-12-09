import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import OpenAI from "openai";

const openai = new OpenAI({ apiKey: Deno.env.get("OPENAI_API_KEY")! });

serve(async (req) => {
  const { context } = await req.json();
  const completion = await openai.chat.completions.create({
    model: "gpt-4o-mini",
    messages: [
      { role: "system", content: "You are LifeOS coach. Reply JSON." },
      { role: "user", content: JSON.stringify(context) },
    ],
    response_format: { type: "json_object" },
  });
  return new Response(completion.choices[0].message.content, {
    headers: { "Content-Type": "application/json" },
  });
});
