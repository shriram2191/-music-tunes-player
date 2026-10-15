class Region {
  final String country;
  final String countryCode; // ISO code, used for auto-detect from device locale
  final String flag;
  final String language;
  final List<String> terms; // Audius search terms that surface this market's music
  const Region(this.country, this.countryCode, this.flag, this.language, this.terms);
}

const List<Region> regions = [
  Region('India', 'IN', '🇮🇳', 'Hindi', ['bollywood', 'hindi pop', 'indian classical']),
  Region('United States', 'US', '🇺🇸', 'English', ['pop', 'hip hop', 'indie']),
  Region('United Kingdom', 'GB', '🇬🇧', 'English', ['uk rap', 'drum and bass', 'garage']),
  Region('South Korea', 'KR', '🇰🇷', 'Korean', ['k-pop', 'korean r&b']),
  Region('Japan', 'JP', '🇯🇵', 'Japanese', ['j-pop', 'city pop']),
  Region('Brazil', 'BR', '🇧🇷', 'Portuguese', ['brazilian funk', 'sertanejo', 'bossa nova']),
  Region('Mexico', 'MX', '🇲🇽', 'Spanish', ['corridos', 'latin pop']),
  Region('Spain', 'ES', '🇪🇸', 'Spanish', ['reggaeton', 'spanish pop']),
  Region('Argentina', 'AR', '🇦🇷', 'Spanish', ['argentine rock', 'tango']),
  Region('France', 'FR', '🇫🇷', 'French', ['french pop', 'chanson']),
  Region('Germany', 'DE', '🇩🇪', 'German', ['german rap', 'techno']),
  Region('Italy', 'IT', '🇮🇹', 'Italian', ['italian pop', 'italo disco']),
  Region('Nigeria', 'NG', '🇳🇬', 'English', ['afrobeats', 'afro fusion']),
  Region('Egypt', 'EG', '🇪🇬', 'Arabic', ['arabic pop', 'mahraganat']),
  Region('Saudi Arabia', 'SA', '🇸🇦', 'Arabic', ['khaleeji', 'arabic pop']),
  Region('Turkey', 'TR', '🇹🇷', 'Turkish', ['turkish pop', 'anatolian rock']),
  Region('Russia', 'RU', '🇷🇺', 'Russian', ['russian pop', 'phonk']),
  Region('Indonesia', 'ID', '🇮🇩', 'Indonesian', ['indonesian pop', 'dangdut']),
  Region('Philippines', 'PH', '🇵🇭', 'Filipino', ['opm', 'pinoy pop']),
  Region('Thailand', 'TH', '🇹🇭', 'Thai', ['thai pop', 'luk thung']),
  Region('Vietnam', 'VN', '🇻🇳', 'Vietnamese', ['vietnamese pop']),
  Region('Pakistan', 'PK', '🇵🇰', 'Urdu', ['pakistani pop', 'qawwali']),
  Region('Bangladesh', 'BD', '🇧🇩', 'Bengali', ['bangla song']),
  Region('China', 'CN', '🇨🇳', 'Mandarin', ['mandopop', 'chinese r&b']),
  Region('Canada', 'CA', '🇨🇦', 'English', ['canadian pop', 'hip hop']),
  Region('Australia', 'AU', '🇦🇺', 'English', ['australian pop', 'indie']),
];
