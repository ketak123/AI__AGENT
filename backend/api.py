import asyncio
import json
import os
from typing import Optional, List, Dict, Any
from fastapi import APIRouter, BackgroundTasks, HTTPException, Query
import httpx

from . import models, social_models
from .db import (
    SessionLocal, Company, AgentTask, SocialAccount, ChatMessageRecord,
    CompanyKnowledge, InboundLead, LeadInteraction, IntegrationConfig
)
from .agents import orchestrate, run_single_agent, AGENT_TITLES
from .adapters import LLMAdapter, SocialAdapter, WhatsAppAdapter, EmailAdapter
from .knowledge_engine import KnowledgeEngine

router = APIRouter()
llm = LLMAdapter()
social = SocialAdapter()
whatsapp_adapter = WhatsAppAdapter()
email_adapter = EmailAdapter()


@router.get("/health")
def health_check():
    """Health check endpoint for status monitoring."""
    db = SessionLocal()
    try:
        companies_count = db.query(Company).count()
        tasks_count = db.query(AgentTask).count()
        leads_count = db.query(InboundLead).count()
        return {
            "status": "healthy",
            "service": "Autonomous Business Multi-Agent Platform",
            "database": "connected",
            "companies_count": companies_count,
            "tasks_count": tasks_count,
            "leads_count": leads_count,
            "supported_agents": list(AGENT_TITLES.keys()),
        }
    finally:
        db.close()


@router.post("/chat", response_model=models.ChatResponse)
async def chat(payload: models.ChatRequest):
    """Handle conversational AI commands from the Flutter dashboard."""
    prompt = payload.prompt.strip()
    agent_type = payload.agent_type or "ai_manager"
    company_context = ""

    db = SessionLocal()
    try:
        if payload.company_id:
            
            kb_context = KnowledgeEngine.get_company_context(payload.company_id, query=prompt)
            if kb_context:
                company_context = f"\n\n{kb_context}"
            else:
                comp = db.get(Company, payload.company_id)
                if comp:
                    company_context = f"\nCompany Context: Name='{comp.name}', Status='{comp.status}', Details={comp.data}"

        
        db.add(ChatMessageRecord(
            company_id=payload.company_id,
            sender="user",
            content=prompt
        ))
        db.commit()
    finally:
        db.close()

    system_prompt = (
        f"You are the {AGENT_TITLES.get(agent_type, 'Autonomous AI Business Manager')}. "
        "Provide direct, high-value, structured business insights in clean Markdown. "
        f"{company_context}"
    )

    result = await llm.generate(prompt, system_prompt=system_prompt, agent_type=agent_type)

    
    db = SessionLocal()
    try:
        db.add(ChatMessageRecord(
            company_id=payload.company_id,
            sender=agent_type,
            content=result
        ))
        db.commit()
    finally:
        db.close()

    suggestions = [
        "Create 30-day Go-To-Market strategy",
        "Generate 5 high-converting ad copy variations",
        "Draft investor update email",
        "Estimate unit economics & CAC:LTV",
    ]

    return models.ChatResponse(
        result=result,
        agent_type=agent_type,
        suggestions=suggestions
    )


@router.get("/companies", response_model=List[models.CompanyOut])
def list_companies():
    db = SessionLocal()
    try:
        comps = db.query(Company).order_by(Company.id.desc()).all()
        res = []
        for c in comps:
            data = {}
            try:
                data = json.loads(c.data or "{}")
            except Exception:
                data = {}
            res.append(models.CompanyOut(
                id=c.id,
                name=c.name,
                status=c.status,
                data=data,
                created_at=c.created_at,
                updated_at=c.updated_at
            ))
        return res
    finally:
        db.close()


@router.post("/companies", response_model=models.CompanyOut)
def create_company(payload: models.CompanyCreate):
    db = SessionLocal()
    try:
        meta = {
            "industry": payload.industry or "Technology",
            "location": payload.location or "Global",
            "budget": payload.budget or "$10,000",
            "goals": payload.goals or "Accelerate revenue growth and automate operations",
        }
        comp = Company(
            name=payload.name,
            status="created",
            data=json.dumps(meta)
        )
        db.add(comp)
        db.commit()
        db.refresh(comp)
        return models.CompanyOut(
            id=comp.id,
            name=comp.name,
            status=comp.status,
            data=meta,
            created_at=comp.created_at,
            updated_at=comp.updated_at
        )
    finally:
        db.close()


