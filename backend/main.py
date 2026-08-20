



from .app_main import app


if __name__ == "__main__":
    import uvicorn
    uvicorn.run("backend.app_main:app", host="0.0.0.0", port=8001, reload=True)
