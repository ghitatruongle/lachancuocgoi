
import whisper
import sys
import json
import numpy as np
import torch

print("Loading Whisper model...", file=sys.stderr)
model = whisper.load_model("base")
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
