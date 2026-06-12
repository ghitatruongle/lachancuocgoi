const speechService = require('../services/speechService');

class CallSession {
  constructor(socket, callData = {}) {
    this.id = `call_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;
    this.socket = socket;
    this.callData = callData;
    this.startTime = new Date();
    this.transcripts = [];
    this.audioChunks = [];
    this.isActive = false;
  }

  addTranscript(text, speaker = 'unknown') {
    const transcript = {
      id: this.transcripts.length + 1,
      text,
      speaker,
      timestamp: Date.now() - this.startTime.getTime()
    };
    this.transcripts.push(transcript);
    return transcript;
  }

  getTranscript() {
    return this.transcripts;
  }

  end() {
    this.isActive = false;
    this.endTime = new Date();
    const duration = this.endTime - this.startTime;
    return {
      id: this.id,
      duration,
      transcriptCount: this.transcripts.length,
      transcripts: this.transcripts
    };
  }
}

class AudioStreamHandler {
  constructor(io) {
    this.io = io;
    this.sessions = new Map();
    this.speechService = speechService;
  }

  initialize() {
    this.speechService.initialize().then(() => {
      console.log('Audio Stream Handler ready with Speech-to-Text');
    }).catch(err => {
      console.error('Failed to initialize Speech-to-Text:', err);
    });
  }

  handleConnection(socket) {
    console.log(`Audio stream connected: ${socket.id}`);

    socket.on('start-call', async (data) => {
      const session = new CallSession(socket, data);
      this.sessions.set(socket.id, session);
      session.isActive = true;

      socket.emit('call-started', {
        sessionId: session.id,
        message: 'Call session started'
      });

      this.io.emit('supervision-needed', {
        sessionId: session.id,
        phoneNumber: data.phoneNumber || 'Unknown',
        timestamp: new Date().toISOString()
      });
    });

    socket.on('approve-call', (data) => {
      const session = this.sessions.get(socket.id);
      if (session) {
        session.callData.approved = true;
        socket.emit('call-approved', {
          sessionId: session.id,
          message: 'Call approved, forwarding to supervisor'
        });
      }
    });

    socket.on('reject-call', (data) => {
      const session = this.sessions.get(socket.id);
      if (session) {
        session.callData.rejected = true;
        session.end();
        socket.emit('call-rejected', {
          sessionId: session.id,
          message: 'Call rejected'
        });
      }
    });

    socket.on('audio-chunk', async (data) => {
      const session = this.sessions.get(socket.id);
      if (!session || !session.isActive) return;

      try {
        session.audioChunks.push(data.audio);

        if (session.audioChunks.length >= 5) {
          const combinedAudio = Buffer.concat(session.audioChunks);
          session.audioChunks = [];

          const result = await this.speechService.transcribe(combinedAudio);

          if (result.text && result.text.trim()) {
            const transcript = session.addTranscript(result.text, 'caller');

            socket.emit('transcript', {
              sessionId: session.id,
              text: result.text,
              transcript: transcript
            });

            socket.broadcast.emit('transcript-update', {
              sessionId: session.id,
              text: result.text,
              transcript: transcript
            });
          }
        }
      } catch (error) {
        console.error('Transcription error:', error);
      }
    });

    socket.on('end-call', (data) => {
      const session = this.sessions.get(socket.id);
      if (session) {
        const summary = session.end();
        socket.emit('call-ended', summary);
        this.sessions.delete(socket.id);
      }
    });

    socket.on('disconnect', () => {
      const session = this.sessions.get(socket.id);
      if (session) {
        session.end();
        this.sessions.delete(socket.id);
      }
    });
  }

  getActiveSessions() {
    return Array.from(this.sessions.values()).filter(s => s.isActive);
  }
}

module.exports = AudioStreamHandler;
