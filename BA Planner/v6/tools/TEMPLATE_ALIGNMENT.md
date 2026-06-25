# Template Layer & ROI Aligner

Run from the project root:

```powershell
python -m tools.template_alignment_gui
```

Optional startup files:

```powershell
python -m tools.template_alignment_gui --reference "screenshot.png" --layer "templates/icons/temp/square.png" --layer "icon.png"
```

## Workflow

1. Select **Reference** to load the real screenshot.
2. Add `square.png`, an item icon, or any other virtual-template inputs as independent layers.
3. Select a layer and drag it, or use the X/Y controls. Arrow keys move the selected layer by 1 pixel; Shift+arrow moves it by 10 pixels.
4. Adjust layer size, opacity, visibility, and order. Mouse wheel zooms; at high zoom a one-pixel grid appears.
5. Enter the ROI X/Y/width/height in screenshot pixels. The red rectangle is the exported matcher area.
6. Hold **Hold to hide layers (blink)** to compare the reference and virtual layers quickly.
7. Save the project JSON to resume later, or select **Export ROI**.

Export produces:

- `reference_roi.png`: real screenshot ROI
- `virtual_template_roi.png`: synthetic layers only
- `overlay_preview_roi.png`: visual alignment preview
- `virtual_template_full.png`: synthetic full canvas
- `alignment.json`: exact layer and ROI coordinates

Set layer opacity to 100 before exporting a production template. Lower opacity is useful while aligning.
