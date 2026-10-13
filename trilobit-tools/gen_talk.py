#!/usr/bin/env python3
"""Generic dialogue (design doc section M): residents talk about their job, their district and the city, depending on what they
are doing right now (at work or off duty), their wealth tier and the time of day; faction members talk by faction.
Also writes the job barks the residents call out while they work.
usage: gen_talk.py <mod dir> -> <mod>/talk.json   (run after gen_residents.py; gen_residents imports BARKS from here)"""
import json, os, sys

# ---------------------------------------------------------------- job lines: job -> (at work, off duty, one short bark)
JOB = {
    # poor
    "day_laborer":   ("I move crates for the cargo yard.  Thirty yen a pallet if the foreman likes you.", "Back is shot.  Tomorrow I lift it all again.", "Mind your feet, load coming through!"),
    "street_vendor": ("Skewers, noodles, whatever fell off a truck.  Everybody has to eat.", "Closed for the night.  The stall does not sleep, but I do.", "Hot skewers!  Hot skewers, ten yen!"),
    "scrapper":      ("Pulling copper out of dead machines.  The scrapyard buys by the kilo.", "I smell like a scrapyard.  Do not stand too close.", "Copper's down again.  Always down."),
    "courier":       ("Parcels.  Anywhere in the district in twenty minutes, no questions about what is inside.", "Legs are done for the day.  Feet first, then food.", "Package for the third floor!"),
    "dishwasher":    ("Dishes.  Thousands of dishes.  The cook shouts, I scrub.", "Hands still smell like soap.  It never washes out.", "Plates!  I need plates back here!"),
    "janitor":       ("Somebody has to clean up after the offices.  Nobody ever sees me, and that is the job.", "The floors are clean.  Mine is not.", "Mop, bucket, mop, bucket..."),
    # middle
    "clerk":          ("I keep the department store ledgers straight.  It pays, and it is quiet.", "Off the clock.  Do not ask me where anything is.", "Welcome.  Welcome in."),
    "technician":     ("Telecom maintenance.  When the lines go down, I am the reason they come back.", "I fixed boxes all day.  Do not ask me about your router.", "Check the cable run again."),
    "nurse":          ("Hospital ward.  Long shifts, short staff, and a lot of people who will not follow the instructions.", "Off shift.  I am not looking at anyone's wounds tonight.", "Bed four needs a new drip."),
    "teacher":        ("Teaching at the district school.  The kids are fine; the budget is not.", "I graded forty papers today.  Give me tea.", "Eyes on the board, please."),
    "shop_assistant": ("Supermarket floor.  I know every shelf.  Do not ask about the sale prices, they change twice a day.", "Off work.  I am going to eat somebody else's cooking.", "Restocking, excuse me."),
    "police_clerk":   ("Precinct paperwork.  Forms for the forms.  You would not believe how many people confess to the wrong crime.", "Do not report anything to me; I am off duty.", "Number forty-one, please."),
    "driver":         ("Driving.  Routes, fares, and a city that never uses its own crosswalks.", "Parked the cab.  My feet need to be used for something.", "Mind the doors!"),
    "engineer":       ("Systems engineering at the corporate office.  Most of it is making somebody else's mistakes survive another quarter.", "Do not tell me about your problems.  I have forty of my own.", "Rerun the test."),
    # rich
    "executive": ("Executive floor.  Meetings, then meetings about the meetings.", "I have staff for that.", "Hold my calls."),
    "owner":     ("I own a few places.  Hotels, mainly.  Margins are thin, but rooms keep filling.", "Business is in the office.  This is my home.", "Is the suite ready?"),
    "investor":  ("I move money around.  Mostly other people's.  It is less fun than it sounds.", "The markets are closed.  I am not.", "Hmm.  Sell."),
    "surgeon":   ("Hospital surgery.  Implants, grafts, the occasional miracle.  People pay a great deal to avoid a long recovery.", "I have been on my feet since dawn.  Let me sit.", "Scalpel."),
    "official":  ("Retired from the district office.  They still ask my opinion, which is the best part.", "Pensions are generous if you know the right people.", "Mm."),
}
JOB_TIER = {j: t for t, js in (("poor", ["day_laborer", "street_vendor", "scrapper", "courier", "dishwasher", "janitor"]),
                              ("mid", ["clerk", "technician", "nurse", "teacher", "shop_assistant", "police_clerk", "driver", "engineer"]),
                              ("rich", ["executive", "owner", "investor", "surgeon", "official"])) for j in js}
