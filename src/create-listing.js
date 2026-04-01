#!/usr/bin/env node
'use strict';

/**
 * Create an Etsy listing with AI-generated description and tags.
 *
 * Usage:
 *   node src/create-listing.js --title "Sage Botanical Print" --image ./art.jpg --price 25.00 --quantity 1
 *
 * Options:
 *   --title      Product title (required)
 *   --image      Path to your image file (optional)
 *   --price      Price in USD (default: 20.00)
 *   --quantity   Quantity available (default: 1)
 *
 * Requires ANTHROPIC_API_KEY in .env for AI-generated content.
 * Run node src/auth.js first to authenticate with Etsy.
 */

const path = require('node:path');
const fs = require('node:fs');

require('dotenv').config({ path: path.join(__dirname, '..', '.env') });

const etsy = require('./etsy-client');

function parseArgs(argv) {
  const args = {};
  for (let i = 2; i < argv.length; i++) {
    if (argv[i].startsWith('--')) {
      const key = argv[i].slice(2);
      args[key] = argv[i + 1] || '';
      i++;
    }
  }
  return args;
}

async function generateListingContent(title) {
  const apiKey = process.env.ANTHROPIC_API_KEY;
  if (!apiKey) {
    console.log('No ANTHROPIC_API_KEY found — skipping AI generation, using title as description.');
    return {
      description: title,
      tags: [],
    };
  }

  console.log('Using Claude AI to generate listing description and tags...');

  const prompt = `You are helping an Etsy seller create a compelling product listing for their art/botanical shop "Cedar and Sage Apothecary".

Product title: "${title}"

Please generate:
1. A warm, engaging Etsy listing description (3-4 short paragraphs). Include details about the art style, potential uses, and why someone would love it. Make it feel personal and nature-inspired.
2. Exactly 13 tags relevant to the product (Etsy allows up to 13). Each tag must be 20 characters or less.

Respond in this exact JSON format:
{
  "description": "...",
  "tags": ["tag1", "tag2", ..., "tag13"]
}`;

  const res = await fetch('https://api.anthropic.com/v1/messages', {
    method: 'POST',
    headers: {
      'x-api-key': apiKey,
      'anthropic-version': '2023-06-01',
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      model: 'claude-haiku-4-5-20251001',
      max_tokens: 1024,
      messages: [{ role: 'user', content: prompt }],
    }),
  });

  if (!res.ok) {
    const err = await res.text();
    console.warn(`Claude API error: ${res.status} ${err}. Using title as description.`);
    return { description: title, tags: [] };
  }

  const data = await res.json();
  const text = data.content[0].text.trim();

  try {
    // Extract JSON from the response
    const jsonMatch = text.match(/\{[\s\S]*\}/);
    if (!jsonMatch) throw new Error('No JSON found');
    return JSON.parse(jsonMatch[0]);
  } catch {
    console.warn('Could not parse AI response as JSON. Using title as description.');
    return { description: text || title, tags: [] };
  }
}

async function main() {
  const args = parseArgs(process.argv);

  if (!args.title) {
    console.error('Usage: node src/create-listing.js --title "Your Product Title" [--image ./art.jpg] [--price 25.00] [--quantity 1]');
    process.exit(1);
  }

  const title = args.title;
  const imagePath = args.image ? path.resolve(args.image) : null;
  const price = parseFloat(args.price || '20.00');
  const quantity = parseInt(args.quantity || '1', 10);

  if (imagePath && !fs.existsSync(imagePath)) {
    console.error(`Image file not found: ${imagePath}`);
    process.exit(1);
  }

  console.log(`\nCreating listing: "${title}"`);
  console.log(`Price: $${price.toFixed(2)} | Quantity: ${quantity}`);
  if (imagePath) console.log(`Image: ${imagePath}`);
  console.log('');

  // Generate description and tags with Claude AI
  const { description, tags } = await generateListingContent(title);

  console.log('Generated description preview:');
  console.log(description.slice(0, 200) + (description.length > 200 ? '...' : ''));
  console.log(`\nTags: ${tags.join(', ')}`);
  console.log('');

  // Get Etsy shop ID
  console.log('Fetching your Etsy shop...');
  const shopId = await etsy.getMyShopId();
  console.log(`Shop ID: ${shopId}`);

  // Create the listing as a draft
  console.log('Creating draft listing on Etsy...');
  const listing = await etsy.createListing(shopId, {
    quantity,
    title,
    description,
    price,
    who_made: 'i_did',
    when_made: 'made_to_order',
    taxonomy_id: 2078, // Art > Prints (general)
    tags: tags.slice(0, 13),
    materials: [],
    shipping_profile_id: null, // Will need to set this for active listings
    state: 'draft',
    type: 'physical',
  });

  console.log(`Listing created! ID: ${listing.listing_id}`);

  // Upload image if provided
  if (imagePath) {
    console.log('Uploading image...');
    await etsy.uploadListingImage(shopId, listing.listing_id, imagePath);
    console.log('Image uploaded successfully.');
  }

  console.log(`\nDone! View your draft listing in your Etsy seller dashboard:`);
  console.log(`https://www.etsy.com/your/shops/me/listings/draft`);
}

main().catch((err) => {
  console.error('\nError:', err.message);
  process.exit(1);
});
