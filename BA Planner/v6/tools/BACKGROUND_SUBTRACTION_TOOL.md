# ROI Background/Subtraction Preview Tool

This is a new standalone helper for the existing `tools` package. It does not
modify the previous alignment GUI or studio files.

## Install location

Copy this file into your project:

```text
tools/template_background_subtractor.py
```

## Run

```powershell
python -m tools.template_background_subtractor
```

Open an existing Template Alignment Studio project directly:

```powershell
python -m tools.template_background_subtractor "debug/260622/template_alignment.json"
```

Use a reference/background screenshot and an external source image directly:

```powershell
python -m tools.template_background_subtractor --reference "screenshot.png" --source "digit_or_icon.png"
```

## What it does

- Loads a Studio/legacy alignment project JSON.
- Reads the reference/background image.
- Lets you choose a named ROI or manually edit the area.
- Lets you subtract one of these sources:
  - all visible project virtual layers,
  - one selected project layer,
  - an external image pasted into the ROI.
- Shows the subtraction result live in the right preview pane.
- Lets you tune source traits before subtraction:
  - offset X/Y,
  - width/height,
  - alpha strength,
  - RGB gain,
  - RGB bias,
  - gamma,
  - blur,
  - alpha threshold,
  - alpha-weighted subtraction.
- Lets you limit subtraction to pixels near a target reference color. In this version it is deliberately visible in two places:
  - a top toolbar checkbox: `Color filter #2D4663`,
  - the top of the right panel: `COLOR FILTER / subtraction mask`,
  - set a hex color such as `#2D4663`,
  - tune `Tolerance %`,
  - optionally use `Feather px` to soften the mask.
- Exports current ROI previews and a JSON snapshot of the controls.

## Reference color filter

The color filter is useful when the source image lies under text or numbers.
Without the filter, subtracting an icon can also subtract the icon color from
under the text strokes, which may distort the remaining text residual.

When enabled, the tool checks the **reference ROI pixels** and keeps the source
alpha only where the reference color is close to the target color. For example,
with target `#2D4663`, source subtraction is applied only around pixels whose
reference RGB is within the selected tolerance from that color.

The tolerance is calculated as a percentage of the maximum RGB Euclidean color
distance. A tolerance of `8` means roughly 8% of the full RGB color cube distance.

Suggested workflow:

1. Set preview to `Adjusted source only` or `Source alpha/mask`.
2. Enable the top toolbar `Color filter #2D4663` checkbox, or the right-panel `Enable color filter: subtract only where reference is near target color` checkbox.
3. Enter the target color, for example `#2D4663`.
4. Raise `Tolerance %` until the intended background/icon region remains.
5. Keep the tolerance low enough that text/number strokes are excluded.
6. Use `Feather px` only if the mask edge is too harsh.

## Preview modes

- `Residual: abs(reference - source)`
- `Residual: signed centered at 128`
- `Residual: positive only`
- `Residual: negative only`
- `Cleaned/reference minus source`
- `Adjusted source only`
- `Reference ROI only`
- `Source alpha/mask`
- `Reference + adjusted source overlay`

## Suggested workflow

1. Open the `.json` project from Template Alignment Studio.
2. Choose the ROI that contains the number/icon you are trying to remove.
3. Choose `Project layer: selected layer only` if you want to tune one layer.
4. Use `Offset X/Y`, `Width/Height`, `Alpha %`, `RGB gain %`, `RGB bias`, and `Gamma` until the residual becomes visually small.
5. If text or numbers sit above the source image, enable the reference color filter and tune the target color/tolerance.
6. Use `Mean abs` and `Max abs` as rough numerical feedback.
7. Export the preview when you find a good setting.


## Troubleshooting

If the reference color filter controls are not visible, you are probably still running an older local copy. The current window title must include `color filter visible v2`, and the toolbar must show `Color filter #2D4663`. Verify the loaded module with:

```powershell
python -c "import tools.template_background_subtractor as t; print(t.__file__); print('color filter visible v2' in open(t.__file__, encoding='utf-8').read())"
```

The second printed value should be `True`. If it is `False`, overwrite the file shown by the first printed path with the updated `template_background_subtractor.py`.
