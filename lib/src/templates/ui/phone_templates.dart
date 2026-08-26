/// Templates for the phone-number family: the country table, the country
/// selector and the phone field that masks itself per country.
abstract final class PhoneTemplates {
  /// Returns the generated appCountry template.
  static String appCountry() => r'''
import 'package:flutter/foundation.dart';

/// A country the phone field can be set to: ISO code, calling code and the
/// shapes its national numbers take.
///
/// [masks] is a list, narrowest first, because plans are not all fixed-width —
/// a field grows through them as the user types. Masks describe the
/// *national* number only; the calling code lives in [dial].
@immutable
class AppCountry {
  /// Creates a country entry. The shipped table is [AppCountries.all]; build
  /// one of these directly only to add a country the table is missing.
  const AppCountry(this.iso, this.dial, this.name, this.masks);

  /// ISO 3166-1 alpha-2, upper case: `PT`.
  final String iso;

  /// E.164 calling code without its `+`: `351`.
  ///
  /// Shared codes carry the full identifying prefix — the British Virgin
  /// Islands is `1284`, not `1` — so [AppCountries.byDialCode] can tell them
  /// apart.
  final String dial;

  /// English country name — what the picker lists and what [matches] searches.
  final String name;

  /// National-number masks, one `#` per digit, narrowest first. Never empty.
  final List<String> masks;

  /// The flag, derived from [iso] rather than stored: an ASCII letter maps onto
  /// its regional indicator symbol, and a pair of those renders as a flag. No
  /// image assets, and nothing to keep in sync with the table.
  String get flag => String.fromCharCodes([
    for (final unit in iso.toUpperCase().codeUnits) unit + _regionalIndicator,
  ]);

  /// `+351` — what the selector shows and what [e164] starts with.
  String get dialCode => '+$dial';

  /// Digit counts a complete national number may have, narrowest first.
  List<int> get lengths => [for (final mask in masks) _slotsIn(mask)];

  /// Fewest digits a complete number here can have.
  int get minDigits => _slotsIn(masks.first);

  /// Most digits a number here can hold — the cap the field enforces.
  int get maxDigits => _slotsIn(masks.last);

  /// The narrowest mask [digits] still fits in, else the widest.
  ///
  /// This is what lets a variable-length plan work: an Australian number wears
  /// `#### ####` until the ninth digit arrives and it becomes `# #### ####`.
  String maskFor(String digits) {
    for (final mask in masks) {
      if (digits.length <= _slotsIn(mask)) return mask;
    }
    return masks.last;
  }

  /// [digits] punctuated by the mask it fits; anything past [maxDigits] is
  /// dropped. Separators are only written while a digit still needs a slot, so
  /// a half-typed number never ends on a dangling bracket or space.
  String format(String digits) {
    final numeric = _digitsOnly(digits);
    final mask = maskFor(numeric);
    final buffer = StringBuffer();
    var next = 0;
    for (var i = 0; i < mask.length && next < numeric.length; i++) {
      buffer.write(mask[i] == _slot ? numeric[next++] : mask[i]);
    }
    return buffer.toString();
  }

  /// Whether [digits] is a *complete* national number here — the length must
  /// match one of the plan's shapes exactly, not fall in a range.
  bool accepts(String digits) => lengths.contains(_digitsOnly(digits).length);

  /// The E.164 form of [digits]: `+351912345678`. What you send to an API, and
  /// what [AppCountries.split] reads back.
  String e164(String digits) => '+$dial${_digitsOnly(digits)}';

  /// How well this country answers [query] — lower is better, negative is no
  /// match. `+351`, `351`, `PT` and `portu` all find Portugal.
  ///
  /// Ranked rather than boolean because a plain `contains` puts Egypt above
  /// Portugal for the query `PT`.
  int matchRank(String query) {
    final needle = query.trim().toLowerCase();
    if (needle.isEmpty) return 0;
    final bare = needle.startsWith('+') ? needle.substring(1) : needle;
    final lowerIso = iso.toLowerCase();
    final lowerName = name.toLowerCase();

    if (lowerIso == needle) return 0;
    if (dial == bare) return 1;
    if (lowerName.startsWith(needle)) return 2;
    if (lowerIso.startsWith(needle)) return 3;
    if (dial.startsWith(bare)) return 4;
    if (lowerName.contains(needle)) return 5;
    return -1;
  }

  /// Whether [query] matches this country at all — see [matchRank].
  bool matches(String query) => matchRank(query) >= 0;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is AppCountry && other.iso == iso);

  @override
  int get hashCode => iso.hashCode;

  @override
  String toString() => '$flag $name ($dialCode)';
}

/// A phone number as the field currently holds it — reported by
/// `AppPhoneInput.onChanged` so a form never has to re-parse the text.
@immutable
class AppPhoneNumber {
  /// Creates a number in [country] made of [national] digits.
  const AppPhoneNumber({required this.country, required this.national});

  /// The country the field is set to.
  final AppCountry country;

  /// The national part, digits only and unpunctuated: `912345678`.
  final String national;

  /// The full international form: `+351912345678`.
  String get e164 => country.e164(national);

  /// The national part wearing its mask: `912 345 678`.
  String get formatted => country.format(national);

  /// Whether this is a complete number for [country] — see [AppCountry.accepts].
  bool get isValid => national.isNotEmpty && country.accepts(national);

  /// Whether the user has typed nothing at all.
  bool get isEmpty => national.isEmpty;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AppPhoneNumber &&
          other.country == country &&
          other.national == national);

  @override
  int get hashCode => Object.hash(country, national);

  @override
  String toString() => e164;
}

/// The shipped country table and the lookups over it.
///
/// Plans come from `flutter_multi_formatter` (MIT). They describe how numbers
/// are *written*, not a substitute for libphonenumber — validate server-side
/// too if you need carrier-level correctness.
abstract final class AppCountries {
  /// The country a field starts on when it is given nothing else.
  ///
  /// Assign at startup to follow the SIM, the locale, or wherever your users
  /// actually are: `AppCountries.initial = AppCountries.byIso('PT')!;`
  static AppCountry initial = byIso('US')!;

  /// Which country a *shared* calling code resolves to — `+1` is both the US
  /// and Canada. Edit freely; an unlisted code falls back to the first match.
  static const Map<String, String> preferredForSharedDialCode = {
    '1': 'US',
    '7': 'RU',
    '44': 'GB',
    '47': 'NO',
    '61': 'AU',
    '64': 'NZ',
    '262': 'RE',
    '354': 'IS',
    '500': 'FK',
    '590': 'GP',
  };

  /// Look up by ISO 3166-1 alpha-2, case-insensitive. Null when unknown.
  static AppCountry? byIso(String iso) => _byIso[iso.trim().toUpperCase()];

  /// Every country using [dial], with or without its `+`.
  static List<AppCountry> allByDialCode(String dial) {
    final code = _digitsOnly(dial);
    return [for (final country in all) if (country.dial == code) country];
  }

  /// The country a `+…` number belongs to, matched on the longest calling code
  /// that prefixes it — so `+1284…` resolves to the British Virgin Islands
  /// rather than to the United States. Shared codes resolve through
  /// [preferredForSharedDialCode]. Null when nothing matches.
  static AppCountry? byDialCode(String phone) {
    final digits = _digitsOnly(phone);
    if (digits.isEmpty) return null;

    final longest = digits.length < _longestDial ? digits.length : _longestDial;
    for (var length = longest; length > 0; length--) {
      final matches = allByDialCode(digits.substring(0, length));
      if (matches.isEmpty) continue;
      if (matches.length == 1) return matches.first;

      final preferred = preferredForSharedDialCode[matches.first.dial];
      return matches.firstWhere(
        (country) => country.iso == preferred,
        orElse: () => matches.first,
      );
    }
    return null;
  }

  /// Splits a number into its country and national digits. A `+`-prefixed
  /// number goes through [byDialCode]; anything else pairs with [fallback].
  ///
  ///   AppCountries.split('+351912345678')  // (Portugal, '912345678')
  static AppPhoneNumber split(String phone, {AppCountry? fallback}) {
    final country = fallback ?? initial;
    final trimmed = phone.trim();
    if (!trimmed.startsWith('+')) {
      return AppPhoneNumber(country: country, national: _digitsOnly(trimmed));
    }

    final match = byDialCode(trimmed);
    if (match == null) {
      return AppPhoneNumber(country: country, national: _digitsOnly(trimmed));
    }
    return AppPhoneNumber(
      country: match,
      national: _digitsOnly(trimmed).substring(match.dial.length),
    );
  }

  /// Countries matching [query], best match first — see [AppCountry.matchRank].
  /// An empty query returns everything, untouched.
  ///
  /// Pass [within] to search a subset, such as the countries one form offers.
  static List<AppCountry> search(String query, {List<AppCountry>? within}) {
    final pool = within ?? all;
    final ranked = <({int rank, int index, AppCountry country})>[];
    for (var index = 0; index < pool.length; index++) {
      final rank = pool[index].matchRank(query);
      if (rank >= 0) {
        ranked.add((rank: rank, index: index, country: pool[index]));
      }
    }
    // Ties keep the order they came in, which is alphabetical for the table.
    ranked.sort(
      (a, b) =>
          a.rank != b.rank ? a.rank.compareTo(b.rank) : a.index.compareTo(b.index),
    );
    return [for (final entry in ranked) entry.country];
  }

  static final Map<String, AppCountry> _byIso = {
    for (final country in all) country.iso: country,
  };

  static final int _longestDial = all
      .map((country) => country.dial.length)
      .reduce((a, b) => a > b ? a : b);

  /// Every country, sorted by [AppCountry.name].
  static const List<AppCountry> all = [
    AppCountry('LA', '856', '(Laos) Lao People\'s Democratic Republic', ['## #### ####']),
    AppCountry('AF', '93', 'Afghanistan', ['### ### ####']),
    AppCountry('AL', '355', 'Albania', ['## ### ####']),
    AppCountry('DZ', '213', 'Algeria', ['# ## ## ## ##']),
    AppCountry('AS', '1684', 'American Samoa', ['### ####']),
    AppCountry('AD', '376', 'Andorra', ['### ### ####']),
    AppCountry('AO', '244', 'Angola', ['#### ### ####']),
    AppCountry('AI', '1264', 'Anguilla', ['### ####']),
    AppCountry('AG', '1268', 'Antigua and Barbuda', ['### ####']),
    AppCountry('AR', '54', 'Argentina', ['# ### ####']),
    AppCountry('AM', '374', 'Armenia', ['### ### ##', '### ### ####']),
    AppCountry('AW', '297', 'Aruba', ['## ### ####']),
    AppCountry('AC', '247', 'Ascension Island', ['#####', '######', '#####-#####', '######-######']),
    AppCountry('AU', '61', 'Australia', ['#### ####', '# #### ####']),
    AppCountry('AT', '43', 'Austria', ['### ### ####', '### ### #####', '### ### ######', '### ### #######']),
    AppCountry('AZ', '994', 'Azerbaijan', ['### ### ####']),
    AppCountry('BS', '1242', 'Bahamas', ['### ####']),
    AppCountry('BH', '973', 'Bahrain', ['### ### ####']),
    AppCountry('BD', '880', 'Bangladesh', ['### ### ####']),
    AppCountry('BB', '1246', 'Barbados', ['### ####']),
    AppCountry('BY', '375', 'Belarus', ['(##) ###-##-##']),
    AppCountry('BE', '32', 'Belgium', ['### ## ## ##']),
    AppCountry('BZ', '501', 'Belize', ['### ####']),
    AppCountry('BJ', '229', 'Benin', ['### ### ####']),
    AppCountry('BM', '1441', 'Bermuda', ['### ####']),
    AppCountry('BT', '975', 'Bhutan', ['## ### ####']),
    AppCountry('BO', '591', 'Bolivia, Plurinational State of', ['### ### ####']),
    AppCountry('BA', '387', 'Bosnia and Herzegovina', ['### ### ####']),
    AppCountry('BW', '267', 'Botswana', ['### ####']),
    AppCountry('BR', '55', 'Brazil', ['(##) ####-####', '(##) #####-####']),
    AppCountry('IO', '246', 'British Indian Ocean Territory', ['### ####']),
    AppCountry('BN', '673', 'Brunei Darussalam', ['### ####']),
    AppCountry('BG', '359', 'Bulgaria', ['# ### ####']),
    AppCountry('BF', '226', 'Burkina Faso', ['# ### ####']),
    AppCountry('BI', '257', 'Burundi', ['### ####']),
    AppCountry('KH', '855', 'Cambodia', ['## ### ####']),
    AppCountry('CM', '237', 'Cameroon', ['# ### ####']),
    AppCountry('CA', '1', 'Canada', ['(###) ### ####']),
    AppCountry('CV', '238', 'Cape Verde', ['### ####']),
    AppCountry('KY', '345', 'Cayman Islands', ['#) ### ####']),
    AppCountry('CF', '236', 'Central African Republic', ['# ### ####']),
    AppCountry('TD', '235', 'Chad', ['# ### ####']),
    AppCountry('CL', '56', 'Chile', ['## ### ####']),
    AppCountry('CN', '86', 'China', ['### #### ####']),
    AppCountry('CX', '61', 'Christmas Island', ['# #### ####']),
    AppCountry('CC', '61', 'Cocos (Keeling) Islands', ['# #### ####']),
    AppCountry('CO', '57', 'Colombia', ['### ### ####']),
    AppCountry('KM', '269', 'Comoros', ['### ####']),
    AppCountry('CG', '242', 'Congo', ['## ## #####']),
    AppCountry('CD', '243', 'Congo, The Democratic Republic of the', ['## ## #####']),
    AppCountry('CK', '682', 'Cook Islands', ['##']),
    AppCountry('CR', '506', 'Costa Rica', ['# ### ####']),
    AppCountry('CI', '225', 'Cote d\'Ivoire', ['########']),
    AppCountry('HR', '385', 'Croatia', ['## ### ####', '## ### #### #', '## ### #### ##', '## ### #### ###']),
    AppCountry('CU', '53', 'Cuba', ['### ### ####']),
    AppCountry('CY', '357', 'Cyprus', ['# ### ####', '## #######', '## ########', '## #########']),
    AppCountry('CZ', '420', 'Czech Republic', ['### ### ###', '### ### ### #', '### ### ### ##', '### ### ### ###']),
    AppCountry('DK', '45', 'Denmark', ['## ## ## ##']),
    AppCountry('DJ', '253', 'Djibouti', ['# ### ####']),
    AppCountry('DM', '1767', 'Dominica', ['### ####']),
    AppCountry('DO', '1809', 'Dominican Republic', ['### ####']),
    AppCountry('EC', '593', 'Ecuador', ['## ### ####']),
    AppCountry('EG', '20', 'Egypt', ['### ### ####']),
    AppCountry('SV', '503', 'El Salvador', ['## #### ####']),
    AppCountry('GQ', '240', 'Equatorial Guinea', ['## ### ####']),
    AppCountry('ER', '291', 'Eritrea', ['### ####']),
    AppCountry('EE', '372', 'Estonia', ['### ###', '### ####', '#### ####', '#########']),
    AppCountry('ET', '251', 'Ethiopia', ['## ### ####']),
    AppCountry('FK', '500', 'Falkland Islands (Malvinas)', ['#####']),
    AppCountry('FO', '298', 'Faroe Islands', ['######']),
    AppCountry('FJ', '679', 'Fiji', ['### ####']),
    AppCountry('FI', '358', 'Finland', ['## ### #', '## ### ##', '## ### ###', '## ### ####', '### ### ####', '### ### #####', '### ### ######']),
    AppCountry('FR', '33', 'France', ['# ## ## ## ##']),
    AppCountry('GF', '594', 'French Guiana', ['### ## ## ##']),
    AppCountry('PF', '689', 'French Polynesia', ['######']),
    AppCountry('GA', '241', 'Gabon', ['######']),
    AppCountry('GM', '220', 'Gambia', ['### ####']),
    AppCountry('GE', '995', 'Georgia', ['### ######']),
    AppCountry('DE', '49', 'Germany', ['## ########', '## #########', '## ##########', '## ###########']),
    AppCountry('GH', '233', 'Ghana', ['## ### ####']),
    AppCountry('GI', '350', 'Gibraltar', ['#####']),
    AppCountry('GR', '30', 'Greece', ['# ### ####']),
    AppCountry('GL', '299', 'Greenland', ['######']),
    AppCountry('GD', '1473', 'Grenada', ['### ####']),
    AppCountry('GP', '590', 'Guadeloupe', ['### ## ## ##']),
    AppCountry('GU', '1671', 'Guam', ['### ####']),
    AppCountry('GT', '502', 'Guatemala', ['### ####']),
    AppCountry('GG', '44', 'Guernsey', ['(#) #### ######']),
    AppCountry('GN', '224', 'Guinea', ['### ######']),
    AppCountry('GW', '245', 'Guinea-Bissau', ['### ####']),
    AppCountry('GY', '592', 'Guyana', ['### ####']),
    AppCountry('HT', '509', 'Haiti', ['### ####']),
    AppCountry('HN', '504', 'Honduras', ['### ####']),
    AppCountry('HK', '852', 'Hong Kong', ['#### ####']),
    AppCountry('HU', '36', 'Hungary', ['# ### ####', '## ### ####']),
    AppCountry('IS', '354', 'Iceland', ['### ####']),
    AppCountry('IN', '91', 'India', ['### ### ####']),
    AppCountry('ID', '62', 'Indonesia', ['## #### ####', '### #### ####']),
    AppCountry('IR', '98', 'Iran, Islamic Republic of', ['### ### ####']),
    AppCountry('IQ', '964', 'Iraq', ['(##) ### #####']),
    AppCountry('IE', '353', 'Ireland', ['## ### ####', '## ### #### #', '## ### #### ##']),
    AppCountry('IL', '972', 'Israel', ['## ### ####']),
    AppCountry('IT', '39', 'Italy', ['## ### ####', '### ### ####', '## #### #####']),
    AppCountry('JM', '1876', 'Jamaica', ['### ####']),
    AppCountry('JP', '81', 'Japan', ['## ### ####']),
    AppCountry('JO', '962', 'Jordan', ['# ### ####']),
    AppCountry('KZ', '7', 'Kazakhstan', ['(###) ### ####']),
    AppCountry('KE', '254', 'Kenya', ['### ######']),
    AppCountry('KI', '686', 'Kiribati', ['#####']),
    AppCountry('KP', '850', 'Korea, Democratic People\'s Republic of', ['# ### ####']),
    AppCountry('KR', '82', 'Korea, Republic of', ['# ### ####']),
    AppCountry('KW', '965', 'Kuwait', ['#### ####']),
    AppCountry('KG', '996', 'Kyrgyzstan', ['### ######']),
    AppCountry('AX', '354', 'Land Islands', ['### ####']),
    AppCountry('LV', '371', 'Latvia', ['#### ####']),
    AppCountry('LB', '961', 'Lebanon', ['## ### ###']),
    AppCountry('LS', '266', 'Lesotho', ['#### ####']),
    AppCountry('LR', '231', 'Liberia', ['## ### ####']),
    AppCountry('LY', '218', 'Libyan Arab Jamahiriya', ['## ### ####']),
    AppCountry('LI', '423', 'Liechtenstein', ['### ####']),
    AppCountry('LT', '370', 'Lithuania', ['### ####', '### #####']),
    AppCountry('LU', '352', 'Luxembourg', ['######']),
    AppCountry('MO', '853', 'Macao', ['#### ####']),
    AppCountry('MK', '389', 'Macedonia', ['# ### ####']),
    AppCountry('MG', '261', 'Madagascar', ['### ####']),
    AppCountry('MW', '265', 'Malawi', ['#########']),
    AppCountry('MY', '60', 'Malaysia', ['# ### ####', '## ### ####']),
    AppCountry('MV', '960', 'Maldives', ['### ####']),
    AppCountry('ML', '223', 'Mali', ['#### ####']),
    AppCountry('MT', '356', 'Malta', ['#### ####']),
    AppCountry('MH', '692', 'Marshall Islands', ['### ####']),
    AppCountry('MQ', '596', 'Martinique', ['### ## ## ##']),
    AppCountry('MR', '222', 'Mauritania', ['### ####']),
    AppCountry('MU', '230', 'Mauritius', ['### ####']),
    AppCountry('YT', '262', 'Mayotte', ['### ## ## ##']),
    AppCountry('MX', '52', 'Mexico', ['### ### ####']),
    AppCountry('FM', '691', 'Micronesia, Federated States of', ['### ####']),
    AppCountry('MD', '373', 'Moldova, Republic of', ['### #####']),
    AppCountry('MC', '377', 'Monaco', ['#### ####']),
    AppCountry('MN', '976', 'Mongolia', ['## ######']),
    AppCountry('ME', '382', 'Montenegro', ['## ######', '### ### ###', '### ### ### #', '### ### ### ##', '### ### ### ###']),
    AppCountry('MS', '1664', 'Montserrat', ['### ####']),
    AppCountry('MA', '212', 'Morocco', ['## ### ####']),
    AppCountry('MZ', '258', 'Mozambique', ['### ######']),
    AppCountry('MM', '95', 'Myanmar', ['## ### ####']),
    AppCountry('NA', '264', 'Namibia', ['## ######']),
    AppCountry('NR', '674', 'Nauru', ['### ####']),
    AppCountry('NP', '977', 'Nepal', ['### ### ####']),
    AppCountry('NL', '31', 'Netherlands', ['## ### ####']),
    AppCountry('AN', '599', 'Netherlands Antilles', ['########']),
    AppCountry('NC', '687', 'New Caledonia', ['######']),
    AppCountry('NZ', '64', 'New Zealand', ['(#) ### ####', '(##) ### ####', '(###) ### ####']),
    AppCountry('NI', '505', 'Nicaragua', ['#### ####']),
    AppCountry('NE', '227', 'Niger', ['## ######']),
    AppCountry('NG', '234', 'Nigeria', ['### ### ####']),
    AppCountry('NU', '683', 'Niue', ['#######']),
    AppCountry('NF', '672', 'Norfolk Island', ['# ## ###']),
    AppCountry('MP', '1670', 'Northern Mariana Islands', ['### ####']),
    AppCountry('NO', '47', 'Norway', ['#### ####']),
    AppCountry('OM', '968', 'Oman', ['#### ####']),
    AppCountry('PK', '92', 'Pakistan', ['### #######']),
    AppCountry('PW', '680', 'Palau', ['### ####']),
    AppCountry('PS', '970', 'Palestina', ['# ### ####']),
    AppCountry('PA', '507', 'Panama', ['### ####']),
    AppCountry('PG', '675', 'Papua New Guinea', ['### ####']),
    AppCountry('PY', '595', 'Paraguay', ['### ######']),
    AppCountry('PE', '51', 'Peru', ['## #########']),
    AppCountry('PH', '63', 'Philippines', ['## ### ####']),
    AppCountry('PN', '64', 'Pitcairn', ['# ### ####']),
    AppCountry('PL', '48', 'Poland', ['## ### ####']),
    AppCountry('PT', '351', 'Portugal', ['### ### ###', '### ### ### #', '### ### ### ##']),
    AppCountry('PR', '1939', 'Puerto Rico', ['### ####']),
    AppCountry('QA', '974', 'Qatar', ['#### ####']),
    AppCountry('RO', '40', 'Romania', ['### ### ###']),
    AppCountry('RU', '7', 'Russia', ['(###) ###-##-##']),
    AppCountry('RW', '250', 'Rwanda', ['### ###']),
    AppCountry('RE', '262', 'Réunion', ['### ## ## ##']),
    AppCountry('BL', '590', 'Saint Barthélemy', ['### ## ## ##']),
    AppCountry('SH', '290', 'Saint Helena, Ascension and Tristan Da Cunha', ['####']),
    AppCountry('KN', '1869', 'Saint Kitts and Nevis', ['### ####']),
    AppCountry('LC', '1758', 'Saint Lucia', ['### ####']),
    AppCountry('MF', '590', 'Saint Martin', ['### ######']),
    AppCountry('PM', '508', 'Saint Pierre and Miquelon', ['## ##']),
    AppCountry('VC', '1784', 'Saint Vincent and the Grenadines', ['### ####']),
    AppCountry('WS', '685', 'Samoa', ['### ####']),
    AppCountry('SM', '378', 'San Marino', ['#### ######']),
    AppCountry('ST', '239', 'Sao Tome and Principe', ['### ####']),
    AppCountry('SA', '966', 'Saudi Arabia', ['## ### ####']),
    AppCountry('SN', '221', 'Senegal', ['## ### ####']),
    AppCountry('RS', '381', 'Serbia', ['## ### ####', '## ### ## ## #', '## ### ## ## ##', '### ### ## ## ##']),
    AppCountry('SC', '248', 'Seychelles', ['### ####']),
    AppCountry('SL', '232', 'Sierra Leone', ['## ######']),
    AppCountry('SG', '65', 'Singapore', ['#### ####']),
    AppCountry('SK', '421', 'Slovakia', ['### ### ###']),
    AppCountry('SI', '386', 'Slovenia', ['# ### ## ##']),
    AppCountry('SB', '677', 'Solomon Islands', ['#####']),
    AppCountry('SO', '252', 'Somalia', ['## ### ###']),
    AppCountry('ZA', '27', 'South Africa', ['## ### ####']),
    AppCountry('GS', '500', 'South Georgia and the South Sandwich Islands', ['#####']),
    AppCountry('ES', '34', 'Spain', ['### ### ###']),
    AppCountry('LK', '94', 'Sri Lanka', ['## ### ####']),
    AppCountry('SD', '249', 'Sudan', ['## ### ####']),
    AppCountry('SR', '597', 'Suriname', ['######']),
    AppCountry('SJ', '47', 'Svalbard and Jan Mayen', ['#### ####']),
    AppCountry('SZ', '268', 'Swaziland', ['# ### ####']),
    AppCountry('SE', '46', 'Sweden', ['## ### ####', '## ### #### #', '## ### #### ##', '## ### #### ###', '## ### #### ####']),
    AppCountry('CH', '41', 'Switzerland', ['## ### ## ##', '### ### ## ##', '### ### ## ## #', '### ### ## ## ##']),
    AppCountry('SY', '963', 'Syrian Arab Republic', ['## ### ####']),
    AppCountry('TW', '886', 'Taiwan', ['# #### ####']),
    AppCountry('TJ', '992', 'Tajikistan', ['## ### ####']),
    AppCountry('TZ', '255', 'Tanzania', ['## ### ####']),
    AppCountry('TH', '66', 'Thailand', ['# ### ####']),
    AppCountry('TL', '670', 'Timor-Leste', ['### ###']),
    AppCountry('TG', '228', 'Togo', ['# ### ####']),
    AppCountry('TK', '690', 'Tokelau', ['####']),
    AppCountry('TO', '676', 'Tonga', ['### ####']),
    AppCountry('TT', '1868', 'Trinidad and Tobago', ['### ####']),
    AppCountry('TN', '216', 'Tunisia', ['#### ####']),
    AppCountry('TR', '90', 'Turkey', ['### ### ####']),
    AppCountry('TM', '993', 'Turkmenistan', ['## ######']),
    AppCountry('TC', '1649', 'Turks and Caicos Islands', ['### ####']),
    AppCountry('TV', '688', 'Tuvalu', ['#####']),
    AppCountry('UG', '256', 'Uganda', ['### ######']),
    AppCountry('UA', '380', 'Ukraine', ['## ### ####']),
    AppCountry('AE', '971', 'United Arab Emirates', ['## ######', '## #######']),
    AppCountry('GB', '44', 'United Kingdom', ['#### ######']),
    AppCountry('US', '1', 'United States', ['(###) ### ####']),
    AppCountry('UY', '598', 'Uruguay', ['#### ####']),
    AppCountry('UZ', '998', 'Uzbekistan', ['## ### ####']),
    AppCountry('VU', '678', 'Vanuatu', ['#####']),
    AppCountry('VE', '58', 'Venezuela, Bolivarian Republic of', ['### ### ####']),
    AppCountry('VN', '84', 'Viet Nam', ['### ### ####']),
    AppCountry('VG', '1284', 'Virgin Islands, British', ['### ####']),
    AppCountry('VI', '1340', 'Virgin Islands, U.S.', ['### ####']),
    AppCountry('WF', '681', 'Wallis and Futuna', ['## ####']),
    AppCountry('YE', '967', 'Yemen', ['# ######']),
    AppCountry('ZM', '260', 'Zambia', ['## ### ####']),
    AppCountry('ZW', '263', 'Zimbabwe', ['## ### ####']),
  ];
}

/// The mask character standing in for one digit.
const String _slot = '#';

/// `A` maps onto U+1F1E6, so an ISO letter pair renders as a flag.
const int _regionalIndicator = 0x1F1E6 - 0x41;

final RegExp _nonDigits = RegExp(r'\D');

int _slotsIn(String mask) => _slot.allMatches(mask).length;

String _digitsOnly(String value) => value.replaceAll(_nonDigits, '');
''';

