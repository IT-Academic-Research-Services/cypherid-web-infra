'use strict';

const { DynamoDBClient, PutItemCommand } = require('@aws-sdk/client-dynamodb');
const { SESClient, SendEmailCommand }    = require('@aws-sdk/client-ses');
const { randomUUID }                     = require('crypto');

const dynamo = new DynamoDBClient({});
const ses    = new SESClient({});

// ── Configuration (set via Lambda environment variables) ──────────────────────
const TABLE_NAME      = process.env.DYNAMO_TABLE   || 'seqtoid-mailing-list';
const NOTIFY_EMAIL    = process.env.NOTIFY_EMAIL;
const FROM_EMAIL      = process.env.FROM_EMAIL;
const ALLOWED_ORIGINS = (process.env.ALLOWED_ORIGINS || 'https://seqtoid.org').split(',');

// ── Helpers ───────────────────────────────────────────────────────────────────
function corsHeaders(origin) {
  const allowed = ALLOWED_ORIGINS.includes(origin) ? origin : ALLOWED_ORIGINS[0];
  return {
    'Access-Control-Allow-Origin':  allowed,
    'Access-Control-Allow-Methods': 'POST, OPTIONS',
    'Access-Control-Allow-Headers': 'Content-Type',
  };
}

function respond(statusCode, body, origin) {
  return {
    statusCode,
    headers: { 'Content-Type': 'application/json', ...corsHeaders(origin) },
    body: JSON.stringify(body),
  };
}

function sanitize(str, maxLen = 255) {
  if (typeof str !== 'string') return '';
  return str.trim().replace(/[<>"']/g, '').slice(0, maxLen);
}

function isValidEmail(email) {
  return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email);
}

// ── Main handler ──────────────────────────────────────────────────────────────
exports.handler = async (event) => {
  const origin = (event.headers && (event.headers['origin'] || event.headers['Origin'])) || '';

  // Handle CORS preflight
  if (event.requestContext?.http?.method === 'OPTIONS' || event.httpMethod === 'OPTIONS') {
    return respond(200, {}, origin);
  }

  // Parse body
  let body;
  try {
    body = JSON.parse(event.body || '{}');
  } catch {
    return respond(400, { error: 'Invalid request.' }, origin);
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
    return respond(422, { error: errors.join(' ') }, origin);
  }

  // ── Write to DynamoDB ──────────────────────────────────────────────────────
  const id        = randomUUID();
  const timestamp = new Date().toISOString();

  try {
    await dynamo.send(new PutItemCommand({
      TableName: TABLE_NAME,
      Item: {
        id:          { S: id },
        email:       { S: email },
        name:        { S: name },
        institution: { S: institution },
        focus:       { S: focus || '' },
        createdAt:   { S: timestamp },
        source:      { S: 'landing-page' },
      },
      // Prevent duplicate emails from overwriting existing records
      ConditionExpression: 'attribute_not_exists(email)',
    }));
  } catch (err) {
    if (err.name === 'ConditionalCheckFailedException') {
      // Duplicate email — return success silently, do not leak registration status
      console.log(`Duplicate signup attempt for: ${email}`);
      return respond(200, { message: "You're on the list!" }, origin);
    }
    console.error('DynamoDB error:', err);
    return respond(500, { error: 'Could not save your signup. Please try again.' }, origin);
  }

  // ── Send notification email via SES ───────────────────────────────────────
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
                `Record ID:   ${id}`,
              ].join('\n'),
            },
          },
        },
      }));
    } catch (sesErr) {
      // Non-fatal — record is already saved
      console.error('SES notification failed (record saved):', sesErr);
    }
  }

  return respond(200, { message: "You're on the list!" }, origin);
};
