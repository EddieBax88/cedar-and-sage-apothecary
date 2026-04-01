#!/usr/bin/env node
'use strict';

/**
 * Etsy OAuth 2.0 PKCE Authorization Flow
 *
 * Run: node src/auth.js
 *
 * Before running, make sure you have registered
 * http://localhost:3000/callback as a Callback URL in your Etsy app at:
 * https://www.etsy.com/developers/your-apps
 */

const crypto = require('node:crypto');
const http = require('node:http');
const fs = require('node:fs');
const path = require('node:path');
const { execSync } = require('node:child_process');

require('dotenv').config({ path: path.join(__dirname, '..', '.env') });

const ETSY_API_KEY = process.env.ETSY_API_KEY;
const REDIRECT_URI = 'http://localhost:3000/callback';
const SCOPES = 'listings_r listings_w';
const ENV_PATH = path.join(__dirname, '..', '.env');

if (!ETSY_API_KEY) {
  console.error('ETSY_API_KEY not found in .env file.');
  process.exit(1);
}

// Generate a PKCE code verifier: URL-safe base64 of 32 random bytes
function generateCodeVerifier() {
  return crypto.randomBytes(32).toString('base64url');
}

// Generate PKCE code challenge: URL-safe base64 of SHA256 of verifier
function generateCodeChallenge(verifier) {
  return crypto.createHash('sha256').update(verifier).digest('base64url');
}

// Generate a random state string for CSRF protection
function generateState() {
  return crypto.randomBytes(16).toString('hex');
}

// Update a single key in the .env file
function updateEnv(key, value) {
  let content = fs.readFileSync(ENV_PATH, 'utf8');
  const regex = new RegExp(`^${key}=.*$`, 'm');
  if (regex.test(content)) {
    content = content.replace(regex, `${key}=${value}`);
  } else {
    content += `\n${key}=${value}`;
  }
  fs.writeFileSync(ENV_PATH, content);
}

// Exchange authorization code for access + refresh tokens
async function exchangeCodeForTokens(code, codeVerifier) {
  const params = new URLSearchParams({
    grant_type: 'authorization_code',
    client_id: ETSY_API_KEY,
    redirect_uri: REDIRECT_URI,
    code,
    code_verifier: codeVerifier,
  });

  const res = await fetch('https://api.etsy.com/v3/public/oauth/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: params.toString(),
  });

  if (!res.ok) {
    const err = await res.text();
    throw new Error(`Token exchange failed: ${res.status} ${err}`);
  }

  return res.json();
}

async function main() {
  const codeVerifier = generateCodeVerifier();
  const codeChallenge = generateCodeChallenge(codeVerifier);
  const state = generateState();

  const authUrl = new URL('https://www.etsy.com/oauth/connect');
  authUrl.searchParams.set('response_type', 'code');
  authUrl.searchParams.set('client_id', ETSY_API_KEY);
  authUrl.searchParams.set('redirect_uri', REDIRECT_URI);
  authUrl.searchParams.set('scope', SCOPES);
  authUrl.searchParams.set('state', state);
  authUrl.searchParams.set('code_challenge', codeChallenge);
  authUrl.searchParams.set('code_challenge_method', 'S256');

  console.log('\nOpening Etsy authorization page in your browser...');
  console.log('If the browser does not open, paste this URL manually:\n');
  console.log(authUrl.toString());
  console.log('');

  // Try to open the browser automatically (Linux)
  try {
    execSync(`xdg-open "${authUrl.toString()}"`, { stdio: 'ignore' });
  } catch {
    // Ignore — user will open manually
  }

  // Start local server to capture the OAuth redirect
  await new Promise((resolve, reject) => {
    const server = http.createServer(async (req, res) => {
      const url = new URL(req.url, 'http://localhost:3000');

      if (url.pathname !== '/callback') {
        res.end('Not found');
        return;
      }

      const returnedState = url.searchParams.get('state');
      const code = url.searchParams.get('code');
      const error = url.searchParams.get('error');

      if (error) {
        res.writeHead(400);
        res.end(`Authorization error: ${error} — ${url.searchParams.get('error_description')}`);
        server.close();
        reject(new Error(`Etsy authorization error: ${error}`));
        return;
      }

      if (returnedState !== state) {
        res.writeHead(400);
        res.end('State mismatch — possible CSRF attack. Authorization cancelled.');
        server.close();
        reject(new Error('State mismatch'));
        return;
      }

      try {
        const tokens = await exchangeCodeForTokens(code, codeVerifier);

        // Save tokens to .env
        const expiresAt = Date.now() + tokens.expires_in * 1000;
        updateEnv('ETSY_ACCESS_TOKEN', tokens.access_token);
        updateEnv('ETSY_REFRESH_TOKEN', tokens.refresh_token);
        updateEnv('ETSY_TOKEN_EXPIRES', expiresAt.toString());

        res.writeHead(200, { 'Content-Type': 'text/html' });
        res.end('<h2>Authenticated successfully! You can close this tab and return to the terminal.</h2>');
        server.close();
        console.log('Authenticated successfully! Tokens saved to .env');
        resolve();
      } catch (err) {
        res.writeHead(500);
        res.end(`Error: ${err.message}`);
        server.close();
        reject(err);
      }
    });

    server.listen(3000, () => {
      console.log('Waiting for Etsy to redirect back to http://localhost:3000/callback ...');
    });

    server.on('error', reject);
  });
}

main().catch((err) => {
  console.error('Auth failed:', err.message);
  process.exit(1);
});
