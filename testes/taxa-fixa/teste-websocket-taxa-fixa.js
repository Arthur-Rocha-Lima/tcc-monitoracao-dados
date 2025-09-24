import ws from 'k6/ws';
import { check } from 'k6';
import { Trend, Counter } from 'k6/metrics';

const latencyTrend = new Trend('websocket_latency', true);
const messagesSent = new Counter('messages_sent');
const messagesReceived = new Counter('messages_received');

export const options = {
  vus: 10,
  duration: '1m',
};

export default function () {
  const url = 'ws://localhost:8081/ws';
  
  const response = ws.connect(url, {}, function (socket) {
    let messageCounter = 0;
    const messageTimes = new Map();
    const vuId = __VU;
    
    socket.on('message', function (data) {
      const receivedTime = Date.now();
      messagesReceived.add(1);
      
      try {
        const response = JSON.parse(data);
        const originalMessage = JSON.parse(response.client_message);
        const messageId = originalMessage.id;
        
        if (messageTimes.has(messageId)) {
          const sentTime = messageTimes.get(messageId);
          const latencyMs = receivedTime - sentTime;
          
          latencyTrend.add(latencyMs);
          messageTimes.delete(messageId);
        }
        } catch (e) {
        }
    });
    
    socket.on('error', function (e) {});
    socket.on('close', function () {});
    
    function sendMessage() {
      messageCounter++;
      const messageId = `vu${vuId}_msg${messageCounter}`;
      const sentTime = Date.now();
      
      const message = {
        id: messageId,
        timestamp: sentTime,
        vu: vuId,
        counter: messageCounter,
        data: `Test message ${messageCounter}`
      };
      
      messageTimes.set(messageId, sentTime);
      
      socket.send(JSON.stringify(message));
      messagesSent.add(1);
    }
    
    let count = 0;
    function scheduleNext() {
      if (count < 60) {
        sendMessage();
        count++;
        socket.setTimeout(scheduleNext, 1000);
      } else {
        socket.close();
      }
    }
    
    scheduleNext();
  });
  
  check(response, {
    'Connected': (r) => r && r.status === 101,
  });
}