require('dotenv').config();
const express = require('express');
const http = require('http');
const { Server } = require('socket.io');
const cors = require('cors');

const app = express();
const server = http.createServer(app);
const io = new Server(server, {
  cors: {
    origin: '*',
    methods: ['GET', 'POST']
  }
});

app.use(cors());
app.use(express.urlencoded({ extended: true }));
app.use(express.json());

const PORT = process.env.PORT || 3000;

const isTwilioConfigured = () => {
  return process.env.TWILIO_ACCOUNT_SID &&
         process.env.TWILIO_AUTH_TOKEN &&
         process.env.TWILIO_ACCOUNT_SID !== 'your_twilio_account_sid';
};

if (isTwilioConfigured()) {
  const twilioRoutes = require('./routes/twilioRoutes');
  app.use('/twilio', twilioRoutes);
  app.use('/webhook', twilioRoutes);
  console.log('Twilio routes enabled');
} else {
  app.post('/incoming-call', (req, res) => {
    console.log('Twilio not configured - simulating incoming call webhook');
    console.log('Body:', req.body);
    const twiml = `<?xml version="1.0" encoding="UTF-8"?>
<Response>
  <Say language="vi-VN">Xin chào, cuộc gọi này đang được giám sát.</Say>
  <Dial>
    <Conference beep="false" startConferenceOnEnter="true" endConferenceOnExit="false">supervised-call</Conference>
  </Dial>
</Response>`;
    res.type('text/xml').send(twiml);
  });
  console.log('Twilio not configured - using mock endpoint');
}

const AudioStreamHandler = require('./services/audioStreamHandler');
const audioHandler = new AudioStreamHandler(io);
audioHandler.initialize();

io.on('connection', (socket) => {
  console.log(`Client connected: ${socket.id}`);

  audioHandler.handleConnection(socket);

  socket.on('disconnect', () => {
    console.log(`Client disconnected: ${socket.id}`);
  });
});

app.get('/health', (req, res) => {
  res.json({
    status: 'ok',
    timestamp: new Date().toISOString(),
    twilioConfigured: isTwilioConfigured(),
    activeSessions: audioHandler.getActiveSessions().length
  });
});

app.get('/sessions', (req, res) => {
  const sessions = audioHandler.getActiveSessions().map(s => ({
    id: s.id,
    startTime: s.startTime,
    isActive: s.isActive,
    transcriptCount: s.transcripts.length
  }));
  res.json({ sessions });
});

app.get('/', (req, res) => {
  res.json({
    name: 'Call Supervisor Server',
    version: '1.0.0',
    status: 'running',
    twilioConfigured: isTwilioConfigured(),
    activeSessions: audioHandler.getActiveSessions().length,
    endpoints: {
      health: 'GET /health',
      sessions: 'GET /sessions',
      incomingCall: 'POST /incoming-call',
      webhooks: {
        status: 'POST /webhook/status',
        recording: 'POST /webhook/recording'
      }
    },
    websocketEvents: {
      clientToServer: ['start-call', 'approve-call', 'reject-call', 'audio-chunk', 'end-call'],
      serverToClient: ['call-started', 'call-approved', 'call-rejected', 'transcript', 'transcript-update', 'call-ended', 'supervision-needed']
    }
  });
});

process.on('SIGINT', () => {
  console.log('\nShutting down...');
  const speechService = require('./services/speechService');
  speechService.stop();
  process.exit(0);
});

server.listen(PORT, () => {
  console.log(`========================================`);
  console.log(`Call Supervisor Server`);
  console.log(`========================================`);
  console.log(`Server running on port ${PORT}`);
  console.log(`WebSocket server ready`);
  console.log(`Twilio configured: ${isTwilioConfigured()}`);
  console.log(`========================================`);
  console.log(`To expose this server publicly:`);
  console.log(`1. Run: cloudflared tunnel --url http://localhost:3000`);
  console.log(`2. Copy the URL provided (e.g., https://xxxx.trycloudflare.com)`);
  console.log(`3. Use that URL as your Twilio webhook`);
  console.log(`========================================`);
});
