#!/usr/bin/env python3
"""Usage: imported by recompose.py, swing-sim.py and layer-lint.py; not run on its own.

Loads a layer rig (the rig JSON plus every PNG it names, as float arrays), poses it and stacks it.
A part with a "parent" turns about its own pivot, then rides its parent (a clapper in a bell).
A "mask" layer is never drawn; it rides the part it "follows" and only serves as a "clip".
"""

import json
import os
import sys

import cv2
import numpy as np


def load(rig_path, layer_dir=None):
    with open(rig_path) as handle:
        rig = json.load(handle)
    layer_dir = layer_dir or os.path.dirname(os.path.abspath(rig_path))
    width, height = rig["canvas"]
    layers = []
    for spec in rig["layers"]:
        path = os.path.join(layer_dir, spec["file"])
        pixels = cv2.imread(path, cv2.IMREAD_UNCHANGED)
        if pixels is None:
            sys.exit(f"missing layer {path}")
        if pixels.ndim != 3 or pixels.shape[2] != 4:
            sys.exit(f"{spec['file']} has no alpha channel; every layer must be RGBA")
        if pixels.shape[:2] != (height, width):
            sys.exit(f"{spec['file']} is {pixels.shape[1]}x{pixels.shape[0]}, canvas is {width}x{height}")
        layers.append({**spec, "bgr": pixels[..., :3] / 255.0, "alpha": pixels[..., 3] / 255.0})
    names = {layer["name"] for layer in layers}
    for layer in layers:
        for field in ("follows", "clip", "parent"):
            if field in layer and layer[field] not in names:
                sys.exit(f"{layer['name']}.{field} names unknown layer {layer[field]}")
    return rig, layers


def by_name(layers):
    return {layer["name"]: layer for layer in layers}


def _matrix(named, layer, degrees):
    """2x3 affine for a layer: its own turn about its pivot, then its parent's, all the way up."""
    mover = named[layer["follows"]] if "follows" in layer else layer
    matrix = np.vstack([cv2.getRotationMatrix2D((0.0, 0.0), 0, 1.0), [0, 0, 1]])
    while mover is not None:
        angle = degrees * mover.get("swing", 0)
        if angle and "pivot" in mover:
            turn = cv2.getRotationMatrix2D(tuple(map(float, mover["pivot"])), -angle, 1.0)
            matrix = np.vstack([turn, [0, 0, 1]]) @ matrix
        mover = named.get(mover.get("parent"))
    return matrix[:2]


def pose(layers, degrees):
    """Each part rotated about its pivot by degrees * swing, then by its parents; shadows and masks
    ride their part, and a clip uses the clip layer as posed, not as drawn at rest."""
    named = by_name(layers)
    moved = {}
    for layer in layers:
        bgr, alpha = layer["bgr"], layer["alpha"]
        matrix = _matrix(named, layer, degrees)
        if not np.allclose(matrix, [[1, 0, 0], [0, 1, 0]]):
            height, width = alpha.shape
            premultiplied = cv2.warpAffine(bgr * alpha[..., None], matrix, (width, height), flags=cv2.INTER_LINEAR)
            alpha = cv2.warpAffine(alpha, matrix, (width, height), flags=cv2.INTER_LINEAR)
            bgr = premultiplied / np.maximum(alpha, 1e-6)[..., None]
        moved[layer["name"]] = {**layer, "bgr": bgr, "alpha": alpha}
    posed = []
    for layer in layers:
        out = moved[layer["name"]]
        if "clip" in layer:
            out = {**out, "alpha": out["alpha"] * moved[layer["clip"]]["alpha"]}
        posed.append(out)
    return posed


def composite(layers, background=None):
    height, width = layers[0]["alpha"].shape
    out = np.zeros((height, width, 3)) if background is None else np.broadcast_to(background, (height, width, 3)).copy()
    coverage = np.zeros((height, width))
    for layer in (layer for layer in layers if layer.get("role") != "mask"):
        a = layer["alpha"][..., None]
        out = layer["bgr"] * a + out * (1 - a)
        coverage = layer["alpha"] + coverage * (1 - layer["alpha"])
    return out, coverage
