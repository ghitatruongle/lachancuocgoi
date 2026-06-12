const twilio = require('twilio');

class TwiMLService {
  constructor() {
    this.client = twilio(
      process.env.TWILIO_ACCOUNT_SID,
      process.env.TWILIO_AUTH_TOKEN
    );
  }

  createSupervisionResponse() {
    const twiml = new twilio.twiml.VoiceResponse();

    twiml.say({
      voice: 'alice',
      language: 'vi-VN'
    }, 'Xin chào, cuộc gọi này đang được giám sát. Vui lòng đợi trong giây lát.');

    twiml.dial().conference('supervised-call', {
      beep: false,
      startConferenceOnEnter: true,
      endConferenceOnExit: false,
      maxParticipants: 2,
      record: 'record-from-start',
      recordingStatusCallback: '/webhook/recording'
    });

    return twiml.toString();
  }

  async makeCall(to, from, url) {
    try {
      const call = await this.client.calls.create({
        to: to,
        from: from,
        url: url,
        method: 'POST'
      });
      return call;
    } catch (error) {
      console.error('Error making call:', error);
      throw error;
    }
  }

  async getCallStatus(callSid) {
    try {
      const call = await this.client.calls(callSid).fetch();
      return call;
    } catch (error) {
      console.error('Error getting call status:', error);
      throw error;
    }
  }
}

module.exports = new TwiMLService();
