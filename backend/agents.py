import asyncio
import json
import traceback
from typing import Optional, List, Dict, Any
from .adapters import LLMAdapter, SocialAdapter
from .db import SessionLocal, AgentTask, Company, SocialAccount

llm = LLMAdapter()
social = SocialAdapter()

AGENT_TITLES = {
    "strategy": "Chief Strategy Officer (CSO Agent)",
    "product": "VP of Product & Technology (Product Agent)",
    "marketing": "Head of Growth & Marketing (Marketing Agent)",
    "finance": "Chief Financial Officer (Finance Agent)",
    "social_media": "Omnichannel Social Media Manager",
    "operations": "Operations & Workflow Automation Agent",
}


def _get_company_context(session, company_id: int) -> Dict[str, Any]:
    comp = session.get(Company, company_id)
    if not comp:
        return {"company_name": f"Company #{company_id}", "status": "unknown"}
    data = {}
    try:
        data = json.loads(comp.data or "{}")
    except Exception:
        data = {}
    data["company_name"] = comp.name or data.get("company_name") or f"Company #{company_id}"
    return data


async def run_single_agent(company_id: int, agent_type: str, custom_instruction: Optional[str] = None) -> int:
    """Run a single specialized autonomous agent and update the database."""
    session = SessionLocal()
    task = None
    try:
        title = AGENT_TITLES.get(agent_type, f"{agent_type.capitalize()} Agent")
        task = AgentTask(
            company_id=company_id,
            agent_type=agent_type,
            title=title,
            status="running"
        )
        session.add(task)
        session.commit()
        session.refresh(task)

        context = _get_company_context(session, company_id)
        c_name = context.get("company_name", f"Company #{company_id}")
        industry = context.get("industry", "Technology & Business Services")
        target_audience = context.get("target_audience", "B2B / Direct-to-Consumer")
        business_model = context.get("business_model", "SaaS / Digital Services")
        goals = context.get("goals", "Scale customer acquisition and automate operations")
        budget = context.get("budget", "$5,000 - $25,000/month")

        # Import KnowledgeEngine for rich training injection
        from .knowledge_engine import KnowledgeEngine
        kb_text = KnowledgeEngine.get_company_context(company_id)

        system_prompt = (
            f"You are the {title} for '{c_name}'. Industry: {industry}. Model: {business_model}. "
            f"Deliver structured, actionable, executive-grade analysis in markdown.\n\n"
            f"{kb_text}"
        )

        if agent_type == "strategy":
            prompt = (
                f"Formulate a complete Strategic Growth & Positioning Brief for '{c_name}'.\n"
                f"- Industry: {industry}\n"
                f"- Target Market: {target_audience}\n"
                f"- Goals: {goals}\n"
                f"- Budget: {budget}\n\n"
                "Include:\n"
                "1. Executive Summary & Defensible Value Proposition\n"
                "2. Strategic SWOT Analysis (Strengths, Weaknesses, Opportunities, Threats)\n"
                "3. 30/60/90-Day Execution Milestones\n"
                "4. Top 3 Risk Mitigation Tactics"
            )
            result = await llm.generate(prompt, system_prompt=system_prompt, agent_type="strategy")

        elif agent_type == "product":
            prompt = (
                f"Develop a 90-Day Product Roadmap & Technical Architecture Blueprint for '{c_name}'.\n"
                f"- Industry: {industry}\n"
                f"- Target Audience: {target_audience}\n"
                f"- Core Goals: {goals}\n\n"
                "Include:\n"
                "1. Core MVP Feature Prioritization (MoSCoW Matrix)\n"
                "2. Recommended Modern Tech Stack & Scalability Architecture\n"
                "3. Sprint Breakdown (Sprint 1 to 4)\n"
                "4. Product Success Metrics & Retention Guardrails"
            )
            result = await llm.generate(prompt, system_prompt=system_prompt, agent_type="product")

        elif agent_type == "marketing":
            prompt = (
                f"Design an Omnichannel Growth & Customer Acquisition Blueprint for '{c_name}'.\n"
                f"- Industry: {industry}\n"
                f"- Target Audience: {target_audience}\n"
                f"- Budget: {budget}\n\n"
                "Include:\n"
                "1. Core Positioning Angles & High-Converting Hooks\n"
                "2. 7-Day Social Content Calendar (LinkedIn, X, Instagram)\n"
                "3. Paid Ad Campaigns & Lead Magnet Funnel Blueprint\n"
                "4. 3-Part Automated Onboarding Email Sequence Outline"
            )
            result = await llm.generate(prompt, system_prompt=system_prompt, agent_type="marketing")

        elif agent_type == "finance":
            prompt = (
                f"Generate a Financial Model, Unit Economics & Margin Projection for '{c_name}'.\n"
                f"- Industry: {industry}\n"
                f"- Budget: {budget}\n"
                f"- Model: {business_model}\n\n"
                "Include:\n"
                "1. Unit Economics (Projected CAC, LTV, LTV:CAC Ratio, Payback Period)\n"
                "2. Revenue Breakdown by Tier & Pricing Strategy\n"
                "3. Projected 12-Month Financial Summary Table (Gross Revenue, COGS, OPEX, Net Profit)\n"
                "4. Break-Even Analysis & Working Capital Safeguards"
            )
            result = await llm.generate(prompt, system_prompt=system_prompt, agent_type="finance")

        elif agent_type == "social_media":
            prompt = (
                f"Create ready-to-publish social media announcements for '{c_name}' across all platforms.\n"
                f"- Industry: {industry}\n"
                f"- Target Audience: {target_audience}\n\n"
                "Provide:\n"
                "1. High-Impact Twitter/X Thread (3 tweets)\n"
                "2. Engaging LinkedIn Thought Leadership Article Post\n"
                "3. Instagram Visual Post Caption with 10 high-traffic hashtags\n"
                "4. WhatsApp VIP Broadcast Announcement"
            )
            generated_posts = await llm.generate(prompt, system_prompt=system_prompt, agent_type="marketing")

            
            accounts = session.query(SocialAccount).filter(SocialAccount.company_id == company_id).all()
            dispatch_results = []
            if accounts:
                for acc in accounts:
                    creds = {}
                    try:
                        creds = json.loads(acc.credentials or "{}")
                    except Exception:
                        creds = {}
                    res = await social.post(acc.platform, generated_posts[:200], credentials=creds, label=acc.label)
                    dispatch_results.append(res)
            else:
                
                r1 = await social.post("linkedin", generated_posts[:150], label="Auto LinkedIn")
                r2 = await social.post("twitter", generated_posts[:150], label="Auto X")
                dispatch_results.extend([r1, r2])

            result = (
                f"{generated_posts}\n\n"
                f"---\n"
                f"### 📡 Automated Channel Dispatch Summary\n"
                f"**Dispatched to {len(dispatch_results)} configured/simulated channels:**\n"
                f"```json\n{json.dumps(dispatch_results, indent=2)}\n```"
            )
        else:
            prompt = custom_instruction or f"Perform business analysis for company {c_name} regarding {agent_type}."
            result = await llm.generate(prompt, system_prompt=system_prompt)

        
        task.status = "done"
        task.result = result
        session.add(task)
        session.commit()
        session.refresh(task)

        
        comp = session.get(Company, company_id)
        if comp:
            comp.status = "active"
            session.add(comp)
            session.commit()

        return task.id

    except Exception as e:
        if task:
            task.status = "failed"
            task.error = f"{str(e)}\n{traceback.format_exc()}"
            session.add(task)
            session.commit()
        raise e
    finally:
        session.close()


async def orchestrate(company_id: int, agents: Optional[List[str]] = None) -> bool:
    """Run the entire autonomous multi-agent pipeline sequentially with progress updates."""
    if not agents:
        agents = ["strategy", "product", "marketing", "finance", "social_media"]

    session = SessionLocal()
    try:
        comp = session.get(Company, company_id)
        if comp:
            comp.status = "orchestrating"
            session.add(comp)
            session.commit()
    finally:
        session.close()

    for a in agents:
        try:
            await run_single_agent(company_id, a)
        except Exception as err:
            print(f"[Orchestrator Error] Agent {a} failed for company {company_id}: {err}")

    session = SessionLocal()
    try:
        comp = session.get(Company, company_id)
        if comp:
            comp.status = "completed"
            session.add(comp)
            session.commit()
    finally:
        session.close()

    return True
