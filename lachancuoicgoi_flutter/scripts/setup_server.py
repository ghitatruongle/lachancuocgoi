#!/usr/bin/env python3
"""
Server setup script for La Chan Cuoi Goi API
Phase 11 - Backend API Server Configuration

This script sets up a basic Flask/FastAPI server structure for the fraud detection API.
"""

import os
import json
from datetime import datetime

SERVER_DIR = "server_api"

def create_server_structure():
    """Tạo cấu trúc thư mục cho server API"""
    
    directories = [
        SERVER_DIR,
        f"{SERVER_DIR}/routes",
        f"{SERVER_DIR}/models",
        f"{SERVER_DIR}/services",
        f"{SERVER_DIR}/database",
        f"{SERVER_DIR}/tests",
        f"{SERVER_DIR}/config",
    ]
    
    for dir_path in directories:
        os.makedirs(dir_path, exist_ok=True)
        print(f"✓ Created directory: {dir_path}")
    
    return True

def create_main_server_file():
    """Tạo file server chính (FastAPI)"""
    
    content = '''"""
La Chan Cuoi Goi - Fraud Detection API Server
FastAPI implementation for phone number fraud detection
"""

from fastapi import FastAPI, HTTPException, status
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field
from typing import Optional, List
from datetime import datetime
import random

app = FastAPI(
    title="La Chan Cuoi Goi API",
    description="API for detecting fraudulent phone numbers",
    version="1.0.0"
)

# CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Configure appropriately for production
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Models
class PhoneCheckRequest(BaseModel):
    phone_number: str = Field(..., min_length=10, max_length=15)

class ReportFraudRequest(BaseModel):
    phone_number: str
    category: str
    description: str
    reported_at: datetime

class AnalysisResult(BaseModel):
    phone_number: str
    risk_level: str  # low, medium, high, unknown
    category: Optional[str] = None
    confidence: float
    tags: Optional[List[str]] = None
    last_updated: datetime

class Statistics(BaseModel):
    total_checks: int
    fraud_detected: int
    safe_numbers: int
    reports_received: int

# Mock database (replace with real DB in production)
fraud_database = {
    "0123456789": {"risk_level": "high", "category": "fraud", "confidence": 0.95},
    "0987654321": {"risk_level": "medium", "category": "telemarketing", "confidence": 0.75},
    "0168888888": {"risk_level": "low", "category": "safe", "confidence": 0.90},
}

statistics = {
    "total_checks": 0,
    "fraud_detected": 0,
    "safe_numbers": 0,
    "reports_received": 0,
}

@app.get("/api/v1/health")
async def health_check():
    """Health check endpoint"""
    return {"status": "healthy", "timestamp": datetime.now().isoformat()}

@app.post("/api/v1/check", response_model=AnalysisResult)
async def check_phone_number(request: PhoneCheckRequest):
    """Check if a phone number is potentially fraudulent"""
    statistics["total_checks"] += 1
    
    phone = request.phone_number
    
    # Check database
    if phone in fraud_database:
        data = fraud_database[phone]
        statistics["fraud_detected"] += 1 if data["risk_level"] in ["high", "medium"] else 0
        
        return AnalysisResult(
            phone_number=phone,
            risk_level=data["risk_level"],
            category=data["category"],
            confidence=data["confidence"],
            tags=["verified", "community_reported"],
            last_updated=datetime.now()
        )
    
    # If not in database, return unknown
    statistics["safe_numbers"] += 1
    return AnalysisResult(
        phone_number=phone,
        risk_level="unknown",
        confidence=0.0,
        last_updated=datetime.now()
    )

@app.post("/api/v1/report", status_code=status.HTTP_201_CREATED)
async def report_fraud_number(request: ReportFraudRequest):
    """Report a fraudulent phone number from community"""
    statistics["reports_received"] += 1
    
    # In production, save to database and trigger review process
    print(f"New report received: {request.phone_number} - {request.category}")
    
    return {
        "message": "Report submitted successfully",
        "report_id": random.randint(10000, 99999),
        "status": "pending_review"
    }

@app.get("/api/v1/statistics", response_model=Statistics)
async def get_statistics():
    """Get platform statistics"""
    return Statistics(**statistics)

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
'''
    
    with open(f"{SERVER_DIR}/main.py", "w", encoding="utf-8") as f:
        f.write(content)
    
    print(f"✓ Created main server file: {SERVER_DIR}/main.py")

def create_requirements_file():
    """Tạo file requirements.txt"""
    
    content = '''fastapi==0.104.1
uvicorn[standard]==0.24.0
pydantic==2.5.0
python-multipart==0.0.6
pytest==7.4.3
httpx==0.25.2
'''
    
    with open(f"{SERVER_DIR}/requirements.txt", "w", encoding="utf-8") as f:
        f.write(content)
    
    print(f"✓ Created requirements file: {SERVER_DIR}/requirements.txt")

def create_readme():
    """Tạo README cho server"""
    
    content = '''# La Chan Cuoi Goi - Fraud Detection API Server

## Setup

```bash
# Create virtual environment
python -m venv venv
source venv/bin/activate  # On Windows: venv\\Scripts\\activate

# Install dependencies
pip install -r requirements.txt

# Run server
python main.py
```

## API Endpoints

### Health Check
```
GET /api/v1/health
```

### Check Phone Number
```
POST /api/v1/check
Content-Type: application/json

{
  "phone_number": "0123456789"
}
```

### Report Fraud Number
```
POST /api/v1/report
Content-Type: application/json

{
  "phone_number": "0123456789",
  "category": "scam",
  "description": "Lừa đảo chuyển khoản",
  "reported_at": "2024-01-15T10:30:00"
}
```

### Get Statistics
```
GET /api/v1/statistics
```

## Testing

```bash
pytest tests/ -v
```

## Production Deployment

For production deployment:
1. Set up proper database (PostgreSQL recommended)
2. Configure environment variables
3. Use gunicorn instead of uvicorn
4. Set up reverse proxy (nginx)
5. Enable HTTPS
6. Configure rate limiting
7. Set up monitoring and logging
'''
    
    with open(f"{SERVER_DIR}/README.md", "w", encoding="utf-8") as f:
        f.write(content)
    
    print(f"✓ Created README: {SERVER_DIR}/README.md")

def main():
    print("=" * 60)
    print("Setting up La Chan Cuoi Goi API Server (Phase 11)")
    print("=" * 60)
    
    # Create directory structure
    create_server_structure()
    
    # Create main server file
    create_main_server_file()
    
    # Create requirements file
    create_requirements_file()
    
    # Create README
    create_readme()
    
    print("\n" + "=" * 60)
    print("✓ Server setup completed successfully!")
    print("=" * 60)
    print(f"\nTo run the server:")
    print(f"  cd {SERVER_DIR}")
    print(f"  pip install -r requirements.txt")
    print(f"  python main.py")
    print(f"\nServer will be available at: http://localhost:8000")
    print(f"API docs at: http://localhost:8000/docs")

if __name__ == "__main__":
    main()
