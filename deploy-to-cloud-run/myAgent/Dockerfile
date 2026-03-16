FROM python:3.11-slim

ENV PYTHONUNBUFFERED=True
ENV APP_HOME=/app
WORKDIR $APP_HOME

RUN pip install --no-cache-dir google-adk google-genai python-dotenv uvicorn a2a-sdk

COPY agent.py .
COPY a2a_main.py .
COPY __init__.py .

CMD ["uvicorn", "a2a_main:a2a_app", "--host", "0.0.0.0", "--port", "8080"]