  /// Returns the generated appPhoneInput template.
  static String appPhoneInput() => r'''
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import './app_country.dart';
import './app_input.dart';
import './app_input_format.dart';
import './app_country_picker.dart';
import './app_input_style.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/security/validation_service.dart';

export './app_country.dart';

/// A phone field that masks what is typed for the country it is set to, with
/// the country picker built into its prefix.
///
///   AppPhoneInput(
///     initialCountry: 'PT',
///     onChanged: (number) => _phone = number.e164,
///   )
///
/// The field holds the *national* number and punctuates it as the user types.
/// The calling code is never in the text, so it cannot be typed twice — read
/// the joined-up value from [AppPhoneNumber.e164]. Switching country re-masks
/// what is already there rather than clearing it.
class AppPhoneInput extends StatefulWidget {
  /// Creates a phone field.
  const AppPhoneInput({
    super.key,
    this.label = 'Phone',
    this.controller,
    this.initialValue,
    this.initialCountry,
    this.countries,
    this.onChanged,
    this.onSubmitted,
    this.hint,
    this.required = false,
    this.enabled = true,
    this.readOnly = false,
    this.autoFocus = false,
    this.focusNode,
    this.textInputAction,
    this.validator,
    this.autovalidateMode,
    this.showDialCode = true,
    this.pickerTitle = 'Select a country',
    this.searchHint = 'Search country or code',
    this.labelMode,
    this.variant,
    this.type,
    this.shape,
    this.size,
  });

  /// Field label, shown wherever [AppInputConfig] puts labels.
  final String label;

  /// Controls the *national* part. Its text is the masked number, so read a
  /// clean value from [AppPhoneNumber] via [onChanged] rather than parsing it.
  final TextEditingController? controller;

  /// Seeds the field. An E.164 value picks the country too — `+351912345678`
  /// opens on Portugal — while a bare national number keeps [initialCountry].
  final String? initialValue;

  /// ISO 3166-1 alpha-2 of the country to open on. Defaults to
  /// [AppCountries.initial]. Ignored when [initialValue] carries a `+`.
  final String? initialCountry;

  /// The countries the picker offers. Defaults to [AppCountries.all]; pass a
  /// subset to restrict a form to where you actually operate.
  final List<AppCountry>? countries;

  /// Called on every keystroke and on every country change.
  final ValueChanged<AppPhoneNumber>? onChanged;

  /// Called when the keyboard's action key is pressed.
  final ValueChanged<AppPhoneNumber>? onSubmitted;

  /// Placeholder. Defaults to the country's own mask, so an empty field
  /// already shows the shape it wants.
  final String? hint;

  /// Marks the label and rejects an empty value.
  final bool required;

  final bool enabled;

  /// Shows the value without letting it be edited. The country picker is
  /// disabled too — a read-only number cannot change country.
  final bool readOnly;

  final bool autoFocus;
  final FocusNode? focusNode;
  final TextInputAction? textInputAction;

  /// Replaces the built-in rule, which checks the number is complete for its
  /// country. Receives the masked national text.
  final FormFieldValidator<String>? validator;

  final AutovalidateMode? autovalidateMode;

  /// Whether the prefix shows `+351` next to the flag. Turn off for a narrow
  /// field where the flag alone carries it.
  final bool showDialCode;

  /// Title over the country picker sheet.
  final String pickerTitle;

  /// Placeholder in the picker's search field.
  final String searchHint;

  /// Null follows [AppInputConfig.defaults].
  final AppInputLabelMode? labelMode;
  final AppInputVariant? variant;
  final AppInputType? type;
  final AppInputShape? shape;
  final AppInputSize? size;

  /// The built-in rule, exposed so a custom [validator] can build on it. Runs
  /// [ValidationService], then holds the number to its country's digit counts.
  static String? validate(
    String? value, {
    required AppCountry country,
    bool required = false,
  }) {
    final digits = _digitsOnly(value ?? '');
    if (digits.isEmpty) {
      return required ? AppInputStyle.config.requiredMessage : null;
    }

    final result = ValidationService.validate(
      country.e164(digits),
      inputType: InputType.phone,
    );
    if (!result.isValid) return result.error;

    return country.accepts(digits)
        ? null
        : 'Enter a ${_lengths(country)} number for ${country.name}';
  }

  static String _lengths(AppCountry country) {
    final lengths = country.lengths;
    if (lengths.length == 1) return '${lengths.first}-digit';
    return '${lengths.sublist(0, lengths.length - 1).join(', ')} or '
        '${lengths.last} digit';
  }

  @override
  State<AppPhoneInput> createState() => _AppPhoneInputState();
}

class _AppPhoneInputState extends State<AppPhoneInput> {
  late AppCountry _country;
  late final TextEditingController _controller;
  late final bool _ownsController;

  @override
  void initState() {
    super.initState();

    final seeded = AppCountries.split(
      widget.initialValue ?? '',
      fallback: widget.initialCountry == null
          ? AppCountries.initial
          : AppCountries.byIso(widget.initialCountry!) ?? AppCountries.initial,
    );
    _country = seeded.country;

    _ownsController = widget.controller == null;
    _controller = widget.controller ?? TextEditingController();
    if (_controller.text.isEmpty && seeded.national.isNotEmpty) {
      _controller.text = _country.format(seeded.national);
    }
  }

  @override
  void dispose() {
    if (_ownsController) _controller.dispose();
    super.dispose();
  }

  /// What the field currently holds, as a whole number.
  AppPhoneNumber get _value =>
      AppPhoneNumber(country: _country, national: _digitsOnly(_controller.text));

  void _openPicker() async {
    // The sheet is configured once, in AppCountryPicker — the flag, the
    // calling code and the ranked search are the same here as in a standalone
    // country field, and stay that way because there is only one of them.
    final picked = await AppCountryPicker.show(
      context,
      title: widget.pickerTitle,
      searchHint: widget.searchHint,
      countries: widget.countries,
      selectedIso: _country.iso,
      variant: widget.variant,
    );
    if (picked == null || !mounted) return;
    _selectCountry(picked);
  }

  /// Re-masks the digits already in the field for the new country — Flutter
  /// only runs `inputFormatters` on an edit, so nothing else would.
  void _selectCountry(AppCountry country) {
    setState(() => _country = country);

    final digits = _digitsOnly(_controller.text);
    final reshaped = country.format(digits);
    if (reshaped != _controller.text) {
      _controller.value = TextEditingValue(
        text: reshaped,
        selection: TextSelection.collapsed(offset: reshaped.length),
      );
    }
    widget.onChanged?.call(_value);
  }

  Widget get _countrySelector {
    final accent = AppInputStyle.accentOf(context, widget.variant);
    final enabled = widget.enabled && !widget.readOnly;

    return Semantics(
      button: true,
      label: 'Country: ${_country.name}, ${_country.dialCode}',
      child: InkWell(
        onTap: enabled
            ? () {
                HapticFeedback.selectionClick();
                _openPicker();
              }
            : null,
        borderRadius: AppConstants.borderRadius12,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppConstants.space12,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // The flag is an emoji, so it must not be tinted by the icon
              // theme the decoration wraps a prefix in.
              Text(
                _country.flag,
                style: const TextStyle(fontSize: _flagSize),
              ),
              if (widget.showDialCode) ...[
                const SizedBox(width: AppConstants.space4),
                Text(
                  _country.dialCode,
                  style: AppInputStyle.valueStyle(
                    context,
                    size: widget.size,
                    variant: widget.variant,
                    enabled: enabled,
                  ),
                ),
              ],
              Icon(
                Icons.keyboard_arrow_down,
                size: AppInputStyle.configOf(widget.size).iconSize,
                color: enabled ? accent : null,
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppInput(
      label: widget.label,
      format: AppInputFormat.phone,
      controller: _controller,
      hint: widget.hint ?? _country.masks.first,
      required: widget.required,
      enabled: widget.enabled,
      readOnly: widget.readOnly,
      autoFocus: widget.autoFocus,
      focusNode: widget.focusNode,
      textInputAction: widget.textInputAction,
      // Rebuilt on every country change, which is what re-points the mask.
      inputFormatters: [PhoneNumberInputFormatter(_country)],
      prefixIcon: _countrySelector,
      validator:
          widget.validator ??
          (value) => AppPhoneInput.validate(
            value,
            country: _country,
            required: widget.required,
          ),
      autovalidateMode: widget.autovalidateMode,
      onChanged: (_) => widget.onChanged?.call(_value),
      onSubmitted: (_) => widget.onSubmitted?.call(_value),
      labelMode: widget.labelMode,
      variant: widget.variant,
      type: widget.type,
      shape: widget.shape,
      size: widget.size,
    );
  }
}

/// Types a national number in the shape [country] writes them in.
///
/// Re-picks the mask on every keystroke, so a multi-shape plan widens as the
/// number grows. Digits past the longest mask are dropped, so the plan is
/// also the length cap.
class PhoneNumberInputFormatter extends TextInputFormatter {
  /// Formats for [country].
  const PhoneNumberInputFormatter(this.country);

  /// The country whose masks are applied.
  final AppCountry country;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final trailing = _digitsAfterCaret(newValue);
    final text = country.format(newValue.text);
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(
        offset: _offsetLeaving(text, trailing),
      ),
    );
  }
}

/// Flags are emoji, so they are sized as text rather than as an icon.
const double _flagSize = 20;

final RegExp _nonDigits = RegExp(r'\D');
final RegExp _digit = RegExp(r'\d');

String _digitsOnly(String value) => value.replaceAll(_nonDigits, '');

/// How many digits sit after the caret — the part of the value an edit leaves
/// untouched, and so the anchor the re-masked string can be measured against.
int _digitsAfterCaret(TextEditingValue value) {
  final caret = value.selection.end;
  if (caret < 0 || caret > value.text.length) return 0;
  return _digitsOnly(value.text.substring(caret)).length;
}

/// The offset in [text] that leaves exactly [digits] digits after it.
int _offsetLeaving(String text, int digits) {
  if (digits <= 0) return text.length;
  var seen = 0;
  for (var i = text.length - 1; i >= 0; i--) {
    if (_digit.hasMatch(text[i])) {
      seen++;
      if (seen == digits) return i;
    }
  }
  return 0;
}
''';
}
