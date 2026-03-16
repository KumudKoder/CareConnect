FROM python:3.11-slim

ENV PYTHONUNBUFFERED=True
ENV APP_HOME=/app
WORKDIR $APP_HOME

RUN pip install --no-cache-dir fastmcp

COPY server.py .

CMD ["python", "server.py"]
