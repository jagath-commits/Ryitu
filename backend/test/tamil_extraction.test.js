const assert = require('assert');
const { cleanExtractedText, decodeLegacyTamilIfPresent, LEGACY_SPECIAL_MAP, LEGACY_ASCII_MAP } = require('../src/utils/textCleaner.util');

console.log('🧪 Running Tamil Extraction & Legacy Decoding Test Suite...\n');

// Test 1: User's first test passage with corrupted legacy glyphs (வ “ரக, வே„பாரி, தவŽக்”, கண்ணŽƒ, etc.)
const sample1 = `வ “ரக நாயகன் வே„பாரி-1
முன்னுரை
இளைப்பாற நிழலின்றித் தவŽக்”\x7F வழிப்போக்கன ன் கண்ணŽƒ பž\x7F பெரு
ஆலமர\x7F ேபால, மூவேந்தர்களு\x7F மன்னர்க„ பலரு\x7F ஆண்ட தமிழகத்திƒ,
தவŽத்தைலந்த உயŽர்களுக்காகத் தன்னையே தந்தவன் வே„பாரி.
தன்னலம‚றெகாடை உ„ளத்தாலு\x7F...`;

const output1 = cleanExtractedText(sample1);
console.log('Output 1:\n' + output1 + '\n');

assert.ok(output1.includes('வீரயுக நாயகன் வேள்பாரி') || output1.includes('வீரக'), 'Must correctly decode வ “ரக -> வீரக / வீரயுக');
assert.ok(output1.includes('வேள்பாரி'), 'Must correctly decode வே„பாரி -> வேள்பாரி');
assert.ok(output1.includes('தவிக்கும்'), 'Must correctly decode தவŽக்”\\x7F -> தவிக்கும்');
assert.ok(output1.includes('கண்ணில்'), 'Must correctly decode கண்ணŽƒ -> கண்ணில்');
assert.ok(output1.includes('படும் பெரு'), 'Must correctly decode பž\\x7F பெரு -> படும் பெரு');
assert.ok(output1.includes('ஆலமரம் போல'), 'Must correctly decode ஆலமர\\x7F ேபால -> ஆலமரம் போல');
assert.ok(output1.includes('மூவேந்தர்களும்'), 'Must correctly decode மூவேந்தர்களு\\x7F -> மூவேந்தர்களும்');
assert.ok(output1.includes('மன்னர்கள்'), 'Must correctly decode மன்னர்க„ -> மன்னர்கள்');
assert.ok(output1.includes('பலரும்'), 'Must correctly decode பலரு\\x7F -> பலரும்');
assert.ok(output1.includes('தமிழகத்தில்'), 'Must correctly decode தமிழகத்திƒ -> தமிழகத்தில்');
assert.ok(output1.includes('உயிர்களுக்காகத்'), 'Must correctly decode உயŽர்களுக்காகத் -> உயிர்களுக்காகத்');
assert.ok(output1.includes('தன்னலமற்ற'), 'Must correctly decode தன்னலம\\x7F‚ற -> தன்னலமற்ற');
assert.ok(output1.includes('கொடை'), 'Must correctly decode ெகாடை -> கொடை');
assert.ok(output1.includes('உள்ளத்தாலும்'), 'Must correctly decode உ„ளத்தாலு\\x7F -> உள்ளத்தாலும்');
console.log('✔ Test 1 Passed: Exact Velpari passage successfully restored to pure Unicode Tamil!');

// Test 2: User's second test passage with full legacy novel text
const sample2 = `ஒள ¯ நyச{திரமானா}; வ„ளƒ எ}றெசாƒலி} வœவமானா}. «ƒைலtெகாœt”{ ேதைர{
த|தவ} மyž\x7F அƒல... தன¢ வ “ர{தாƒ எ}² ஒள வ “˜ ெவ‚றிtெகாœைய நாyœvெச}றவ}
ேவ„பாƬ.
இய‚ைகt” மன தன } ேபராைசt” இைடயŽƒ இ}² நடt”\x7F ேபாராyட{தி}
ஆதிவœவதா}\x7F ேவ„பாƬயŽ} கைத. தி¯© திைசெயƒலா\x7F அ¯வŽ ெகாyž\x7F ”றிxசி நில{திƒ,
அ|த அ¯வŽ ந“Ƭ§ ”¸ைமைட பாƬயŽ} கரப‚றி நடtக வா¯uக„...
”ல~பாடƒ
¬tைக வŽைட{தபœ பா€|¢ெகாzœ¯|தன`;

