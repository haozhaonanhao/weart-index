# backend/core/config.py
import os

DATABASE_URL  = os.getenv("DATABASE_URL", "postgresql+asyncpg://postgres:postgres@localhost:5432/weart")
SECRET_KEY    = os.getenv("SECRET_KEY", "change-me-in-production")
ELASTICSEARCH = os.getenv("ELASTICSEARCH_URL", "http://localhost:9200")
AI_API_KEY    = os.getenv("AI_API_KEY", "")          # DeepSeek / OpenAI API key
AI_API_URL    = os.getenv("AI_API_URL", "https://api.deepseek.com/v1")
DEBUG         = os.getenv("DEBUG", "true").lower() == "true"
