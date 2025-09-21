require('dotenv').config();
const express = require('express');
const cors = require('cors');
const multer = require('multer');
const { MongoClient, ObjectId } = require('mongodb');

const app = express();
app.use(cors());
app.use(express.json());

// Multer config to store uploaded files in memory as buffers
const upload = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: 5 * 1024 * 1024 } // 5MB per file
});

// MongoDB connection settings
const MONGO_URI = process.env.MONGO_URI || 'mongodb+srv://truxoo:truxoo@final.g5ydq2b.mongodb.net/?retryWrites=true&w=majority&appName=final';
const DB_NAME = 'truxoo';

let db;

// Connect to MongoDB
MongoClient.connect(MONGO_URI)
  .then((client) => {
    db = client.db(DB_NAME);
    console.log('✅ Connected to MongoDB');
  })
  .catch((err) => {
    console.error('❌ MongoDB Connection Error:', err);
    process.exit(1);
  });

// Driver Registration Endpoint
app.post(
  '/api/driver/register',
  upload.fields([
    { name: 'truck_photo', maxCount: 1 },
    { name: 'pan_aadhar_photo', maxCount: 1 },
    { name: 'license_photo', maxCount: 1 },
    { name: 'driver_photo', maxCount: 1 }
  ]),
  async (req, res) => {
    try {
      const formData = req.body;
      const files = req.files || {};
      const fileEntries = {};

      // Package files for MongoDB storage
      for (const key in files) {
        const file = files[key][0];
        fileEntries[key] = {
          originalname: file.originalname,
          mimetype: file.mimetype,
          buffer: file.buffer
        };
      }

      const driverDoc = {
        ...formData,
        files: fileEntries,
        registeredAt: new Date()
      };

      const result = await db.collection('drivers').insertOne(driverDoc);

      res.status(201).json({
        message: 'Driver registered successfully',
        driverId: result.insertedId
      });
    } catch (err) {
      console.error('❌ Error registering driver:', err);
      res.status(500).json({ error: 'Failed to register driver' });
    }
  }
);

// Retrieve Driver Info (with metadata)
app.get('/api/driver/:id', async (req, res) => {
  try {
    const driver = await db.collection('drivers').findOne({ _id: new ObjectId(req.params.id) });
    if (!driver) {
      return res.status(404).json({ error: 'Driver not found' });
    }
    res.json(driver);
  } catch (err) {
    console.error('❌ Error fetching driver:', err);
    res.status(500).json({ error: 'Failed to fetch driver' });
  }
});

// Serve specific driver file (e.g., license photo)
app.get('/api/driver/:id/file/:fileKey', async (req, res) => {
  try {
    const driver = await db.collection('drivers').findOne({ _id: new ObjectId(req.params.id) });
    if (!driver || !driver.files || !driver.files[req.params.fileKey]) {
      return res.status(404).json({ error: 'File not found' });
    }

    const file = driver.files[req.params.fileKey];
    res.set('Content-Type', file.mimetype);
    res.send(file.buffer);
  } catch (err) {
    console.error('❌ Error fetching file:', err);
    res.status(500).json({ error: 'Failed to fetch file' });
  }
});

// Start Express server on port 3000 listening on all network interfaces
const PORT = process.env.PORT || 3000;
app.listen(PORT, '0.0.0.0', () => {
  console.log(`🚀 Server running on http://0.0.0.0:${PORT}`);
});
