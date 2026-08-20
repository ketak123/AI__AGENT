from pathlib import Path
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import FileResponse
from dotenv import load_dotenv
from .api import router
from .db import init_db

BASE_DIR = Path(__file__).resolve().parent.parent
ADMIN_HTML_PATH = BASE_DIR / "backend" / "admin.html"


load_dotenv(BASE_DIR / "backend" / ".env")

app = FastAPI(title="Business Multi-Agent System")

app.add_middleware(
    CORSMiddleware,
    
    allow_origins=["*"],
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(router, prefix="/api")


init_db()


@app.get("/")
@app.get("/admin")
def admin_index():
    return FileResponse(str(ADMIN_HTML_PATH))


if __name__ == "__main__":
    import uvicorn
    uvicorn.run("backend.app_main:app", host="0.0.0.0", port=8001, reload=True)
