import express from 'express';
import multer from 'multer';
import fs from 'fs';
import path from 'path';
import { pipeline } from '@xenova/transformers';

const app = express();
const port = 3000;

const upload = multer({ dest: 'uploads/' });

let whisper;

// Load Whisper model
(async () => {
  console.log("Loading Whisper model...");
  whisper = await pipeline('automatic-speech-recognition', 'distil-whisper/distil-small.en');
  console.log("Whisper model loaded.");
})();

app.post('/transcribe', upload.single('audio'), async (req, res) => {
  try {
    const filePath = path.resolve(req.file.path);

    const output = await whisper(filePath);
    res.json({ transcription: output.text });

    fs.unlink(filePath, (err) => {
      if (err) console.error("File deletion error:", err);
    });

  } catch (error) {
    console.error("Transcription error:", error);
    res.status(500).json({ error: error.message });
  }
});

app.listen(port, () => {
  console.log(`Server running on http://localhost:${port}`);
});
