const functions = require("firebase-functions");
const express = require("express");
const cors = require("cors");
const axios = require("axios");
const app = express();

app.use(cors({ origin: true }));
app.use(express.json());

app.post("/", async (req, res) => {
  const { phoneNumber, message } = req.body;

  if (!phoneNumber || !message) {
    return res.status(400).json({ error: "Missing phone number or message." });
  }

  const arkeselApiKey = "UEFuQkJ5UWFiRnRvZFpqbXZTeXI";
  const senderId = "TremSol"; // Replace with your approved sender ID

  const url = `https://sms.arkesel.com/sms/api?action=send-sms&api_key=${arkeselApiKey}&to=${encodeURIComponent(phoneNumber)}&from=${encodeURIComponent(senderId)}&sms=${encodeURIComponent(message)}`;

  try {
    const response = await axios.get(url);
    console.log("✅ Arkesel SMS Response:", response.data);

    if (response.data.status === "success") {
      return res.status(200).json({ success: true, data: response.data });
    } else {
      return res.status(500).json({
        error: "Failed to send SMS via Arkesel.",
        details: response.data,
      });
    }
  } catch (err) {
    console.error("❌ Arkesel SMS Error:", err.response?.data || err.message);
    return res.status(500).json({
      error: "Failed to send SMS via Arkesel.",
      details: err.response?.data || err.message,
    });
  }
});

exports.sendOrderSMS = functions.https.onRequest(app);