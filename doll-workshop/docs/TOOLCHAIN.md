# Toolchain

## Pinned versions

| tool | version | used for |
|---|---|---|
| Godot | **4.5.2-stable**, standard build (`Godot_v4.5.2-stable_linux.x86_64.zip`, SHA-512 `e3ce6194...aacbe5a8d`) | the workshop, the runtime, the tests |
| Renderer | Compatibility (OpenGL 3.3 / GLES 3) | everything 2D; the palette shader uses only basic texture reads |
| Python | 3.10 or newer (built and tested on 3.13) with numpy, scipy, Pillow | the generator |
| C compiler | any `cc` (gcc 13 used) | `tools/dollgen/sdfcore.c`, built on first use |

No dependencies on Blender, Steam, a web server or any AI service.  The generator runs offline; the runtime has no
dependencies beyond Godot.

## Why GDScript, not C# / .NET, in this build

The brief asked for Godot .NET 4.5.2 with C# / .NET 8.  The workspace this set was built in can download Godot's .NET
build, but cannot reach Microsoft's .NET servers or NuGet, so the .NET 8 SDK could not be installed and no C# could be
compiled or run, let alone tested.  Shipping untested C# would contradict the brief's "reliable tools, proven quality".
Trilobit itself is GDScript on Godot 4.3, and a standard Godot build cannot call C#, so a C# runtime would also only
reach the game after the game moved to .NET.

So the runtime is GDScript, fully tested here on Godot 4.5.2 (standard) and written to run on the game's 4.3.  The
interface is data, not code: the baked atlases and `dolls.json` are language-neutral, and the runtime is small
(`compose()` is about 40 lines; the palette port about 150).  A C# port reads the same files; the tests that pin the
behaviour (palette values, composition order, pixel fidelity) carry over as acceptance tests.

To move to .NET later: Godot .NET 4.5.2 (`Godot_v4.5.2-stable_mono_linux_x86_64.zip`, SHA-512 `5abc52f0...68316a98`)
with the .NET 8 SDK (8.0.4xx); port `doll_library.gd`, `doll_palette.gd`, `doll_spec.gd`, `doll_rig.gd` and
`doll_generator.gd` one to one; keep `palette.gdshader` as is.

## Running

```sh
python3 tools/dollgen/bake.py ../godot-spike/data/items.json dolls --jobs 2      # full bake (64 px)
python3 tools/dollgen/bake.py ../godot-spike/data/items.json dolls32 --jobs 2 --lod 32   # the 32 px world set
python3 tools/dollgen/bake.py ../godot-spike/data/items.json dolls --palette-only  # colour presets only (seconds)
python3 tools/dollgen/qa.py dolls                                                # quality checks on the bake
godot --headless --path . --import                                               # import the pages
godot --headless --path . -s tests/run_tests.gd [-- res://dolls32]               # data and runtime
python3 tools/dollgen/expect.py ../godot-spike/data/items.json tests/expected_64 64   # reference images
xvfb-run godot --path . --rendering-driver opengl3 -s tests/render_check.gd -- res://dolls res://tests/expected_64   # pixel fidelity
xvfb-run godot --path . --rendering-driver opengl3 -s tests/render_samples.gd -- OUT   # review sheets
bash run_all.sh                                                                  # all of the above after a bake
```