@router.get("/companies/{company_id}", response_model=models.CompanyOut)
def get_company(company_id: int):
    db = SessionLocal()
    try:
        comp = db.get(Company, company_id)
        if not comp:
            raise HTTPException(status_code=404, detail="Company not found")
        data = {}
        try:
            data = json.loads(comp.data or "{}")
        except Exception:
            data = {}
        return models.CompanyOut(
            id=comp.id,
            name=comp.name,
            status=comp.status,
            data=data,
            created_at=comp.created_at,
            updated_at=comp.updated_at
        )
    finally:
        db.close()


@router.put("/companies/{company_id}", response_model=models.CompanyOut)
def update_company(company_id: int, payload: models.CompanyUpdate):
    db = SessionLocal()
    try:
        comp = db.get(Company, company_id)
        if not comp:
            raise HTTPException(status_code=404, detail="Company not found")

        if payload.name is not None:
            comp.name = payload.name
        if payload.status is not None:
            comp.status = payload.status
        if payload.data is not None:
            prior = {}
            try:
                prior = json.loads(comp.data or "{}")
            except Exception:
                prior = {}
            prior.update(payload.data)
            comp.data = json.dumps(prior)

        db.add(comp)
        db.commit()
        db.refresh(comp)

        data = {}
        try:
            data = json.loads(comp.data or "{}")
        except Exception:
            data = {}
        return models.CompanyOut(
            id=comp.id,
            name=comp.name,
            status=comp.status,
            data=data,
            created_at=comp.created_at,
            updated_at=comp.updated_at
        )
    finally:
        db.close()


@router.delete("/companies/{company_id}")
def delete_company(company_id: int):
    db = SessionLocal()
    try:
        comp = db.get(Company, company_id)
        if not comp:
            raise HTTPException(status_code=404, detail="Company not found")
       
        # Cascade delete all company-associated records
        db.query(AgentTask).filter(AgentTask.company_id == company_id).delete()
        db.query(SocialAccount).filter(SocialAccount.company_id == company_id).delete()
        db.query(ChatMessageRecord).filter(ChatMessageRecord.company_id == company_id).delete()
        db.query(CompanyKnowledge).filter(CompanyKnowledge.company_id == company_id).delete()
        db.query(LeadInteraction).filter(LeadInteraction.company_id == company_id).delete()
        db.query(InboundLead).filter(InboundLead.company_id == company_id).delete()
        db.query(IntegrationConfig).filter(IntegrationConfig.company_id == company_id).delete()
        db.delete(comp)
        db.commit()
        return {"status": "deleted", "company_id": company_id}
    finally:
        db.close()


@router.post("/companies/{company_id}/profile")
def save_company_profile(company_id: int, payload: dict):
    """Save or merge structured company profile details."""
    db = SessionLocal()
    try:
        comp = db.get(Company, company_id)
        if not comp:
            raise HTTPException(status_code=404, detail="Company not found")

        prior_data = {}
        try:
            prior_data = json.loads(comp.data or "{}")
        except Exception:
            prior_data = {}

        merged = {**prior_data, **payload}
        new_name = payload.get("company_name") or payload.get("name")
        if new_name:
            comp.name = str(new_name).strip()
        comp.data = json.dumps(merged)
        comp.status = "configured"
        db.add(comp)
        db.commit()
        db.refresh(comp)
        return {"status": "saved", "company_id": company_id, "data": merged}
    finally:
        db.close()


@router.post("/companies/{company_id}/generate-plan")
async def generate_company_plan(company_id: int, payload: Optional[dict] = None):
    """Generate a comprehensive, executive-grade AI business plan."""
    db = SessionLocal()
    try:
        comp = db.get(Company, company_id)
        if not comp:
            raise HTTPException(status_code=404, detail="Company not found")

        company_data = {}
        try:
            company_data = json.loads(comp.data or "{}") if comp.data else {}
        except Exception:
            company_data = {}

        if payload:
            company_data = {**company_data, **payload}

        c_name = company_data.get('company_name') or company_data.get('name') or comp.name
        industry = company_data.get('industry', 'Technology & Digital Services')
        location = company_data.get('location', 'Global')
        business_model = company_data.get('business_model', 'B2B / Services/B2C/Freelancer')
        target_audience = company_data.get('target_audience', 'Enterprise & Mid-Market')
        budget = company_data.get('budget', 'Low eg: 20k / Medium: 50k / High: 100k / Very High: 200k+')
        goals = company_data.get('goals', 'Create a Comprehensive Strategy')

        prompt = f"""
Create a master business plan and execution strategy for this enterprise:

Company Profile:
- Name: {c_name}
- Industry: {industry}
- Location: {location}
- Business Model: {business_model}
- Target Audience: {target_audience}
- Operating Budget: {budget}
- Primary Objectives: {goals}

Deliver the master plan with these detailed sections:
# {c_name} — Master Business Strategy & Operating Plan

## 1. Executive Summary & Value Proposition
## 2. Market Opportunity & Competitive Moat
## 3. Product & Technology Roadmap (Phases 1 - 3)
## 4. Growth & Customer Acquisition Engine (Omnichannel)
## 5. 30-60-90 Day Launch & Milestone Matrix
## 6. Financial Forecast & Unit Economics Model
## 7. Autonomous AI Agent Automation Playbook
## 8. Critical KPIs & Immediate Next Actions
"""
        system_prompt = "You are a world-class venture partner, business strategist, and growth architect."
        summary = await llm.generate(prompt, system_prompt=system_prompt, agent_type="strategy")

        company_data["generated_plan"] = summary
        comp.data = json.dumps(company_data)
        comp.status = "plan_generated"
        db.add(comp)
        db.commit()

        return {
            "status": "ok",
            "company_id": company_id,
            "company_name": c_name,
            "plan": summary
        }
    finally:
        db.close()


