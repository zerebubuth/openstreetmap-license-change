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
  [u'straße',u'str.',u'strasse'],
  [u'weg',u'wg'],
  [u'von',u'v.'],
  [u'bürgermeister',u'bgm'],
  [u'in der',u'i.d.',u'i. d.'],
  [u'kleinen',u'kl'],
  [u'in',u'i.']
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
