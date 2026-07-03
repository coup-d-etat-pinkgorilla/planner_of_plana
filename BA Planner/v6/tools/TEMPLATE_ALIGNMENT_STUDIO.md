# Template Alignment Studio

Run from the project root:

```powershell
python -m tools.template_alignment_studio
```

Open an existing project directly:

```powershell
python -m tools.template_alignment_studio "debug/260622/template_alignment.json"
```

## Layers & text

- **Add image** adds backgrounds, icons, and other PNG layers.
- **Add text** creates a real rendered text layer.
- Text controls include content, TTF/OTF/TTC file, font size, fill color,
  outline width/color, and horizontal shear.
- Drag the selected layer, use arrow keys for 1-pixel movement, or
  Shift+arrow for 10-pixel movement.
- Use **Copy** to duplicate the selected layer with a unique name and a small
  offset.
- Width and height define the text layer canvas and clipping area.

## Named ROIs

- Open the **Named ROIs** tab and create as many regions as needed.
- Give each region a stable matcher name such as `equipment_icon`,
  `equipment_level_text`, `favorite_t1_marker`, or `favorite_t2_marker`.
- ROI rectangles and parallelograms can be dragged directly on the canvas.
  X/Y/width/height and slant fields provide exact pixel adjustment.
- Use **Copy** to duplicate the selected ROI with a unique name and a small
  offset.
- Export creates separate reference, virtual-template, and overlay-preview
  PNGs for every enabled named ROI.

The studio reads projects created by the first alignment tool. Saving from the
studio adds text-layer and named-ROI data while retaining a legacy primary ROI.
