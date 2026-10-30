# Diagrams

Architecture figures for the README. Each figure is one self-contained HTML
file (inline SVG and CSS, Google Fonts only, no JavaScript) plus two PNG
renders:

| Figure | Source | Renders | Capture size |
|---|---|---|---|
| Bootstrap with Terraform | `terraform-bootstrap.html` | `terraform-bootstrap.png`, `terraform-bootstrap-dark.png` | 1128x578 |
| Ingress over SPIFFE mTLS | `mtls-ingress.html` | `mtls-ingress.png`, `mtls-ingress-dark.png` | 1128x469 |
| Artifacts and events over SPIFFE mTLS | `mtls-artifacts.html` | `mtls-artifacts.png`, `mtls-artifacts-dark.png` | 1128x578 |
| Apps and tenancy | `apps-tenancy.html` | `apps-tenancy.png`, `apps-tenancy-dark.png` | 1128x578 |

The HTML is the source of truth. Edit it, then regenerate both PNGs. The
README embeds the PNGs with `<picture>` and `prefers-color-scheme`, so both
renders must always match the HTML.

To add a figure, copy the existing file closest in shape and replace the
title, `aria-label`, `<desc>` and SVG body.

## Before drawing

- Readers are Flux users. Each figure answers one question (how is it
  bootstrapped, what does ingress look like, which mTLS checks do the
  controllers enforce) and drops everything that does not help answer it.
- Every box and arrow must map to something in the repo: a manifest under
  `clusters/`, `infrastructure/` or `apps/`, the Terraform in `terraform/`,
  or a check in `scripts/e2e.sh`. Read those first.
- Write the plan down: nodes, the one focal node, arrows, and what the budget
  forces out.
- Budget per figure: 8 nodes, 12 arrows, 1 focal node. Over that, split into
  two figures.
- One node per idea, one sublabel per node. The sublabel carries the fact a
  Flux user needs: the Flux kind a controller reconciles, the route, the
  SPIFFE ID. No callouts, no tag chips, no icons, no compartment rows, no
  namespace zones.

## Page structure

- `.frame` capped at 1080px, `body` padding `1.25rem 1.5rem 1rem`, no
  `min-height` or vertical centering.
- Header: one `h1` (Inter 600, 22px) that states the takeaway, for example
  "Envoy Gateway routes HTTP to Flux and apps over SPIFFE mTLS". No eyebrow, no subtitle.
- `<svg>` has `role="img"`, `aria-label` set to the title, and
  `aria-describedby` pointing at a `<desc>` with the id `<file>-desc`. The
  `<desc>` is one paragraph describing the content, not the geometry. Do not
  add an SVG `<title>`: browsers show it as a tooltip over the whole figure.
- Every figure uses `viewBox` x `16`, width `952`, so text renders at the
  same size in all of them. The background `<rect>` matches the `viewBox`
  exactly. CSS `svg { min-width }` is `952px`.

## Theme

Every colour in the SVG is a CSS variable, so one file renders both themes:
`var(--paper)`, `var(--paper-2)`, `var(--ink)`, `var(--muted)`,
`var(--soft)`, `var(--accent)`, `var(--link)`, `var(--mtls)`, and
`rgba(var(--ink-rgb), a)`, `rgba(var(--muted-rgb), a)`,
`rgba(var(--accent-rgb), a)` for tints.

| Token | Light | Dark |
|---|---|---|
| paper | `#f5f5f5` | `#2d3142` |
| paper-2 | `#ffffff` | `#393e53` |
| ink | `#2d3142` | `#f5f5f5` |
| muted | `#4f5d75` | `#bfc0c0` |
| soft | `#7a8399` | `#8e98ac` |
| accent | `#eb6c36` | `#f08a59` |
| link | `#2e5aa8` | `#6a95d8` |
| mtls | `#7646c4` | `#b394ea` |

Light tokens live on `:root`. Dark tokens apply under
`:root:has(#theme:checked)` (a CSS-only checkbox toggle, top right, hidden
until hover) and `:root:has(#dark:target)`, so opening `<file>.html#dark`
renders dark without touching the toggle.

## Typography

- Node names: Geist 600, 12px.
- Sublabels: Geist Mono 9px.
- Arrow labels: Geist Mono 8px, uppercase, `letter-spacing 0.08em`, 14
  characters max. Prefer none: label an arrow only when the legend and the
  node names do not already say what flows.
- No em dashes, no emoji.

