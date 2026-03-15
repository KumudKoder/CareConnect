# Use a lightweight Python 3.10+ image
FROM python:3.10-slim

# Set working directory
WORKDIR /app

# Install dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY main.py .

# Cloud Run expects the service to listen on the PORT environment variable
ENV PORT=8080

# Run the FastAPI server using uvicorn
CMD ["python", "main.py"]