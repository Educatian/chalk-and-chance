#!/usr/bin/env python3
"""Add funds-of-knowledge / asset-framing fields to every persona file.

For each student we add:
  assets          : list of real-world strengths / community knowledge (Moll & Gonzalez)
  asset_hint      : what the teacher learns on the first Connect (NOTICE / interpret beat)
  connect_line    : what the student says when the teacher bridges content to that asset
  connect_resolves: whether connecting-to-an-asset is itself a valid path to the goal
                    (True => this student has >=2 defensible routes, softening the
                     single-right-move mechanic the qualitative audit flagged)

Run:  python tools/add_assets.py
"""
import json, os

HERE = os.path.dirname(__file__)
LIB = os.path.join(HERE, "..", "data", "persona_library")

ASSETS = {
  "noah_g5_fractions": {
    "assets": ["divides snacks fairly so his little sister never complains",
               "draws comic panels in equal-sized boxes"],
    "asset_hint": "Noah is the one who splits the last brownie so his sister can't argue. He already reasons about equal shares - that's fractions in his own world.",
    "connect_line": "Oh - like splitting the brownie! More people means smaller pieces. So 1/8 is the smaller share. I actually get it now.",
    "connect_resolves": True,
  },
  "jordan_skeptic": {
    "assets": ["rebuilds and tunes his older brother's bike", "tracks his own stats in a racing game"],
    "asset_hint": "Jordan keeps asking 'when do we use this?' He rebuilds bikes - gear ratios are exactly this math. The skepticism is a bid for relevance, not defiance.",
    "connect_line": "Wait, this is just gear ratios. I do this on the bike every weekend. Okay, NOW it's worth my time.",
    "connect_resolves": True,
  },
  "diego_ell": {
    "assets": ["translates for his grandmother at appointments", "explains schoolwork to younger cousins in Spanish first"],
    "asset_hint": "Diego works it out in Spanish before he'll risk English. Letting him reason in his home language first is a resource, not a deficit (Moll's funds of knowledge).",
    "connect_line": "Oh - 'lo explico en espanol primero'... yes. When I say it my way first, then I can tell you in English. It makes sense.",
    "connect_resolves": True,
  },
  "riley_avoidant": {
    "assets": ["builds elaborate redstone machines in Minecraft", "keeps a notebook of game strategies"],
    "asset_hint": "Riley shrugs at the worksheet, but builds intricate redstone logic at home. So this is avoidance / fear of being wrong, NOT a thinking gap. Read the FUNCTION before you respond.",
    "connect_line": "I mean... I do way harder logic in Minecraft. I guess I just didn't want to mess this up in front of everyone.",
    "connect_resolves": True,
  },
  "sam_withdrawn": {
    "assets": ["sketches characters in the margins", "knows every fact about deep-sea creatures"],
    "asset_hint": "Sam has gone quiet, but the margins are full of drawings. There's a door in there - an interest you can open before you ask for thinking.",
    "connect_line": "...you saw my drawings? I could draw the problem instead of writing it... yeah. Okay. I can try that.",
    "connect_resolves": True,
  },
  "meilin_anxious": {
    "assets": ["meticulous illustrator who redraws until it's right", "helps friends calm down before tests"],
    "asset_hint": "Mei-Lin's perfectionism is the same care that makes her redraw art until it's right. Name the effort, not the result - that's what unlocks her.",
    "connect_line": "...you noticed how much I revised it? ...okay. Maybe the mistakes are part of getting it right.",
    "connect_resolves": False,
  },
  "priya_quiet": {
    "assets": ["notices what everyone else misses", "writes long thoughtful book reviews"],
    "asset_hint": "Priya rarely volunteers, but she catches details no one else does. The asset is there; she just needs to be invited into the air-time.",
    "connect_line": "Oh - you actually want to hear what I thought? ...I did notice something nobody mentioned.",
    "connect_resolves": False,
  },
  "deshawn_offtask": {
    "assets": ["captains his rec basketball team", "the kid everyone follows at recess"],
    "asset_hint": "Deshawn is off-task AND the natural leader the others follow. Build the relationship and channel that leadership - warm demander, not just redirect.",
    "connect_line": "Aight, aight. You actually get me. ...Fine, I'll lead by getting MY work done first.",
    "connect_resolves": False,
  },
  "marcus_volatile": {
    "assets": ["makes beats on his phone", "calms himself with a rhythm or a walk"],
    "asset_hint": "Marcus is escalating. He grounds himself through music and rhythm. Connect to that to bring the temperature down before any academic demand.",
    "connect_line": "...yeah. Music helps me chill. ...Okay. I'm good now. We can do the work.",
    "connect_resolves": False,
  },
  "talia_dominator": {
    "assets": ["genuinely loves the subject and helps peers", "runs the school recycling club"],
    "asset_hint": "Talia dominates because she's eager, not selfish - she already helps peers and runs a club. Channel that energy into lifting others, don't just shut it down.",
    "connect_line": "Oh! I could help draw out the quieter folks instead of just answering? ...I'd actually love that.",
    "connect_resolves": False,
  },
}

def main():
    n = 0
    for pid, fields in ASSETS.items():
        path = os.path.join(LIB, pid + ".json")
        if not os.path.exists(path):
            print("MISSING", pid); continue
        with open(path, encoding="utf-8") as f:
            d = json.load(f)
        for k, v in fields.items():
            d[k] = v
        with open(path, "w", encoding="utf-8") as f:
            json.dump(d, f, ensure_ascii=False, indent=2)
        n += 1
        print("updated", pid, "connect_resolves=", fields["connect_resolves"])
    print("DONE", n, "personas")

if __name__ == "__main__":
    main()
