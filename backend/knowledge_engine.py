import json
from typing import List, Dict, Any, Optional
from .db import SessionLocal, Company, CompanyKnowledge


class KnowledgeEngine:
   
    @staticmethod
    def get_company_context(company_id: int, query: Optional[str] = None) -> str:
        session = SessionLocal()
        try:
            comp = session.get(Company, company_id)
            if not comp:
                return ""

            company_meta = {}
            try:
                company_meta = json.loads(comp.data or "{}")
            except Exception:
                company_meta = {}

            company_name = comp.name or company_meta.get("company_name", "Enterprise")
            industry = company_meta.get("industry", "Business")
            location = company_meta.get("location", "Global")
            target_audience = company_meta.get("target_audience", "General")
            business_model = company_meta.get("business_model", "Direct")

            
            knowledge_items = session.query(CompanyKnowledge).filter(
                CompanyKnowledge.company_id == company_id
            ).all()

            context_sections = [
                f"### COMPANY PROFILE: {company_name}",
                f"- Industry: {industry}",
                f"- Location: {location}",
                f"- Business Model: {business_model}",
                f"- Target Audience: {target_audience}",
            ]

            if company_meta.get("goals"):
                context_sections.append(f"- Objectives: {company_meta.get('goals')}")

            if knowledge_items:
                context_sections.append("\n### VERIFIED COMPANY KNOWLEDGE BASE & TRAINING DATA:")
                for item in knowledge_items:
                    context_sections.append(
                        f"**[{item.category.upper()}] {item.title}:**\n{item.content.strip()}\n"
                    )

            return "\n".join(context_sections)
        finally:
            session.close()

    @staticmethod
    def seed_company_preset(company_id: int, preset_type: str = "indian_tea"):
        
        session = SessionLocal()
        try:
            
            existing = session.query(CompanyKnowledge).filter(CompanyKnowledge.company_id == company_id).all()
            if existing:
                return existing

            presets = []
            if preset_type == "indian_tea":
                presets = [
                    {
                        "title": "ChaiVeda Product Line & Blend Catalog",
                        "category": "product",
                        "content": (
                            "- **Royal Assam CTC Gold**: Malty, rich, full-bodied blend sourced directly from Upper Assam tea estates. Ideal for traditional Kadak Chai. Available in 250g (₹299), 500g (₹549), and 1kg (₹999).\n"
                            "- **Darjeeling Spring First Flush**: Hand-picked organic orthodox whole-leaf black tea with floral muscatel notes. Available in 100g tin (₹750).\n"
                            "- **Spiced Ayurvedic Masala Chai**: Premium Assam CTC infused with whole crushed green cardamom, cinnamon, clove, ginger, and black pepper. 250g pouch (₹349).\n"
                            "- **Kashmiri Kahwa Green Tea**: Whole green tea leaves with saffron strands, crushed almonds, and cardamom. 100g (₹599).\n"
                            "- **B2B Bulk Horeca Packs**: 5kg & 10kg master bags for cafes, corporate cafeterias, and hotels with 30-40% wholesale margin discounts."
                        )
                    },
                    {
                        "title": "Brand Voice, Tone & Messaging Guidelines",
                        "category": "brand_tone",
                        "content": (
                            "- **Tone**: Warm, hospitable, authentic Indian heritage with modern elegance (Desi hospitality meets luxury tea craftsmanship).\n"
                            "- **Key Phrases**: 'Single-estate freshness', 'From the gardens of Assam to your morning cup', 'Pure whole-leaf goodness', 'Kadak swaad, shuddh vishwas'.\n"
                            "- **Customer Approach**: Welcoming, respectful (use 'Namaste / Greetings'), always highlighting unadulterated freshness and direct-from-farmer ethical sourcing.\n"
                            "- **WhatsApp Style**: Friendly emojis (☕ 🌿 ✨), clear pricing, instant dispatch guarantees, and quick sample order link."
                        )
                    },
                    {
                        "title": "Customer FAQs & Order Policies",
                        "category": "faq",
                        "content": (
                            "- **Shipping**: Free nationwide express shipping on prepaid orders above ₹499. Dispatched within 24 hours from Guwahati & Siliguri hubs.\n"
                            "- **Cash on Delivery (COD)**: Available for domestic pin codes across India with ₹40 COD fee.\n"
                            "- **Wholesale & Bulk Inquiries**: Minimum order quantity for wholesale rates is 10kg. Custom cafe blends and private labeling available on request.\n"
                            "- **Shelf Life**: 24 months in sealed nitrogen-flushed triple-layer foil pouches."
                        )
                    },
                    {
                        "title": "Top Performing Ad Lead Auto-Responder Scripts",
                        "category": "past_campaign",
                        "content": (
                            "When someone clicks a Facebook/Instagram ad asking for 'Masala Chai' or 'Tea Samples':\n"
                            "1. Send immediate greeting via WhatsApp addressing them by first name.\n"
                            "2. Mention the specific tea they inquired about.\n"
                            "3. Offer the exclusive 'First Cup Welcome Kit' (4 blend sampler pack at 20% off with coupon `CHAI20`).\n"
                            "4. Provide direct WhatsApp ordering or website checkout link."
                        )
                    }
                ]
            elif preset_type == "saas":
                presets = [
                    {
                        "title": "CloudSync Platform Core Capabilities & Pricing",
                        "category": "product",
                        "content": (
                            "- **Starter Tier**: $49/mo for up to 5 team members. Includes core workflow automations and 10,000 monthly events.\n"
                            "- **Growth Tier**: $199/mo for up to 25 members. Includes AI copilot, unlimited webhooks, and 100,000 monthly events.\n"
                            "- **Enterprise Tier**: $799+/mo. Dedicated VPC, SSO, SLA guarantee, and 24/7 technical concierge."
                        )
                    },
                    {
                        "title": "Inbound Lead Auto-Response Playbook",
                        "category": "past_campaign",
                        "content": (
                            "When a trial signup or ad lead comes in:\n"
                            "1. Send immediate WhatsApp/Email with a 1-click sandbox demo link.\n"
                            "2. Propose a 15-minute tailored architecture review.\n"
                            "3. Include a link to the ROI calculator."
                        )
                    }
                ]

            for p in presets:
                session.add(CompanyKnowledge(
                    company_id=company_id,
                    title=p["title"],
                    category=p["category"],
                    content=p["content"]
                ))
            session.commit()
            return presets
        finally:
            session.close()
