// Read-only raw evidence for one Figma node, run through the remote server's `use_figma`
// (load the `figma-use` skill first). Replace NODE_ID, pass it as the `code` argument, and
// save the returned JSON: `texts` feeds `scripts/text-diff.mjs`.
//
// Returns, for the node and every descendant that carries effects or non-solid fills:
//   effects  - blur type, radius, startRadius and offsets exactly as authored
//   fills    - gradient stops (0-255 rgb + alpha) with the raw gradientTransform, and for image
//              fills the scaleMode, imageTransform, scalingFactor, rotation and filters
// and every text string that is actually visible (a hidden ancestor hides the text too).

const NODE_ID = "0:0";

const round = (value) => (typeof value === "number" ? Math.round(value * 10000) / 10000 : value);

function paint(fill) {
  const out = { type: fill.type, opacity: round(fill.opacity), blendMode: fill.blendMode };
  if (fill.type === "SOLID") {
    out.rgb = [fill.color.r, fill.color.g, fill.color.b].map((c) => Math.round(c * 255));
  }
  if (fill.gradientStops) {
    out.stops = fill.gradientStops.map((stop) => ({
      position: round(stop.position),
      rgba: [stop.color.r, stop.color.g, stop.color.b]
        .map((c) => Math.round(c * 255))
        .concat(round(stop.color.a)),
    }));
    out.gradientTransform = fill.gradientTransform.map((row) => row.map(round));
  }
  if (fill.type === "IMAGE") {
    out.scaleMode = fill.scaleMode;
    if (fill.imageTransform) out.imageTransform = fill.imageTransform.map((row) => row.map(round));
    if (fill.scalingFactor !== undefined) out.scalingFactor = round(fill.scalingFactor);
    if (fill.rotation) out.rotation = fill.rotation;
    if (fill.filters) out.filters = { ...fill.filters };
  }
  return out;
}

function visibleInTree(node, root) {
  for (let current = node; current; current = current.parent) {
    if (current.visible === false) return false;
    if (current === root) return true;
  }
  return true;
}

function evidence(node) {
  const effects = "effects" in node ? node.effects.filter((e) => e.visible !== false) : [];
  const fills =
    "fills" in node && Array.isArray(node.fills)
      ? node.fills.filter((f) => f.visible !== false && f.type !== "SOLID")
      : [];
  if (effects.length === 0 && fills.length === 0) return null;
  return {
    id: node.id,
    name: node.name,
    size: [round(node.width), round(node.height)],
    effects: effects.map((effect) => ({ ...effect })),
    fills: fills.map(paint),
  };
}

const root = await figma.getNodeByIdAsync(NODE_ID);
if (!root) throw new Error(`Node ${NODE_ID} not found`);

const nodes = [root, ...("findAll" in root ? root.findAll(() => true) : [])];
return {
  id: root.id,
  name: root.name,
  type: root.type,
  size: [round(root.width), round(root.height)],
  children: "children" in root ? root.children.length : 0,
  layers: nodes.map(evidence).filter(Boolean),
  texts: ("findAllWithCriteria" in root
    ? root.findAllWithCriteria({ types: ["TEXT"] })
    : root.type === "TEXT"
      ? [root]
      : []
  )
    .filter((text) => visibleInTree(text, root))
    .map((text) => ({ id: text.id, text: text.characters })),
};