@router.post("/companies/{company_id}/run")
async def run_company_orchestration(company_id: int, payload: Optional[models.OrchestrateRequest] = None):

    db = SessionLocal()
    try:
        comp = db.get(Company, company_id)
        if not comp:
            raise HTTPException(status_code=404, detail="Company not found")
        comp.status = "running"
        db.add(comp)
        db.commit()
    finally:
        db.close()

    agents = payload.agents if payload and payload.agents else None
    asyncio.create_task(orchestrate(company_id, agents=agents))

    return {
        "status": "started",
        "company_id": company_id,
        "agents": agents or ["strategy", "product", "marketing", "finance", "social_media"]
    }


@router.post("/companies/{company_id}/run-agent/{agent_type}")
async def run_single_agent_endpoint(company_id: int, agent_type: str):
   
    db = SessionLocal()
    try:
        comp = db.get(Company, company_id)
        if not comp:
            raise HTTPException(status_code=404, detail="Company not found")
    finally:
        db.close()

    task_id = await run_single_agent(company_id, agent_type)
    return {"status": "completed", "company_id": company_id, "agent_type": agent_type, "task_id": task_id}


@router.get("/companies/{company_id}/tasks", response_model=List[models.TaskOut])
def list_company_tasks(company_id: int):
    db = SessionLocal()
    try:
        tasks = db.query(AgentTask).filter(AgentTask.company_id == company_id).order_by(AgentTask.id.desc()).all()
        return tasks
    finally:
        db.close()


@router.get("/tasks", response_model=List[models.TaskOut])
def list_all_tasks(limit: int = 100, agent_type: Optional[str] = None):
    db = SessionLocal()
    try:
        q = db.query(AgentTask)
        if agent_type:
            q = q.filter(AgentTask.agent_type == agent_type)
        return q.order_by(AgentTask.id.desc()).limit(limit).all()
    finally:
        db.close()


@router.get("/tasks/{task_id}", response_model=models.TaskOut)
def get_task(task_id: int):
    db = SessionLocal()
    try:
        task = db.get(AgentTask, task_id)
        if not task:
            raise HTTPException(status_code=404, detail="Task not found")
        return task
    finally:
        db.close()


@router.post("/companies/{company_id}/social_accounts", response_model=social_models.SocialAccountOut)
def add_social_account(company_id: int, payload: social_models.SocialAccountCreate):
    db = SessionLocal()
    try:
        comp = db.get(Company, company_id)
        if not comp:
            raise HTTPException(status_code=404, detail="Company not found")
        creds_str = json.dumps(payload.credentials or {})
        acc = SocialAccount(
            company_id=company_id,
            platform=payload.platform.lower().strip(),
            credentials=creds_str,
            label=payload.label or f"{payload.platform.capitalize()} Account"
        )
        db.add(acc)
        db.commit()
        db.refresh(acc)
        return acc
    finally:
        db.close()


@router.get("/companies/{company_id}/social_accounts", response_model=List[social_models.SocialAccountOut])
def list_social_accounts(company_id: int):
    db = SessionLocal()
    try:
        return db.query(SocialAccount).filter(SocialAccount.company_id == company_id).all()
    finally:
        db.close()


