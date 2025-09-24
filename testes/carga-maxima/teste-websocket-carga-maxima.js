import ws from 'k6/ws';
import { check } from 'k6';
import { Trend, Counter } from 'k6/metrics';

const latencyTrend = new Trend('websocket_latency', true);
const messagesSent = new Counter('messages_sent_total');
const messagesReceived = new Counter('messages_received_total');
const completedRoundTrips = new Counter('completed_round_trips');

export const options = {
  vus: 10,
  duration: '60s',
  summaryTrendStats: ['avg', 'min', 'med', 'max', 'p(90)', 'p(95)', 'p(99)'],
};

export default function () {
  const url = 'ws://localhost:8081/ws';
  let messageCounter = 0;
  const startTime = Date.now();
  const vuId = __VU;

  let waitingForResponse = false;
  let currentMessageId = null;
  let currentSentTime = null;

  const response = ws.connect(url, function (socket) {
    socket.on('open', function () {
      check(null, { 'Connected': () => true });
      
      sendNextMessage(socket);
    });

    socket.on('message', function (data) {
      messagesReceived.add(1);
      
      const receivedTime = Date.now();
      
      try {
        const response = JSON.parse(data);
        let messageId = null;
        
        if (response.client_message) {
          try {
            const original = JSON.parse(response.client_message);
            messageId = original.id;
          } catch (e) {
          }
        }
        
        if (messageId === currentMessageId && currentSentTime) {
          const latencyMs = receivedTime - currentSentTime;
          latencyTrend.add(latencyMs);
          completedRoundTrips.add(1);
          
          if (latencyMs > 5 || messageCounter % 1000 === 0) {
          }
        }
        
        sendNextMessage(socket);
        
      } catch (e) {
        sendNextMessage(socket);
      }
    });

    socket.on('close', function () {
      const duration = (Date.now() - startTime) / 1000;
      const rate = (completedRoundTrips.value/duration).toFixed(0);
    });

    socket.on('error', function (e) {
      console.log(`❌ VU ${vuId}: ${e.error()}`);
    });

    function sendNextMessage(socket) {
      const now = Date.now();
      
      if (now >= startTime + 60000) {
        socket.close();
        return;
      }
      
      try {
        messageCounter++;
        currentMessageId = `vu${vuId}_ultra_${messageCounter}`;
        currentSentTime = now;
        
        const msg = JSON.stringify({
          id: currentMessageId,
          t: currentSentTime,
          v: vuId,
          c: messageCounter
        });
        
        socket.send(msg);
        messagesSent.add(1);
        
      } catch (error) {
      }
    }

    setInterval(() => {
      if (currentSentTime && (Date.now() - currentSentTime) > 500) {
        sendNextMessage(socket);
      }
    }, 1);

    setTimeout(() => {
      socket.close();
    }, 60000);
  });

  check(response, { 'Connected': (r) => r && r.status === 101 });
}