#!/usr/bin/python
# coding: utf-8
#License: Beerware
#Author: MonkZ
import sys
from heapq import heappush, heappop

if not(len(sys.argv) == 3 or (len(sys.argv) == 4 and sys.argv[3] == "-v")):
  print "Please pass two strings to this program"
  exit(1)
target1 = sys.argv[1].decode("utf-8").lower()
target2 = sys.argv[2].decode("utf-8").lower()
verbose = len(sys.argv) == 4

if verbose:
  print "TEST: %s " % target1
  print "TEST: %s " % target2


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
    [u'doctor', u'dr'],
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
    [u'bei', u'b'],
    [u'bürgermeister', u'bgm'],
    [u'der', u'd'],
    [u'den', u'd'],
    [u'dem', u'd'],
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
    [u'unter', u'u'],
    [u'vom', u'v'],
    [u'von dem', u'vd'],
    [u'von der', u'vd'],
    [u'von', u'v'],
    [u'weg', u'wg'],
    [u'zu', u'z'],
    [u'zum', u'z'],
    [u'zur', u'z'],
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
    [u'n'  , u'north'],
    [u'e'  , u'east'],
    [u's'  , u'south'],
    [u'w'  , u'west'],
  ]

#build substitution rules out of classes (plz do this only once per redactionbot-start)
rules = {}
for clazz in classes:
  for elem in clazz:
    if not elem in rules.keys():
      rules[elem] = set([])
    rules[elem] = rules[elem] | (set(clazz) - set([elem]))
    
#filter rules against targets
filteredforwardrules = {}
for rule in rules.keys():
  if target1.find(rule) != -1:
    filteredforwardrules[rule] = rules[rule]

filteredbackwardrules = {}
for rule in rules.keys():
  if target2.find(rule) != -1:
    filteredbackwardrules[rule] = rules[rule]

#add special rules like "kill spaces"
filteredforwardrules[u' '] = set([u' ', u'', u'-', u'.', u'. '])
filteredforwardrules[u'-'] = set([u'-', u' '])
filteredforwardrules[u'.'] = set([u'.', u' ', u''])
filteredbackwardrules[u' '] = set([u' ', u'', u'-', u'.', u'. '])
filteredbackwardrules[u'-'] = set([u'-', u' '])
filteredbackwardrules[u'.'] = set([u'.', u' ', u''])


if verbose:
  print filteredforwardrules
  print filteredbackwardrules

#rulemangling
toextendforw = [(0,('',target1))]
toextendbackw = [(0,('',target2))]

def manglenext(heap, manglerules, target):
  if heap != []:
    #remove the best unvisited word from queue and mangle it
    wdist, (wordstart, wordend) = heappop(heap)
    #if we found our string we're happy
    if wordstart + wordend == target:
      print "Found"
      exit(0)

    if verbose:
      if target == target1:
        print "Forw:"
      else:
        print "Backw:"
      print "pop %s | %s - dist: %i" % (wordstart, wordend, wdist)

    #call every rule
    for rule in manglerules.keys():
      #and try to use it (maybe this could be improved by find our ruletrigger in first place)
      for substitute in manglerules[rule]:
        #execute rule (just split once!!)
        newsplit = wordend.split(rule,1)
        # if rule doesn't apply len != 2
        if len(newsplit) == 2:
          newwordstart = wordstart + newsplit[0] + substitute
          newwordend = newsplit[1]
          #everything in wordstart have to match targets first characters
          if target.startswith(newwordstart):
            heappush(heap, (len(newwordend),(newwordstart,newwordend)))
            #to avoid loops with insert space (and insert special rule ' ')
            if rule != ' ':
              heappush(heap, (len(newwordend),(newwordstart,' '+newwordend))) # insert space

#try rules on every string until we've no more strings
while(toextendforw != [] or toextendbackw != []):
  manglenext(toextendforw, filteredforwardrules, target2)
  manglenext(toextendbackw, filteredbackwardrules, target1)

# :(
print "NOT Found"
exit(2)
