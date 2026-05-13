"""
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
