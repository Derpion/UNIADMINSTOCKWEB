const express = require('express');
const axios = require('axios');
const cors = require('cors');
const app = express();
const PORT = 3000;

app.use(cors());
app.use(express.json());

app.post('/send-sms', async (req, res) => {
  try {
    const { apikey, number, message, sendername } = req.body;

    const response = await axios.post('https://api.semaphore.co/api/v4/messages', {
      apikey,
      number,
      message,
      sendername,
    });

    res.json(response.data);
  } catch (error) {
    res.status(500).send(error.response ? error.response.data : error.message);
  }
});

app.listen(PORT, () => {
  console.log(`Proxy server running on port ${PORT}`);
});
