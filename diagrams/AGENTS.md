# Diagrams

Architecture figures for the README. Each figure is one self-contained HTML
file (inline SVG and CSS, Google Fonts only, no JavaScript) plus two PNG
renders:

| Figure | Source | Renders | Capture size |
|---|---|---|---|
| Ingress over SPIFFE mTLS | `mtls-ingress.html` | `mtls-ingress.png`, `mtls-ingress-dark.png` | 1128x824 |
| Artifact delivery over SPIFFE mTLS | `mtls-artifacts.html` | `mtls-artifacts.png`, `mtls-artifacts-dark.png` | 1128x702 |
| Bootstrap with Terraform | `terraform-bootstrap.html` | `terraform-bootstrap.png`, `terraform-bootstrap-dark.png` | 1128x768 |

The HTML is the source of truth. Edit it, then regenerate both PNGs. The
README embeds the PNGs with `<picture>` and `prefers-color-scheme`, so both
renders must always match the HTML.

To add a figure, copy the existing file closest in shape and replace the
header, `aria-label`, `<desc>` and SVG body.

## Before drawing

- Every box and arrow must map to something in the repo: a manifest under
  `clusters/`, `infrastructure/` or `apps/`, the Terraform in `terraform/`,
  or a check in `scripts/e2e.sh`. Read those first.
- Write the plan down: zones, nodes, the one focal node, arrows with labels,
  and what the budget forces out.
- Budget per figure: 9 nodes, 12 arrows, 3 zones, 1 focal node. Over that,
  split into two figures.
- One node per idea. Fold details into sublabels or compartment rows instead
  of adding boxes. No callouts: a fact that matters becomes a node, a
  sublabel or an arrow label.

## Page structure

- `.frame` capped at 1080px, `body` padding `1.25rem 1.5rem 1rem`, no
  `min-height` or vertical centering.
- Header: eyebrow `ARCHITECTURE` with a `/ fluxoperator.dev` link span, `h1`
  title (Inter 600, 22px), `.subtitle` (Inter 500, 15px, muted, one line).
- `<svg>` has `role="img"`, `aria-label` set to the title, and
  `aria-describedby` pointing at a `<desc>` with the id `<file>-desc`. The
  `<desc>` is one paragraph describing the content, not the geometry. Do not
  add an SVG `<title>`: browsers show it as a tooltip over the whole figure.
- `viewBox` cropped to 16px outside the drawn content on every side. The
  background `<rect>` matches the `viewBox` exactly. CSS `svg { min-width }`
  equals the `viewBox` width.

## Theme

Every colour in the SVG is a CSS variable, so one file renders both themes:
`var(--paper)`, `var(--paper-2)`, `var(--ink)`, `var(--muted)`,
`var(--soft)`, `var(--accent)`, `var(--link)`, and
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

Light tokens live on `:root`. Dark tokens apply under
`:root:has(#theme:checked)` (a CSS-only checkbox toggle, top right, hidden
until hover) and `:root:has(#dark:target)`, so opening `<file>.html#dark`
renders dark without touching the toggle.

## Typography

- Node names: Geist 600, 12px.
- Sublabels, paths, hostnames, ports, SPIFFE IDs: Geist Mono 9px, 8px for
  secondary lines.
- Tag chips and zone labels: Geist Mono 7px, uppercase, tracked.
- Arrow labels: Geist Mono 8px, uppercase, `letter-spacing 0.08em`, 14
  characters max.
- No em dashes, no emoji.

## Node treatments

All boxes are `rx=6`, 1px stroke, drawn as an opaque `var(--paper)` mask
rect followed by the styled rect. A 28x12 tag chip sits 8px inside the
top-left corner and names the technology (`CTRL`, `UI`, `APP`, `GIT`, `OCI`,
`K8S`, `L7`).

| Role | Fill | Stroke | Used for |
|---|---|---|---|
| Focal | `accent-rgb` 0.08 | `accent` | Envoy proxy, source-controller, bootstrap Job |
| Flux component | `paper-2` | `ink` | Flux controllers, Web UI |
| Workload / Kubernetes objects | `ink-rgb` 0.08 | `ink-rgb` 0.25 | podinfo, cluster state |
| External | `ink-rgb` 0.03 | `ink-rgb` 0.30 | Git provider, registries |
| Client / actor | `muted-rgb` 0.10 | `soft` | browser, Terraform |

A node that serves several routes or sources gets compartment rows: a
hairline (`accent-rgb` 0.30 on the focal node, `muted-rgb` 0.30 elsewhere)
under the header, one row per route, each row with its own arrow aligned on
the row's y.

Zones are namespaces: `rx=8`, fill `ink-rgb` 0.02, stroke `ink-rgb` 0.10,
label in `var(--soft)` on a 12px paper mask over the top edge, nodes starting
32px below the zone top.

## Arrows

| Meaning | Stroke |
|---|---|
| Plain HTTP / HTTPS outside the mesh | `var(--link)`, solid, `#arrow-link` marker |
| SPIFFE mTLS | `var(--muted)`, solid, `#arrow` marker |
| Kubernetes API (apply), hand-off to Flux | `var(--muted)`, `stroke-dasharray="4,3"` |

In `terraform-bootstrap`, which shows no network traffic between workloads,
the solid muted arrow means install or reconcile; its legend says so.

- All strokes 1.2px. Straight lines when both ends share x or y; otherwise
  orthogonal elbows with `Q` quarter arcs of r=8. Never diagonal.
- Arrows leave and enter an edge perpendicular to it. Connectors sharing an
  edge get distinct attach points at least 12px apart.
- No arrow passes behind a box that is not one of its endpoints.
- Labels sit on a 12px tall `var(--paper)` mask, 8px above horizontal
  strokes or 8px beside vertical ones. The mask is at least 4px wider than
  the text on each side and must not overlap any node.
- Every legend entry is used in the figure, and every treatment in the
  figure is in the legend. The legend is a horizontal strip below a hairline
  at the bottom.

## Geometry

- Everything on a 4px grid. Nodes are 64px tall (taller only for
  compartment rows or lists), 152px wide, or 176px for focal nodes with
  rows.
- A gap with an arrow label needs room for the mask plus 8px on each side:
  72px for labels up to about 9 characters.
- Paint order: background, zones, arrows, label masks and labels, nodes,
  then node text and icons.

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
