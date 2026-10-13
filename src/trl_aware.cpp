#include "trl_aware.h"

#include <algorithm>
#include <cmath>
#include <unordered_map>

#include "calendar.h"
#include "character.h"
#include "creature.h"
#include "creature_tracker.h"
#include "map.h"
#include "messages.h"
#include "monster.h"
#include "mtype.h"
#include "npc.h"
#include "rng.h"
#include "line.h"

namespace trl_aware
{

namespace
{

const json_character_flag flag_chr_aware( "TRL_ALERT_AWARE" );
const json_character_flag flag_chr_noncombatant( "TRL_NONCOMBATANT" );

struct entry {
    int st = UNAWARE;
    int meter = 0;                            // 0..100
    int timer = 0;                            // turns left in SEARCHING / RETURNING
    bool reached = false;                     // SEARCHING: has reached the last known position
    std::optional<tripoint_abs_ms> last_pos;  // last known position of the player
    std::optional<tripoint_abs_ms> post;      // where we were before getting worked up
    std::optional<tripoint_abs_ms> spot;      // current search point
    int spot_turns = 0;
    int last_turn = -1;                       // last turn gate() ran
    bool last_result = false;
};

std::unordered_map<const Creature *, entry> table;
int table_turn = -1;

int now()
{
    return to_turns<int>( calendar::turn - calendar::turn_zero );
}

entry &get( const Creature &c )
{
    const int t = now();
    if( t < table_turn ) {
        table.clear();  // new game or load
    }
    table_turn = t;
    entry &e = table[&c];
    // A stale entry belongs to a creature that is gone (its address may have been reused).
    if( e.last_turn >= 0 && t - e.last_turn > 20 ) {
        e = entry();
    }
    return e;
}

bool player_sees( const Creature &c )
{
    map &here = get_map();
    return !c.is_hallucination() && get_player_character().sees( here, c );
}

void say( const Creature &c, game_message_type type, const char *fmt )
{
    if( player_sees( c ) ) {
        add_msg( type, fmt, c.disp_name( false, true ) );
    }
}

void note_post( const Creature &c, entry &e )
{
    if( !e.post ) {
        e.post = c.pos_abs();
    }
}

point rot( const point &f, int k )
{
    static const point ring[8] = { { 0, -1 }, { 1, -1 }, { 1, 0 }, { 1, 1 }, { 0, 1 }, { -1, 1 }, { -1, 0 }, { -1, -1 } };
    int idx = 0;
    for( int i = 0; i < 8; ++i ) {
        if( ring[i] == f ) {
            idx = i;
        }
    }
    return ring[( idx + k + 8 ) % 8];
}

} // namespace

bool enabled( const Creature &c )
{
    if( const monster *m = c.as_monster() ) {
        // function-local so the id is resolved after game data has loaded
        static const mon_flag_id flag_mon_aware( "TRL_ALERT_AWARE" );
        return m->has_flag( flag_mon_aware );
    }
    if( const npc *n = c.as_npc() ) {
        return n->has_flag( flag_chr_aware );
    }
    return false;
}

bool noncombatant( const Creature &c )
{
    if( const npc *n = c.as_npc() ) {
        return n->has_flag( flag_chr_noncombatant );
    }
    return false;
}

int level( const Creature &c )
{
    if( !enabled( c ) ) {
        return -1;
    }
    auto it = table.find( &c );
    return it == table.end() ? static_cast<int>( UNAWARE ) : it->second.st;
}

std::optional<tripoint_abs_ms> last_known( const Creature &c )
{
    auto it = table.find( &c );
    if( it == table.end() ) {
        return std::nullopt;
    }
    return it->second.last_pos;
}

bool gate( Creature &c, const Creature &player, bool raw )
{
    entry &e = get( c );
    const int t = now();
    if( e.last_turn == t ) {
        return e.last_result;
    }
    e.last_turn = t;

    const int prev = e.st;
    const tripoint_abs_ms ppos = player.pos_abs();

    if( raw ) {
        const int dist = rl_dist( c.pos_abs(), ppos );
        float vis = 1.0f;
        float stance = 1.0f;
        if( const Character *pc = player.as_character() ) {
            vis = pc->visibility() / 100.0f;
            if( pc->is_crouching() ) {
                stance = 0.7f;
            } else if( pc->is_running() ) {
                stance = 1.3f;
            }
        }
        float gain = 45.0f / ( 1.0f + dist / 6.0f ) * vis * stance;
        // Straight ahead is noticed faster than the edge of the view.
        const double dx = ppos.x() - c.pos_abs().x();
        const double dy = ppos.y() - c.pos_abs().y();
        const double len = std::sqrt( dx * dx + dy * dy );
        const point f = c.trl_facing;
        const double flen = std::sqrt( static_cast<double>( f.x * f.x + f.y * f.y ) );
        if( len > 0.0 && flen > 0.0 ) {
            const double cs = ( f.x * dx + f.y * dy ) / ( flen * len );
            if( cs > 0.7 ) {
                gain *= 1.5f;
            } else if( cs < 0.25 ) {
                gain *= 0.6f;
            }
        }
        if( e.st != UNAWARE ) {
            gain *= 1.5f;
        }
        if( dist <= 1 ) {
            gain = 100.0f;
        }
        e.meter = std::min( 100, e.meter + std::max( 1, static_cast<int>( gain ) ) );
        e.last_pos = ppos;
        if( e.meter >= 100 ) {
            e.st = HUNTING;
        } else if( e.st == UNAWARE && e.meter >= 25 ) {
            note_post( c, e );
            e.st = SUSPICIOUS;
        } else if( e.st == RETURNING ) {
            e.st = SUSPICIOUS;
        }
    } else {
        if( e.st == HUNTING ) {
            e.st = SEARCHING;
            e.meter = 70;
            e.timer = 35 + rng( 0, 15 );
            e.reached = false;
            e.spot.reset();
        } else if( e.st == UNAWARE ) {
            e.meter = std::max( 0, e.meter - 6 );
        }
    }

    if( e.st != prev ) {
        if( e.st == HUNTING ) {
            say( c, m_bad, _( "%s spots you!" ) );
        } else if( e.st == SUSPICIOUS && prev != HUNTING ) {
            say( c, m_warning, _( "%s notices something." ) );
        } else if( e.st == SEARCHING && prev == HUNTING ) {
            say( c, m_good, _( "%s loses sight of you." ) );
        }
    }
    e.last_result = raw && e.st == HUNTING;
    return e.last_result;
}

void heard( Creature &c, const tripoint_abs_ms &src, int volume )
{
    if( volume < 1 ) {
        return;
    }
    // Ordinary city noise (residents walking about) must not keep guards twitchy: only noise that
    // comes from the player's own spot, or that is loud where it is heard, is worth a look.
    const bool from_player = rl_dist( src, get_player_character().pos_abs() ) <= 2;
    if( !from_player && volume < 12 ) {
        return;
    }
    entry &e = get( c );
    if( e.st == HUNTING ) {
        return;
    }
    if( ( e.st == SUSPICIOUS || e.st == SEARCHING ) && e.last_pos && rl_dist( src, *e.last_pos ) <= 4 ) {
        // the same area again: keep looking a bit longer, do not restart
        e.timer = std::max( e.timer, 10 );
        return;
    }
    const int prev = e.st;
    note_post( c, e );
    e.last_pos = src;
    e.meter = std::max( e.meter, std::min( 90, 25 + volume * 2 ) );
    e.reached = false;
    e.spot.reset();
    e.st = SUSPICIOUS;
    c.trl_face_toward( src );
    if( prev != SUSPICIOUS ) {
        say( c, m_warning, _( "%s hears something." ) );
    }
}

void alerted( Creature &c, const tripoint_abs_ms &src )
{
    entry &e = get( c );
    note_post( c, e );
    e.meter = 100;
    e.last_pos = src;
    if( e.st != HUNTING ) {
        e.st = HUNTING;
        c.trl_face_toward( src );
        say( c, m_bad, _( "%s is on to you!" ) );
    }
}

drive_result drive( Creature &c )
{
    drive_result r;
    auto it = table.find( &c );
    if( it == table.end() ) {
        return r;
    }
    entry &e = it->second;
    const tripoint_abs_ms here_pos = c.pos_abs();
    map &here = get_map();

    switch( e.st ) {
        case SUSPICIOUS:
            if( !e.last_pos ) {
                e.st = UNAWARE;
                break;
            }
            if( rl_dist( here_pos, *e.last_pos ) <= 1 ) {
                e.st = SEARCHING;
                e.timer = 14;
                e.reached = true;
                e.spot.reset();
                break;
            }
            r.active = true;
            r.dest = e.last_pos;
            return r;
        case SEARCHING:
            if( !e.last_pos || --e.timer <= 0 ) {
                e.st = RETURNING;
                e.timer = 60;
                say( c, m_good, _( "%s gives up the search." ) );
                break;
            }
            if( !e.reached ) {
                if( rl_dist( here_pos, *e.last_pos ) <= 1 ) {
                    e.reached = true;
                } else {
                    r.active = true;
                    r.dest = e.last_pos;
                    return r;
                }
            }
            // Sweep: wander between random spots near the last known position.
            if( !e.spot || rl_dist( here_pos, *e.spot ) <= 1 || ++e.spot_turns > 10 ) {
                e.spot.reset();
                e.spot_turns = 0;
                for( int i = 0; i < 8; ++i ) {
                    tripoint_abs_ms cand = *e.last_pos + point( rng( -6, 6 ), rng( -6, 6 ) );
                    cand.z() = here_pos.z();
                    if( here.inbounds( cand ) && here.passable( here.get_bub( cand ) ) ) {
                        e.spot = cand;
                        break;
                    }
                }
            }
            if( e.spot ) {
                r.active = true;
                r.dest = e.spot;
                return r;
            }
            break;
        case RETURNING:
            if( !e.post || rl_dist( here_pos, *e.post ) <= 1 || --e.timer <= 0 ) {
                e.st = UNAWARE;
                e.meter = 0;
                e.post.reset();
                e.last_pos.reset();
                r.finished = true;
                break;
            }
            r.active = true;
            r.dest = e.post;
            return r;
        default:
            break;
    }
    return r;
}

float sneak_mult( const Creature &target, const Creature &attacker )
{
    if( !attacker.is_avatar() || !enabled( target ) ) {
        return 1.0f;
    }
    auto it = table.find( &target );
    const int st = it == table.end() ? static_cast<int>( UNAWARE ) : it->second.st;
    if( st == UNAWARE ) {
        return 3.0f;
    }
    if( st == SUSPICIOUS || st == SEARCHING || st == RETURNING ) {
        return 1.5f;
    }
    return 1.0f;
}

void sweep( Creature &c )
{
    if( one_in( 5 ) ) {
        c.trl_facing = rot( c.trl_facing == point::zero ? point( 0, 1 ) : c.trl_facing, one_in( 2 ) ? 1 : -1 );
    }
}

} // namespace trl_aware
