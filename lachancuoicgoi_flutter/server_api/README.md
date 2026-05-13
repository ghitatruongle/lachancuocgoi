# La Chan Cuoi Goi - Fraud Detection API Server

## Setup

```bash
# Create virtual environment
python -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate

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
