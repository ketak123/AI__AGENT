from pydantic import BaseModel, Field
from typing import Optional, Any, List, Dict
import datetime


class ChatRequest(BaseModel):
    prompt: str = Field(..., min_length=1, max_length=10000)
    agent_type: Optional[str] = "ai_manager"  
    company_id: Optional[int] = None


class ChatResponse(BaseModel):
    result: str
    agent_type: str = "ai_manager"
    suggestions: List[str] = []


class CompanyCreate(BaseModel):
    name: str = Field(..., min_length=1, max_length=120)
    industry: Optional[str] = None
    location: Optional[str] = None
    budget: Optional[str] = None
    goals: Optional[str] = None


class CompanyUpdate(BaseModel):
    name: Optional[str] = None
    status: Optional[str] = None
    data: Optional[Dict[str, Any]] = None


class CompanyOut(BaseModel):
    id: int
    name: str
    status: str
    data: Optional[Dict[str, Any]] = None
    created_at: Optional[datetime.datetime] = None
    updated_at: Optional[datetime.datetime] = None

    class Config:
        orm_mode = True


class TaskOut(BaseModel):
    id: int
    company_id: int
    agent_type: str
    title: Optional[str] = ""
    status: str
    result: Optional[str] = None
    error: Optional[str] = None
    created_at: Optional[datetime.datetime] = None
    updated_at: Optional[datetime.datetime] = None

    class Config:
        orm_mode = True


class PlanGenerateRequest(BaseModel):
    company_name: Optional[str] = None
    industry: Optional[str] = None
    location: Optional[str] = None
    business_model: Optional[str] = None
    target_audience: Optional[str] = None
    budget: Optional[str] = None
    goals: Optional[str] = None
    selected_tasks: Optional[List[str]] = None
    custom_tasks: Optional[str] = None
    brand: Optional[Dict[str, Any]] = None


class SocialPostRequest(BaseModel):
    content: str = Field(..., min_length=1)
    platforms: Optional[List[str]] = None  
    image_url: Optional[str] = None


class OrchestrateRequest(BaseModel):
    agents: Optional[List[str]] = None  



class KnowledgeCreate(BaseModel):
    title: str = Field(..., min_length=1, max_length=200)
    category: Optional[str] = "general"  
    content: str = Field(..., min_length=1)


class KnowledgeOut(BaseModel):
    id: int
    company_id: int
    title: str
    category: str
    content: str
    created_at: Optional[datetime.datetime] = None
    updated_at: Optional[datetime.datetime] = None

    class Config:
        orm_mode = True



class InboundLeadCreate(BaseModel):
    name: str = Field(..., min_length=1)
    phone: Optional[str] = None
    email: Optional[str] = None
    source: Optional[str] = "ad"  # "facebook_ad", "instagram_ad", "whatsapp", "website"
    interest: Optional[str] = ""
    company_id: Optional[int] = None
    custom_data: Optional[Dict[str, Any]] = None
    auto_respond: Optional[bool] = True


class LeadInteractionOut(BaseModel):
    id: int
    lead_id: int
    company_id: int
    channel: str
    direction: str
    message: str
    status: str
    provider_response: Optional[str] = "{}"
    created_at: Optional[datetime.datetime] = None

    class Config:
        orm_mode = True


class InboundLeadOut(BaseModel):
    id: int
    company_id: int
    name: str
    phone: Optional[str] = None
    email: Optional[str] = None
    source: str
    interest: str
    status: str
    custom_data: Optional[str] = "{}"
    created_at: Optional[datetime.datetime] = None
    updated_at: Optional[datetime.datetime] = None
    interactions: Optional[List[LeadInteractionOut]] = []

    class Config:
        orm_mode = True


class LeadCaptureResponse(BaseModel):
    status: str
    lead_id: int
    company_id: int
    whatsapp_response: Optional[str] = None
    email_response: Optional[str] = None
    wa_link: Optional[str] = None
    mailto_link: Optional[str] = None
    channels_notified: List[str] = []
    message: str



class DirectWhatsAppRequest(BaseModel):
    phone: str
    message: str
    lead_id: Optional[int] = None


class DirectEmailRequest(BaseModel):
    email: str
    subject: str
    content: str
    lead_id: Optional[int] = None


 
class IntegrationConfigCreate(BaseModel):
    channel: str  
    config: Dict[str, Any]
    is_active: Optional[bool] = True


class IntegrationConfigOut(BaseModel):
    id: int
    company_id: int
    channel: str
    config: Dict[str, Any]
    is_active: bool
    created_at: Optional[datetime.datetime] = None
    updated_at: Optional[datetime.datetime] = None

