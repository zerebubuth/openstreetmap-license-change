# encoding: UTF-8
require 'set'
require 'algorithms'
# mod for doing stuff w/ abbrevs
module Abbrev
  # a list of abbreviations culled, at least in part, from the USPS
  # official list https://www.usps.com/send/official-abbreviations.htm#2
  # this might be too country-specific, but it's a start.
  classes = [
    ["alley", "aly"],
    ["and", "&"],
    ["annex", "anx"],
    ["arcade", "arc"],
    ["avenue", "ave"],
    ["beach", "bch"],
    ["burg", "bg"],
    ["bluff", "blf"],
    ["boulevard", "blvd"],
    ["bend", "bnd"],
    ["branch", "br"],
    ["bridge", "brg"],
    ["brook", "brk"],
    ["bottom", "btm"],
    ["bayoo", "byu"],
    ["circle", "cir"],
    ["club", "clb"],
    ["cliff", "clf"],
    ["common", "cmn"],
    ["corner", "cor"],
    ["camp", "cp"],
    ["cape", "cpe"],
    ["crescent", "cr","cres"],
    ["creek", "crk"],
    ["course", "crse"],
    ["crest", "crst"],
    ["causeway", "cswy"],
    ["court", "ct"],
    ["center", "ctr"],
    ["curve", "curv"],
    ["cove", "cv"],
    ["canyon", "cyn"],
    ["dale", "dl"],
    ["dam", "dm"],
    ["drive", "dr"],
    ["doctor", "dr"],
    ["divide", "dv"],
    ["east", "e"],
    ["estate", "est"],
    ["expressway", "expy"],
    ["extension", "ext"],
    ["field", "fld"],
    ["flat", "flt"],
    ["ford", "frd"],
    ["forge", "frg"],
    ["fork", "frk"],
    ["forest", "frst"],
    ["ferry", "fry"],
    ["fort", "ft"],
    ["freeway", "fwy"],
    ["garden", "gdn"],
    ["glen", "gln"],
    ["green", "grn"],
    ["grove", "grv"],
    ["gateway", "gtwy"],
    ["harbor", "hbr"],
    ["hill", "hl"],
    ["hollow", "holw"],
    ["haven", "hvn"],
    ["highway", "hwy"],
    ["inlet", "inlt"],
    ["island", "is"],
    ["junction", "jct"],
    ["knoll", "knl"],
    ["key", "ky"],
    ["lock", "lck"],
    ["lodge", "ldg"],
    ["loaf", "lf"],
    ["light", "lgt"],
    ["lake", "lk"],
    ["lane", "ln"],
    ["landing", "lndg"],
    ["meadow", "mdw"],
    ["mill", "ml"],
    ["manor", "mnr"],
    ["mission", "msn"],
    ["mount", "mt"],
    ["mountain", "mtn"],
    ["motorway", "mtwy"],
    ["neck", "nck"],
    ["north", "n"],
    ["orchard", "orch"],
    ["parkway", "pkwy"],
    ["place", "pl"],
    ["plain", "pln"],
    ["plaza", "plz"],
    ["pine", "pne"],
    ["prairie", "pr"],
    ["port", "prt"],
    ["passage", "psge"],
    ["point", "pt"],
    ["radial", "radl"],
    ["road", "rd"],
    ["ridge", "rdg"],
    ["river", "riv"],
    ["ranch", "rnch"],
    ["row", "row"],
    ["rapid", "rpd"],
    ["rest", "rst"],
    ["route", "rte"],
    ["shoal", "shl"],
    ["shore", "shr"],
    ["skyway", "skwy"],
    ["south", "s"],
    ["summit", "smt"],
    ["spring", "spg"],
    ["square", "sq"],
    ["street", "st"],
    ["station", "sta"],
    ["stravenue", "stra"],
    ["stream", "strm"],
    ["terrace", "ter"],
    ["turnpike", "tpke"],
    ["track", "trak"],
    ["trace", "trce"],
    ["trafficway", "trfy"],
    ["trail", "trl"],
    ["throughway", "trwy"],
    ["tunnel", "tunl"],
    ["union", "un"],
    ["viaduct", "via"],
    ["vista", "vis"],
    ["ville", "vl"],
    ["village", "vlg"],
    ["valley", "vly"],
    ["view", "vw"],
    ["way", "wy"],
    ["well", "wl"],
    ["west", "w"],
    ["crossing", "xing"],
    ["crossroad", "xrd"],

    # Russian abbreviations
    # Copyright (C) 2011-2012 Dmitry Marakasov
    # from https://github.com/AMDmi3/streetmangler/blob/master/lib/locales/ru.cc#L27
    ["улица", "ул"],
    ["площадь", "пл"],
    ["переулок", "пер", "пер-к"],
    ["проезд", "пр-д"],
    ["шоссе", "ш"],
    ["бульвар", "бул", "б-р"],
    ["тупик", "туп"],
    ["набережная", "наб"],
    ["проспект", "просп", "пр-кт", "пр-т"],
    ["тракт", "тр-т", "тр"],
    ["эстакада", "эст"],
    ["район", "р-н"],
    ["микрорайон", "мкр-н", "мк-н", "мкр", "мкрн"],
    ["посёлок", "поселок", "пос"],
    ["деревня", "дер", "д"],
    ["квартал", "кв-л", "кв"],

    # German abbreviations
    ["anschlussstelle", "as"],
    ["an", "a"],
    ["bahnhof", "bf"],
    ["bei", "b"],
    ["bürgermeister", "bgm"],
    ["der", "d"],
    ["den", "d"],
    ["dem", "d"],
    ["evangelische", "ev", "evang"],
    ["evangelischer", "ev", "evang"],
    ["evangelisches", "ev", "evang"],
    ["evangelisch", "ev", "evang"],
    ["fachhochschule", "fh"],
    ["gasse", "g"],
    ["gemeinschaft", "gem"],
    ["gemeinschafts", "gem"],
    ["georg", "gg"],
    ["groß", "gr"],
    ["große", "gr"],
    ["großer", "gr"],
    ["großes", "gr"],
    ["grundschule", "gs"],
    ["gymnasium", "gym", "gymn"],
    ["hauptbahnhof", "hbf"],
    ["hauptschule", "hs"],
    ["hochschule", "hs"],
    ["in", "i"],
    ["johann", "joh"],
    ["johannes", "joh"],
    ["katholische", "kath"],
    ["katholischer", "kath"],
    ["katholisches", "kath"],
    ["katholisch", "kath"],
    ["kindergarten", "kiga"],
    ["kindertagesstätte", "kita"],
    ["klein", "kl"],
    ["kleine", "kl"],
    ["kleiner", "kl"],
    ["kleines", "kl"],
    ["krankenhaus", "kh", "krkh", "krh", "krhs"],
    ["obere", "ob"],
    ["oberer", "ob"],
    ["oberes", "ob"],
    ["platz", "pl"],
    ["realschule", "rs"],
    ["römisch", "röm"],
    ["samtgemeinde", "sg"],
    ["sankt", "st"],
    ["sebastian", "seb"],
    ["straße", "str"],
    ["und", "u","&"],
    ["universität", "uni"],
    ["unterer", "unt","u"],
    ["unteres", "unt","u"],
    ["untere", "unt","u"],
    ["unter", "u"],
    ["vom", "v"],
    ["von", "v"],
    ["weg", "wg"],
    ["zur", "z"],
    ["zum", "z"],
    ["zu", "z"],
    # Swiss German
    ["strasse", "str"],
    
    #compass
     # of course, this is horribly english-specific...
     # but how would one expand this in a sensible fashion to
     # cover other languages?
    ["n", "north"],
    ["e", "east"],
    ["s", "south"],
    ["w", "west"],
    # german
    ["n", "nord"],
    ["o", "ost"],
    ["s", "süd"],
  ]

