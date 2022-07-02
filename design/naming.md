# Naming

For consistency, here's how Pink's API should be named. This should *largely* guard against the bikeshedding I'm incredibly prone to.

## Procedures

Procedure naming takes the form of:

```odin
pink.subsystem_verb()
pink.subsystem_verb_object()
pink.subsystem_subject_verb_object()
pink.subsystem_subject_subsubject_verb()
```

Specializations of given procedures should be specified with suffixes as they are in the Odin standard library.

If a procedure affects a subsystem's global state (e.g. setting the renderer color) or has no clear subject, we use format #1 or #2. If a procedure acts on a struct closely tied to a subsystem or its primary purpose is creating such a struct, we use format #3.

Examples:
```odin
pink.system_start()
pink.system_consume_object(what: What)

thing := pink.system_thing_create()
pink.system_thing_exec(&thing)
pink.system_thing_member_exec(&thing.member)
```

This pattern can be scaled as far as necessary, although we should stay away from nesting subjects too deeply. Consider a redesign instead.

## Structs

If a subsystem creates and manages multiple types of structs, they should be prefixed with the subsystem's name.

```odin
pink.Render_Buffer
pink.Render_Command
```

If a subsystem exists for the sole purpose of managing a single type of struct, it should share the struct's name.

```odin
pink.Font
```

## Properties

Procedures which retrieve state information **omit** the word "get"--e.g. `pink.window_size()` rather than `pink.window_get_size()`.

```odin
pink.subsystem_property()
pink.subsystem_struct_property(from_struct: ^Subsystem_Struct)
```

We only use "get" when there are significant side effects or an involved procedure to obtaining something. As a quick way of checking, imagine replacing "get" in a procedure name with "fetch." If both names seem appropriate, "get" is deserved. In these cases, however, consider a more precise term--`font_measure_string` rather than `font_get_bounds`

We don't expose state properties to the user except through procedure calls. Use `pink.window_width()` instead of `pink.window_width`.

## Other Notes

If a procedure has multiple versions or specializations, name them according to mental precedence. That is to say, if there are procedures which are **equally valid interpretations of a process**--e.g. a procedure which can be called with either an `f32` or an `f64`--give them both specialized names. If there are procedures which are **extensions or specializations of a basic procedure** (cognitively--implementation doesn't matter), name the basic procedure without specialization and the extensions with specialization.

For example, a procedure named `set_color` may be expected to take a `Color` argument; this seems like the default:
```odin
pink.graphics_set_color(color: pink.Color)
```
Which means convenience methods get named using specialized suffixes:
```odin
pink.graphics_set_color_rgba(r, g, b, a: f32)
pink.graphics_set_color_hsl(h, s, l: f32)
```

On the other hand, if we don't promote radians over degrees (undecided), we'd specialize rotation methods equally:
```odin
pink.transform_rotate_deg(transform: Transform, degrees: f64)
pink.transform_rotate_rad(transform: Transform, radians: f64)
```
