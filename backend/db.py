from pathlib import Path
from sqlalchemy import create_engine, Column, Integer, String, Text, DateTime, inspect, text
from sqlalchemy.orm import sessionmaker, declarative_base
import datetime

BASE_DIR = Path(__file__).resolve().parent.parent
DATABASE_URL = f"sqlite:///{(BASE_DIR / 'business_agents.db').as_posix()}"

engine = create_engine(DATABASE_URL, connect_args={"check_same_thread": False})
SessionLocal = sessionmaker(bind=engine, autoflush=False, autocommit=False)
Base = declarative_base()


class Company(Base):
    __tablename__ = "companies"
    id = Column(Integer, primary_key=True, index=True)
    name = Column(String, index=True)
    status = Column(String, default="created")  
    data = Column(Text, default="{}")           
    created_at = Column(DateTime, default=datetime.datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.datetime.utcnow, onupdate=datetime.datetime.utcnow)


class AgentTask(Base):
    __tablename__ = "tasks"
    id = Column(Integer, primary_key=True, index=True)
    company_id = Column(Integer, index=True)
    agent_type = Column(String, index=True)      
    title = Column(String, default="")
    status = Column(String, default="pending")  
    result = Column(Text, default="")
    error = Column(Text, default="")
    created_at = Column(DateTime, default=datetime.datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.datetime.utcnow, onupdate=datetime.datetime.utcnow)


class SocialAccount(Base):
    __tablename__ = "social_accounts"
    id = Column(Integer, primary_key=True, index=True)
    company_id = Column(Integer, index=True)
    platform = Column(String, index=True)        
    credentials = Column(Text, default="{}")   
    label = Column(String, default="")
    created_at = Column(DateTime, default=datetime.datetime.utcnow)


class ChatMessageRecord(Base):
    __tablename__ = "chat_messages"
    id = Column(Integer, primary_key=True, index=True)
    company_id = Column(Integer, index=True, nullable=True)
    sender = Column(String)                     
    content = Column(Text)
    created_at = Column(DateTime, default=datetime.datetime.utcnow)


class CompanyKnowledge(Base):
    __tablename__ = "company_knowledge"
    id = Column(Integer, primary_key=True, index=True)
    company_id = Column(Integer, index=True)
    title = Column(String, index=True)           
    category = Column(String, default="general") 
    content = Column(Text)                      
    created_at = Column(DateTime, default=datetime.datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.datetime.utcnow, onupdate=datetime.datetime.utcnow)


class InboundLead(Base):
    __tablename__ = "inbound_leads"
    id = Column(Integer, primary_key=True, index=True)
    company_id = Column(Integer, index=True)
    name = Column(String, index=True)
    phone = Column(String, index=True, nullable=True)
    email = Column(String, index=True, nullable=True)
    source = Column(String, default="ad")       
    interest = Column(Text, default="")          
    status = Column(String, default="new")      
    custom_data = Column(Text, default="{}")     
    created_at = Column(DateTime, default=datetime.datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.datetime.utcnow, onupdate=datetime.datetime.utcnow)


class LeadInteraction(Base):
    __tablename__ = "lead_interactions"
    id = Column(Integer, primary_key=True, index=True)
    lead_id = Column(Integer, index=True)
    company_id = Column(Integer, index=True)
    channel = Column(String, index=True)         
    direction = Column(String, default="outbound") 
    message = Column(Text)
    status = Column(String, default="sent")      
    provider_response = Column(Text, default="{}") 
    created_at = Column(DateTime, default=datetime.datetime.utcnow)


class IntegrationConfig(Base):
    __tablename__ = "integration_configs"
    id = Column(Integer, primary_key=True, index=True)
    company_id = Column(Integer, index=True)
    channel = Column(String, index=True)         
    config = Column(Text, default="{}")          
    is_active = Column(Integer, default=1)      
    created_at = Column(DateTime, default=datetime.datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.datetime.utcnow, onupdate=datetime.datetime.utcnow)


def init_db():
    
    Base.metadata.create_all(bind=engine)

   
    with engine.connect() as conn:
        inspector = inspect(engine)

        if "companies" in inspector.get_table_names():
            columns = [col["name"] for col in inspector.get_columns("companies")]
            if "updated_at" not in columns:
                conn.execute(text("ALTER TABLE companies ADD COLUMN updated_at DATETIME"))
            if "data" not in columns:
                conn.execute(text("ALTER TABLE companies ADD COLUMN data TEXT DEFAULT '{}'"))

        if "tasks" in inspector.get_table_names():
            columns = [col["name"] for col in inspector.get_columns("tasks")]
            if "title" not in columns:
                conn.execute(text("ALTER TABLE tasks ADD COLUMN title VARCHAR DEFAULT ''"))
            if "error" not in columns:
                conn.execute(text("ALTER TABLE tasks ADD COLUMN error TEXT DEFAULT ''"))
            if "updated_at" not in columns:
                conn.execute(text("ALTER TABLE tasks ADD COLUMN updated_at DATETIME"))

        conn.commit()