@router.delete("/companies/{company_id}/social_accounts/{account_id}")
def delete_social_account(company_id: int, account_id: int):
    db = SessionLocal()
    try:
        acc = db.get(SocialAccount, account_id)
        if not acc or acc.company_id != company_id:
            raise HTTPException(status_code=404, detail="Social account not found")
        db.delete(acc)
        db.commit()
        return {"status": "deleted", "account_id": account_id}
    finally:
        db.close()


@router.post("/companies/{company_id}/post")
async def post_to_social(company_id: int, body: models.SocialPostRequest):
    
    db = SessionLocal()
    try:
        comp = db.get(Company, company_id)
        if not comp:
            raise HTTPException(status_code=404, detail="Company not found")

        accs = db.query(SocialAccount).filter(SocialAccount.company_id == company_id).all()
    finally:
        db.close()

    results = []
    if accs:
        for a in accs:
            if body.platforms and a.platform not in body.platforms:
                continue
            creds = {}
            try:
                creds = json.loads(a.credentials or "{}")
            except Exception:
                creds = {}
            if body.image_url:
                creds["image_url"] = body.image_url
            res = await social.post(a.platform, body.content, credentials=creds, label=a.label)
            results.append({"account_id": a.id, "platform": a.platform, "result": res})
    else:
        # If no accounts configured yet, perform multi-channel dispatch simulation
        targets = body.platforms or ["twitter", "linkedin", "instagram", "whatsapp"]
        for p in targets:
            creds = {"image_url": body.image_url} if body.image_url else None
            res = await social.post(p, body.content, credentials=creds, label=f"Demo {p.capitalize()}")
            results.append({"account_id": 0, "platform": p, "result": res})

    return {
        "status": "success",
        "company_id": company_id,
        "channels_dispatched": len(results),
        "results": results
    }



@router.get("/auth/instagram/start")
def instagram_oauth_start(company_id: int):
    app_id = os.getenv("FACEBOOK_APP_ID")
    redirect = os.getenv("INSTAGRAM_OAUTH_REDIRECT_URI")
    if not app_id or not redirect:
        return {
            "auth_url": f"https://example.com/oauth/simulated?company_id={company_id}",
            "note": "Set FACEBOOK_APP_ID and INSTAGRAM_OAUTH_REDIRECT_URI in backend/.env for live Graph API."
        }
    scopes = "instagram_basic,instagram_content_publish,pages_show_list,pages_read_engagement"
    url = f"https://www.facebook.com/v17.0/dialog/oauth?client_id={app_id}&redirect_uri={redirect}&scope={scopes}&response_type=code&state={company_id}"
    return {"auth_url": url}


@router.get("/auth/instagram/callback")
async def instagram_oauth_callback(code: Optional[str] = None, state: Optional[str] = None):
    if not code or not state:
        raise HTTPException(status_code=400, detail="Missing code or state in callback")

    app_id = os.getenv("FACEBOOK_APP_ID")
    app_secret = os.getenv("FACEBOOK_APP_SECRET")
    redirect = os.getenv("INSTAGRAM_OAUTH_REDIRECT_URI")

    if not app_id or not app_secret or not redirect:
        
        db = SessionLocal()
        try:
            company_id = int(state)
            creds = {"access_token": "simulated_token_xyz", "ig_user_id": "17841400000000"}
            acc = SocialAccount(company_id=company_id, platform="instagram", credentials=json.dumps(creds), label="Instagram Business (Dev)")
            db.add(acc)
            db.commit()
        finally:
            db.close()
        return {"status": "ok", "company_id": state, "note": "OAuth simulated development credentials saved."}

    
    token_url = f"https://graph.facebook.com/v17.0/oauth/access_token?client_id={app_id}&redirect_uri={redirect}&client_secret={app_secret}&code={code}"
    async with httpx.AsyncClient(timeout=30.0) as client:
        r = await client.get(token_url)
        r.raise_for_status()
        short_token = r.json().get("access_token")

        exch_url = f"https://graph.facebook.com/v17.0/oauth/access_token?grant_type=fb_exchange_token&client_id={app_id}&client_secret={app_secret}&fb_exchange_token={short_token}"
        r2 = await client.get(exch_url)
        r2.raise_for_status()
        long_token = r2.json().get("access_token")

        pages_url = f"https://graph.facebook.com/v17.0/me/accounts?access_token={long_token}"
        r3 = await client.get(pages_url)
        r3.raise_for_status()
        pages = r3.json().get("data", [])
        ig_id = None
        for p in pages:
            if p.get("instagram_business_account"):
                ig_id = p["instagram_business_account"].get("id")
                break

        if not ig_id:
            raise HTTPException(status_code=400, detail="No Instagram Business account connected to Facebook Page")

        db = SessionLocal()
        try:
            company_id = int(state)
            creds = {"access_token": long_token, "ig_user_id": ig_id}
            acc = SocialAccount(company_id=company_id, platform="instagram", credentials=json.dumps(creds), label="Instagram Business Account")
            db.add(acc)
            db.commit()
        finally:
            db.close()

    return {"status": "ok", "company_id": state, "ig_user_id": ig_id}




