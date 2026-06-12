'use strict';

const { DynamoDBClient, PutItemCommand } = require('@aws-sdk/client-dynamodb');
const { SESClient, SendEmailCommand }    = require('@aws-sdk/client-ses');

const dynamo = new DynamoDBClient({});
const ses    = new SESClient({});

// ── Configuration (set via Lambda environment variables) ──────────────────────
const TABLE_NAME      = process.env.DYNAMO_TABLE   || 'seqtoid-mailing-list';
const NOTIFY_EMAIL    = process.env.NOTIFY_EMAIL;
const FROM_EMAIL      = process.env.FROM_EMAIL;
const ALLOWED_ORIGINS = (process.env.ALLOWED_ORIGINS || 'https://seqtoid.org')
                          .split(',')
                          .map(o => o.trim());

// ── CORS helpers ──────────────────────────────────────────────────────────────
// Lambda handles ALL CORS headers — API Gateway CORS settings must be disabled.
// This ensures every response (200, 4xx, 5xx) includes the correct headers,
// which is required when using WAF with a REST API (v1) proxy integration.

function getCorsHeaders(requestOrigin) {
  // Reflect the requesting origin if it is in the allow-list; otherwise use first entry.
  const origin = ALLOWED_ORIGINS.includes(requestOrigin)
    ? requestOrigin
    : ALLOWED_ORIGINS[0];

  return {
    'Access-Control-Allow-Origin':      origin,
    'Access-Control-Allow-Methods':     'POST, OPTIONS',
    'Access-Control-Allow-Headers':     'Content-Type, X-Requested-With',
    'Access-Control-Allow-Credentials': 'false',
    'Access-Control-Max-Age':           '86400',
  };
}

function respond(statusCode, body, requestOrigin) {
  return {
    statusCode,
    headers: {
      'Content-Type': 'application/json',
      ...getCorsHeaders(requestOrigin || ''),
    },
    body: JSON.stringify(body),
  };
}

// ── Input helpers ─────────────────────────────────────────────────────────────
function sanitize(str, maxLen = 255) {
  if (typeof str !== 'string') return '';
  return str.trim().replace(/[<>"'`]/g, '').slice(0, maxLen);
}

function isValidEmail(email) {
  return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email);
}

// ── Main handler ──────────────────────────────────────────────────────────────
exports.handler = async (event) => {
  // Normalise headers — API Gateway REST passes them with mixed case
  const headers = {};
  if (event.headers) {
    Object.keys(event.headers).forEach(k => {
      headers[k.toLowerCase()] = event.headers[k];
    });
  }
  const requestOrigin = headers['origin'] || '';
  const httpMethod    = event.httpMethod || event.requestContext?.http?.method || 'POST';

  // ── Handle CORS preflight (OPTIONS) ───────────────────────────────────────
  if (httpMethod === 'OPTIONS') {
    return respond(200, {}, requestOrigin);
  }

  // ── Only accept POST ───────────────────────────────────────────────────────
  if (httpMethod !== 'POST') {
    return respond(405, { error: 'Method not allowed.' }, requestOrigin);
  }

  // ── Parse body ─────────────────────────────────────────────────────────────
  let body;
  try {
    body = JSON.parse(event.body || '{}');
  } catch {
    return respond(400, { error: 'Invalid request body.' }, requestOrigin);
  }

  // ── Input validation ───────────────────────────────────────────────────────
  const name        = sanitize(body.name);
  const email       = sanitize(body.email, 320);
  const institution = sanitize(body.institution);
  const focus       = sanitize(body.focus);

  const errors = [];
  if (!name)                     errors.push('Name is required.');
  if (!email)                    errors.push('Email is required.');
  else if (!isValidEmail(email)) errors.push('Email address is not valid.');
  if (!institution)              errors.push('Institution is required.');

  if (errors.length) {
    return respond(422, { error: errors.join(' ') }, requestOrigin);
  }

  // ── Write to DynamoDB ──────────────────────────────────────────────────────
  const timestamp = new Date().toISOString();

  try {
    await dynamo.send(new PutItemCommand({
      TableName: TABLE_NAME,
      Item: {
        email:       { S: email },
        name:        { S: name },
        institution: { S: institution },
        focus:       { S: focus || '' },
        createdAt:   { S: timestamp },
        source:      { S: 'landing-page' },
      },
      // Prevent duplicate emails — condition fails silently (handled below)
      ConditionExpression: 'attribute_not_exists(email)',
    }));
  } catch (err) {
    if (err.name === 'ConditionalCheckFailedException') {
      // Duplicate email — return success to avoid leaking registration status
      console.log(`Duplicate signup ignored for: ${email}`);
      return respond(200, { message: "You're on the list!" }, requestOrigin);
    }
    console.error('DynamoDB error:', err);
    return respond(500, { error: 'Could not save your signup. Please try again.' }, requestOrigin);
  }

  // ── Send admin notification via SES ───────────────────────────────────────
  if (NOTIFY_EMAIL && FROM_EMAIL) {
    try {
      await ses.send(new SendEmailCommand({
        Source:      FROM_EMAIL,
        Destination: { ToAddresses: [NOTIFY_EMAIL] },
        Message: {
          Subject: { Data: `[SeqToID] New mailing list signup: ${name}` },
          Body: {
            Text: {
              Data: [
                'New mailing list signup on SeqToID.org',
                '',
                `Name:        ${name}`,
                `Email:       ${email}`,
                `Institution: ${institution}`,
                `Focus:       ${focus || '(not provided)'}`,
                `Timestamp:   ${timestamp}`,
              ].join('\n'),
            },
          },
        },
      }));
    } catch (sesErr) {
      // Non-fatal — record is already saved in DynamoDB
      console.error('SES notification failed (record saved):', sesErr);
    }
  }

  return respond(200, { message: "You're on the list!" }, requestOrigin);
};