## Node treatments

All boxes are `rx=6`, 1px stroke, drawn as an opaque `var(--paper)` mask
rect followed by the styled rect. Name and sublabel are centred.

| Role | Fill | Stroke |
|---|---|---|
| Focal (one per figure) | `accent-rgb` 0.08 | `accent` |
| Flux component | `paper-2` | `ink` |
| Everything else | `ink-rgb` 0.06 | `ink-rgb` 0.28 |

## Arrows

| Meaning | Stroke |
|---|---|
| HTTP or HTTPS outside the mesh | `var(--link)`, solid, `#arrow-link` marker |
| SPIFFE mTLS | `var(--mtls)`, solid, `#arrow-mtls` marker |
| Install and reconcile in `terraform-bootstrap` | `var(--muted)`, solid, `#arrow` marker |
| Kubernetes API, or hand-off to Flux in `terraform-bootstrap` | `var(--muted)`, `stroke-dasharray="4,3"` |

- All strokes 1.2px. Straight lines when both ends share x or y; otherwise
  orthogonal elbows with `Q` quarter arcs of r=8. Never diagonal.
- Arrows leave and enter an edge perpendicular to it. Connectors sharing an
  edge get distinct attach points at least 12px apart.
- One node fanning out to several (or several into one) uses a bus: the
  arrows share a trunk and a vertical segment midway between the columns,
  with one label beside the bus.
- No arrow passes behind a box that is not one of its endpoints.
- Labels sit on a 12px tall `var(--paper)` mask, 8px above horizontal
  strokes or 8px beside vertical ones. The mask is at least 4px wider than
  the text on each side and must not overlap any node.
- The legend is one row below a hairline at the bottom, no heading: the
  arrow styles used in the figure plus a "Flux component" box.

## Geometry

- Everything on a 4px grid. Nodes are 152x64 (176 wide when the name needs
  it); a focal node may span rows.
- Columns at x 32, 288, 544, 800 and rows at y 32, 128, 224, 320, so the
  gaps are 104px across and 32px down. Shift a column by a multiple of 8
  when a figure needs a wider node. A figure that needs fewer columns centres
  them in the shared width.
- Paint order: background, arrows, label masks and labels, nodes, node text,
  legend.

## Render

Use Chrome (for example via the Chrome DevTools MCP) with a 2x device scale
factor.

1. Open `file://<repo>/diagrams/<name>.html` and set the viewport to
   `1128x<height>x2`.
2. Wait for fonts, hide the toggle and measure:

   ```js
   async () => {
     await document.fonts.ready;
     document.querySelector('.theme-toggle').style.display = 'none';
     return {
       height: Math.round(document.querySelector('.frame').getBoundingClientRect().bottom + 16),
       scrollWidth: document.documentElement.scrollWidth,
     };
   }
   ```

   Set the viewport height to `height`. `scrollWidth` must be 1128.
3. Screenshot the viewport to `<name>.png`.
4. Navigate to `<name>.html#dark`, run the same script, and screenshot to
   `<name>-dark.png`.

Hide the toggle on every load: it appears when the mouse is over the window.

## Verify

Run in the page before capturing:

```js
() => {
  const svg = document.querySelector('svg');
  const boxes = [...svg.querySelectorAll('rect[stroke-width="1"]')]
    .filter(r => +r.getAttribute('height') >= 64)
    .map(r => ({ x: +r.getAttribute('x'), y: +r.getAttribute('y'),
                 w: +r.getAttribute('width'), h: +r.getAttribute('height') }));
  const overflow = [];
  for (const t of svg.querySelectorAll('text')) {
    const b = t.getBBox();
    const box = boxes.find(r => b.x >= r.x - 1 && b.x <= r.x + r.w && b.y >= r.y - 2 && b.y <= r.y + r.h);
    if (box && (b.x < box.x + 4 || b.x + b.width > box.x + box.w - 4)) overflow.push(t.textContent);
  }
  const tightMasks = [...svg.querySelectorAll('rect[height="12"]')]
    .filter(r => r.nextElementSibling?.tagName === 'text')
    .filter(r => r.nextElementSibling.getBBox().width > +r.getAttribute('width') - 4)
    .map(r => r.nextElementSibling.textContent);
  return { overflow, tightMasks };
}
```

Both lists must be empty. Then look at both PNGs: text fit, arrow routing,
label masks, the toggle not visible, and the dark render actually dark.

Commit the HTML and both PNGs together.
