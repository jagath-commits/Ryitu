const assert = require('assert');
const { cleanExtractedText, formatParagraphsForJustify, isPredominantlyEnglish } = require('../src/utils/textCleaner.util');

console.log('🧪 Running Justification & Multi-Language Extraction Tests...');

// Test A: English PDF with hard line breaks wrapped at ~50 chars (like pdf-parse produces)
const rawEnglishPdfText = 
  "The quick brown fox jumps over the lazy dog\n" +
  "and continues running across the green field\n" +
  "without stopping for anything.\n\n" +
  "• Point 1: System architecture\n" +
  "• Point 2: Microservices implementation\n\n" +
  "Chapter 2: Algorithms\n\n" +
  "In computer science, algorithms are step-by-step\n" +
  "procedures for calculation, data processing and\n" +
  "automated reasoning.";

const cleanedEng = cleanExtractedText(rawEnglishPdfText);
console.log('Cleaned English:\n', cleanedEng);

assert.ok(isPredominantlyEnglish(rawEnglishPdfText), 'Must detect as English');
assert.ok(!cleanedEng.includes('The quick brown fox jumps over the lazy dog\n'), 'Intra-paragraph line breaks should be joined with space');
assert.ok(cleanedEng.includes('The quick brown fox jumps over the lazy dog and continues running across the green field without stopping for anything.'), 'Paragraph 1 must be a continuous single line for justification');
assert.ok(cleanedEng.includes('• Point 1: System architecture'), 'Preserves bullet point 1');
assert.ok(cleanedEng.includes('• Point 2: Microservices implementation'), 'Preserves bullet point 2');
assert.ok(cleanedEng.includes('Chapter 2: Algorithms'), 'Preserves chapter heading');
console.log('✔ Test A Passed: English paragraph re-flow works perfectly for justification!');

// Test B: Tamil PDF with hard line breaks wrapped at ~50 chars
const rawTamilPdfText = 
  "வேள்பாரி ஒரு வரலாற்று நாயகன். சங்க காலத்தில் வாழ்ந்த\n" +
  "பறம்பு நாட்டின் மன்னன். கொடை வள்ளல்களில் ஒருவராகப்\n" +
  "போற்றப்படும் மாவீரன்.\n\n" +
  "• குறிஞ்சி நிலம்\n" +
  "• முல்லைக்கொடிக்குத் தேர் தந்தவன்";

const cleanedTamil = cleanExtractedText(rawTamilPdfText);
console.log('Cleaned Tamil:\n', cleanedTamil);

assert.ok(!isPredominantlyEnglish(rawTamilPdfText), 'Must detect as Tamil');
assert.ok(cleanedTamil.includes('வேள்பாரி ஒரு வரலாற்று நாயகன். சங்க காலத்தில் வாழ்ந்த பறம்பு நாட்டின் மன்னன். கொடை வள்ளல்களில் ஒருவராகப் போற்றப்படும் மாவீரன்.'), 'Tamil paragraph intra-line breaks must be joined with space for justification');
assert.ok(cleanedTamil.includes('• குறிஞ்சி நிலம்'), 'Preserves Tamil bullet point');
console.log('✔ Test B Passed: Tamil paragraph re-flow works perfectly for justification!');

console.log('🎉 ALL JUSTIFICATION TESTS PASSED!');
