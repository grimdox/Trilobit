# Art direction

**The feel:** Ghost in the Shell's city at night.  Neutral, cold-lit people under sodium and neon; skin that still
reads warm; hard blacks; hardware that is engineered, not decorated; one or two lights on a body, never a rainbow.
Two families share one language: gritty street operators and netrunners (worn cloth, plates, straps) and sleek
prosthetic bodies (pearl or graphite shells, panel seams, a cool sheen).

## Silhouette and proportion

* **View:** three-quarters, the body turned 22 degrees toward screen right, the camera 10 degrees above.  The head turns
  a further 14 degrees toward the viewer so the face reads (a pixel-art cheat).  The game mirrors for the other way.
* **Scale:** 64 px sprites; a medium body is 59 px from the soles to the crown, 5.4 heads tall: a slightly heroic head
  for readability, a long enough neck to show collars and jaw hardware.
* **Frames:** each size is a different build, not a scaled copy.

  | | small | medium | large |
  |---|---|---|---|
  | male | wiry netrunner: narrow shoulders, low muscle, a slight forward hunch | the approved athletic build | heavy enforcer: wide shoulders, thick neck, big arms, square jaw |
  | female | petite: narrow, light | athletic: toned, strong shoulders | tall and strong: broad shoulders, muscle |

  Female builds have narrower shoulders, a pinched waist, wider hips and glutes, a bust, a softer jaw and a smaller head.
* **Active stance:** every idle stands ready - feet apart, near foot forward, knees soft, weight slightly forward,
  hands closed.  Weapons: one-handed blades upright in the near fist, two-handed weapons through both fists, pistols at
  low ready muzzle down, rifles across the body (approved directions), tools carried low.
* **Actions read sideways.** Straight ahead points at the viewer and foreshortens to nothing, so every aim, thrust and
  cut drives 45 degrees to the character's left-forward, which the camera shows running toward screen right, and the
  torso turns into it (a shooter's stance).

## Light and shading

* One key light from the upper left front; the head has its own, more frontal fill so faces are never in shadow.
* **Five shades** per material on a hand-built ramp (shade 0 is reserved for lines and deep creases).  Ramps are built
  in OKLab: shadows lean to a cool violet, lights to a warm pale, chroma falls at both ends.  This keeps every skin tone
  readable and gives the cold-lit look.
* **Rim light** (shade 6): the city's cyan back light on the shadow side's edge - the GITS signature.  Never on lit
  edges.
* **Glint** (shade 7) on glossy materials only: hair, leather, metal, plates, prosthetic shell, lenses.
* **Occlusion** darkens real creases (armpits, under the pectorals, between the legs, under a collar), not the round of
  a limb.
* **Anatomy is drawn, not noise.** At this size soft 3D muscle averages into tubes, so the forms come from the solids
  and the definition from a few deliberate marks: pectoral line, sternum, abdominals, iliac line, collarbones (light),
  deltoid split, knee and thigh lines.  Cloth hides them by being an inflated, smoothed copy of the big forms only.

## Line

* A 1 px ink outline outside every layer's silhouette (#0b0c12), so the doll reads on any floor.
* No outline where a layer joins a lower one smoothly (the shoulder growing out of the torso, the neck into the head).
* Inside a layer, a surface passing behind another gets a line in its own darkest shade (a leg behind a leg).
* Held items keep their approved designs and palettes, drawn natively at the angle they are held.

## Colour

* **Danger red is for hostiles only** (the Bratva red coat).  The random generator refuses it on any other archetype.
* Cloth presets are restrained city colours: black, gunmetal, slate, ink navy, olive, drab, khaki, bone, teal, rust,
  oxblood, white, police blue.  Hair has natural tones and four dyes (teal, cyan, violet, wine).
* Implant lights: cyan family by default, amber, teal, violet, white.  Glowing eyes are implants (optics), never natural.
* Layers must separate: an outer layer differs from the one under it by at least 0.07 in OKLab lightness (rule R3).

## Faces

Eyes are three pixels wide, so they are drawn: five shapes (round - the approved anime eye, almond, hooded, wide,
sharp) by six expressions (neutral, focused, angry, pain, surprised, blink).  Brows use the hair colour.  The rig blinks
on its own.  Whites sit at a mid value so they never read as a visor.

## What a doll may not do (enforced by tests and QA)

* show skin through a full suit (Q6); split into islands (Q3); float or sink (Q4); lose its outline (Q5);
  use more than seven shades of one material (Q8); pop between idle frames (Q7);
* wear two tops, two pairs of trousers, two helmets; armour twice on one body area; two implants in one place (R1, R2);
* show the danger red unless hostile (R4); mix human and synthetic skins (R5).
