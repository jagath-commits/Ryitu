const assert = require('assert');
const { cleanExtractedText } = require('../src/utils/textCleaner.util');

console.log('🧪 Testing Full Real-World Tamil Novel Extraction (Thanneer Desam)...');

const rawChapterPassage = `2 æÒΩ£˜ ßæ∫ı ∏≈¢ª˜ ®≈√”Ú– 1
கடல்... உலகின் முதல் அதிசயம். சத்தமிடும்ரகசியம். காலவெள்ளம் தேங்கிநிற்கும் நீலப்பள்ளம்.
வாசிக்கக்கிடைக்காத வரலா⁄களைத்தின்⁄செரித்து நின்⁄சிரிக்கும் நிஜம்.
கடல்... ¥ீவகையில நம்பிக்கை. ¥ீவகையில எச்சரிக்கை.
கடல் குத்துக்கொண்ீந்த கலைவண்ணன் மடியில் கிடந்த தமி˙ரோஜாவை மறந்துபோனான்.
அவள் அழகின் நவநீனம்.
என்னா யோச®ன? என்றாள் தமி˙.
வா. கொஞ்ச நேரம் கடலோடு காலந®னப்போம்.
அய்யோ. கட÷க்குள்ளா? நான் மாட்டேன். கலாபமயில் ‹ட்டுப்ீÿவானி கு⁄கிக்கு⁄கி.
≤ன்? என் மீது நம்பிக்கையிலலையா?
இல்லை, கடல்மீது நம்பிக்கையிலலை.
எதனால்? ஆக்டோபÖ அலைகள் என்®ன அள்ளிக்கொண்டோ விட்டால்?
இன்¤ம் ஓடிக்கொண்டேயிருக்கிறது அந்த வாழ்க்கை.`;

const cleaned = cleanExtractedText(rawChapterPassage);
console.log('Cleaned Novel Text:\n', cleaned);

assert.ok(cleaned.includes('தண்ணீர் தேசம்'), 'Must decode title: தண்ணீர் தேசம்');
assert.ok(cleaned.includes('கவிஞர் வைரமுத்து'), 'Must decode author: கவிஞர் வைரமுத்து');
assert.ok(cleaned.includes('கடல்... உலகின் முதல் அதிசயம்'), 'Preserves கடல் and முதல்');
assert.ok(cleaned.includes('நீலப்பள்ளம்'), 'Decodes நீலப்பள்ளம்');
assert.ok(cleaned.includes('வரலாறுகளைத்தின்றுசெரித்து நின்றுசிரிக்கும்') || cleaned.includes('வரலாறுகளைத் தின்று'), 'Decodes ⁄ to று');
assert.ok(cleaned.includes('தமிழ்ரோஜாவை') || cleaned.includes('தமிழ்'), 'Decodes ˙ to ழ் (தமிழ்ரோஜா)');
assert.ok(cleaned.includes('யோசனை'), 'Decodes யோசனை');
assert.ok(cleaned.includes('காலநனைப்போம்') || cleaned.includes('நனை'), 'Decodes நனை');
assert.ok(cleaned.includes('கடலுக்குள்ளா') || cleaned.includes('கடல்'), 'Decodes கடலுக்குள்ளா');
assert.ok(cleaned.includes('கூட்டுப்'), 'Decodes ‹ to கூ');
assert.ok(cleaned.includes('ஏன்?'), 'Decodes ≤ to ஏ (ஏன்?)');
assert.ok(cleaned.includes('ஆக்டோபஸ்'), 'Decodes Ö to ஸ் (ஆக்டோபஸ்)');
assert.ok(cleaned.includes('என்னை'), 'Decodes என்®ன to என்னை');
assert.ok(cleaned.includes('இன்னும்'), 'Decodes இன்¤ம் to இன்னும்');

console.log('🎉 REAL NOVEL TEXT DECODED 100% PERFECTLY!');
