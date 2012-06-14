# encoding: UTF-8

# mod for doing stuff w/ abbrevs
module Abbrev
  # a list of abbreviations culled, at least in part, from the USPS
  # official list https://www.usps.com/send/official-abbreviations.htm#2
  # this might be too country-specific, but it's a start.
  ABBREVIATIONS = {
    "alley" => ["aly"],
    "and" => ["&"],
    "annex" => ["anx"],
    "arcade" => ["arc"],
    "avenue" => ["ave"],
    "beach" => ["bch"],
    "burg" => ["bg"],
    "bluff" => ["blf"],
    "boulevard" => ["blvd"],
    "bend" => ["bnd"],
    "branch" => ["br"],
    "bridge" => ["brg"],
    "brook" => ["brk"],
    "bottom" => ["btm"],
    "bayoo" => ["byu"],
    "circle" => ["cir"],
    "club" => ["clb"],
    "cliff" => ["clf"],
    "common" => ["cmn"],
    "corner" => ["cor"],
    "camp" => ["cp"],
    "cape" => ["cpe"],
    "crescent" => ["cr","cres"],
    "creek" => ["crk"],
    "course" => ["crse"],
    "crest" => ["crst"],
    "causeway" => ["cswy"],
    "court" => ["ct"],
    "center" => ["ctr"],
    "curve" => ["curv"],
    "cove" => ["cv"],
    "canyon" => ["cyn"],
    "dale" => ["dl"],
    "dam" => ["dm"],
    "drive" => ["dr"],
    "doctor" => ["dr"],
    "divide" => ["dv"],
    "east" => ["e"],
    "estate" => ["est"],
    "expressway" => ["expy"],
    "extension" => ["ext"],
    "field" => ["fld"],
    "flat" => ["flt"],
    "ford" => ["frd"],
    "forge" => ["frg"],
    "fork" => ["frk"],
    "forest" => ["frst"],
    "ferry" => ["fry"],
    "fort" => ["ft"],
    "freeway" => ["fwy"],
    "garden" => ["gdn"],
    "glen" => ["gln"],
    "green" => ["grn"],
    "grove" => ["grv"],
    "gateway" => ["gtwy"],
    "harbor" => ["hbr"],
    "hill" => ["hl"],
    "hollow" => ["holw"],
    "haven" => ["hvn"],
    "highway" => ["hwy"],
    "inlet" => ["inlt"],
    "island" => ["is"],
    "junction" => ["jct"],
    "knoll" => ["knl"],
    "key" => ["ky"],
    "lock" => ["lck"],
    "lodge" => ["ldg"],
    "loaf" => ["lf"],
    "light" => ["lgt"],
    "lake" => ["lk"],
    "lane" => ["ln"],
    "landing" => ["lndg"],
    "meadow" => ["mdw"],
    "mill" => ["ml"],
    "manor" => ["mnr"],
    "mission" => ["msn"],
    "mount" => ["mt"],
    "mountain" => ["mtn"],
    "motorway" => ["mtwy"],
    "neck" => ["nck"],
    "north" => ["n"],
    "orchard" => ["orch"],
    "parkway" => ["pkwy"],
    "place" => ["pl"],
    "plain" => ["pln"],
    "plaza" => ["plz"],
    "pine" => ["pne"],
    "prairie" => ["pr"],
    "port" => ["prt"],
    "passage" => ["psge"],
    "point" => ["pt"],
    "radial" => ["radl"],
    "road" => ["rd"],
    "ridge" => ["rdg"],
    "river" => ["riv"],
    "ranch" => ["rnch"],
    "row" => ["row"],
    "rapid" => ["rpd"],
    "rest" => ["rst"],
    "route" => ["rte"],
    "shoal" => ["shl"],
    "shore" => ["shr"],
    "skyway" => ["skwy"],
    "south" => ["s"],
    "summit" => ["smt"],
    "spring" => ["spg"],
    "square" => ["sq"],
    "street" => ["st"],
    "station" => ["sta"],
    "stravenue" => ["stra"],
    "stream" => ["strm"],
    "terrace" => ["ter"],
    "turnpike" => ["tpke"],
    "track" => ["trak"],
    "trace" => ["trce"],
    "trafficway" => ["trfy"],
    "trail" => ["trl"],
    "throughway" => ["trwy"],
    "tunnel" => ["tunl"],
    "union" => ["un"],
    "viaduct" => ["via"],
    "vista" => ["vis"],
    "ville" => ["vl"],
    "village" => ["vlg"],
    "valley" => ["vly"],
    "view" => ["vw"],
    "way" => ["wy"],
    "well" => ["wl"],
    "west" => ["w"],
    "crossing" => ["xing"],
    "crossroad" => ["xrd"],

    # Russian abbreviations
    # Copyright (C) 2011-2012 Dmitry Marakasov
    # from https://github.com/AMDmi3/streetmangler/blob/master/lib/locales/ru.cc#L27
    "улица" => ["ул"],
    "площадь" => ["пл"],
    "переулок" => ["пер", "пер-к"],
    "проезд" => ["пр-д"],
    "шоссе" => ["ш"],
    "бульвар" => ["бул", "б-р"],
    "тупик" => ["туп"],
    "набережная" => ["наб"],
    "проспект" => ["просп", "пр-кт", "пр-т"],
    "тракт" => ["тр-т", "тр"],
    "эстакада" => ["эст"],
    "район" => ["р-н"],
    "микрорайон" => ["мкр-н", "мк-н", "мкр", "мкрн"],
    "посёлок" => ["поселок", "пос"],
    "деревня" => ["дер", "д"],
    "квартал" => ["кв-л", "кв"],

    # German abbreviations
    "anschlussstelle" => ["as"],
    "an" => ["a"],
    "bahnhof" => ["bf"],
    "bürgermeister" => ["bgm"],
    "der" => ["d"],
    "den" => ["d"],
    "evangelische" => ["ev", "evang"],
    "evangelischer" => ["ev", "evang"],
    "evangelisches" => ["ev", "evang"],
    "evangelisch" => ["ev", "evang"],
    "fachhochschule" => ["fh"],
    "gasse" => ["g"],
    "gemeinschaft" => ["gem"],
    "gemeinschafts" => ["gem"],
    "georg" => ["gg"],
    "groß" => ["gr"],
    "große" => ["gr"],
    "großer" => ["gr"],
    "großes" => ["gr"],
    "grundschule" => ["gs"],
    "gymnasium" => ["gym", "gymn"],
    "hauptbahnhof" => ["hbf"],
    "hauptschule" => ["hs"],
    "hochschule" => ["hs"],
    "johann" => ["joh"],
    "johannes" => ["joh"],
    "katholische" => ["kath"],
    "katholischer" => ["kath"],
    "katholisches" => ["kath"],
    "katholisch" => ["kath"],
    "kindergarten" => ["kiga"],
    "kindertagesstätte" => ["kita"],
    "klein" => ["kl"],
    "kleine" => ["kl"],
    "kleiner" => ["kl"],
    "kleines" => ["kl"],
    "krankenhaus" => ["kh", "krkh", "krh", "krhs"],
    "obere" => ["ob"],
    "oberer" => ["ob"],
    "oberes" => ["ob"],
    "platz" => ["pl"],
    "realschule" => ["rs"],
    "römisch" => ["röm"],
    "samtgemeinde" => ["sg"],
    "sankt" => ["st"],
    "sebastian" => ["seb"],
    "straße" => ["str"],
    "und" => ["u","&"],
    "universität" => ["uni"],
    "unterer" => ["unt"],
    "unteres" => ["unt"],
    "untere" => ["unt"],
    "vom" => ["v"],
    "vondem" => ["vd"],
    "vonder" => ["vd"],
    "von" => ["v"],
    "weg" => ["wg"],
    # Swiss German
    "strasse" => ["str"],
  }

  # In languages like German that use compound words with no spaces, we will find
  # words that end with an abbreviated suffix. For now let's treat these as a special
  # case to avoid too much extra load.
  ABB_SUFFIX = {
    "weg" => ["wg"],
    "strasse" => ["str"],
    "straße" => ["str"],
    "gasse" => ["g"],
    "platz" => ["pl"],
  }

  # of course, this is horribly english-specific...
  # but how would one expand this in a sensible fashion to
  # cover other languages?
  COMPASS = {
    "n"   => ["north"],
    "nne" => ["north","north","east"],
    "ne"  => ["north","east"],
    "ene" => ["east","north","east"],
    "e"   => ["east"],
    "ese" => ["east","south","east"],
    "se"  => ["south","east"],
    "sse" => ["south","south","east"],
    "s"   => ["south"],
    "ssw" => ["south","south","west"],
    "sw"  => ["south","west"],
    "wsw" => ["west","south","west"],
    "w"   => ["west"],
    "wnw" => ["west","north","west"],
    "nw"  => ["north","west"],
    "nnw" => ["north","north","west"]
  }

  def self.equal_abb_suffixes?(full_el, abb_el)
    ABB_SUFFIX.any? do |full_suf, abb_suf_list|
      pref_len = full_el.size - full_suf.size

      full_el.end_with? full_suf and abb_el[0..pref_len] == full_el[0..pref_len] and abb_suf_list.include? abb_el[pref_len..-1]
    end
  end

  def self.matches?(a_el, b_el)
    (a_el == b_el) or
    (ABBREVIATIONS.has_key?(a_el) && ABBREVIATIONS[a_el].any? {|a_ab| a_ab == b_el}) or
    (ABBREVIATIONS.has_key?(b_el) && ABBREVIATIONS[b_el].any? {|b_ab| b_ab == a_el}) or
    ABBREVIATIONS.any? {|k, v| v.include? a_el and v.include? b_el} or
    equal_abb_suffixes?(a_el, b_el) or
    equal_abb_suffixes?(b_el, a_el)
  end

  def self.drop_matching_prefix(a,b)
    i = 0
    while i < a.size and i < b.size and matches? a[i], b[i]
      i = i + 1
    end

    [ a[i..-1], b[i..-1] ]
  end

  def self.expand_element(el)
    res = [[el]]

    if comp = COMPASS[el]
      res << comp # Append expanded direction as separate words
      res << [comp.join] # Append direction as joined word
    end

    ABB_SUFFIX.each do |suf, abbs|
      res << [el[0..el.size - suf.size - 1], suf] if el.end_with? suf # Split suffix from word (for German)
    end

    res
  end

  # Expand tail return list of representation variants (words + tail) for a given tail string
  def self.expand_tail(s)
    res = []

    if m = s.split(/[-.,;:[:space:]]+/, 2) # Split first word by default separator
      expand_element(m[0]).each do |els|
        res << [els, m[1] || '']
      end
    end

    if m = s.split(/[.,;:[:space:]]+/, 2) # Split first word using reduced separator (for russian abbrevations with '-')
      expand_element(m[0]).each do |els|
        res << [els, m[1] || '']
      end
    end

    res.uniq
  end

  # Each string is represented as a list of prefix words and unparsed tail
  def self.equal_expansions_with_prefixes(a_words, a_tail, b_words, b_tail)
    a_words, b_words = drop_matching_prefix a_words, b_words # First of all we drop common parts of prefix word lists

    if a_words.empty? and b_words.empty? # Both prefixes are empty - we should expand both tails

      return true if a_tail.empty? and b_tail.empty? # Both tails are empty too - match is found
      return false if a_tail.empty? or b_tail.empty? # Only one of tails is empty - they can't be equal

      a_exps = expand_tail(a_tail)
      b_exps = expand_tail(b_tail)

      a_exps.any? do |new_a_words, new_a_tail| # Check all expansion variants of a
        b_exps.any? do |new_b_words, new_b_tail| # Check all expansion variants of b
          equal_expansions_with_prefixes(new_a_words, new_a_tail, new_b_words, new_b_tail)
        end
      end

    elsif a_words.empty? # Prefix of a is empty, but a isn't

      return false if a_tail.empty? # Tail of a is empty - there is nothing to expand

      expand_tail(a_tail).any? do |new_a_words, new_a_tail| # Check all expansion variants of a
        equal_expansions_with_prefixes(new_a_words, new_a_tail, b_words, b_tail)
      end

    elsif b_words.empty? # Prefix of a is empty, but b isn't

      return false if b_tail.empty? # Tail of b is empty - there is nothing to expand

      expand_tail(b_tail).any? do |new_b_words, new_b_tail| # Check all expansion variants of b
        equal_expansions_with_prefixes(a_words, a_tail, new_b_words, new_b_tail)
      end

    end

    # If there is something last in both word lists - they can't be equal
  end

  # function for expanding a string into a list of strings
  # TODO: may need some work for internationalisation
  def self.equal_expansions(a, b)
    a.gsub!('&',' & ')
    b.gsub!('&',' & ')
    equal_expansions_with_prefixes([], a.downcase, [], b.downcase) # In the start prefix words are empty and only tail present
  end

end
