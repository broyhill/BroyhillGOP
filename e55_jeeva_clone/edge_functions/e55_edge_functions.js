/**
 * E55 Autonomous Intelligence Agent — Supabase Edge Functions
 * BroyhillGOP NEXUS Platform
 *
 * 17 API endpoints for the E55 ecosystem.
 * Deploy to: supabase/functions/e55-agent/index.ts
 *
 * ENDPOINTS:
 *   POST /agent/create          — Create new agent profile for candidate
 *   GET  /agent/:id/status      — Get agent dashboard stats
 *   PATCH /agent/:id/config     — Update monitoring config (toggle groups)
 *   POST /agent/:id/icp         — Create ICP profile (natural language search)
 *   GET  /agent/:id/origins     — Get prospect origin attribution report
 *
 *   POST /prospect/discover     — Record new prospect with origin tracking
 *   POST /prospect/enrich       — Queue prospect for waterfall enrichment
 *   GET  /prospect/:gr_id/briefing — Get pre-call briefing
 *
 *   POST /group/join            — Join a social group (start monitoring)
 *   GET  /groups/directory       — List available groups by category
 *   GET  /groups/discover        — AI-suggested groups to join
 *
 *   POST /newsletter/subscribe  — Subscribe prospect to issue newsletter
 *   GET  /newsletter/performance — Newsletter metrics dashboard
 *
 *   POST /news/event            — Register a news cycle event
 *   POST /news/activate         — Activate groups for a news event
 *
 *   POST /outreach/sequence     — Create outreach sequence
 *   POST /inbox/classify        — Classify inbound message
 *
 *   GET  /sources               — List enrichment sources with stats
 */

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.0";

const supabaseUrl = Deno.env.get("SUPABASE_URL");
const supabaseKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
const supabase = createClient(supabaseUrl, supabaseKey);

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "GET, POST, PATCH, DELETE, OPTIONS",
};