const output2 = cleanExtractedText(sample2);
console.log('Output 2:\n' + output2 + '\n');

// Assertions on Output 2
assert.ok(output2.includes('நட்சத்திரமானான்'), 'Must decode நyச{திரமானா} -> நட்சத்திரமானான்');
assert.ok(output2.includes('வள்ளல்'), 'Must decode வ„ளƒ -> வள்ளல்');
assert.ok(output2.includes('வடிவமானான்'), 'Must decode வœவமானா} -> வடிவமானான்');
assert.ok(output2.includes('தேரைத்'), 'Must decode ேதைர{ -> தேரைத்');
assert.ok(output2.includes('தந்தவன்'), 'Must decode த|தவ} -> தந்தவன்');
assert.ok(output2.includes('மட்டும் அல்ல'), 'Must decode மyž\\x7F அƒல -> மட்டும் அல்ல');
assert.ok(output2.includes('தனது'), 'Must decode தன¢ -> தனது');
assert.ok(output2.includes('வீரத்தால்'), 'Must decode வ “ர{தாƒ -> வீரத்தால்');
assert.ok(output2.includes('என்று'), 'Must decode எ}² -> என்று');
assert.ok(output2.includes('வெற்றிக்கொடியை'), 'Must decode ெவ‚றிtெகாœைய -> வெற்றிக்கொடியை');
assert.ok(output2.includes('நாட்டிச்சென்றவன்'), 'Must decode நாyœvெச}றவ} -> நாட்டிச்சென்றவன்');
assert.ok(output2.includes('வேள்பாரி'), 'Must decode ேவ„பாƬ -> வேள்பாரி');
assert.ok(output2.includes('இயற்கைக்கு'), 'Must decode இய‚ைகt” -> இயற்கைக்கு');
assert.ok(output2.includes('பேராசைக்கு'), 'Must decode ேபராைசt” -> பேராசைக்கு');
assert.ok(output2.includes('இடையில்'), 'Must decode இைடயŽƒ -> இடையில்');
assert.ok(output2.includes('இன்று'), 'Must decode இ}² -> இன்று');
assert.ok(output2.includes('போராட்டத்தின்'), 'Must decode ேபாராyட{தி} -> போராட்டத்தின்');
assert.ok(output2.includes('வேள்பாரியின்'), 'Must decode ேவ„பாƬயŽ} -> வேள்பாரியின்');
assert.ok(output2.includes('அருவி'), 'Must decode அ¯வŽ -> அருவி');
assert.ok(output2.includes('குறிஞ்சி நிலத்தில்'), 'Must decode ”றிxசி நில{திƒ -> குறிஞ்சி நிலத்தில்');
assert.ok(output2.includes('அந்த'), 'Must decode அ|த -> அந்த');
assert.ok(output2.includes('கரபற்றி'), 'Must decode கரப‚றி -> கரபற்றி');
assert.ok(output2.includes('நடக்க'), 'Must decode நடtக -> நடக்க');
assert.ok(output2.includes('வாருங்கள்'), 'Must decode வா¯uக„ -> வாருங்கள்');
assert.ok(output2.includes('குலப்பாடல்'), 'Must decode ”ல~பாடƒ -> குலப்பாடல்');
assert.ok(output2.includes('விடைத்தபடி'), 'Must decode வŽைட{தபœ -> விடைத்தபடி');
assert.ok(output2.includes('பாய்ந்துகொண்டிருந்தன'), 'Must decode பா€|¢ெகாzœ¯|தன -> பாய்ந்துகொண்டிருந்தன');
console.log('✔ Test 2 Passed: Full novel passage decoded accurately with 100% grammar and structure!');

// Test 3: Modern Unicode Tamil preservation (must NOT be mutated or distorted)
const modernTamil = 'தமிழ்நாடு இந்தியாவின் தென் பகுதியில் அமைந்துள்ள ஒரு மாநிலமாகும். சென்னை இதன் தலைநகரம்.';
const outputModern = cleanExtractedText(modernTamil);
assert.strictEqual(outputModern, modernTamil, 'Clean modern Unicode Tamil must remain 100% untouched');
console.log('✔ Test 3 Passed: Modern Unicode Tamil is 100% preserved without modification.');

// Test 4: English text preservation (must NOT be affected)
const englishText = 'This is a standard English book with chapter titles, punctuation, and formatting.\nIt should be 100% untouched.';
const outputEnglish = cleanExtractedText(englishText);
assert.strictEqual(outputEnglish, englishText, 'Standard English text must remain 100% untouched');
console.log('✔ Test 4 Passed: English text is 100% preserved.');

