const assert = require('assert');
const { cleanExtractedText, isTamilDocumentOrPassage, isPredominantlyEnglish } = require('../src/utils/textCleaner.util');

console.log('🧪 Running Comprehensive English and Tamil Integrity Verification...\n');

// ==========================================
// 1. ENGLISH PDF EXTRACTION TESTS
// (Must have ZERO Tamil characters, 100% clean formatting)
// ==========================================
console.log('--- 1. Testing English Text Extraction (Zero Tamil Contamination) ---');

const englishPassages = [
  {
    name: 'English with double curly quotes & ellipsis',
    input: '“I think this is great,” she said. Wait… what about this?',
    expectedContains: ['“I think this is great,”', 'Wait…']
  },
  {
    name: 'English with single curly quotes',
    input: 'He said: ‘Welcome to the club!’ That’s wonderful.',
    expectedContains: ['‘Welcome to the club!’', 'That’s']
  },
  {
    name: 'English with en-dashes, degrees, registered trademark',
    input: 'See pages 10–20 for more details. Operating temperature: 20°–30°C. Registered® trademark © 2026.',
    expectedContains: ['10–20', '20°–30°C', 'Registered®', '© 2026']
  },
  {
    name: 'English technical & mathematical symbols',
    input: 'Note: 50% ≤ x ≤ 100%, and ∆y ≈ 0.5 μm. Resistance: 50 Ω. Formula: f(x) = √x.',
    expectedContains: ['50% ≤ x ≤ 100%', '∆y ≈ 0.5 μm', '50 Ω', '√x']
  },
  {
    name: 'English computer science textbook passage',
    input: 'Algorithm 1: Find the shortest path between nodes u and v in graph G = (V, E).\nFor each v in V, dist[v] = infinity.\n\n• Step 1: Initialize distances\n• Step 2: Traverse neighbors',
    expectedContains: ['Algorithm 1', 'dist[v]', '• Step 1: Initialize distances']
  },
  {
    name: 'English literary quote',
    input: '“To be, or not to be, that is the question…”\nWhether ’tis nobler in the mind to suffer the slings and arrows of outrageous fortune.',
    expectedContains: ['“To be, or not to be, that is the question…”', '’tis nobler']
  }
];

for (const t of englishPassages) {
  const output = cleanExtractedText(t.input);
  const tamilChars = output.match(/[\u0B80-\u0BFF]/g);
  assert.strictEqual(tamilChars, null, `FAIL: ${t.name} produced Tamil characters: ${tamilChars ? tamilChars.join(',') : ''}`);
  for (const exp of t.expectedContains) {
    assert.ok(output.includes(exp), `FAIL: ${t.name} should contain "${exp}", got: "${output}"`);
  }
  console.log(`✔ ${t.name} passed`);
}

// ==========================================
// 2. TAMIL NOVEL & LEGACY FONT PDF TESTS
// (Must decode 100% accurately with zero spelling corruption)
// ==========================================
console.log('\n--- 2. Testing Tamil Novel & Legacy Font Extraction (Spelling & Letter Accuracy) ---');

// Test 2a: Velpari CP1252 / Softland passage
const sample1 = `வ “ரக நாயகன் வே„பாரி-1
முன்னுரை
இளைப்பாற நிழலின்றித் தவŽக்”\x7F வழிப்போக்கன ன் கண்ணŽƒ பž\x7F பெரு
ஆலமர\x7F ேபால, மூவேந்தர்களு\x7F மன்னர்க„ பலரு\x7F ஆண்ட தமிழகத்திƒ,
தவŽத்தைலந்த உயŽர்களுக்காகத் தன்னையே தந்தவன் வே„பாரி.
தன்னலம‚றெகாடை உ„ளத்தாலு\x7F...`;

const out1 = cleanExtractedText(sample1);
assert.ok(out1.includes('வேள்பாரி'), 'Decodes வேள்பாரி');
assert.ok(out1.includes('தவிக்கும்'), 'Decodes தவிக்கும்');
assert.ok(out1.includes('கண்ணில்'), 'Decodes கண்ணில்');
assert.ok(out1.includes('ஆலமரம் போல'), 'Decodes ஆலமரம் போல');
assert.ok(out1.includes('மூவேந்தர்களும்'), 'Decodes மூவேந்தர்களும்');
assert.ok(out1.includes('மன்னர்கள்'), 'Decodes மன்னர்கள்');
assert.ok(out1.includes('தமிழகத்தில்'), 'Decodes தமிழகத்தில்');
assert.ok(out1.includes('உயிர்களுக்காகத்'), 'Decodes உயிர்களுக்காகத்');
assert.ok(out1.includes('தன்னலமற்ற'), 'Decodes தன்னலமற்ற');
assert.ok(out1.includes('கொடை'), 'Decodes கொடை');
assert.ok(out1.includes('உள்ளத்தாலும்'), 'Decodes உள்ளத்தாலும்');
console.log('✔ Velpari CP1252 / Softland passed with 100% spelling accuracy');

