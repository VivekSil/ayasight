require('dotenv').config();
const express = require('express');
const multer = require('multer');
const fs = require('fs');
const path = require('path');
const OpenAI = require('openai');

const app = express();
const port = 3000;

// Configure Multer for file uploads
const storage = multer.diskStorage({
  destination: (req, file, cb) => {
    cb(null, 'uploads/');
  },
  filename: (req, file, cb) => {
    cb(null, `${Date.now()}-${file.originalname}`);
  },
});
const upload = multer({ storage });

// Initialize OpenAI with Cohere's Compatibility API
const openai = new OpenAI({
  baseURL: 'https://api.cohere.ai/compatibility/v1',
  apiKey: process.env.COHERE_API_KEY,
});

// Endpoint to handle image upload and send to Aya Vision
app.post('/analyze-image', upload.single('image'), async (req, res) => {
  try {
    if (!req.file) {
      return res.status(400).json({ error: 'No image uploaded.' });
    }

    // Read the uploaded image file
    const imagePath = path.join(__dirname, req.file.path);
    const imageData = fs.readFileSync(imagePath);
    const base64Image = imageData.toString('base64');
    const mimeType = req.file.mimetype;

    // Construct the message with the image
    const messages = [
      {
        role: 'user',
        content: [
          { type: 'text', text: 'Describe this image.' },
          {
            type: 'image_url',
            image_url: {
              url: `data:${mimeType};base64,${base64Image}`,
            },
          },
        ],
      },
    ];

    // Send the request to Aya Vision
    const completion = await openai.chat.completions.create({
      model: 'c4ai-aya-vision-8b',
      messages: messages,
    });

    // Respond with Aya Vision's output
    res.json({ response: completion.choices[0].message.content });
  } catch (error) {
    console.error('Error processing image:', error);
    res.status(500).json({ error: 'Failed to process the image.' });
  }
});

app.listen(port, () => {
  console.log(`Server is running on http://localhost:${port}`);
});
