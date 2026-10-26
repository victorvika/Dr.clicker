/// App UI strings — multi-language support
/// Default: English
class S {
  static String _lang = 'en';
  static void setLang(String l) => _lang = l;
  static String get lang => _lang;

  static const languages = {
    'en': 'English',
    'hi': 'Hindi (हिन्दी)',
    'ta': 'Tamil (தமிழ்)',
    'te': 'Telugu (తెలుగు)',
    'kn': 'Kannada (ಕನ್ನಡ)',
  };

  static String t(String key) {
    final map = _all[key];
    if (map == null) return key;
    return map[_lang] ?? map['en'] ?? key;
  }

  static const _all = {
    // ── HEADER ──
    'app_name':           {'en': 'Dr.Clicker', 'hi': 'Dr.Clicker', 'ta': 'Dr.Clicker', 'te': 'Dr.Clicker', 'kn': 'Dr.Clicker'},
    'app_subtitle':       {'en': 'Auto-Accept • Rapido & Ola • 100% Free', 'hi': 'ऑटो-एक्सेप्ट • Rapido & Ola • 100% फ्री', 'ta': 'ஆட்டோ-அக்செப்ட் • Rapido & Ola • 100% இலவசம்', 'te': 'ఆటో-యాక్సెప్ట్ • Rapido & Ola • 100% ఉచితం', 'kn': 'ಆಟೋ-ಆಕ್ಸೆಪ್ಟ್ • Rapido & Ola • 100% ಉಚಿತ'},
    'status_on':          {'en': 'ON', 'hi': 'चालू', 'ta': 'ஆன்', 'te': 'ఆన్', 'kn': 'ಆನ್'},
    'status_off':         {'en': 'OFF', 'hi': 'बंद', 'ta': 'ஆஃப்', 'te': 'ఆఫ్', 'kn': 'ಆಫ್'},

    // ── PERMISSIONS ──
    'perm_title':         {'en': 'PERMISSIONS — COMPLETE THESE 3 STEPS', 'hi': 'अनुमतियाँ — ये 3 कदम पूरे करो', 'ta': 'அனுமதிகள் — இந்த 3 படிகளை முடியுங்கள்', 'te': 'అనుమతులు — ఈ 3 దశలను పూర్తి చేయండి', 'kn': 'ಅನುಮತಿಗಳು — ಈ 3 ಹಂತಗಳನ್ನು ಪೂರ್ಣಗೊಳಿಸಿ'},
    'perm_a11y':          {'en': 'Enable Accessibility', 'hi': 'Accessibility चालू करो', 'ta': 'Accessibility இயக்கு', 'te': 'Accessibility ఆన్ చేయండి', 'kn': 'Accessibility ಆನ್ ಮಾಡಿ'},
    'perm_overlay':       {'en': 'Grant Overlay Permission', 'hi': 'Overlay अनुमति दो', 'ta': 'Overlay அனுமதி கொடு', 'te': 'Overlay అనుమతి ఇవ్వండి', 'kn': 'Overlay ಅನುಮತಿ ನೀಡಿ'},
    'perm_battery':       {'en': 'Disable Battery Optimization', 'hi': 'Battery Optimization हटाओ', 'ta': 'Battery Optimization நீக்கு', 'te': 'Battery Optimization తీసివేయండి', 'kn': 'Battery Optimization ತೆಗೆಯಿರಿ'},
    'tap':                {'en': 'TAP', 'hi': 'टैप', 'ta': 'தட்டு', 'te': 'నొక్కండి', 'kn': 'ಒತ್ತಿ'},

    // ── ENGINE ──
    'engine_title':       {'en': 'Engine Activation', 'hi': 'इंजन चालू करो', 'ta': 'Engine இயக்கு', 'te': 'Engine ఆన్ చేయండి', 'kn': 'Engine ಆನ್ ಮಾಡಿ'},
    'engine_on_desc':     {'en': '⚡ Monitoring screen — auto-click active', 'hi': '⚡ स्क्रीन मॉनिटर हो रही है', 'ta': '⚡ திரை கண்காணிக்கிறது', 'te': '⚡ స్క్రీన్ పర్యవేక్షణ', 'kn': '⚡ ಸ್ಕ್ರೀನ್ ಮೇಲ್ವಿಚಾರಣೆ'},
    'engine_off_desc':    {'en': 'Auto-accepts rides when they appear', 'hi': 'Ride आने पर auto-accept करेगा', 'ta': 'Ride வரும்போது auto-accept செய்யும்', 'te': 'Ride వచ్చినప్పుడు auto-accept చేస్తుంది', 'kn': 'Ride ಬಂದಾಗ auto-accept ಮಾಡುತ್ತದೆ'},

    // ── FLOATING PANEL ──
    'float_title':        {'en': 'Floating Panel', 'hi': 'फ्लोटिंग पैनल', 'ta': 'மிதக்கும் பேனல்', 'te': 'ఫ్లోటింగ్ ప్యానెల్', 'kn': 'ಫ್ಲೋಟಿಂಗ್ ಪ್ಯಾನೆಲ್'},
    'float_on_desc':      {'en': '🟢 Visible on screen — drag to move', 'hi': '🟢 स्क्रीन पर दिख रहा है', 'ta': '🟢 திரையில் தெரிகிறது', 'te': '🟢 స్క్రీన్‌పై కనిపిస్తోంది', 'kn': '🟢 ಸ್ಕ್ರೀನ್‌ನಲ್ಲಿ ಕಾಣಿಸುತ್ತಿದೆ'},
    'float_off_desc':     {'en': 'Status panel over Rapido/Ola', 'hi': 'Rapido/Ola पर status panel', 'ta': 'Rapido/Ola மீது status panel', 'te': 'Rapido/Ola పైన status panel', 'kn': 'Rapido/Ola ಮೇಲೆ status panel'},

    // ── VOICE ──
    'voice_title':        {'en': 'Voice Announcement', 'hi': 'वॉइस अनाउंसमेंट', 'ta': 'குரல் அறிவிப்பு', 'te': 'వాయిస్ ప్రకటన', 'kn': 'ಧ್ವನಿ ಘೋಷಣೆ'},
    'voice_on_desc':      {'en': '🔊 Announces price, distance, drop on accept', 'hi': '🔊 Price, distance, drop बताएगा', 'ta': '🔊 Price, distance, drop சொல்லும்', 'te': '🔊 Price, distance, drop చెబుతుంది', 'kn': '🔊 Price, distance, drop ಹೇಳುತ್ತದೆ'},
    'voice_off_desc':     {'en': 'Silent mode — no voice', 'hi': 'मौन मोड', 'ta': 'அமைதி பயன்முறை', 'te': 'మౌన మోడ్', 'kn': 'ಮೌನ ಮೋಡ್'},
    'voice_lang':         {'en': 'VOICE LANGUAGE', 'hi': 'आवाज़ भाषा', 'ta': 'குரல் மொழி', 'te': 'వాయిస్ భాష', 'kn': 'ಧ್ವನಿ ಭಾಷೆ'},
    'test_voice':         {'en': 'Test Voice', 'hi': 'टेस्ट वॉइस', 'ta': 'குரலை சோதி', 'te': 'వాయిస్ పరీక్ష', 'kn': 'ಧ್ವನಿ ಪರೀಕ್ಷೆ'},

    // ── CLICK SPEED ──
    'speed_title':        {'en': 'CLICK SPEED', 'hi': 'क्लिक स्पीड', 'ta': 'கிளிக் வேகம்', 'te': 'క్లిక్ స్పీడ్', 'kn': 'ಕ್ಲಿಕ್ ಸ್ಪೀಡ್'},
    'speed_desc':         {'en': 'Tap delay: {0}ms — lower = faster', 'hi': 'टैप देरी: {0}ms — कम = तेज़', 'ta': 'தட்டு தாமதம்: {0}ms — குறைவு = வேகம்', 'te': 'ట్యాప్ ఆలస్యం: {0}ms — తక్కువ = వేగం', 'kn': 'ಟ್ಯಾಪ್ ವಿಳಂಬ: {0}ms — ಕಡಿಮೆ = ವೇಗ'},
    'ultra_fast':         {'en': '⚡ Ultra', 'hi': '⚡ अल्ट्रा', 'ta': '⚡ அதிவேகம்', 'te': '⚡ అల్ట్రా', 'kn': '⚡ ಅಲ್ಟ್ರಾ'},
    'fast':               {'en': '🏃 Fast', 'hi': '🏃 तेज़', 'ta': '🏃 வேகம்', 'te': '🏃 వేగం', 'kn': '🏃 ವೇಗ'},
    'normal':             {'en': '🚶 Normal', 'hi': '🚶 सामान्य', 'ta': '🚶 சாதாரணம்', 'te': '🚶 సాధారణ', 'kn': '🚶 ಸಾಮಾನ್ಯ'},
    'slow':               {'en': '🐢 Slow', 'hi': '🐢 धीमा', 'ta': '🐢 மெதுவாக', 'te': '🐢 నెమ్మది', 'kn': '🐢 ನಿಧಾನ'},

    // ── FILTERS ──
    'price_filter':       {'en': 'PRICE FILTER', 'hi': 'प्राइस फ़िल्टर', 'ta': 'விலை வடிகட்டி', 'te': 'ధర ఫిల్టర్', 'kn': 'ಬೆಲೆ ಫಿಲ್ಟರ್'},
    'price_desc':         {'en': 'Rupees (₹) — 0 = no limit', 'hi': 'रुपये (₹) — 0 = कोई सीमा नहीं', 'ta': 'ரூபாய் (₹) — 0 = வரம்பு இல்லை', 'te': 'రూపాయలు (₹) — 0 = పరిమితి లేదు', 'kn': 'ರೂಪಾಯಿ (₹) — 0 = ಮಿತಿ ಇಲ್ಲ'},
    'filter_off_desc':    {'en': 'Filter OFF — all rides accepted', 'hi': 'फ़िल्टर OFF — सब rides accept', 'ta': 'வடிகட்டி OFF — எல்லா rides accept', 'te': 'ఫిల్టర్ OFF — అన్ని rides accept', 'kn': 'ಫಿಲ್ಟರ್ OFF — ಎಲ್ಲಾ rides accept'},
    'dist_filter':        {'en': 'DISTANCE FILTER', 'hi': 'दूरी फ़िल्टर', 'ta': 'தூர வடிகட்டி', 'te': 'దూరం ఫిల్టర్', 'kn': 'ದೂರ ಫಿಲ್ಟರ್'},
    'dist_desc':          {'en': 'Kilometres — 0 = no limit', 'hi': 'किलोमीटर — 0 = कोई सीमा नहीं', 'ta': 'கிலோமீட்டர் — 0 = வரம்பு இல்லை', 'te': 'కిలోమీటర్లు — 0 = పరిమితి లేదు', 'kn': 'ಕಿಲೋಮೀಟರ್ — 0 = ಮಿತಿ ಇಲ್ಲ'},
    'min_price':          {'en': 'Min ₹', 'hi': 'न्यून ₹', 'ta': 'குறைந்த ₹', 'te': 'కనిష్ట ₹', 'kn': 'ಕನಿಷ್ಠ ₹'},
    'max_price':          {'en': 'Max ₹', 'hi': 'अधिक ₹', 'ta': 'அதிக ₹', 'te': 'గరిష్ట ₹', 'kn': 'ಗರಿಷ್ಠ ₹'},
    'min_km':             {'en': 'Min KM', 'hi': 'न्यून KM', 'ta': 'குறைந்த KM', 'te': 'కనిష్ట KM', 'kn': 'ಕನಿಷ್ಠ KM'},
    'max_km':             {'en': 'Max KM', 'hi': 'अधिक KM', 'ta': 'அதிக KM', 'te': 'గరిష్ట KM', 'kn': 'ಗರಿಷ್ಠ KM'},

    // ── BLOCKLIST ──
    'block_title':        {'en': 'LOCATION BLOCKLIST', 'hi': 'लोकेशन ब्लॉकलिस्ट', 'ta': 'இடம் தடுப்பு பட்டியல்', 'te': 'స్థానం బ్లాక్‌లిస్ట్', 'kn': 'ಸ್ಥಳ ಬ್ಲಾಕ್‌ಲಿಸ್ಟ್'},
    'block_desc':         {'en': 'Rides from these areas will be REJECTED', 'hi': 'इन क्षेत्रों की rides reject होंगी', 'ta': 'இந்த பகுதிகளின் rides reject ஆகும்', 'te': 'ఈ ప్రాంతాల rides reject అవుతాయి', 'kn': 'ಈ ಪ್ರದೇಶಗಳ rides reject ಆಗುತ್ತವೆ'},
    'block_add_hint':     {'en': 'Add location name...', 'hi': 'लोकेशन नाम जोड़ो...', 'ta': 'இடத்தின் பெயர் சேர்...', 'te': 'స్థానం పేరు జోడించండి...', 'kn': 'ಸ್ಥಳದ ಹೆಸರು ಸೇರಿಸಿ...'},
    'block_add_btn':      {'en': 'ADD', 'hi': 'जोड़ो', 'ta': 'சேர்', 'te': 'జోడించు', 'kn': 'ಸೇರಿಸಿ'},
    'block_empty':        {'en': 'No blocked locations — all rides accepted', 'hi': 'कोई ब्लॉक नहीं — सब rides accept', 'ta': 'தடுப்பு இல்லை — எல்லா rides accept', 'te': 'బ్లాక్ లేదు — అన్ని rides accept', 'kn': 'ಬ್ಲಾಕ್ ಇಲ್ಲ — ಎಲ್ಲಾ rides accept'},

    // ── STATS ──
    'rides_accepted':     {'en': 'Rides Accepted', 'hi': 'Rides स्वीकृत', 'ta': 'Rides ஏற்கப்பட்டவை', 'te': 'Rides ఆమోదించబడినవి', 'kn': 'Rides ಸ್ವೀಕರಿಸಿದವು'},
    'last_speed':         {'en': 'Last Click Speed', 'hi': 'अंतिम क्लिक स्पीड', 'ta': 'கடைசி கிளிக் வேகம்', 'te': 'చివరి క్లిక్ స్పీడ్', 'kn': 'ಕೊನೆಯ ಕ್ಲಿಕ್ ಸ್ಪೀಡ್'},

    // ── BUTTONS ──
    'save_settings':      {'en': 'Save Settings', 'hi': 'सेटिंग्स सेव करो', 'ta': 'அமைப்புகளை சேமி', 'te': 'సెట్టింగ్‌లను సేవ్ చేయండి', 'kn': 'ಸೆಟ್ಟಿಂಗ್‌ಗಳನ್ನು ಸೇವ್ ಮಾಡಿ'},
    'save_and_start':     {'en': 'Save & Start Engine', 'hi': 'सेव करो और इंजन चालू', 'ta': 'சேமி & Engine தொடங்கு', 'te': 'సేవ్ & Engine ప్రారంభించు', 'kn': 'ಸೇವ್ & Engine ಪ್ರಾರಂಭಿಸಿ'},
    'save_and_stop':      {'en': 'Save & Stop Engine', 'hi': 'सेव करो और इंजन बंद', 'ta': 'சேமி & Engine நிறுத்து', 'te': 'సేవ్ & Engine ఆపు', 'kn': 'ಸೇವ್ & Engine ನಿಲ್ಲಿಸಿ'},
    'reset_counter':      {'en': 'Reset Counter', 'hi': 'काउंटर रीसेट', 'ta': 'எண்ணிக்கை மீட்டமை', 'te': 'కౌంటర్ రీసెట్', 'kn': 'ಕೌಂಟರ್ ರೀಸೆಟ್'},
    'history_btn':        {'en': 'Accepted Orders History', 'hi': 'स्वीकृत ऑर्डर इतिहास', 'ta': 'ஏற்கப்பட்ட ஆர்டர் வரலாறு', 'te': 'ఆమోదించిన ఆర్డర్ చరిత్ర', 'kn': 'ಸ್ವೀಕರಿಸಿದ ಆರ್ಡರ್ ಇತಿಹಾಸ'},

    // ── SETTINGS ──
    'settings_title':     {'en': 'SETTINGS', 'hi': 'सेटिंग्स', 'ta': 'அமைப்புகள்', 'te': 'సెట్టింగ్‌లు', 'kn': 'ಸೆಟ್ಟಿಂಗ್‌ಗಳು'},
    'app_lang':           {'en': 'APP LANGUAGE', 'hi': 'ऐप भाषा', 'ta': 'ஆப் மொழி', 'te': 'యాప్ భాష', 'kn': 'ಆ್ಯಪ್ ಭಾಷೆ'},

    // ── HISTORY ──
    'hist_title':         {'en': 'Order History', 'hi': 'ऑर्डर इतिहास', 'ta': 'ஆர்டர் வரலாறு', 'te': 'ఆర్డర్ చరిత్ర', 'kn': 'ಆರ್ಡರ್ ಇತಿಹಾಸ'},
    'hist_empty_title':   {'en': 'No Orders Yet', 'hi': 'अभी कोई ऑर्डर नहीं', 'ta': 'இன்னும் ஆர்டர்கள் இல்லை', 'te': 'ఇంకా ఆర్డర్లు లేవు', 'kn': 'ಇನ್ನೂ ಆರ್ಡರ್‌ಗಳಿಲ್ಲ'},
    'hist_empty_desc':    {'en': 'Turn on engine and let rides be accepted.\nThey will show up here!', 'hi': 'इंजन चालू करो, rides accept होंगी।\nयहाँ दिखेंगी!', 'ta': 'Engine ஆன் செய்யுங்கள், rides accept ஆகும்.\nஇங்கே தெரியும்!', 'te': 'Engine ఆన్ చేయండి, rides accept అవుతాయి.\nఇక్కడ కనిపిస్తాయి!', 'kn': 'Engine ಆನ್ ಮಾಡಿ, rides accept ಆಗುತ್ತವೆ.\nಇಲ್ಲಿ ಕಾಣಿಸುತ್ತವೆ!'},
    'hist_clear':         {'en': 'Clear History?', 'hi': 'इतिहास मिटाओ?', 'ta': 'வரலாறு அழிக்க?', 'te': 'చరిత్ర తొలగించాలా?', 'kn': 'ಇತಿಹಾಸ ಅಳಿಸಬೇಕೇ?'},
    'hist_clear_desc':    {'en': 'All accepted orders will be deleted.', 'hi': 'सभी accepted orders delete हो जाएँगे।', 'ta': 'எல்லா accepted orders delete ஆகும்.', 'te': 'అన్ని accepted orders delete అవుతాయి.', 'kn': 'ಎಲ್ಲಾ accepted orders delete ಆಗುತ್ತವೆ.'},
    'cancel':             {'en': 'Cancel', 'hi': 'रद्द करो', 'ta': 'ரத்து', 'te': 'రద్దు', 'kn': 'ರದ್ದು'},
    'delete_all':         {'en': 'Delete All', 'hi': 'सब मिटाओ', 'ta': 'எல்லாம் அழி', 'te': 'అన్నీ తొలగించు', 'kn': 'ಎಲ್ಲಾ ಅಳಿಸಿ'},
    'accepted':           {'en': 'Accepted', 'hi': 'स्वीकृत', 'ta': 'ஏற்கப்பட்டது', 'te': 'ఆమోదించబడింది', 'kn': 'ಸ್ವೀಕರಿಸಲಾಗಿದೆ'},
    'total':              {'en': 'Total', 'hi': 'कुल', 'ta': 'மொத்தம்', 'te': 'మొత్తం', 'kn': 'ಒಟ್ಟು'},
    'other':              {'en': 'Other', 'hi': 'अन्य', 'ta': 'மற்றவை', 'te': 'ఇతర', 'kn': 'ಇತರೆ'},
    'blocked':            {'en': 'Blocked', 'hi': 'ब्लॉक', 'ta': 'தடுக்கப்பட்டது', 'te': 'బ్లాక్ చేయబడింది', 'kn': 'ಬ್ಲಾಕ್ ಮಾಡಲಾಗಿದೆ'},
  };
}
