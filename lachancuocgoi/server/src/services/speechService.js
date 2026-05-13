const { spawn } = require('child_process');
const path = require('path');
const fs = require('fs');

class SpeechService {
  constructor() {
    this.model = null;
    this.modelName = process.env.WHISPER_MODEL || 'base';
    this.isReady = false;
    this.pythonProcess = null;
  }

  async initialize() {
    console.log(`Initializing Whisper model (${this.modelName})...`);
    console.log('This may take a few minutes on first run to download the model.');

    const scriptPath = path.join(__dirname, 'whisper_server.py');

    const pythonCode = `
import whisper
import sys
import json
import numpy as np
import torch

print("Loading Whisper model...", file=sys.stderr)
model = whisper.load_model("${this.modelName}")
print("Whisper model loaded successfully!", file=sys.stderr)

import base64
import io
import soundfile as sf

while True:
    try:
        line = input()
        if line == "PING":
            print("PONG")
            sys.stdout.flush()
            continue

        data = json.loads(line)

        if data.get("type") == "transcribe":
            audio_base64 = data.get("audio")
            audio_bytes = base64.b64decode(audio_base64)

            audio_np = np.frombuffer(audio_bytes, dtype=np.float32)

            if audio_np.ndim > 1:
                audio_np = audio_np.mean(axis=1)

            audio_np = audio_np.astype(np.float32)
            audio_np = audio_np / np.max(np.abs(audio_np) + 1e-10)

            result = model.transcribe(audio_np, language="vi", fp16=torch.cuda.is_available())

            response = {
                "success": True,
                "text": result["text"],
                "language": result["language"],
                "segments": [
                    {
                        "start": seg["start"],
                        "end": seg["end"],
                        "text": seg["text"]
                    } for seg in result.get("segments", [])
                ]
            }
            print(json.dumps(response))
            sys.stdout.flush()

    except Exception as e:
        error_response = {"success": False, "error": str(e)}
        print(json.dumps(error_response))
        sys.stdout.flush()
`;

    fs.writeFileSync(scriptPath, pythonCode);

    this.pythonProcess = spawn('python', [scriptPath], {
      stdio: ['pipe', 'pipe', 'pipe']
    });

    this.pythonProcess.stdout.setEncoding('utf-8');
    this.pythonProcess.stderr.setEncoding('utf-8');

    this.pythonProcess.stdout.on('data', (data) => {
      const lines = data.toString().split('\n').filter(line => line.trim());
      for (const line of lines) {
        if (line === 'PONG') {
          this.isReady = true;
          console.log('Whisper service is ready!');
        } else {
          try {
            const result = JSON.parse(line);
            this.handleResult(result);
          } catch (e) {
          }
        }
      }
    });

    this.pythonProcess.stderr.on('data', (data) => {
      console.log('Whisper:', data.toString().trim());
    });

    this.pythonProcess.on('error', (error) => {
      console.error('Whisper process error:', error);
    });

    this.pythonProcess.on('exit', (code) => {
      console.log(`Whisper process exited with code ${code}`);
      this.isReady = false;
    });

    return new Promise((resolve, reject) => {
      const timeout = setTimeout(() => {
        console.log('Whisper initialization taking longer than expected...');
      }, 5000);

      const checkReady = () => {
        if (this.isReady) {
          clearTimeout(timeout);
          resolve();
        } else {
          setTimeout(checkReady, 500);
        }
      };
      checkReady();
    });
  }

  handleResult(result) {
    if (this.pendingCallback) {
      this.pendingCallback(result);
      this.pendingCallback = null;
    }
  }

  async transcribe(audioBuffer) {
    if (!this.isReady || !this.pythonProcess) {
      throw new Error('Whisper service is not ready');
    }

    let timeoutId = null;
    
    return new Promise((resolve, reject) => {
      this.pendingCallback = (result) => {
        if (timeoutId) {
          clearTimeout(timeoutId);
          timeoutId = null;
        }
        if (result.success) {
          resolve(result);
        } else {
          reject(new Error(result.error));
        }
      };

      const data = {
        type: 'transcribe',
        audio: audioBuffer.toString('base64')
      };

      this.pythonProcess.stdin.write(JSON.stringify(data) + '\n');

      timeoutId = setTimeout(() => {
        if (this.pendingCallback) {
          this.pendingCallback = null;
          reject(new Error('Transcription timeout'));
        }
      }, 30000);
    });
  }

  async ping() {
    if (!this.pythonProcess || this.pythonProcess.stdin.destroyed) {
      return false;
    }
    try {
      this.pythonProcess.stdin.write('PING\n');
      return true;
    } catch {
      return false;
    }
  }

  stop() {
    if (this.pythonProcess) {
      this.pythonProcess.stdin.write('STOP\n');
      this.pythonProcess.kill();
      this.pythonProcess = null;
    }
  }
}

module.exports = new SpeechService();
