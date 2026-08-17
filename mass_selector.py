#!/usr/bin/env python3
"""Brux-identical stratified BB/CC mass selector for the 2024 production."""

from pathlib import Path
import sys

N_MASS_POINTS = 311
MIN_MASS = 40
MAX_MASS = 350
ANCHOR_START = 25
ANCHOR_STEP = 10
EXTRAPOLATION_START = 245

if len(sys.argv) != 2:
    raise SystemExit("usage: mass_selector.py PROCESS")

process = int(sys.argv[1])
effective_job = process % N_MASS_POINTS
rows = []
with Path(__file__).with_name("mass_weights_2024.tsv").open(encoding="ascii") as table:
    for line in table:
        if line.startswith("#") or not line.strip():
            continue
        mass, bb, cc = line.split()
        rows.append((int(mass), float(bb), float(cc)))

if len(rows) != 23 or [row[0] for row in rows] != list(range(25, 246, 10)):
    raise SystemExit("mass_weights_2024.tsv does not match the Brux anchor table")

bb_anchors = [row[1] for row in rows]
cc_anchors = [row[2] for row in rows]

def brux_weight(anchors, mass):
    if mass >= EXTRAPOLATION_START:
        t = (mass - EXTRAPOLATION_START) / 10.0
        return anchors[-1] + t * (anchors[-1] - anchors[-2])
    i = (mass - ANCHOR_START) // ANCHOR_STEP + 1
    t = (mass - (ANCHOR_START + ANCHOR_STEP * (i - 1))) / 10.0
    return anchors[i - 1] + t * (anchors[i] - anchors[i - 1])

bb_weights = [brux_weight(bb_anchors, mass) for mass in range(MIN_MASS, MAX_MASS + 1)]
cc_weights = [brux_weight(cc_anchors, mass) for mass in range(MIN_MASS, MAX_MASS + 1)]
bb_total = sum(bb_weights)
cc_total = sum(cc_weights)

def stratified_mass(weights):
    target = (effective_job + 0.5) * sum(weights) / N_MASS_POINTS
    cumulative = 0.0
    for mass, weight in zip(range(MIN_MASS, MAX_MASS + 1), weights):
        cumulative += weight
        if target <= cumulative:
            return int(mass + 0.5)
    raise RuntimeError("mass selector failed to reach the CDF target")

print(stratified_mass(bb_weights), stratified_mass(cc_weights))
