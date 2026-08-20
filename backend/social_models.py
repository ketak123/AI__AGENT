from pydantic import BaseModel
from typing import Optional, Any

class SocialAccountCreate(BaseModel):
    platform: str
    credentials: dict
    label: Optional[str] = None

class SocialAccountOut(BaseModel):
    id: int
    company_id: int
    platform: str
    credentials: Optional[Any] = None
    label: Optional[str] = None

    class Config:
        orm_mode = True