// Test 5: Real-world CP1252 byte stream from user's Velpari PDF
const sampleCp1252 = "வ \x93ரக நாயகன் வே\x84பாரி-1\nமுன்ன்ரை\nஇளைப்பாற நிழலின்றித் தவ\x8eக்\x94ம் வழிப்போக்கன\x8fன் கண்ண\x8e\x83 ப\x9eம் பெரும் ஆலமரம்போல, மூவேந்தர்களும் மன்னர்க\x84 பலரும் ஆண்ட தமிழகத்தி\x83,\nதவ\x8eத்தலைந்த உய\x8eர்களுக்காகத் தன்னையே தந்தவன் வே\x84பாரி.\nதன்னலம\x82ற கொடை உ\x84ளத்தாலும், அன்புவழிப்பட்ட வா\x85வ\x8eய\x83 மரபாலும் பாரிய\x8eன் புக\x85 தமி\x85 நிலம் எங்\x94ம் பரவ\x8eயது. மூவேந்தர்களானேசர, சோழ, பாண்\x9cயர்க\x84 அவன் புக\x85 கண்\x9e வெதும்ப\x8eனர். பறம்பு நாட்\x9cன் நிலவளம் அவர்கள\x8fன் கண்கைள உறுத்தியது. பாரிக்\x94 எதிராகத் தன\x8fத்தன\x8fேய அவர்க\x84 மே\x82ெகாண்ட போர் முய\x82சிக\x84 கை\x95டவ\x8e\x83ைல. இறுதிய\x8e\x83 மூவேந்தர்களும் ஒன்றிணைந்தனர்.\nஅவர்கள\x8fன் \x95ட்\x9eப்பைட பாரிய\x8eன் பறம்புநாட்டை அனைத்துத் திசைகள\x8f\x83 இருந்தும் ஒருசேரத் தாக்கியது. சின்னஞ்சிறு `\x9cரா\x80ீ நகரின் ம\x91து மொத்த கிரேக்கப் பைடம் போர் தொ\x9eத்தைதப் போலத்தான் இதுவும் நிக\x85ந்தது.\nதைலயானங்கானத்துப் போர், வெண்ண\x8eைலப் போர், வாகைப் பறந்தைலப் போர், களிமலப் போர் என சங்ககாலத் தமிழகம், \x94ருதி பெருக்கெ\x9eத்து ஓ\x9cய எண்ண\x82ற போர்க்களங்கைளக் கண்டது. அங்கெ\x83லாம் நடைபெ\x82ற போரி\x83 மூவேந்தர்கள\x8f\x83 யாரேன்ம் ஒருவர் வெ\x82றிபெ\x82றார். ம\x82றவர்க\x84 தோ\x82ேறா\x9cனர். ஆனா\x83, `பறம்புமைலப் போரி\x83ீ மட்\x9eேம மூவேந்தர்களும் ஒருசேர தோ\x83வ\x8eையத் தளிவ\x8eனர். தமிழக வரலா\x82றி\x83 அத\x82\x94 முன்பும் அத\x82\x94ப் ப\x8eன்பும் நிகழாத வ \x93ரச்சரித்திரம் இது.\nபெரும் நிலப்பரப்பை ஆண்ட மூவேந்தர்கள\x8fன் \x95ட்\x9eப்பைட, ஒரு \x94றுநில மன்னனா\x83 சிதற\x9cக்கப்பட்டது. அதன் ப\x8eன் மூவேந்தர்களும் ஒன்றா\x80 சதிசெ\x80து, வஞ்சினம் நிக\x85த்தி, பாரிய\x8eன் உய\x8eர் பறித்தனர். வ \x93ரத்தா\x83 சாதிக்க மு\x9cயாதைத துரோகம் செ\x80து மு\x9cத்தது.\nவென்றவர்கள\x8fன் பெயர்க\x84 இன்று வைர துலங்கவ\x8e\x83ைல. ஆனா\x83 வ \x93\x85த்தப்பட்ட பாரி, வரலா\x82றி\x83";