function json(data, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

serve(async (req) => {
  // CORS preflight
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  const url = new URL(req.url);
  const path = url.pathname.replace(/^\/e55-agent/, "");
  const method = req.method;

  try {
    // ═══════════════════════════════════════════════
    // AGENT ENDPOINTS
    // ═══════════════════════════════════════════════

    // POST /agent/create — Create new agent for candidate
    if (method === "POST" && path === "/agent/create") {
      const body = await req.json();
      const { candidate_id, district, district_type, agent_name } = body;

      const { data, error } = await supabase
        .from("e55_agent_profiles")
        .insert({
          candidate_id,
          district,
          district_type,
          agent_name: agent_name || "Campaign Intelligence Agent",
          agent_status: "active",
        })
        .select()
        .single();

      if (error) return json({ error: error.message }, 400);
      return json({ agent: data, message: "Agent created successfully" });
    }

    // GET /agent/:id/status — Dashboard stats
    if (method === "GET" && path.match(/^\/agent\/[\w-]+\/status$/)) {
      const agentId = path.split("/")[2];

      const { data, error } = await supabase
        .from("e55_agent_dashboard")
        .select("*")
        .eq("agent_id", agentId)
        .single();

      if (error) return json({ error: "Agent not found" }, 404);
      return json(data);
    }

    // PATCH /agent/:id/config — Update monitoring config (group toggles)
    if (method === "PATCH" && path.match(/^\/agent\/[\w-]+\/config$/)) {
      const agentId = path.split("/")[2];
      const body = await req.json();

      const { data, error } = await supabase
        .from("e55_agent_profiles")
        .update({ monitoring_config: body.monitoring_config })
        .eq("id", agentId)
        .select()
        .single();

      if (error) return json({ error: error.message }, 400);

      // Log the config change
      await supabase.from("e55_agent_activity_log").insert({
        agent_id: agentId,
        activity_type: "config_change",
        detail: `Monitoring config updated: ${JSON.stringify(body.monitoring_config).substring(0, 200)}`,
        triggered_by: "candidate",
      });

      return json({ agent: data, message: "Config updated" });
    }

    // POST /agent/:id/icp — Create ICP (Ideal Constituent Profile)
    if (method === "POST" && path.match(/^\/agent\/[\w-]+\/icp$/)) {
      const agentId = path.split("/")[2];
      const body = await req.json();
      const { icp_name, icp_prompt, filters, auto_enrich, enrichment_depth } = body;

      const { data, error } = await supabase
        .from("e55_icp_profiles")
        .insert({
          agent_id: agentId,
          icp_name,
          icp_prompt,
          filters,
          auto_enrich: auto_enrich ?? true,
          enrichment_depth: enrichment_depth || "standard",
          status: "active",
        })
        .select()
        .single();

      if (error) return json({ error: error.message }, 400);

      // Execute the ICP search immediately
      const { data: searchResult } = await supabase.rpc("e55_execute_icp_search", {
        p_icp_id: data.id,
      });

      return json({
        icp: data,
        matches_found: searchResult,
        message: `ICP created: ${icp_name} — ${searchResult} matches found`,
      });
    }

    // GET /agent/:id/origins — Prospect origin attribution
    if (method === "GET" && path.match(/^\/agent\/[\w-]+\/origins$/)) {
      const agentId = path.split("/")[2];

      const { data, error } = await supabase.rpc("e55_origin_attribution_report", {
        p_agent_id: agentId,
      });

      if (error) return json({ error: error.message }, 500);
      return json(data);
    }

    // ═══════════════════════════════════════════════
    // PROSPECT ENDPOINTS
    // ═══════════════════════════════════════════════

    // POST /prospect/discover — Record prospect with full origin
    if (method === "POST" && path === "/prospect/discover") {
      const body = await req.json();
      const {
        agent_id, golden_record_id,
        origin_type, group_id, issue, news_event,
        content, url, connector_id, connector_name
      } = body;

      const { data, error } = await supabase.rpc("e55_record_prospect_discovery", {
        p_agent_id: agent_id,
        p_golden_record_id: golden_record_id,
        p_origin_type: origin_type,
        p_group_id: group_id || null,
        p_issue: issue || null,
        p_news_event: news_event || null,
        p_content: content || null,
        p_url: url || null,
        p_connector_id: connector_id || null,
        p_connector_name: connector_name || null,
      });

      if (error) return json({ error: error.message }, 400);
      return json({
        origin_id: data,
        message: `Prospect GR#${golden_record_id} discovered via ${origin_type}`,
      });
    }

    // POST /prospect/enrich — Queue for enrichment
    if (method === "POST" && path === "/prospect/enrich") {
      const body = await req.json();
      const { agent_id, golden_record_id, person_name, email, depth, origin_type, origin_group_id } = body;

      const { data, error } = await supabase
        .from("e55_enrichment_queue")
        .insert({
          agent_id,
          golden_record_id,
          person_name,
          email,
          pipeline_status: "queued",
          prospect_origin_type: origin_type || "unknown",
          prospect_origin_group_id: origin_group_id,
          priority: 5,
        })
        .select()
        .single();

      if (error) return json({ error: error.message }, 400);
      return json({ queue_id: data.id, message: "Queued for enrichment" });
    }

    // GET /prospect/:gr_id/briefing — Pre-call briefing
    if (method === "GET" && path.match(/^\/prospect\/\d+\/briefing$/)) {
      const grId = parseInt(path.split("/")[2]);
      const agentId = url.searchParams.get("agent_id");

      const { data, error } = await supabase
        .from("e55_precall_briefings")
        .select("*")
        .eq("golden_record_id", grId)
        .eq("agent_id", agentId)
        .order("created_at", { ascending: false })
        .limit(1)
        .single();

      if (error) return json({ error: "No briefing found" }, 404);
      return json(data);
    }

    // ═══════════════════════════════════════════════
    // GROUP ENDPOINTS
    // ═══════════════════════════════════════════════

    // POST /group/join — Join and start monitoring a group
    if (method === "POST" && path === "/group/join") {
      const body = await req.json();
      const { agent_id, group_id } = body;

      const { data, error } = await supabase
        .from("e55_group_memberships")
        .insert({
          agent_id,
          group_id,
          status: "active",
          monitor_posts: true,
          monitor_members: true,
          auto_newsletter_recruit: true,
        })
        .select()
        .single();

      if (error) return json({ error: error.message }, 400);

      // Log it
      await supabase.from("e55_agent_activity_log").insert({
        agent_id,
        activity_type: "group_joined",
        target_type: "group",
        target_id: group_id,
        detail: "Joined group and started monitoring",
        origin_group_id: group_id,
      });

      return json({ membership: data, message: "Group joined" });
    }

    // GET /groups/directory — List groups by category
    if (method === "GET" && path === "/groups/directory") {
      const category = url.searchParams.get("category");
      const county = url.searchParams.get("county");
      const verified = url.searchParams.get("verified");

      let query = supabase
        .from("e55_social_group_directory")
        .select("*")
        .order("member_count", { ascending: false });

      if (category) query = query.eq("directory_category", category);
      if (county) query = query.eq("county", county);
      if (verified === "true") query = query.eq("verified", true);

      const { data, error } = await query;
      if (error) return json({ error: error.message }, 500);
      return json(data);
    }

    // GET /groups/discover — AI-suggested groups
    if (method === "GET" && path === "/groups/discover") {
      const agentId = url.searchParams.get("agent_id");
      const county = url.searchParams.get("county");

      // Get groups the agent hasn't joined yet
      const { data: existing } = await supabase
        .from("e55_group_memberships")
        .select("group_id")
        .eq("agent_id", agentId);

      const existingIds = (existing || []).map((g) => g.group_id);

      let query = supabase
        .from("e55_social_group_directory")
        .select("*")
        .order("ai_match_score", { ascending: false })
        .limit(10);

      if (county) query = query.eq("county", county);
      if (existingIds.length > 0) {
        // Filter out already-joined groups
        query = query.not("id", "in", `(${existingIds.join(",")})`);
      }

      const { data, error } = await query;
      if (error) return json({ error: error.message }, 500);
      return json(data);
    }

    // ═══════════════════════════════════════════════
    // NEWSLETTER ENDPOINTS
    // ═══════════════════════════════════════════════

    // POST /newsletter/subscribe
    if (method === "POST" && path === "/newsletter/subscribe") {
      const body = await req.json();
      const { agent_id, golden_record_id, newsletter_name, newsletter_category, origin_group_id } = body;

      const { data, error } = await supabase
        .from("e55_newsletter_tracking")
        .insert({
          agent_id,
          golden_record_id,
          newsletter_name,
          newsletter_category,
          origin_group_id,
        })
        .select()
        .single();

      if (error) return json({ error: error.message }, 400);
      return json({ subscription: data, message: "Subscribed to newsletter" });
    }

    // GET /newsletter/performance
    if (method === "GET" && path === "/newsletter/performance") {
      const agentId = url.searchParams.get("agent_id");

      const { data, error } = await supabase
        .from("e55_newsletter_performance")
        .select("*")
        .eq("agent_id", agentId);

      if (error) return json({ error: error.message }, 500);
      return json(data);
    }

    // ═══════════════════════════════════════════════
    // NEWS CYCLE ENDPOINTS
    // ═══════════════════════════════════════════════

    // POST /news/event — Register news event
    if (method === "POST" && path === "/news/event") {
      const body = await req.json();

      const { data, error } = await supabase
        .from("e55_news_cycle_events")
        .insert({
          headline: body.headline,
          summary: body.summary,
          issue_category: body.issue_category,
          related_directories: body.related_directories,
          impact_level: body.impact_level || "medium",
          source_url: body.source_url,
          affected_counties: body.affected_counties || [],
          ai_talking_points: body.ai_talking_points || [],
          status: "active",
        })
        .select()
        .single();

      if (error) return json({ error: error.message }, 400);

      // Auto-activate
      const { data: activated } = await supabase.rpc("e55_activate_news_cycle", {
        p_news_event_id: data.id,
      });

      return json({
        event: data,
        agents_activated: activated,
        message: `News event registered: ${body.headline}`,
      });
    }

    // POST /news/activate — Manual activation
    if (method === "POST" && path === "/news/activate") {
      const body = await req.json();
      const { data, error } = await supabase.rpc("e55_activate_news_cycle", {
        p_news_event_id: body.event_id,
      });

      if (error) return json({ error: error.message }, 500);
      return json({ agents_activated: data });
    }

    // ═══════════════════════════════════════════════
    // OUTREACH + INBOX ENDPOINTS
    // ═══════════════════════════════════════════════

    // POST /outreach/sequence
    if (method === "POST" && path === "/outreach/sequence") {
      const body = await req.json();

      const { data, error } = await supabase
        .from("e55_outreach_sequences")
        .insert({
          agent_id: body.agent_id,
          golden_record_id: body.golden_record_id,
          sequence_name: body.sequence_name || `${body.sequence_type} sequence`,
          sequence_type: body.sequence_type,
          origin_group_id: body.origin_group_id,
          origin_issue: body.origin_issue,
          total_steps: body.steps?.length || 3,
          steps_config: body.steps || [],
          channel: body.channel || "email",
          status: "active",
        })
        .select()
        .single();

      if (error) return json({ error: error.message }, 400);
      return json({ sequence: data, message: "Outreach sequence created" });
    }

    // POST /inbox/classify — Classify inbound message
    if (method === "POST" && path === "/inbox/classify") {
      const body = await req.json();
      const { agent_id, golden_record_id, channel, subject, message_body, origin_group_id } = body;

      // Simple classification (would use AI in production)
      const text = `${subject} ${message_body}`.toLowerCase();
      let intent = "other";
      const intents = {
        donation_intent: ["donate", "contribute", "give", "support"],
        volunteer_offer: ["volunteer", "help", "sign up", "canvass"],
        event_interest: ["event", "rally", "meeting", "attend"],
        issue_question: ["position", "stand", "policy", "thoughts"],
        positive_feedback: ["great", "thank", "love", "amazing"],
      };
      for (const [cat, words] of Object.entries(intents)) {
        if (words.some((w) => text.includes(w))) { intent = cat; break; }
      }

      const { data, error } = await supabase
        .from("e55_unified_inbox")
        .insert({
          agent_id,
          golden_record_id,
          channel,
          direction: "inbound",
          subject,
          body: message_body,
          intent_category: intent,
          sentiment: "neutral",
          urgency: "normal",
          origin_group_id,
        })
        .select()
        .single();

      if (error) return json({ error: error.message }, 400);
      return json({ message: data, classified_as: intent });
    }

    // ═══════════════════════════════════════════════
    // ENRICHMENT SOURCES
    // ═══════════════════════════════════════════════

    // GET /sources — List all enrichment sources
    if (method === "GET" && path === "/sources") {
      const { data, error } = await supabase
        .from("e55_enrichment_sources")
        .select("*")
        .order("waterfall_priority", { ascending: true });

      if (error) return json({ error: error.message }, 500);

      const tiers = {
        government: data.filter((s) => s.waterfall_priority <= 10),
        social: data.filter((s) => s.waterfall_priority > 10 && s.waterfall_priority <= 25),
        commercial: data.filter((s) => s.waterfall_priority > 25 && s.waterfall_priority <= 45),
        political: data.filter((s) => s.waterfall_priority > 45 && s.waterfall_priority <= 60),
        business: data.filter((s) => s.waterfall_priority > 60 && s.waterfall_priority <= 75),
        media: data.filter((s) => s.waterfall_priority > 75 && s.waterfall_priority <= 90),
        wealth: data.filter((s) => s.waterfall_priority > 90),
      };

      return json({ total: data.length, tiers, all: data });
    }

    // ═══════════════════════════════════════════════
    // 404
    // ═══════════════════════════════════════════════
    return json({ error: `Not found: ${method} ${path}` }, 404);

  } catch (err) {
    console.error("E55 Edge Function Error:", err);
    return json({ error: err.message }, 500);
  }
});