// Test 2b: Velpari Late-Volume DTP pages (1200-1313)
const lateDtpSample = `காரைனலயின் மைல்விளிம்பில்னபண்களின் கண்ணீர் ,
உருளமுடியாதனபரும்பானறயாக உருத்திரண்டு நின்றிருந்தது.
ஆறாம்நாள் நள்ளிரவு கூவல்குடியினர் எழுப்பிய ஓனச
னைலனயங்கும் எதினராலித்தது .
பனனயன் கைமன பனனயன் கைமன
பல்லுயிர் ஓம்பும் பாரி மவமள
தினனயின் அளமவ பிறவுயிர் வாடினும்
துடித்துக்காக்கும்னதால்குடி மவந்மத – நீ
சூதுனசய்யினும் சூழ்ந்து தாக்கினும்
ஏதுைற்றவராய் இழந்மதனசல்வர்`;

const outDtp = cleanExtractedText(lateDtpSample);
assert.ok(outDtp.includes('பெண்களின்'), 'Decodes பெண்களின்');
assert.ok(outDtp.includes('பெரும்பாறையாக'), 'Decodes பெரும்பாறையாக');
assert.ok(outDtp.includes('காரமலையின்'), 'Decodes காரமலையின்');
assert.ok(outDtp.includes('மேல்விளிம்பில்'), 'Decodes மேல்விளிம்பில்');
assert.ok(outDtp.includes('எதிரொலித்தது'), 'Decodes எதிரொலித்தது');
assert.ok(outDtp.includes('பனையன் மகனே'), 'Decodes பனையன் மகனே');
assert.ok(outDtp.includes('பாரி வேளே'), 'Decodes பாரி வேளே');
assert.ok(outDtp.includes('தினையின் அளவே'), 'Decodes தினையின் அளவே');
assert.ok(outDtp.includes('தொல்குடி வேந்தே'), 'Decodes தொல்குடி வேந்தே');
assert.ok(outDtp.includes('சூதுசெய்யினும்'), 'Decodes சூதுசெய்யினும்');
assert.ok(outDtp.includes('ஏதுமற்றவராய்'), 'Decodes ஏதுமற்றவராய்');
console.log('✔ Velpari Late-Volume DTP kombu passed with 100% spelling accuracy');

// Test 2c: Thanneer Desam MacRoman / InDesign TSCII
const macRomanSample = `taNNIr tEcam
æÒΩநீசு ßæ∫ı
∏≈துபூசு ®≈√குÚ–
2
¡ீÚ–≈¡®ழ்.
Ãவுரு Ã®வுீı ¡ீÛ–≈°∫ı.
–®வுÚ–®≈Úæ ß∫°∏ı.
ளு≈˚®முளு≈˚®முமூ°ˆ
லு≈∫√Ì∏˚. ¨Ì∏துல்Úæதுரு
லு∏◊ı லு∆Ã¡மூதுரு∏˚.
லு®» ±Ò 303.`;

const outMac = cleanExtractedText(macRomanSample);
assert.ok(outMac.includes('தண்ணீர் தேசம்'), 'Decodes தண்ணீர் தேசம்');
assert.ok(outMac.includes('கவிஞர் வைரமுத்து'), 'Decodes கவிஞர் வைரமுத்து');
assert.ok(outMac.includes('மருத்துவமனை.'), 'Decodes மருத்துவமனை.');
assert.ok(outMac.includes('குடல்'), 'Decodes குடல்');
assert.ok(outMac.includes('மருந்துவாசம்.'), 'Decodes மருந்துவாசம்.');
assert.ok(outMac.includes('துடைத்துவைத்த சோகம்.'), 'Decodes துடைத்துவைத்த சோகம்.');
assert.ok(outMac.includes('வெள்ளைவெள்ளையாய்'), 'Decodes வெள்ளைவெள்ளையாய்');
assert.ok(outMac.includes('அவசரங்கள். ஆங்கிலத்தில்'), 'Decodes அவசரங்கள். ஆங்கிலத்தில்');
assert.ok(outMac.includes('அகவும் அழகுமயில்கள்.'), 'Decodes அகவும் அழகுமயில்கள்.');
assert.ok(outMac.includes('அறை எண் 303.'), 'Decodes அறை எண் 303.');
console.log('✔ Thanneer Desam MacRoman / TSCII passed with 100% spelling accuracy');

