const fs = require('fs');
const path = require('path');

// Curated book cover gradient palettes
const PALETTES = [
  { bg1: '#1A365D', bg2: '#2B6CB0', accent: '#63B3ED', text: '#FFFFFF', sub: '#CBD5E0' }, // Navy / Blue
  { bg1: '#234E52', bg2: '#319795', accent: '#81E6D9', text: '#FFFFFF', sub: '#E6FFFA' }, // Teal
  { bg1: '#44337A', bg2: '#6B46C1', accent: '#B794F4', text: '#FFFFFF', sub: '#FAF5FF' }, // Purple
  { bg1: '#742A2A', bg2: '#9B2C2C', accent: '#FEB2B2', text: '#FFFFFF', sub: '#FFF5F5' }, // Crimson
  { bg1: '#1C453B', bg2: '#2F855A', accent: '#68D391', text: '#FFFFFF', sub: '#F0FFF4' }, // Forest
  { bg1: '#2D3748', bg2: '#4A5568', accent: '#CBD5E0', text: '#FFFFFF', sub: '#E2E8F0' }, // Slate
  { bg1: '#7B341E', bg2: '#C05621', accent: '#FBD38D', text: '#FFFFFF', sub: '#FFFAF0' }, // Amber
  { bg1: '#1A202C', bg2: '#2D3748', accent: '#E2E8F0', text: '#FFFFFF', sub: '#A0AEC0' }  // Dark Obsidian
];

function escapeXml(unsafe) {
  return String(unsafe)
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&apos;');
}

/**
 * Generates an SVG book cover with typography, gradient, and decorative elements
 */
function generateCoverSvg(title, author = 'Unknown') {
  const hash = (title + author).split('').reduce((acc, char) => acc + char.charCodeAt(0), 0);
  const palette = PALETTES[hash % PALETTES.length];

  // Truncate title and author for clean typography
  const safeTitle = escapeXml(title.length > 50 ? title.substring(0, 47) + '...' : title);
  const safeAuthor = escapeXml(author.length > 35 ? author.substring(0, 32) + '...' : author);

  // Split title into lines if long
  const words = safeTitle.split(' ');
  const lines = [];
  let currentLine = '';
  for (const word of words) {
    if ((currentLine + ' ' + word).trim().length > 18) {
      if (currentLine) lines.push(currentLine.trim());
      currentLine = word;
    } else {
      currentLine += (currentLine ? ' ' : '') + word;
    }
  }
  if (currentLine) lines.push(currentLine.trim());
  const displayLines = lines.slice(0, 4);

  const titleTspans = displayLines
    .map((line, idx) => `<tspan x="200" dy="${idx === 0 ? 0 : 36}">${line}</tspan>`)
    .join('');

  return `<?xml version="1.0" encoding="UTF-8"?>
<svg width="400" height="600" viewBox="0 0 400 600" fill="none" xmlns="http://www.w3.org/2000/svg">
  <defs>
    <linearGradient id="coverGrad" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" stop-color="${palette.bg1}" />
      <stop offset="100%" stop-color="${palette.bg2}" />
    </linearGradient>
    <linearGradient id="spineGrad" x1="0%" y1="0%" x2="100%" y2="0%">
      <stop offset="0%" stop-color="rgba(0,0,0,0.35)" />
      <stop offset="60%" stop-color="rgba(255,255,255,0.08)" />
      <stop offset="100%" stop-color="rgba(0,0,0,0.2)" />
    </linearGradient>
  </defs>

  <!-- Background -->
  <rect width="400" height="600" rx="16" fill="url(#coverGrad)" />

  <!-- Book Spine Highlight -->
  <rect x="0" y="0" width="30" height="600" rx="4" fill="url(#spineGrad)" />

  <!-- Border Frame -->
  <rect x="25" y="25" width="350" height="550" rx="8" stroke="${palette.accent}" stroke-opacity="0.3" stroke-width="2" fill="none" />

  <!-- Decorative Book Icon -->
  <g transform="translate(176, 120)" fill="${palette.accent}" opacity="0.85">
    <path d="M24 6L6 2C4.9 1.8 3.8 2.3 3.3 3.3C2.8 4.3 3.1 5.5 4 6.2L24 20L44 6.2C44.9 5.5 45.2 4.3 44.7 3.3C44.2 2.3 43.1 1.8 42 2L24 6Z"/>
    <path d="M4 11V38C4 39.1 4.9 40 6 40H22V24L4 11Z" opacity="0.6"/>
    <path d="M44 11L26 24V40H42C43.1 40 44 39.1 44 38V11Z" opacity="0.75"/>
  </g>

  <!-- Title -->
  <text x="200" y="250" text-anchor="middle" font-family="-apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif" font-weight="700" font-size="28" fill="${palette.text}" letter-spacing="0.5">
    ${titleTspans}
  </text>

  <!-- Divider Line -->
  <line x1="140" y1="420" x2="260" y2="420" stroke="${palette.accent}" stroke-width="2" stroke-linecap="round" opacity="0.6" />

  <!-- Author -->
  <text x="200" y="460" text-anchor="middle" font-family="-apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif" font-weight="500" font-size="18" fill="${palette.sub}" letter-spacing="1">
    ${safeAuthor}
  </text>

  <!-- Tagline / Badge -->
  <text x="200" y="530" text-anchor="middle" font-family="-apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif" font-weight="600" font-size="12" fill="${palette.accent}" letter-spacing="3" opacity="0.7">
    DIGITAL EDITION
  </text>
</svg>`;
}

async function createAndSaveDefaultCover(title, author, outputDir, fileName) {
  const svg = generateCoverSvg(title, author);
  const filePath = path.join(outputDir, fileName);
  await fs.promises.writeFile(filePath, svg, 'utf8');
  return fileName;
}

module.exports = {
  generateCoverSvg,
  createAndSaveDefaultCover
};