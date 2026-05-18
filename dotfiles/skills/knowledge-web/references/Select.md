# Select, Option, Optgroup, and Datalist

> https://blog.frankmtaylor.com/2026/05/13/you-dont-know-html-lists/

Use `<select>` + `<option>` when the user must choose from a **fixed** list. Use `<input>` + `<datalist>` when the list is a **suggestion** and the user can type their own value.

## Basic `<select>` with `<option>`

Single selection dropdown. The first option is typically a placeholder with an empty value.

```html
<select name="languages">
  <option value="">Select a Language</option>
  <option value="en">English</option>
  <option value="fr">French</option>
  <option value="es">Spanish</option>
  <option value="pt">Portuguese</option>
</select>
```

## Multiple Selection with `multiple` attribute

Adding `multiple` makes all options visible at once. Users can hold `shift` or `cmd`/`ctrl` and click to select several. No need to add `aria-multiselectable` — native semantics handle it.

```html
<select name="languages" multiple>
  <option value="">Select a Language</option>
  <option value="en">English</option>
  <option value="fr">French</option>
  <option value="es">Spanish</option>
  <option value="pt">Portuguese</option>
  <option value="en">Irish</option>
  <option value="cy">Welsh</option>
</select>
```

## Grouping Options with `<optgroup>`

Use `<optgroup label="...">` to visually group related options under a labelled heading.

```html
<select name="languages">
  <optgroup label="Germanic">
    <option value="en">English</option>
  </optgroup>
  <optgroup label="Romance">
    <option value="fr">French</option>
    <option value="es">Spanish</option>
    <option value="pt">Portuguese</option>
  </optgroup>
  <optgroup label="Celtic">
    <option value="en">Irish</option>
    <option value="cy">Welsh</option>
  </optgroup>
</select>
```

## Disabling an `<optgroup>`

Add `disabled` to an `<optgroup>` to make all its options unselectable while still showing them.

```html
<select name="languages">
  <optgroup label="Germanic">
    <option value="en">English</option>
  </optgroup>
  <optgroup label="Romance">
    <option value="fr">French</option>
    <option value="es">Spanish</option>
    <option value="pt">Portuguese</option>
  </optgroup>
  <optgroup label="Celtic" disabled>
    <option value="en">Irish</option>
    <option value="cy">Welsh</option>
  </optgroup>
</select>
```

## Visual Separator with `<hr>` and Controlling Visible Rows with `size`

`<hr>` is valid inside `<select>` and adds a visual divider between groups. The `size` attribute controls how many rows are visible at once. Note: `<optgroup>` labels count towards the `size`, so more rows may be needed than expected.

```html
<select name="languages" size="4" multiple>
  <optgroup label="Germanic">
    <option value="en">English</option>
  </optgroup>
  <hr />
  <optgroup label="Romance">
    <option value="fr">French</option>
    <option value="es">Spanish</option>
    <option value="pt">Portuguese</option>
  </optgroup>
  <hr />
  <optgroup label="Celtic">
    <option value="en">Irish</option>
    <option value="cy">Welsh</option>
  </optgroup>
  <hr />
  <optgroup label="Afroasiatic">
    <option value="he">Hebrew</option>
    <option value="ar">Arabic</option>
  </optgroup>
</select>
```

## `<datalist>` for Suggested (Non-Fixed) Lists

A `<datalist>` suggests options but the user can still type any value. Two steps: give the `<datalist>` an `id`, then set the `<input>`'s `list` attribute to that `id`.

**Do not add a `value` attribute to `<option>` inside a `<datalist>`** — if `value` differs from the text, the user sees the text in the dropdown but the `value` gets inserted into the input when they select it, which is confusing.

```html
<datalist id="languages">
  <option>English</option>
  <option>French</option>
  <option>Spanish</option>
  <option>Portuguese</option>
  <option>Irish</option>
  <option>Welsh</option>
  <option>Hebrew</option>
  <option>Arabic</option>
</datalist>

<input name="language" list="languages">
```

## `<datalist>` with Non-Text Inputs (e.g. `type="week"`)

`<datalist>` works with any input type, not just text. Here it suggests preferred weeks for a week-picker input.

```html
<label for="camp-week">Choose a week</label>

<input
  type="week"
  name="week"
  id="camp-week"
  min="2026-W2"
  max="2026-W51"
  list="preferred-weeks"
/>

<datalist id="preferred-weeks">
  <option>2026-W22</option>
  <option>2026-W23</option>
  <option>2026-W24</option>
  <option>2026-W25</option>
</datalist>
```

## `<datalist>` with `<input type="range">` for Labeled Tick Marks

Pair `<datalist>` with a range input to create labeled stops. Browser support differs: Chrome supports the programmatic CSS approach using `attr()` with a type cast; Firefox requires manual per-value rulesets targeting `::before`.

```html
<div class="rangeField">
  <label for="tips">Tip Percentage</label>

  <input
    type="range"
    name="tips"
    id="tips"
    min="0"
    max="50"
    step="1"
    list="recommended-tips"
  />

  <datalist id="recommended-tips">
    <option value="10" label="10%"></option>
    <option value="18" label="18%"></option>
    <option value="30" label="30%"></option>
    <option value="45" label="45%"></option>
  </datalist>
</div>
```

Base CSS — same width for input and datalist, datalist displayed with vertical writing mode:

```css
.rangeField {
  /* ch is the width of the 0 in computed font — precise for numbers */
  width: 50ch;
}

#recommended-tips,
#tips {
  width: 100%;
  margin: 0;
  padding: 0;
}

#recommended-tips {
  position: relative;
  display: block;
  writing-mode: vertical-lr;
}
```

Chrome / modern browsers — use `attr()` with a type cast to position tick labels programmatically. Max is 50 not 100, so multiply percent by ~1.9:

```css
@supports (x: attr(x type(percentage))) {
  #recommended-tips option {
    --percent: attr(label type(<percentage>));
    position: absolute;
    left: calc((var(--percent) * 1.9) - .1ch);
  }
}
```

Firefox fallback — labels render via `::before`, positions must be set per-value manually using `ch` and `ex` units:

```css
@supports not (x: attr(x type(percentage))) {
  #recommended-tips option {
    height: 1ch;
    margin: 0;
    padding: 0;
  }
  #recommended-tips option::before {
    position: absolute;
    top: .5ex;
  }

  #recommended-tips option[value="10"]::before {
    left: calc(5ch + 2ex);
  }
  #recommended-tips option[value="18"]::before {
    left: calc(9ch + 2.5ex);
  }
  #recommended-tips option[value="30"]::before {
    left: calc(15ch + 4ex);
  }
  #recommended-tips option[value="45"]::before {
    left: calc(22.5ch + 6.5ex);
  }
}
```
