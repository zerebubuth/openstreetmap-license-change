#!/usr/bin/python
# coding: utf-8
#License: GPLv3
#Author: MonkZ
import sys

if len(sys.argv) != 3:
  print "Please pass two strings to this program"
  exit(1)

#needed to trace already substituted parts in our strings
def mark(stri):
  nc = ""
  for c in stri:
    nc = nc + "|*" + c
  return nc

def demark(stri):
  return stri.replace("|*","")

#we want to reach this word
target = sys.argv[2].decode("utf-8")
#stack of strings to extend/substitute next round
#we need to evaluate stack and queue here
toextend = [mark(sys.argv[1].decode("utf-8"))]

#classes of strings/abbrvs/synonyms
#we can improve this by check our tag location
#if it is in UK we should use only UK classes and general rules
classes = [
    [u'alley', u'aly'],
    [u'and', u'&'],
    [u'annex', u'anx'],
    [u'arcade', u'arc'],
    [u'avenue', u'ave'],
    [u'beach', u'bch'],
    [u'burg', u'bg'],
    [u'bluff', u'blf'],
    [u'boulevard', u'blvd'],
    [u'bend', u'bnd'],
    [u'branch', u'br'],
    [u'bridge', u'brg'],
    [u'brook', u'brk'],
    [u'bottom', u'btm'],
    [u'bayoo', u'byu'],
    [u'circle', u'cir'],
    [u'club', u'clb'],
    [u'cliff', u'clf'],
    [u'common', u'cmn'],
    [u'corner', u'cor'],
    [u'camp', u'cp'],
    [u'cape', u'cpe'],
    [u'crescent', u'cr', u'cres'],
    [u'creek', u'crk'],
    [u'course', u'crse'],
    [u'crest', u'crst'],
    [u'causeway', u'cswy'],
    [u'court', u'ct'],
    [u'center', u'ctr'],
    [u'curve', u'curv'],
    [u'cove', u'cv'],
    [u'canyon', u'cyn'],
    [u'dale', u'dl'],
    [u'dam', u'dm'],
    [u'drive', u'dr'],
    [u'divide', u'dv'],
    [u'east', u'e'],
    [u'estate', u'est'],
    [u'expressway', u'expy'],
    [u'extension', u'ext'],
    [u'field', u'fld'],
    [u'flat', u'flt'],
    [u'ford', u'frd'],
    [u'forge', u'frg'],
    [u'fork', u'frk'],
    [u'forest', u'frst'],
    [u'ferry', u'fry'],
    [u'fort', u'ft'],
    [u'freeway', u'fwy'],
    [u'garden', u'gdn'],
    [u'glen', u'gln'],
    [u'green', u'grn'],
    [u'grove', u'grv'],
    [u'gateway', u'gtwy'],
    [u'harbor', u'hbr'],
    [u'hill', u'hl'],
    [u'hollow', u'holw'],
    [u'haven', u'hvn'],
    [u'highway', u'hwy'],
    [u'inlet', u'inlt'],
    [u'island', u'is'],
    [u'junction', u'jct'],
    [u'knoll', u'knl'],
    [u'key', u'ky'],
    [u'lock', u'lck'],
    [u'lodge', u'ldg'],
    [u'loaf', u'lf'],
    [u'light', u'lgt'],
    [u'lake', u'lk'],
    [u'lane', u'ln'],
    [u'landing', u'lndg'],
    [u'meadow', u'mdw'],
    [u'mill', u'ml'],
    [u'manor', u'mnr'],
    [u'mission', u'msn'],
    [u'mount', u'mt'],
    [u'mountain', u'mtn'],
    [u'motorway', u'mtwy'],
    [u'neck', u'nck'],
    [u'north', u'n'],
    [u'orchard', u'orch'],
    [u'parkway', u'pkwy'],
    [u'place', u'pl'],
    [u'plain', u'pln'],
    [u'plaza', u'plz'],
    [u'pine', u'pne'],
    [u'prairie', u'pr'],
    [u'port', u'prt'],
    [u'passage', u'psge'],
    [u'point', u'pt'],
    [u'radial', u'radl'],
    [u'road', u'rd'],
    [u'ridge', u'rdg'],
    [u'river', u'riv'],
    [u'ranch', u'rnch'],
    [u'row', u'row'],
    [u'rapid', u'rpd'],
    [u'rest', u'rst'],
    [u'route', u'rte'],
    [u'shoal', u'shl'],
    [u'shore', u'shr'],
    [u'skyway', u'skwy'],
    [u'south', u's'],
    [u'summit', u'smt'],
    [u'spring', u'spg'],
    [u'square', u'sq'],
    [u'street', u'st'],
    [u'station', u'sta'],
    [u'stravenue', u'stra'],
    [u'stream', u'strm'],
    [u'terrace', u'ter'],
    [u'turnpike', u'tpke'],
    [u'track', u'trak'],
    [u'trace', u'trce'],
    [u'trafficway', u'trfy'],
    [u'trail', u'trl'],
    [u'throughway', u'trwy'],
    [u'tunnel', u'tunl'],
    [u'union', u'un'],
    [u'viaduct', u'via'],
    [u'vista', u'vis'],
    [u'ville', u'vl'],
    [u'village', u'vlg'],
    [u'valley', u'vly'],
    [u'view', u'vw'],
    [u'way', u'wy'],
    [u'well', u'wl'],
    [u'west', u'w'],
    [u'crossing', u'xing'],
    [u'crossroad', u'xrd'],
    
    # Russian abbreviations
    # Copyright (C) 2011-2012 Dmitry Marakasov
    # from https://github.com/AMDmi3/streetmangler/blob/master/lib/locales/ru.cc#L27
    [u'улица', u'ул'],
    [u'площадь', u'пл'],
    [u'переулок', u'пер', u'пер-к'],
    [u'проезд', u'пр-д'],
    [u'шоссе', u'ш'],
    [u'бульвар', u'бул', u'б-р'],
    [u'тупик', u'туп'],
    [u'набережная', u'наб'],
    [u'проспект', u'просп', u'пр-кт', u'пр-т'],
    [u'тракт', u'тр-т', u'тр'],
    [u'эстакада', u'эст'],
    [u'район', u'р-н'],
    [u'микрорайон', u'мкр-н', u'мк-н', u'мкр', u'мкрн'],
    [u'посёлок', u'поселок', u'пос'],
    [u'деревня', u'дер', u'д'],
    [u'квартал', u'кв-л', u'кв'],

    # German abbreviations
    [u'anschlussstelle', u'as'],
    [u'an', u'a'],
    [u'bahnhof', u'bf'],
    [u'bürgermeister', u'bgm'],
    [u'der', u'd'],
    [u'den', u'd'],
    [u'evangelische', u'ev', u'evang'],
    [u'evangelischer', u'ev', u'evang'],
    [u'evangelisches', u'ev', u'evang'],
    [u'evangelisch', u'ev', u'evang'],
    [u'fachhochschule', u'fh'],
    [u'gasse', u'g'],
    [u'gemeinschaft', u'gem'],
    [u'gemeinschafts', u'gem'],
    [u'groß', u'gr'],
    [u'große', u'gr'],
    [u'großer', u'gr'],
    [u'großes', u'gr'],
    [u'grundschule', u'gs'],
    [u'gymnasium', u'gym', u'gymn'],
    [u'hauptbahnhof', u'hbf'],
    [u'hauptschule', u'hs'],
    [u'hochschule', u'hs'],
    [u'johann', u'joh'],
    [u'johannes', u'joh'],
    [u'katholische', u'kath'],
    [u'katholischer', u'kath'],
    [u'katholisches', u'kath'],
    [u'katholisch', u'kath'],
    [u'kindergarten', u'kiga'],
    [u'kindertagesstätte', u'kita'],
    [u'klein', u'kl'],
    [u'kleine', u'kl'],
    [u'kleiner', u'kl'],
    [u'kleines', u'kl'],
    [u'krankenhaus', u'kh', u'krkh', u'krh', u'krhs'],
    [u'obere', u'ob'],
    [u'oberer', u'ob'],
    [u'oberes', u'ob'],
    [u'platz', u'pl'],
    [u'realschule', u'rs'],
    [u'römisch', u'röm'],
    [u'samtgemeinde', u'sg'],
    [u'sankt', u'st'],
    [u'sebastian', u'seb'],
    [u'straße', u'str'],
    [u'und', u'u', u'&'],
    [u'universität', u'uni'],
    [u'unterer', u'unt'],
    [u'unteres', u'unt'],
    [u'untere', u'unt'],
    [u'vom', u'v'],
    [u'von dem', u'vd'],
    [u'von der', u'vd'],
    [u'von', u'v'],
    [u'weg', u'wg'],
    # Swiss German
    [u'strasse', u'str'],
  
  # In languages like German that use compound words with no spaces, we will find
  # words that end with an abbreviated suffix. For now let's treat these as a special
  # case to avoid too much extra load.
    [u'weg', u'wg'],
    [u'strasse', u'str'],
    [u'straße', u'str'],
    [u'gasse', u'g'],
    [u'platz', u'pl'],

  # of course, this is horribly english-specific...
  # but how would one expand this in a sensible fashion to
  # cover other languages?
    [u'n'  , u'north', u'north|* '],
    [u'e'  , u'east', u'east|* '],
    [u's'  , u'south', u'south|* '],
    [u'w'  , u'west', u'west|* '],
  ]

#build substitution rules out of classes (plz do this only once per redactionbot-start)
rules = {}
for clazz in classes:
  for unmarkedelem in clazz:
    elem = mark(unmarkedelem)
    if not elem in rules.keys():
      rules[elem] = set([])
    rules[elem] = rules[elem] | (set(clazz) - set([unmarkedelem]))
#general
#add special rules like "kill spaces"
rules["|* "] = set(["","-"])
rules["|*-"] = set([" "])
print rules

#rulemangling
#try rules on every string until we've no more strings
while(toextend != []):
  #remove current word from queue and mangle it
  current = toextend.pop()
  #print current
  #call every rule
  for rule in rules.keys():
    #and try to use it (maybe this could be improved by find our ruletrigger in first place)
    for substitute in rules[rule]:
      #execute rule
      newword = current.replace(rule,substitute,1)
      #if it is a new string we add it to our stack for further mangling
      unmarkednewword = demark(newword)
      if newword != current:
        toextend.append(newword)
      #if we found our string we're happy
      if unmarkednewword == target:
        print "Found"
        exit(1)
# :(
print "NOT Found"
exit(2)
