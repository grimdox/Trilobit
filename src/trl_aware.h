#pragma once
#ifndef CATA_SRC_TRL_AWARE_H
#define CATA_SRC_TRL_AWARE_H

// Trilobit: graded awareness ("notice meter"), alert states and last-known-position search for
// creatures flagged TRL_ALERT_AWARE (monster flag, or character flag on an NPC).
// State lives in a side table keyed by creature, so it needs no change to the Creature class and
// is simply reset on load.

#include <optional>

#include "coordinates.h"
#include "point.h"

class Creature;

namespace trl_aware
{

enum state : int {
    UNAWARE = 0,    // going about its business
    SUSPICIOUS = 1, // noticed something; walking to where it noticed it
    SEARCHING = 2,  // at or near the last known position, sweeping the area
    HUNTING = 3,    // knows where you are
    RETURNING = 4   // gave up; walking back to its post
};

/** True if this creature uses the awareness system. */
bool enabled( const Creature &c );
/** True if this NPC would rather run than fight (civilians). */
bool noncombatant( const Creature &c );

/**
 * Update the notice meter toward the player once per turn.
 * @param raw_sees  whether the stock sight rules say c can see the player right now.
 * @return whether c should behave as though it sees the player (HUNTING and in view).
 */
bool gate( Creature &c, const Creature &player, bool raw_sees );

/** A sound reached c. src is where it seems to come from. */
void heard( Creature &c, const tripoint_abs_ms &src, int volume );

/** c was hurt or attacked from src: it knows where you are, now. */
void alerted( Creature &c, const tripoint_abs_ms &src );

/** What c should do about its current state. */
struct drive_result {
    bool active = false;                    // true: go to dest
    bool finished = false;                  // true: just returned to normal, drop any stale destination
    std::optional<tripoint_abs_ms> dest;
};
drive_result drive( Creature &c );

/** Where c last knew the player to be. */
std::optional<tripoint_abs_ms> last_known( const Creature &c );

/** Current state as an int (see enum state), or -1 if c does not use awareness. */
int level( const Creature &c );

/** Damage multiplier for a hit by attacker on target, from surprise (1.0 when it does not apply). */
float sneak_mult( const Creature &target, const Creature &attacker );

/** True if the overmap tile is part of a church (a Russian Orthodox church special from gen_faith.py). */
bool church_at( const tripoint_abs_omt &p );
/** True if c is a Bratva creature that must not fight the player right now: the player stands in a church
 *  and has not broken the peace there. */
bool church_truce( const Creature &c );
/** The player hurt victim; if both are inside a church, the peace is broken: the church turns on the player. */
void church_violence( const Creature &victim, const Creature *attacker );

/** Idle sweep: turn an unaware creature toward a new direction now and then. */
void sweep( Creature &c );

} // namespace trl_aware

#endif // CATA_SRC_TRL_AWARE_H
