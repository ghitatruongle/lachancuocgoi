const express = require('express');
const router = express.Router();
const twilioService = require('../services/twilioService');

router.post('/incoming-call', (req, res) => {
  const twiml = twilioService.createSupervisionResponse();
  res.type('text/xml').send(twiml);
});

router.post('/webhook/recording', (req, res) => {
  console.log('Recording webhook:', req.body);
  res.status(200).send('OK');
});

router.post('/webhook/status', (req, res) => {
  console.log('Call status webhook:', req.body);
  res.status(200).send('OK');
});

router.get('/call/:callSid', async (req, res) => {
  try {
    const call = await twilioService.getCallStatus(req.params.callSid);
    res.json(call);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

module.exports = router;
