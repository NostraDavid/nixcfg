---
name: webdesign
description: Design website UIs with generated image mockups, then implement and visually compare when requested. Use for new site designs or visual redesigns. Exclude isolated assets, backend work, and small UI fixes.
---

# Website design from generated images

Use an actual generated website screenshot to establish the visual direction.
For implementation requests, translate that direction into a working interface
and compare the browser result with the concept.

## Establish the brief

Read the relevant page, existing components, brand assets, and supplied
references. Identify the audience, primary action, required content, and target
viewport. Preserve the existing design system when the request requires it.
State useful assumptions; ask only when a missing choice prevents a useful
concept.

Check which image-generation tool the current agent exposes. In VS Code, use the
active agent's image capability and its actual tool contract. In Codex, prefer
the built-in `image_gen` tool and follow the `imagegen` skill when available.
The native route does not require the user's API key.

If image generation is unavailable, state that limitation and prepare the image
prompt or use supplied visual references. Only switch to an external API
workflow when the user explicitly chooses it. Keep generated-image claims
limited to images actually returned by a tool.

## Generate the visual target

Start with one coherent concept at the relevant viewport. Generate alternatives
when they resolve a material design choice or the user requests them. Describe
the website itself as a flat, front-facing screenshot, with enough real content
to judge its hierarchy. Use this prompt structure when helpful:

```text
Website and audience: purpose, users, and primary action.
Screen: page, viewport, and visible sections.
Visual direction: typography, palette, spacing, and distinguishing composition.
Content: required navigation, short exact labels, and realistic information.
References: the role of each supplied image and what must remain recognizable.
Output: a website UI screenshot, with no device frame or perspective effects.
```

Inspect the returned image before treating it as the target. Check information
hierarchy, readability, required content, and the prominence of the primary
action. Refine the largest mismatch with a targeted image edit when needed.
Inspect local reference images before editing them and preserve stated
invariants.

Show the actual concept. Keep a project-bound reference in the workspace when
the tool supplies a file; use the returned artifact or image reference
otherwise. Use the real returned location rather than inventing an output path.
Record the few design decisions needed to reproduce the result, such as type
hierarchy, colors, spacing, and layout. The brief remains authoritative when
generated text is distorted or invented.

## Translate the concept when implementation is requested

A design-only request ends with the concept and its design decisions. When
implementation is already authorized, choose the concept that best satisfies the
brief and continue without adding an approval gate.

Use the project's stack, components, and delivery workflow. Recreate the layout
with real text, semantic elements, working controls, and responsive styles. The
generated screenshot is a design reference, not a full-page background with
invisible controls over it. Reuse existing assets; generate separate photos or
illustrations when the implementation actually needs them.

Map the concept's hierarchy and composition to desktop and narrow layouts.
Preserve navigation and the primary action as content reflows. Check focus,
labels, contrast, and the states needed by the implemented interactions.

## Compare the working result

Run the page and capture browser screenshots at the concept's viewport and a
narrow viewport. Inspect the rendered images alongside the concept. Correct the
largest differences in composition, typography, spacing, color, and image
placement, then verify the primary interaction.

Deliver the concept and, for implementation work, the working page plus its
verification screenshots. State intentional differences and any browser or
image-generation step that could not be performed. Code checks alone do not
establish visual agreement with the generated target.
