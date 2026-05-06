@echo off
echo Starting Cloudflare Tunnel for Call Supervisor Server...
echo.
echo NOTE: You must have the server running on port 3000 first!
echo.
cloudflared tunnel --url http://localhost:3000