BARKS = {(JOB_TIER[j], j): v[2] for j, v in JOB.items()}

# ---------------------------------------------------------------- tier lines
GREET = {
    "poor": ["What do you want?", "Yeah?  Make it quick.", "Spare any yen?  No?  Fine.", "Keep your voice down."],
    "mid": ["Hello.  Can I help you?", "Yes?", "Excuse me, I am on my way somewhere.", "Hm?  Do I know you?"],
    "rich": ["Good day.  Is there something you require?", "Yes?  Do be brief.", "You are not from this part of town.", "I was not expecting visitors."],
}
LIFE = {
    "poor": ["Rent is a joke and the water is worse.  The Bratva want their cut and the NAP want to look the other way.",
             "Nobody here has an implant that works.  We buy them used in the back alleys and hope.",
             "The poor end of town: bars on the windows and dogs on the roofs.  Still, it is home.",
             "Food is cheap on the corner, if you do not mind what it was this morning."],
    "mid": ["Things are all right.  Work, a flat, a small place at the market.  Do not count on the weather.",
            "Rents go up every year.  The clinics only get busier.  Everybody wants one more upgrade.",
            "We keep our heads down.  The NAP patrols are polite, the Bratva stay mostly in the east, and I try not to notice either.",
            "It is a decent district.  I would not want to go lower, and I cannot afford to go higher."],
    "rich": ["Quiet, clean, guarded.  Exactly as it should be.",
             "The towers keep the noise out, and the patrols keep the rest out.",
             "Life is pleasant.  One must only avoid looking at the lower districts from the balcony.",
             "I pay for peace.  It is the best bargain in the city."],
}
RUMOR = {
    "poor": ["They say a Nasim cell is working out of the old tea house.  Do not go near it.",
             "Back-alley implant shop on the corner does honest work, if you can scrape the yen together.",
             "The Bratva are taking tribute from the grocery.  Prices will go up soon.",
             "A man down the block got a spine upgrade and cannot stop twitching.  I will keep my own bones."],
    "mid": ["The new clinic on the avenue installs limbs the same day.  You pay for the speed.",
            "There are android showrooms uptown.  Fifty thousand yen buys you a basic one.  A decent one costs far more.",
            "A power post stands outside the hospital, and most shops.  Ten minutes and a few hundred yen, and your implants are full.",
            "The NAP have doubled the patrols near the towers.  Somebody important must be moving."],
    "rich": ["The atelier uptown has a new range of spinal work.  Lovely, and expensive.",
             "Androids are quite fashionable, if you are willing to pay for the top frames.",
             "The hospital's cyber wing has a waiting list, naturally.  Money makes lists shorter.",
             "The lower districts have been restless.  The NAP assure us it is under control."],
}
RECHARGE = ("Charging posts?  There is one outside every hospital, and a few outside the shops.  A few hundred yen for a top-up; "
            "more for a full charge.  Cheaper than a night in the clinic.")
FAC = {
    "bratva": ("Keep walking.  This street pays us, not you.", "We look after the district.  The district looks after us.  Do not make it complicated.",
               "Money is respect.  Pay and nobody gets hurt."),
    "nap": ("Move along, citizen.  Keep your weapons holstered.", "Patrolling the district.  Report any trouble to a precinct.",
             "The city is stable.  Please keep it that way."),
    "nasim": ("Do not look at me.  Do not look at my screen.", "We do not like what the corporations did to flesh.  Keep your implants quiet.",
              "The Net is bigger than any of you."),
}
FAC_CLASS = {"bratva": ["thug", "enforcer", "fixer"], "nap": ["patrol", "riot", "tactical"], "nasim": ["hacker", "saboteur", "zealot"]}