#build substitution rules out of classes (plz do this only once per redactionbot-start)
@@rules = Hash.new(Set.new)
for clazz in classes
  for elem in clazz
    @@rules[elem] = @@rules[elem] | ((Set.new clazz) - (Set.new [elem]))
  end
end
#special rules like kill spaces, dashes and dots
@@rules[' '] = @@rules[elem] | Set.new(['', '-', '.', '. '])
@@rules['-'] = @@rules[elem] | Set.new([' ', ''])
@@rules['.'] = @@rules[elem] | Set.new([' ', ''])


  # function for expanding a string into a list of strings
    def self.manglenext(heap, manglerules, target)
      if !heap.empty?()
        #remove the best unvisited word from queue and mangle it
        wordstart, wordend = heap.next!()
        print "\n------\n"
        print [wordstart]
        print " - "
        print [wordend]
        #call every rule
        for rule in manglerules.keys()
          #and try to use it
	  if rule == ' '
	    print "\nSPACE\n"
	  end
          #execute rule (just split once!!)
          newsplit = wordend.split(rule,2)
          # if rule doesn't apply len != 2
          if newsplit.size() == 2
            for substitute in manglerules[rule]
              newwordstart = wordstart + newsplit[0] + substitute
              newwordend = newsplit[1]
              #everything in wordstart have to match targets first characters
              if target.start_with?(newwordstart)
                #if we found our string we're happy
		print "\n>>"
		print [target]
		print [newwordstart + newwordend]
                if target == newwordstart + newwordend
                  puts "Found"
                  return true
                end
                heap.push([newwordstart,newwordend],-newwordend.size())
                #to avoid loops with insert space (and insert special rule ' ')
                if rule != ' '
		  newwordspaceend = ' ' + newwordend
                  #if we found our string we're happy
                  if target == newwordstart + newwordspaceend
                    puts "Found"
                    return true
                  end
                  heap.push([newwordstart,newwordspaceend],-newwordend.size()) # insert space
                end
              end
            end
          end
        end
      end
      return false
    end

  # TODO: may need some work for internationalisation
  def self.equal_expansions(a, b)
    input1 = a.downcase() + ' '
    input2 = b.downcase() + ' '
    # TODO: insert abbrev-python-v2 algo here
    if input1 == input2
      #shortcut if string a matches string b
      return true
    end
    # filter rules? maybe if words are long enough / dont remove special rules
    
    #init toextend (priorityqueue)
    extendforwpq = Containers::PriorityQueue.new
    extendforwpq.push(['',input1],0)
    extendbackwpq = Containers::PriorityQueue.new
    extendbackwpq.push(['',input2],0)
    
        
    until extendforwpq.empty?() and extendbackwpq.empty?()
      print "\nForward"
      if manglenext(extendforwpq, @@rules, input2)
        return true
      end
      print "\nBackward"
      if manglenext(extendbackwpq, @@rules, input1)
        return true
      end
    end
    return false
  end

end