@router.get("/companies/{company_id}/knowledge", response_model=List[models.KnowledgeOut])
def get_company_knowledge(company_id: int):
   
    db = SessionLocal()
    try:
        items = db.query(CompanyKnowledge).filter(
            CompanyKnowledge.company_id == company_id
        ).order_by(CompanyKnowledge.id.desc()).all()
        return items
    finally:
        db.close()


@router.post("/companies/{company_id}/knowledge", response_model=models.KnowledgeOut)
def add_company_knowledge(company_id: int, payload: models.KnowledgeCreate):
   
    db = SessionLocal()
    try:
        comp = db.get(Company, company_id)
        if not comp:
            raise HTTPException(status_code=404, detail="Company not found")

        item = CompanyKnowledge(
            company_id=company_id,
            title=payload.title,
            category=payload.category or "general",
            content=payload.content
        )
        db.add(item)
        db.commit()
        db.refresh(item)
        return item
    finally:
        db.close()


@router.delete("/companies/{company_id}/knowledge/{knowledge_id}")
def delete_company_knowledge(company_id: int, knowledge_id: int):
    
    db = SessionLocal()
    try:
        item = db.get(CompanyKnowledge, knowledge_id)
        if not item or item.company_id != company_id:
            raise HTTPException(status_code=404, detail="Knowledge item not found")
        db.delete(item)
        db.commit()
        return {"status": "deleted", "id": knowledge_id}
    finally:
        db.close()


@router.post("/companies/{company_id}/knowledge/seed/{preset_type}")
def seed_company_knowledge_preset(company_id: int, preset_type: str = "indian_tea"):
    
    db = SessionLocal()
    try:
        comp = db.get(Company, company_id)
        if not comp:
            raise HTTPException(status_code=404, detail="Company not found")
    finally:
        db.close()

    KnowledgeEngine.seed_company_preset(company_id, preset_type=preset_type)
    return {"status": "seeded", "preset": preset_type, "company_id": company_id}




@router.get("/companies/{company_id}/integrations", response_model=List[models.IntegrationConfigOut])
def get_company_integrations(company_id: int):
   
    db = SessionLocal()
    try:
        configs = db.query(IntegrationConfig).filter(
            IntegrationConfig.company_id == company_id
        ).all()
        res = []
        for cfg in configs:
            parsed = {}
            try:
                parsed = json.loads(cfg.config or "{}")
            except Exception:
                parsed = {}
            res.append(models.IntegrationConfigOut(
                id=cfg.id,
                company_id=cfg.company_id,
                channel=cfg.channel,
                config=parsed,
                is_active=bool(cfg.is_active),
                created_at=cfg.created_at,
                updated_at=cfg.updated_at
            ))
        return res
    finally:
        db.close()


@router.post("/companies/{company_id}/integrations", response_model=models.IntegrationConfigOut)
def save_company_integration(company_id: int, payload: models.IntegrationConfigCreate):
    
    db = SessionLocal()
    try:
        comp = db.get(Company, company_id)
        if not comp:
            raise HTTPException(status_code=404, detail="Company not found")

        cfg = db.query(IntegrationConfig).filter(
            IntegrationConfig.company_id == company_id,
            IntegrationConfig.channel == payload.channel.lower().strip()
        ).first()

        if not cfg:
            cfg = IntegrationConfig(
                company_id=company_id,
                channel=payload.channel.lower().strip(),
                config=json.dumps(payload.config),
                is_active=1 if payload.is_active else 0
            )
            db.add(cfg)
        else:
            prior = {}
            try:
                prior = json.loads(cfg.config or "{}")
            except Exception:
                prior = {}
            prior.update(payload.config)
            cfg.config = json.dumps(prior)
            cfg.is_active = 1 if payload.is_active else 0

        db.commit()
        db.refresh(cfg)

        parsed = {}
        try:
            parsed = json.loads(cfg.config or "{}")
        except Exception:
            parsed = {}

        return models.IntegrationConfigOut(
            id=cfg.id,
            company_id=cfg.company_id,
            channel=cfg.channel,
            config=parsed,
            is_active=bool(cfg.is_active),
            created_at=cfg.created_at,
            updated_at=cfg.updated_at
        )
    finally:
        db.close()




