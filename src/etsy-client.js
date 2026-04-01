'use strict';

const fs = require('node:fs');
const path = require('node:path');

require('dotenv').config({ path: path.join(__dirname, '..', '.env') });

const ETSY_API_BASE = 'https://api.etsy.com/v3';
const ENV_PATH = path.join(__dirname, '..', '.env');

function getEnv() {
  // Re-read .env each time so we always have the latest tokens
  const raw = fs.readFileSync(ENV_PATH, 'utf8');
  const vars = {};
  for (const line of raw.split('\n')) {
    const match = line.match(/^([^=]+)=(.*)$/);
    if (match) vars[match[1].trim()] = match[2].trim();
  }
  return vars;
}

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

async function refreshAccessToken() {
  const env = getEnv();
  if (!env.ETSY_REFRESH_TOKEN) {
    throw new Error('No refresh token found. Run node src/auth.js first.');
  }

  const params = new URLSearchParams({
    grant_type: 'refresh_token',
    client_id: env.ETSY_API_KEY,
    refresh_token: env.ETSY_REFRESH_TOKEN,
  });

  const res = await fetch(`${ETSY_API_BASE}/public/oauth/token`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: params.toString(),
  });

  if (!res.ok) {
    const err = await res.text();
    throw new Error(`Token refresh failed: ${res.status} ${err}`);
  }

  const tokens = await res.json();
  const expiresAt = Date.now() + tokens.expires_in * 1000;
  updateEnv('ETSY_ACCESS_TOKEN', tokens.access_token);
  updateEnv('ETSY_REFRESH_TOKEN', tokens.refresh_token);
  updateEnv('ETSY_TOKEN_EXPIRES', expiresAt.toString());

  return tokens.access_token;
}

async function getToken() {
  const env = getEnv();

  if (!env.ETSY_ACCESS_TOKEN) {
    throw new Error('Not authenticated. Run: node src/auth.js');
  }

  const expires = parseInt(env.ETSY_TOKEN_EXPIRES || '0', 10);
  // Refresh 60 seconds before expiry to be safe
  if (Date.now() >= expires - 60_000) {
    console.log('Access token expired, refreshing...');
    return refreshAccessToken();
  }

  return env.ETSY_ACCESS_TOKEN;
}

async function request(method, urlPath, body = null, isFormData = false) {
  const token = await getToken();
  const env = getEnv();

  const headers = {
    Authorization: `Bearer ${token}`,
    'x-api-key': env.ETSY_API_KEY,
  };

  const options = { method, headers };

  if (body) {
    if (isFormData) {
      options.body = body; // FormData instance — no Content-Type header (browser sets boundary)
    } else {
      headers['Content-Type'] = 'application/json';
      options.body = JSON.stringify(body);
    }
  }

  const res = await fetch(`${ETSY_API_BASE}${urlPath}`, options);

  if (!res.ok) {
    const err = await res.text();
    throw new Error(`Etsy API error ${res.status} ${method} ${urlPath}: ${err}`);
  }

  return res.json();
}

async function getMe() {
  return request('GET', '/application/users/me');
}

async function getMyShopId() {
  const me = await getMe();
  if (!me.shop_id) {
    throw new Error('No shop found on your Etsy account. Make sure you have an active Etsy shop.');
  }
  return me.shop_id;
}

async function createListing(shopId, data) {
  return request('POST', `/application/shops/${shopId}/listings`, data);
}

async function uploadListingImage(shopId, listingId, imagePath) {
  const { FormData, Blob } = globalThis;
  const imageBuffer = fs.readFileSync(imagePath);
  const ext = path.extname(imagePath).slice(1).toLowerCase();
  const mimeType = ext === 'jpg' || ext === 'jpeg' ? 'image/jpeg' : `image/${ext}`;

  const form = new FormData();
  form.append('image', new Blob([imageBuffer], { type: mimeType }), path.basename(imagePath));
  form.append('rank', '1');

  const token = await getToken();
  const env = getEnv();

  const res = await fetch(
    `${ETSY_API_BASE}/application/shops/${shopId}/listings/${listingId}/images`,
    {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${token}`,
        'x-api-key': env.ETSY_API_KEY,
      },
      body: form,
    }
  );

  if (!res.ok) {
    const err = await res.text();
    throw new Error(`Image upload failed: ${res.status} ${err}`);
  }

  return res.json();
}

async function getShopListings(shopId) {
  return request('GET', `/application/shops/${shopId}/listings?state=active`);
}

module.exports = {
  getMe,
  getMyShopId,
  createListing,
  uploadListingImage,
  getShopListings,
};
