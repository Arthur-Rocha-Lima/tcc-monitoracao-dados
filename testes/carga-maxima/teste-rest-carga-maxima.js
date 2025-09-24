import http from 'k6/http';
import { check } from 'k6';

export let options = {
  scenarios: {
    unlimited_rest_load: {
      executor: 'ramping-vus',
      startVUs: 500,
      stages: [
        { duration: '1m', target: 500 },
      ],
    },
  }
};

const url = 'http://localhost:8080/metrics';

export default function () {
  const response = http.get(url, {
    timeout: '30s',
  });
  
  check(response, {
    'status é 200': (r) => r.status === 200,
    'resposta contém system': (r) => {
      try {
        const body = JSON.parse(r.body);
        return body && body.system;
      } catch (e) {
        return false;
      }
    },
    'tempo de resposta < 10s': (r) => r.timings.duration < 10000,
  });
}