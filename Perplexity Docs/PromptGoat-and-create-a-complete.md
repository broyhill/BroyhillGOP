<img src="https://r2cdn.perplexity.ai/pplx-full-logo-primary-dark%402x.png" style="height:64px;margin-right:32px"/>

# could you re3visit PromptGoat and create a complete integrated soltuion for broyhillgop with open source best in category. . we want create an ai wizard in every ecosystem that assist the candidate  . a slide out nav panel providwes ai interfaCE AND CANDIDATE CAN ASK QUESTIONS AND ACTIVATE RESP;ONSE3S to call to action prompts  so9 ai agen t designed tlo mon

This is a big vision — and it's entirely buildable with open source tools. Here's the complete integrated architecture for BroyhillGOP.[^1]

## The BroyhillGOP AI Wizard — Complete Architecture

The core concept: **every one of the 55 ecosystems gets a persistent AI assistant panel** built from the same open source stack, personalized to that ecosystem's function, and connected to the E20 Brain.[^1]

***

## Layer 1 — The UI Shell: `assistant-ui`

**The Inspinia-compatible slide-out panel**[^2]

**[assistant-ui](https://github.com/assistant-ui/assistant-ui)** (MIT, ~7,900 GitHub stars) is the right foundation. It's headless React — composable unstyled primitives (`Thread`, `Composer`, `Message`) that you style with your own CSS, which means it slots directly into Inspinia without conflicting with the template.[^3][^2]

Key capabilities for BroyhillGOP:

- Streaming responses first-class
- Persistent session state across page navigation
- Vercel AI SDK integration (model-agnostic)
- Fully accessible (WCAG compliant)
- TypeScript native

The slide-out panel becomes an **Inspinia right-sidebar component** — triggered by a persistent AI button in every ecosystem's top nav. It opens without leaving the page.[^4]

***

## Layer 2 — Prompt Optimization: `promptolution`

**The PromptGoat replacement — built in, not bolted on**[^5]

**[promptolution](https://arxiv.org/html/2512.02840v2)** (open source, Python, LLM-agnostic) handles automatic prompt optimization before queries ever reach the LLM. This is the native version of what PromptGoat does as a Chrome extension — except it lives inside your backend pipeline.[^5]

When a candidate types *"write me an email about school choice"*, promptolution intercepts it, rewrites it into a structured expert prompt with role, context, district, candidate persona, target segment, and output format — then sends the optimized version to the LLM.[^5]

The key difference from PromptGoat: **it knows who the candidate is**. PromptGoat knows nothing. Your system knows their district, their issues, their donor file tier, their past campaign messages. Every optimized prompt is **pre-loaded with that context**.[^6]

***

## Layer 3 — The Ecosystem Agent: Context-Aware Per Ecosystem

Each ecosystem's AI wizard has a **different system prompt and toolset** loaded by E20 Brain on page load:[^7]


| Ecosystem | Agent Persona | What It Does |
| :-- | :-- | :-- |
| **E02 Donation** | Fundraising strategist | Suggests ask amounts, draft appeals, segment targeting |
| **E30 Email** | Campaign copywriter | Writes subject lines, body copy, CTAs per segment |
| **E31 SMS** | SMS specialist | 160-char optimized texts by issue segment |
| **E11 Budget** | Finance advisor | Tracks burn rate, flags anomalies, suggests reallocation |
| **E07 Issues** | Opposition researcher | Surfaces local issue data, talking points, counterarguments |
| **E20 Brain** | Campaign command center | Cross-ecosystem orchestration, alert summaries, next best action |


***

## Layer 4 — Call-to-Action Activation Buttons

Below every AI response, the panel renders **pre-built action buttons** that execute directly:[^1]

```
AI: "Your top 47 lapsed donors in zip 27103 haven't given in 18 months. 
     Here's a reactivation email draft."

[✉ Send to 47 Donors]  [✏ Edit First]  [📋 Save to Draft]  [🗓 Schedule]
```

These buttons **call E20 Brain IFTTT triggers** directly — no copy-paste, no leaving the panel. The candidate reads the AI recommendation and hits one button. Done.[^1]

***

## Layer 5 — Open Source Stack Summary

| Layer | Tool | License | Purpose |
| :-- | :-- | :-- | :-- |
| **Chat UI** | [assistant-ui](https://github.com/assistant-ui/assistant-ui) | MIT | Slide-out panel, streaming, composable |
| **Prompt optimization** | [promptolution](https://arxiv.org/html/2512.02840v2) | Open source | Auto-rewrites candidate inputs into expert prompts |
| **LLM routing** | Vercel AI SDK | MIT | Model-agnostic, swap Claude/GPT/Gemini |
| **Agent memory** | Supabase (existing) | Open source | Candidate context, conversation history |
| **Backend agent** | Python FastAPI | MIT | Intercepts, enriches, routes, executes |
| **Trigger execution** | E20 Brain IFTTT (existing) | Your platform | Converts AI responses into platform actions |


***

## How It Connects to E20 Brain

The E20 Brain loads each candidate's **persona context packet** when they log in:[^7]

```
{
  candidate_id: "...",
  district: "Forsyth County Commissioner District 4",
  top_issues: ["property taxes", "rural broadband", "school safety"],
  donor_tier_counts: { A: 847, B: 1204, C: 312 },
  active_campaigns: [...],
  last_ai_actions: [...]
}
```

Every AI wizard query across all 55 ecosystems is **pre-seeded with this packet** via promptolution before hitting the LLM. The candidate never has to explain who they are — the system already knows.[^1]

This is the architecture. The database work finishing tonight is what fills that context packet with real data. When the 26-letter match run completes, every candidate persona on the platform gets a real donor universe — and the AI wizard has something meaningful to work with.[^8]
<span style="display:none">[^10][^11][^12][^13][^14][^15][^16][^9]</span>

<div align="center">⁂</div>

[^1]: BROYHILLGOP_DEVELOPMENT_CONSTITUTION_v1.0.md

[^2]: https://dev.to/alexander_lukashov/i-evaluated-every-ai-chat-ui-library-in-2026-heres-what-i-found-and-what-i-built-4p10

[^3]: https://github.com/assistant-ui/assistant-ui

[^4]: broyhillgop-ecosystem-dashboard-inspinia-model.md

[^5]: https://arxiv.org/html/2512.02840v2

[^6]: Perplexity-Marching-Orders-V4.txt

[^7]: E20-Brain-Hub-Intelligence-Architecture.pdf

[^8]: DataTrust-NC-Voter-File-Integration.md

[^9]: OPEN_SOURCE_P2P_TEXTING_PLATFORM_ARCHITECTURE.md

[^10]: https://pagergpt.ai/ai-chatbot/open-source-chatbot-platforms

[^11]: https://www.youtube.com/watch?v=ufo46oWej3g

[^12]: https://www.reddit.com/r/react/comments/1q6745g/recommendations_for_open_source_ai_chat_ui/

[^13]: https://chatmaxima.com/blog/15-open-source-free-live-chat-widget-solutions-to-boost-your-customer-engagement-in-2024/

[^14]: https://viterbischool.usc.edu/news/2026/03/usc-study-finds-ai-agents-can-autonomously-coordinate-propaganda-campaigns-without-human-direction/

[^15]: https://www.evidentlyai.com/blog/automated-prompt-optimization

[^16]: https://www.wired.com/story/ai-super-pacs-trying-to-influence-midterms/

