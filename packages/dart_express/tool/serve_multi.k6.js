import http from 'k6/http';
import { check, sleep } from 'k6';

const BASE_URL = __ENV.BASE_URL || 'http://127.0.0.1:8080';

export const options = {
  scenarios: {
    bench: {
      executor: 'ramping-vus',
      exec: 'bench',
      startVUs: 0,
      stages: [
        { duration: '10s', target: 10 },
        { duration: '20s', target: 50 },
        { duration: '20s', target: 100 },
        { duration: '10s', target: 0 },
      ],
      gracefulRampDown: '5s',
    },
    health: {
      executor: 'constant-vus',
      exec: 'healthCheck',
      vus: 1,
      duration: '1m',
      startTime: '0s',
      tags: { scenario: 'health' },
    },
  },
  thresholds: {
    http_req_failed: ['rate<0.01'],
    http_req_duration: ['p(95)<50'],
    'checks{endpoint:bench}': ['rate>0.99'],
  },
};

export function setup() {
  const res = http.get(`${BASE_URL}/health`, {
    tags: { endpoint: 'health' },
  });
  check(res, {
    'health 200': (r) => r.status === 200,
    'health status ok': (r) => r.status === 200 && r.json('status') === 'ok',
  });
}

export function bench() {
  const res = http.get(`${BASE_URL}/bench`, {
    tags: { endpoint: 'bench' },
  });

  check(res, {
    'bench 200': (r) => r.status === 200,
    'bench status ok': (r) => r.json('status') === 'ok',
    'bench has requestId': (r) => r.json('requestId') !== undefined,
  });

  sleep(0.1);
}

export function healthCheck() {
  const res = http.get(`${BASE_URL}/health`, {
    tags: { endpoint: 'health' },
  });
  check(res, {
    'health 200': (r) => r.status === 200,
    'health status ok': (r) => r.json('status') === 'ok',
  });
  sleep(1);
}
