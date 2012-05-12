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

  # function for expanding a string into a list of strings
  # TODO: may need some work for internationalisation
  def self.equal_expansions(a, b)
    a = a.downcase.split(/[[:punct:][:space:]]+/)
    b = b.downcase.split(/[[:punct:][:space:]]+/)

    # expand compass directions in each - SPECIAL CASE... this is kinda
    # nasty, but i really can't think of a better way to do it at the
    # moment...
    a = a.inject(Array.new) do |ary,el| 
      if COMPASS.has_key? el
        if a.count < b.count
          ary + COMPASS[el]
        else
          ary << COMPASS[el].join
        end
      else
        ary + [el]
      end
    end
    b = b.inject(Array.new) do |ary,el| 
      if COMPASS.has_key? el
        if a.count > b.count
          ary + COMPASS[el]
        else
          ary << COMPASS[el].join
        end
      else
        ary + [el]
      end
    end

    puts "Thinking about word number for: " + a.to_s + " and " + b.to_s

    # no expansions which alter the number of words. (really? - check this)
    return false if a.length != b.length
puts "Word number was OK for: " + a.to_s + " and " + b.to_s
    
    # check whether each is equal], or can be reached by expansion
    # or abbreviation.
    a.zip(b) do |a_el, b_el|
      if a_el != b_el
          #    puts "a_el: " + a_el
          # puts "b_el: " + b_el
        match = ((ABBREVIATIONS.has_key?(a_el) && ABBREVIATIONS[a_el].any? {|a_ab| a_ab == b_el}) or
                 (ABBREVIATIONS.has_key?(b_el) && ABBREVIATIONS[b_el].any? {|b_ab| b_ab == a_el}))
          
          # Maybe only the end of the words is abbreviated (a suffix)
          
          
          #        split_by_common_start(a_el, b_el) if not match
        return false if not match
      end
    end

    return true
  end

  def self.split_by_common_start(a, b)
    i = 1
    while a[0, i] == b[0, i] do
      common_bit = a[0, i] 
      i = i + 1
    end
    puts "Found common bit: " + common_bit
  end

end