@router.post("/leads/capture", response_model=models.LeadCaptureResponse)
async def capture_inbound_lead(payload: models.InboundLeadCreate):
   
    db = SessionLocal()
    company_id = payload.company_id
    if not company_id:
        
        latest_comp = db.query(Company).order_by(Company.id.desc()).first()
        company_id = latest_comp.id if latest_comp else 1

    try:
       
        lead = InboundLead(
            company_id=company_id,
            name=payload.name.strip(),
            phone=payload.phone.strip() if payload.phone else None,
            email=payload.email.strip() if payload.email else None,
            source=payload.source or "ad",
            interest=payload.interest or "Inquiry",
            status="new",
            custom_data=json.dumps(payload.custom_data or {})
        )
        db.add(lead)
        db.commit()
        db.refresh(lead)

        whatsapp_res_text = None
        email_res_text = None
        channels_notified = []

        if payload.auto_respond:
           
            kb_context = KnowledgeEngine.get_company_context(company_id, query=payload.interest)

           
            integrations = db.query(IntegrationConfig).filter(
                IntegrationConfig.company_id == company_id,
                IntegrationConfig.is_active == 1
            ).all()
            cred_map = {}
            for i in integrations:
                try:
                    cred_map[i.channel] = json.loads(i.config or "{}")
                except Exception:
                    cred_map[i.channel] = {}

            
            if payload.phone:
                wa_prompt = (
                    f"Action: lead_whatsapp_responder\n"
                    f"Lead Name: {payload.name}\n"
                    f"Phone: {payload.phone}\n"
                    f"Source: {payload.source}\n"
                    f"Interest: {payload.interest}\n\n"
                    f"Company Training & Knowledge Base:\n{kb_context}\n\n"
                    "Craft a warm, high-converting, concise WhatsApp message in the company's brand voice addressing the lead by name, highlighting their requested product/service, presenting an exclusive welcome offer/coupon, and giving a clear call to action."
                )
                wa_message = await llm.generate(
                    wa_prompt,
                    system_prompt="You are the Autonomous WhatsApp Customer Concierge AI.",
                    agent_type="marketing"
                )
                whatsapp_res_text = wa_message

               
                wa_result = await whatsapp_adapter.send_message(
                    to_phone=payload.phone,
                    message=wa_message,
                    credentials=cred_map.get("whatsapp")
                )

                
                db.add(LeadInteraction(
                    lead_id=lead.id,
                    company_id=company_id,
                    channel="whatsapp",
                    direction="outbound",
                    message=wa_message,
                    status=wa_result.get("status", "sent"),
                    provider_response=json.dumps(wa_result)
                ))
                channels_notified.append("whatsapp")

           
            if payload.email:
                mail_prompt = (
                    f"Action: lead_email_responder\n"
                    f"Lead Name: {payload.name}\n"
                    f"Email: {payload.email}\n"
                    f"Source: {payload.source}\n"
                    f"Interest: {payload.interest}\n\n"
                    f"Company Training & Knowledge Base:\n{kb_context}\n\n"
                    "Write a professional, beautifully formatted onboarding email including Subject line, value proposition, verified company details, and next steps."
                )
                mail_content = await llm.generate(
                    mail_prompt,
                    system_prompt="You are the Autonomous Client Engagement Executive AI.",
                    agent_type="marketing"
                )
                email_res_text = mail_content

               
                subject = "Welcome & Next Steps"
                for line in mail_content.splitlines():
                    if line.lower().startswith("subject:"):
                        subject = line.split(":", 1)[1].strip()
                        break

               
                mail_result = await email_adapter.send_email(
                    to_email=payload.email,
                    subject=subject,
                    html_content=f"<div style='font-family:sans-serif;line-height:1.6;color:#1e293b;'><pre style='white-space:pre-wrap;font-family:inherit;'>{mail_content}</pre></div>",
                    credentials=cred_map.get("email")
                )

                
                db.add(LeadInteraction(
                    lead_id=lead.id,
                    company_id=company_id,
                    channel="email",
                    direction="outbound",
                    message=mail_content,
                    status=mail_result.get("status", "sent"),
                    provider_response=json.dumps(mail_result)
                ))
                channels_notified.append("email")

            lead.status = "contacted"
            db.commit()

        return models.LeadCaptureResponse(
            status="processed",
            lead_id=lead.id,
            company_id=company_id,
            whatsapp_response=whatsapp_res_text,
            email_response=email_res_text,
            wa_link=wa_result.get("wa_link") if "wa_result" in locals() and wa_result else None,
            mailto_link=mail_result.get("mailto_link") if "mail_result" in locals() and mail_result else None,
            channels_notified=channels_notified,
            message=f"Lead captured successfully for {payload.name} and auto-responded via {', '.join(channels_notified) if channels_notified else 'none'}."
        )
    finally:
        db.close()


