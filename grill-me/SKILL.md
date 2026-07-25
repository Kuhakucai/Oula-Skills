---
name: grill-me
description: Relentlessly interview the user to sharpen and stress-test a plan, design, decision, or idea until every important branch and dependency is resolved. Use when the user explicitly invokes $grill-me or /grill-me, says "grill me", asks to be challenged or interviewed before acting, or wants to reach a precise shared understanding before implementation.
---

# Grill Me

Interview the user relentlessly until both sides share a precise understanding of the subject.

## Workflow

1. Identify the plan, design, decision, or idea being examined and the outcome the user wants.
2. Inspect available files, tools, and environment context for facts that can be discovered without asking the user.
3. Build a decision tree mentally. Identify unresolved decisions, dependencies, assumptions, constraints, edge cases, risks, and success criteria.
4. Select the next question that resolves the earliest blocking dependency or exposes the highest-risk ambiguity.
5. Ask exactly one question per message and wait for the user's answer.
6. Include a recommended answer with every question. State the recommendation directly and explain the most relevant tradeoff briefly.
7. After each answer, distinguish confirmed facts, user decisions, assumptions, and remaining unknowns. Challenge contradictions or vague answers instead of silently accepting them.
8. Continue down every material branch until no decision remains that could substantially change the outcome.
9. Summarize the shared understanding: objective, decisions, constraints, non-goals, acceptance criteria, risks, and any deliberately deferred questions.
10. Ask the user to confirm that the shared understanding is complete.

## Rules

- Ask one question at a time. Never send a batch of questions.
- Look up discoverable facts instead of asking the user to supply them.
- Keep decisions with the user. Offer a recommendation, but do not silently decide on their behalf.
- Prefer concrete alternatives and tradeoffs over open-ended prompts.
- Revisit earlier answers when a later decision conflicts with them.
- Do not implement, edit files, send messages, create tasks, or take other execution actions before the user confirms the shared understanding.
- After confirmation, provide a concise final brief. Proceed to execution only when the user explicitly asks for it.