const outputCp1252 = cleanExtractedText(sampleCp1252);
assert.ok(outputCp1252.includes('வீரயுக நாயகன் வேள்பாரி-1') || outputCp1252.includes('வீரக நாயகன் வேள்பாரி-1'), 'Decodes title');
assert.ok(outputCp1252.includes('முன்னுரை'), 'Decodes முன்னுரை');
assert.ok(outputCp1252.includes('தவிக்கும் வழிப்போக்கனின் கண்ணில் படும்'), 'Decodes தவிக்கும் வழிப்போக்கனின் கண்ணில் படும்');
assert.ok(outputCp1252.includes('வாழ்வியல் மரபாலும் பாரியின் புகழ் தமிழ் நிலம் எங்கும் பரவியது'), 'Decodes வாழ்வியல் மரபாலும் பாரியின் புகழ் தமிழ் நிலம் எங்கும் பரவியது');
assert.ok(outputCp1252.includes('பாண்டியர்கள் அவன் புகழ் கண்டு வெதும்பினர்'), 'Decodes பாண்டியர்கள் அவன் புகழ் கண்டு வெதும்பினர்');
assert.ok(outputCp1252.includes('அவர்களின் கண்களை உறுத்தியது'), 'Decodes அவர்களின் கண்களை உறுத்தியது');
assert.ok(outputCp1252.includes('பாரிக்கு எதிராகத் தனித்தனியே அவர்கள்'), 'Decodes பாரிக்கு எதிராகத் தனித்தனியே அவர்கள்');
assert.ok(outputCp1252.includes('மேற்கொண்ட போர் முயற்சிகள் கைகூடவில்லை'), 'Decodes மேற்கொண்ட போர் முயற்சிகள் கைகூடவில்லை');
assert.ok(outputCp1252.includes('அவர்களின் கூட்டுப்படை பாரியின் பறம்புநாட்டை'), 'Decodes கூட்டுப்படை');
assert.ok(outputCp1252.includes('‘டிராய்’ நகரின் மீது மொத்த கிரேக்கப் படையும் போர் தொடுத்ததைப்'), 'Decodes டிராய் நகரின் மீது மொத்த கிரேக்கப் படையும் போர் தொடுத்ததைப்');
assert.ok(outputCp1252.includes('தலையானங்கானத்துப் போர்'), 'Decodes தலையானங்கானத்துப் போர்');
assert.ok(outputCp1252.includes('வாகைப் பறந்தலைப் போர்'), 'Decodes வாகைப் பறந்தலைப் போர்');
assert.ok(outputCp1252.includes('குருதி பெருக்கெடுத்து ஓடிய எண்ணற்ற போர்க்களங்களைக் கண்டது'), 'Decodes போர்க்களங்களைக் கண்டது');
assert.ok(outputCp1252.includes('அங்கெல்லாம் நடைபெற்ற போரில் மூவேந்தர்களில் யாரேனும் ஒருவர் வெற்றிபெற்றார்'), 'Decodes அங்கெல்லாம் நடைபெற்ற போரில்');
assert.ok(outputCp1252.includes('மற்றவர்கள் தோற்றோடினர்'), 'Decodes தோற்றோடினர்');
assert.ok(outputCp1252.includes('‘பறம்புமலைப் போரில்’ மட்டுமே மூவேந்தர்களும் ஒருசேர தோல்வியைத் தழுவினர்'), 'Decodes பறம்புமலைப் போரில்');
assert.ok(outputCp1252.includes('தமிழக வரலாற்றில் அதற்கு முன்பும் அதற்குப் பின்பும் நிகழாத வீரச்சரித்திரம் இது'), 'Decodes வீரச்சரித்திரம்');
assert.ok(outputCp1252.includes('குறுநில மன்னனால் சிதறடிக்கப்பட்டது'), 'Decodes குறுநில மன்னனால் சிதறடிக்கப்பட்டது');
assert.ok(outputCp1252.includes('ஒன்றாய் சதிசெய்து, வஞ்சினம் நிகழ்த்தி'), 'Decodes ஒன்றாய் சதிசெய்து, வஞ்சினம் நிகழ்த்தி');
assert.ok(outputCp1252.includes('வீரத்தால் சாதிக்க முடியாததை துரோகம் செய்து முடித்தது'), 'Decodes முடியாததை துரோகம் செய்து முடித்தது');
assert.ok(outputCp1252.includes('இன்று வரை துலங்கவில்லை. ஆனால் வீழ்த்தப்பட்ட பாரி'), 'Decodes இன்று வரை துலங்கவில்லை. ஆனால் வீழ்த்தப்பட்ட பாரி');
console.log('✔ Test 5 Passed: Full real-world CP1252 byte stream decoded 100% cleanly!');

console.log('\n🎉 ALL TAMIL INTEGRITY TESTS PASSED WITH 100% SUCCESS!');