@router.get("/companies/{company_id}/leads", response_model=List[models.InboundLeadOut])
def get_company_leads(company_id: int):
    """Retrieve all inbound leads and interaction histories for a company."""
    db = SessionLocal()
    try:
        leads = db.query(InboundLead).filter(
            InboundLead.company_id == company_id
        ).order_by(InboundLead.id.desc()).all()

        res = []
        for l in leads:
            interactions = db.query(LeadInteraction).filter(
                LeadInteraction.lead_id == l.id
            ).order_by(LeadInteraction.id.asc()).all()

            int_outs = [
                models.LeadInteractionOut(
                    id=i.id,
                    lead_id=i.lead_id,
                    company_id=i.company_id,
                    channel=i.channel,
                    direction=i.direction,
                    message=i.message,
                    status=i.status,
                    provider_response=i.provider_response,
                    created_at=i.created_at
                ) for i in interactions
            ]

            res.append(models.InboundLeadOut(
                id=l.id,
                company_id=l.company_id,
                name=l.name,
                phone=l.phone,
                email=l.email,
                source=l.source,
                interest=l.interest,
                status=l.status,
                custom_data=l.custom_data,
                created_at=l.created_at,
                updated_at=l.updated_at,
                interactions=int_outs
            ))
        return res
    finally:
        db.close()




@router.post("/companies/{company_id}/send-whatsapp")
async def send_direct_whatsapp(company_id: int, payload: models.DirectWhatsAppRequest):
    """Send a custom or broadcast WhatsApp message directly."""
    db = SessionLocal()
    try:
        cfg = db.query(IntegrationConfig).filter(
            IntegrationConfig.company_id == company_id,
            IntegrationConfig.channel == "whatsapp"
        ).first()
        creds = json.loads(cfg.config or "{}") if cfg else {}

        res = await whatsapp_adapter.send_message(
            to_phone=payload.phone,
            message=payload.message,
            credentials=creds
        )

        if payload.lead_id:
            db.add(LeadInteraction(
                lead_id=payload.lead_id,
                company_id=company_id,
                channel="whatsapp",
                direction="outbound",
                message=payload.message,
                status=res.get("status", "sent"),
                provider_response=json.dumps(res)
            ))
            db.commit()

        return {"status": "success", "result": res}
    finally:
        db.close()


@router.post("/companies/{company_id}/send-email")
async def send_direct_email(company_id: int, payload: models.DirectEmailRequest):
    """Send a custom email directly."""
    db = SessionLocal()
    try:
        cfg = db.query(IntegrationConfig).filter(
            IntegrationConfig.company_id == company_id,
            IntegrationConfig.channel == "email"
        ).first()
        creds = json.loads(cfg.config or "{}") if cfg else {}

        res = await email_adapter.send_email(
            to_email=payload.email,
            subject=payload.subject,
            html_content=f"<div style='font-family:sans-serif;line-height:1.6;'><pre style='white-space:pre-wrap;font-family:inherit;'>{payload.content}</pre></div>",
            credentials=creds
        )

        if payload.lead_id:
            db.add(LeadInteraction(
                lead_id=payload.lead_id,
                company_id=company_id,
                channel="email",
                direction="outbound",
                message=f"Subject: {payload.subject}\n\n{payload.content}",
                status=res.get("status", "sent"),
                provider_response=json.dumps(res)
            ))
            db.commit()

        return {"status": "success", "result": res}
    finally:
        db.close()