def nest(conds, default):
    """conds: [(condition dict, line)] -> nested yes/no dynamic_line"""
    out = default
    for c, line in reversed(conds):
        d = dict(c)
        d["yes"] = line
        d["no"] = out
        out = d
    return out


def at_work():
    return {"math": ["u_trl_at == 1"]}


def build():
    out = []
    # ---- resident topics (the npc is 'u' in effects, but in dialogue it is the 'npc'/'n_' side)
    def job_line(which):
        return nest([({"npc_has_class": f"trl_nc_res_{JOB_TIER[j]}_{j}"}, JOB[j][which]) for j in JOB], "I get by.")

    def greet():
        lines = []
        for tier in ("poor", "mid", "rich"):
            lines.append(({"npc_has_trait": f"trl_res_{tier}"}, GREET[tier]))
        return nest(lines, "Hm?  Can I help you?")

    back = [{"text": "Anything else?", "topic": "TRL_RESIDENT_TALK"}, {"text": "That's all.  Thanks.", "topic": "TALK_DONE"}]
    out.append({"type": "talk_topic", "id": "TRL_RESIDENT_TALK", "dynamic_line": greet(),
                "responses": [
                    {"text": "What do you do for a living?", "topic": "TRL_RES_JOB"},
                    {"text": "How are things around here?", "topic": "TRL_RES_LIFE"},
                    {"text": "Heard anything lately?", "topic": "TRL_RES_RUMOR"},
                    {"text": "Where can I recharge my implants?", "topic": "TRL_RES_RECHARGE"},
                    {"text": "Just passing through.", "topic": "TALK_DONE"}]})
    out.append({"type": "talk_topic", "id": "TRL_RES_JOB",
                "dynamic_line": {"math": ["n_trl_at == 1"], "yes": job_line(0), "no": job_line(1)}, "responses": back})
    out.append({"type": "talk_topic", "id": "TRL_RES_LIFE",
                "dynamic_line": nest([({"npc_has_trait": f"trl_res_{t}"}, LIFE[t]) for t in ("poor", "rich")], LIFE["mid"]), "responses": back})
    out.append({"type": "talk_topic", "id": "TRL_RES_RUMOR",
                "dynamic_line": nest([({"npc_has_trait": f"trl_res_{t}"}, RUMOR[t]) for t in ("poor", "rich")], RUMOR["mid"]), "responses": back})
    out.append({"type": "talk_topic", "id": "TRL_RES_RECHARGE", "dynamic_line": RECHARGE, "responses": back})
    # ---- faction members
    def fac_line(idx):
        return nest([({"npc_has_class": f"trl_nc_{f}_{c}"}, FAC[f][idx]) for f in FAC for c in FAC_CLASS[f]], "Keep walking.")
    fback = [{"text": "Anything else?", "topic": "TRL_FACTION_MEMBER"}, {"text": "Fine.  I'm leaving.", "topic": "TALK_DONE"}]
    out.append({"type": "talk_topic", "id": "TRL_FACTION_MEMBER", "dynamic_line": fac_line(0),
                "responses": [{"text": "What do you do here?", "topic": "TRL_FAC_JOB"},
                              {"text": "What do you think of the city?", "topic": "TRL_FAC_VIEW"},
                              {"text": "Fine.", "topic": "TALK_DONE"}]})
    out.append({"type": "talk_topic", "id": "TRL_FAC_JOB", "dynamic_line": fac_line(1), "responses": fback})
    out.append({"type": "talk_topic", "id": "TRL_FAC_VIEW", "dynamic_line": fac_line(2), "responses": fback})
    # ---- barks (snippets) the residents call out while they work
    for (tier, job), text in BARKS.items():
        out.append({"type": "snippet", "category": f"trl_bark_{tier}_{job}", "text": [text]})
    return out


if __name__ == "__main__":
    out = build()
    json.dump(out, open(os.path.join(sys.argv[1], "talk.json"), "w"), indent=1)
    print("talk topics:", sum(1 for o in out if o["type"] == "talk_topic"), "barks:", len(BARKS))
