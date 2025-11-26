import express from "express";
import cors from "cors";
import multer from "multer";
import dotenv from "dotenv";
// NOTE: For advanced server-side operations (like setting serverTimestamp),
// it's generally recommended to use the Firebase Admin SDK. 
// Since you are using @google-cloud/firestore, we will stick to your current setup.
import { Firestore } from "@google-cloud/firestore";
import { Storage } from "@google-cloud/storage";
import path from "path";

dotenv.config();

const app = express();
app.use(cors());
app.use(express.json()); // Add this line to parse JSON bodies for the new endpoints

const storage = multer.memoryStorage();
const upload = multer({ storage: storage });

// --- Firestore ---
const firestore = new Firestore({
  projectId: "truxoo-25f15",
  databaseId: "truxoodrivers", 
  keyFilename: "serviceAccountKey.json",
});

// --- Firebase Storage ---
const gcsStorage = new Storage({
  projectId: "truxoo-25f15",
  keyFilename: "serviceAccountKey.json",
});

const bucketName = "truxoo-25f15.firebasestorage.app"; // **Reverting to .appspot.com for reliability**
const bucket = gcsStorage.bucket(bucketName);

// Upload Helper (Unchanged)
async function uploadFile(fileArray, mobileNumber, fileKey) {
  if (!fileArray || fileArray.length === 0) return null;

  const uploadedFile = fileArray[0];
  const destination = `driver_uploads/${mobileNumber}/${fileKey}_${Date.now()}${path.extname(uploadedFile.originalname)}`;

  const fileUpload = bucket.file(destination);

  const stream = fileUpload.createWriteStream({
    metadata: { contentType: uploadedFile.mimetype },
    resumable: false,
  });

  return new Promise((resolve, reject) => {
    stream.on("error", reject);
    stream.on("finish", async () => {
      // NOTE: makePublic() requires the 'Storage Object Admin' role on the service account.
      await fileUpload.makePublic(); 
      resolve(fileUpload.publicUrl());
    });

    stream.end(uploadedFile.buffer);
  });
}

// ----------------------------------------------------
// ➡️ 1. UPDATED REGISTRATION ENDPOINT (/register)
// ----------------------------------------------------

app.post(
  "/register",
  upload.fields([
    { name: "truck_photo", maxCount: 1 },
    { name: "pan_aadhar_photo", maxCount: 1 },
    { name: "license_photo", maxCount: 1 },
    { name: "driver_photo", maxCount: 1 },
  ]),
  async (req, res) => {
    try {
      const { body, files } = req;
      const mobileNumber = body.mobile;

      if (!mobileNumber) {
        return res.status(400).json({ error: "Mobile number is required." });
      }

      // Check if driver already exists
      const driverRef = firestore.collection("drivers").doc(mobileNumber);
      const doc = await driverRef.get();

      if (doc.exists && doc.data().is_verified === true) {
          // If already verified, prevent re-registration and guide to login
          return res.status(409).json({ 
              message: "Driver already fully registered and verified. Please log in.",
              action: "login" 
          });
      }
      
      // Upload files (even if existing, files may have been updated)
      const [truckPhotoUrl, panAadharUrl, licenseUrl, driverPhotoUrl] =
        await Promise.all([
          uploadFile(files.truck_photo, mobileNumber, "truck"),
          uploadFile(files.pan_aadhar_photo, mobileNumber, "panAadhar"),
          uploadFile(files.license_photo, mobileNumber, "license"),
          uploadFile(files.driver_photo, mobileNumber, "driver"),
        ]);
      
      const driverData = {
        ...body,
        truck_photo_url: truckPhotoUrl,
        pan_aadhar_photo_url: panAadharUrl,
        license_photo_url: licenseUrl,
        driver_photo_url: driverPhotoUrl,
        
        // ⬇️ KEY CHANGE: Set is_verified to false for OTP step
        is_verified: false, 
        // ⬆️
        
        createdAt: new Date(),
      };

      await driverRef.set(driverData, { merge: true }); // Use merge if re-registering

      // Respond with a message guiding to the OTP page
      res.status(202).json({ 
            message: "Registration data saved. Proceed to OTP verification.", 
            mobile: mobileNumber,
            action: "verify_otp"
        });
        
    } catch (error) {
      console.error("Error registering driver:", error);
      res.status(500).json({ error: "Failed to register driver" });
    }
  }
);

// ----------------------------------------------------
// ➡️ 2. NEW ENDPOINT: VERIFICATION STATUS UPDATE
// ----------------------------------------------------

app.post("/verify-driver", async (req, res) => {
  try {
    const { mobile } = req.body; // Flutter sends the mobile number

    if (!mobile) {
      return res.status(400).json({ error: "Mobile number is required for verification." });
    }

    const driverRef = firestore.collection("drivers").doc(mobile);
    const doc = await driverRef.get();

    if (!doc.exists) {
        // Should not happen if registration was successful
        return res.status(404).json({ error: "Driver record not found." });
    }

    // Update the is_verified field
    await driverRef.update({
      is_verified: true,
      verification_date: new Date(),
    });

    console.log(`Driver verification status updated for: ${mobile}`);

    res.status(200).json({
      message: "Driver verified and status updated in Firestore.",
      mobile: mobile,
    });

  } catch (error) {
    console.error("Error updating verification status:", error);
    res.status(500).json({ error: "Failed to update driver status." });
  }
});


const PORT = process.env.PORT || 3000;
app.listen(PORT, "0.0.0.0", () =>
  console.log(`🚀 Server running on http://0.0.0.0:${PORT}`)
);