import http from 'k6/http';
import { check, sleep } from 'k6';

export let options = {
  scenarios: {
    rest_1rps_per_vu: {
      executor: 'constant-vus',
      vus: 10,
      duration: '1m',
    },
  }
};

export default function () {
  const url = 'http://localhost:8080/metrics';
  const res = http.get(url);
  
  check(res, {
    'status é 200': (r) => r.status === 200,
    'resposta contém system': (r) => {
      const body = JSON.parse(r.body);
      return body && body.system;
    },
  });
  
  sleep(1);
}