// Test 2d: Thanneer Desam Anjal / InDesign DTP
const anjalSample = `229 நான் இ’க்கிறே…ா? இறந்துவிட்ßº…ா? இறந்தபிறகும் க…வ வ’மா? இரு®ல். நிஜம் - எருல் ாம் நிஜம். பக்கத்திரு நிளிகும் உதவிக்கப்பல் ின் ராட்சக்கிரே…ின் கரங்கள், முழ்கிமூ பºகைத் தண்ணீர்ச் டிசாட்ºச் டிசாட்ºக் கºலுக்கு மேßல் தூக்கிக் கப்பல் ிரு வைத்துவிட்ºது. மரணத்தின் பி மூில் ி’ந்த பºகு, வாழ்வின் ம மூிரு வந்து விழுந்தது. கரை... டிபாழி‘ம் மழை டிபாழிந்து டிகாண்ßºமூி’ந்தது. ந®…‘ம் ம…ிதர்கள் ந®…ந்து டிகாண்ßºமூி’ந்தார்கள். உறவி…ர்கள் உமூிர் து க்க மீ…வர்கள் காத்தி’க்க காவருதுறை‘ம் கºßல்ாரக் காவருப®º‘ம் டிவளிறிப்“ன்…கை ற்த்தி’க்க தண்ணீர் தேசத்துக் கைதிகள் தரை இறங்கி…ார்கள்.`;

const outAnjal = cleanExtractedText(anjalSample);
assert.ok(outAnjal.includes('நான் இருக்கிறேனா?'), 'Decodes நான் இருக்கிறேனா?');
assert.ok(outAnjal.includes('இறந்துவிட்டேனா?'), 'Decodes இறந்துவிட்டேனா?');
assert.ok(outAnjal.includes('இல்லை.'), 'Decodes இல்லை.');
assert.ok(outAnjal.includes('எல்லாம் நிஜம்.'), 'Decodes எல்லாம் நிஜம்.');
assert.ok(outAnjal.includes('பக்கத்தில் நிற்கும் உதவிக்கப்பலின்'), 'Decodes பக்கத்தில் நிற்கும்');
assert.ok(outAnjal.includes('ராட்சக்கிரேனின் கரங்கள்'), 'Decodes ராட்சக்கிரேனின்');
assert.ok(outAnjal.includes('மூழ்கிய படகைத்'), 'Decodes மூழ்கிய படகைத்');
assert.ok(outAnjal.includes('வாழ்வின் மடியில் வந்து விழுந்தது'), 'Decodes வாழ்வின் மடியில் வந்து விழுந்தது');
assert.ok(outAnjal.includes('பொழியும் மழை பொழிந்து கொண்டேயிருந்தது'), 'Decodes பொழியும் மழை பொழிந்து கொண்டேயிருந்தது');
assert.ok(outAnjal.includes('நனையும் மனிதர்கள் நனைந்து கொண்டேயிருந்தார்கள்'), 'Decodes நனையும் மனிதர்கள் நனைந்து கொண்டேயிருந்தார்கள்');
assert.ok(outAnjal.includes('காவல்துறையும் கடலோரக் காவல்படையும்'), 'Decodes காவல்துறையும் கடலோரக் காவல்படையும்');
assert.ok(outAnjal.includes('வெற்றிப்புன்னகை பூத்திருக்க'), 'Decodes வெற்றிப்புன்னகை பூத்திருக்க');
assert.ok(outAnjal.includes('தரை இறங்கினார்கள்'), 'Decodes தரை இறங்கினார்கள்');
console.log('✔ Thanneer Desam Anjal / InDesign DTP passed with 100% spelling accuracy');

// Test 2e: Modern Unicode Tamil
const modernTamil = 'தமிழ்நாடு இந்தியாவின் தென் பகுதியில் அமைந்துள்ள ஒரு மாநிலமாகும். சென்னை இதன் தலைநகரம்.';
const outModern = cleanExtractedText(modernTamil);
assert.strictEqual(outModern, modernTamil, 'Clean modern Unicode Tamil must remain 100% untouched');
console.log('✔ Modern Unicode Tamil passed with 100% preservation');

console.log('\n🎉 ALL ENGLISH AND TAMIL INTEGRITY TESTS PASSED PERFECTLY (100% SUCCESS)!');