@router.get("/config/llm")
def get_llm_status():
    """Get active LLM provider status and configured AI brain engines."""
    gemini_key = os.getenv("GEMINI_API_KEY") or os.getenv("GOOGLE_API_KEY")
    openai_key = os.getenv("OPENAI_API_KEY")
    groq_key = os.getenv("GROQ_API_KEY")
    anthropic_key = os.getenv("ANTHROPIC_API_KEY")

    active_provider = "Simulation Mode (Intelligent Heuristic)"
    if gemini_key:
        active_provider = "Google Gemini (gemini-2.5-flash / flash-latest)"
    elif openai_key and not openai_key.startswith("AIzaSy"):
        active_provider = "OpenAI (GPT-4o / GPT-4o-mini)"
    elif groq_key:
        active_provider = "Groq Cloud (Llama 3.3 70B)"
    elif anthropic_key:
        active_provider = "Anthropic (Claude 3.5 Sonnet)"

    return {
        "active_provider": active_provider,
        "is_live_ai": bool(gemini_key or (openai_key and not openai_key.startswith("AIzaSy")) or groq_key or anthropic_key),
        "providers": {
            "gemini": {
                "configured": bool(gemini_key),
                "model": "gemini-2.5-flash",
                "preview": f"{gemini_key[:6]}...{gemini_key[-4:]}" if gemini_key and len(gemini_key) > 10 else None
            },
            "openai": {
                "configured": bool(openai_key and not openai_key.startswith("AIzaSy")),
                "model": "gpt-4o-mini",
                "preview": f"{openai_key[:6]}...{openai_key[-4:]}" if openai_key and len(openai_key) > 10 else None
            },
            "groq": {
                "configured": bool(groq_key),
                "model": "llama-3.3-70b-versatile",
                "preview": f"{groq_key[:6]}...{groq_key[-4:]}" if groq_key and len(groq_key) > 10 else None
            },
            "anthropic": {
                "configured": bool(anthropic_key),
                "model": "claude-3-5-sonnet",
                "preview": f"{anthropic_key[:6]}...{anthropic_key[-4:]}" if anthropic_key and len(anthropic_key) > 10 else None
            }
        }
    }


@router.post("/config/llm")
def update_llm_config(payload: dict):
    """Update API keys for LLM providers and save to .env."""
    env_path = Path(__file__).resolve().parent / ".env"
    
    # Read existing env lines
    env_lines = []
    if env_path.exists():
        env_lines = env_path.read_text().splitlines()

    env_dict = {}
    for line in env_lines:
        line = line.strip()
        if line and not line.startswith("#") and "=" in line:
            k, v = line.split("=", 1)
            env_dict[k.strip()] = v.strip()

    # Update with new values
    if "gemini_api_key" in payload:
        val = str(payload["gemini_api_key"]).strip()
        env_dict["GEMINI_API_KEY"] = val
        os.environ["GEMINI_API_KEY"] = val
    if "openai_api_key" in payload:
        val = str(payload["openai_api_key"]).strip()
        env_dict["OPENAI_API_KEY"] = val
        os.environ["OPENAI_API_KEY"] = val
    if "groq_api_key" in payload:
        val = str(payload["groq_api_key"]).strip()
        env_dict["GROQ_API_KEY"] = val
        os.environ["GROQ_API_KEY"] = val
    if "anthropic_api_key" in payload:
        val = str(payload["anthropic_api_key"]).strip()
        env_dict["ANTHROPIC_API_KEY"] = val
        os.environ["ANTHROPIC_API_KEY"] = val

    # Write back to .env
    output_lines = [
        "# Autonomous Multi-Agent AI Engine Configuration",
        f"GEMINI_API_KEY={env_dict.get('GEMINI_API_KEY', '')}",
        f"OPENAI_API_KEY={env_dict.get('OPENAI_API_KEY', '')}",
        f"GROQ_API_KEY={env_dict.get('GROQ_API_KEY', '')}",
        f"ANTHROPIC_API_KEY={env_dict.get('ANTHROPIC_API_KEY', '')}",
        "",
        "# Social Media & Webhook Callbacks",
        f"FACEBOOK_APP_ID={env_dict.get('FACEBOOK_APP_ID', '')}",
        f"FACEBOOK_APP_SECRET={env_dict.get('FACEBOOK_APP_SECRET', '')}",
        f"INSTAGRAM_OAUTH_REDIRECT_URI={env_dict.get('INSTAGRAM_OAUTH_REDIRECT_URI', 'http://localhost:8001/api/auth/instagram/callback')}"
    ]
    env_path.write_text("\n".join(output_lines) + "\n")

    return get_llm_status()


@router.post("/config/llm/test")
async def test_llm_connectivity(payload: Optional[dict] = None):
    """Test live LLM connectivity with a custom prompt."""
    test_prompt = (payload.get("prompt") if payload else None) or "Introduce yourself as our autonomous business AI and confirm you are live."
    response_text = await llm.generate(
        test_prompt,
        system_prompt="You are an elite, highly capable autonomous enterprise AI assistant like ChatGPT and Gemini."
    )
    status = get_llm_status()
    return {
        "status": "success",
        "provider": status["active_provider"],
        "is_live_ai": status["is_live_ai"],
        "test_prompt": test_prompt,
        "response": response_text
    }


