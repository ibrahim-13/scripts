# Research

## Get caret position

### Get caret position in text index

```js
function getCursorPos(input) {
    if ("selectionStart" in input && document.activeElement == input) {
        return {
            start: input.selectionStart,
            end: input.selectionEnd
        };
    }
    return -1;
}
```

Example usage:

```js
var cursorPosition = getCursorPos(document.getElementById("text-area-id"))
```

## Set caret position in text index

```js
function setCursorPos(input, start, end) {
    if (arguments.length < 3) end = start;
    if ("selectionStart" in input) {
        setTimeout(function() {
            input.selectionStart = start;
            input.selectionEnd = end;
        }, 1);
    }
}
```

### Get x-axis and y-axis position of caret in textarea

> The code below is a UMD module which sets the `window.getCaretCoordinates` for global access to the function.

The module below works independently, create necessary nodes or elements automatically.

```js
(function () {

// We'll copy the properties below into the mirror div.
// Note that some browsers, such as Firefox, do not concatenate properties
// into their shorthand (e.g. padding-top, padding-bottom etc. -> padding),
// so we have to list every single property explicitly.
var properties = [
  'direction',  // RTL support
  'boxSizing',
  'width',  // on Chrome and IE, exclude the scrollbar, so the mirror div wraps exactly as the textarea does
  'height',
  'overflowX',
  'overflowY',  // copy the scrollbar for IE

  'borderTopWidth',
  'borderRightWidth',
  'borderBottomWidth',
  'borderLeftWidth',
  'borderStyle',

  'paddingTop',
  'paddingRight',
  'paddingBottom',
  'paddingLeft',

  // https://developer.mozilla.org/en-US/docs/Web/CSS/font
  'fontStyle',
  'fontVariant',
  'fontWeight',
  'fontStretch',
  'fontSize',
  'fontSizeAdjust',
  'lineHeight',
  'fontFamily',

  'textAlign',
  'textTransform',
  'textIndent',
  'textDecoration',  // might not make a difference, but better be safe

  'letterSpacing',
  'wordSpacing',

  'tabSize',
  'MozTabSize'

];

var isBrowser = (typeof window !== 'undefined');
var isFirefox = (isBrowser && window.mozInnerScreenX != null);

function getCaretCoordinates(element, position, options) {
  if (!isBrowser) {
    throw new Error('textarea-caret-position#getCaretCoordinates should only be called in a browser');
  }

  var debug = options && options.debug || false;
  if (debug) {
    var el = document.querySelector('#input-textarea-caret-position-mirror-div');
    if (el) el.parentNode.removeChild(el);
  }

  // The mirror div will replicate the textarea's style
  var div = document.createElement('div');
  div.id = 'input-textarea-caret-position-mirror-div';
  document.body.appendChild(div);

  var style = div.style;
  var computed = window.getComputedStyle ? window.getComputedStyle(element) : element.currentStyle;  // currentStyle for IE < 9
  var isInput = element.nodeName === 'INPUT';

  // Default textarea styles
  style.whiteSpace = 'pre-wrap';
  if (!isInput)
    style.wordWrap = 'break-word';  // only for textarea-s

  // Position off-screen
  style.position = 'absolute';  // required to return coordinates properly
  if (!debug)
    style.visibility = 'hidden';  // not 'display: none' because we want rendering

  // Transfer the element's properties to the div
  properties.forEach(function (prop) {
    if (isInput && prop === 'lineHeight') {
      // Special case for <input>s because text is rendered centered and line height may be != height
      if (computed.boxSizing === "border-box") {
        var height = parseInt(computed.height);
        var outerHeight =
          parseInt(computed.paddingTop) +
          parseInt(computed.paddingBottom) +
          parseInt(computed.borderTopWidth) +
          parseInt(computed.borderBottomWidth);
        var targetHeight = outerHeight + parseInt(computed.lineHeight);
        if (height > targetHeight) {
          style.lineHeight = height - outerHeight + "px";
        } else if (height === targetHeight) {
          style.lineHeight = computed.lineHeight;
        } else {
          style.lineHeight = 0;
        }
      } else {
        style.lineHeight = computed.height;
      }
    } else {
      style[prop] = computed[prop];
    }
  });

  if (isFirefox) {
    // Firefox lies about the overflow property for textareas: https://bugzilla.mozilla.org/show_bug.cgi?id=984275
    if (element.scrollHeight > parseInt(computed.height))
      style.overflowY = 'scroll';
  } else {
    style.overflow = 'hidden';  // for Chrome to not render a scrollbar; IE keeps overflowY = 'scroll'
  }

  div.textContent = element.value.substring(0, position);
  // The second special handling for input type="text" vs textarea:
  // spaces need to be replaced with non-breaking spaces - http://stackoverflow.com/a/13402035/1269037
  if (isInput)
    div.textContent = div.textContent.replace(/\s/g, '\u00a0');

  var span = document.createElement('span');
  // Wrapping must be replicated *exactly*, including when a long word gets
  // onto the next line, with whitespace at the end of the line before (#7).
  // The  *only* reliable way to do that is to copy the *entire* rest of the
  // textarea's content into the <span> created at the caret position.
  // For inputs, just '.' would be enough, but no need to bother.
  span.textContent = element.value.substring(position) || '.';  // || because a completely empty faux span doesn't render at all
  div.appendChild(span);

  var coordinates = {
    top: span.offsetTop + parseInt(computed['borderTopWidth']),
    left: span.offsetLeft + parseInt(computed['borderLeftWidth']),
    height: parseInt(computed['lineHeight'])
  };

  if (debug) {
    span.style.backgroundColor = '#aaa';
  } else {
    document.body.removeChild(div);
  }

  return coordinates;
}

if (typeof module != 'undefined' && typeof module.exports != 'undefined') {
  module.exports = getCaretCoordinates;
} else if(isBrowser) {
  window.getCaretCoordinates = getCaretCoordinates;
}

}());
```

### Example implementation to get x-axis and y-axis position of caret in textarea

The code below contains separate example of HTML, CSS and JavaScript of implementation.

```html
<p>This is a demo of <a href="https://github.com/component/textarea-caret-position">textarea-caret-position</a>, a <em>component</em> to determine the pixel coordinates of the cursor in a <code>textarea</code> or <code>input type="text"</code>.
    
<p>Click anywhere in the text to see a red vertical line &ndash; a 1-pixel div that should be positioned exactly at the location of the caret.</p>

<input type="text" size="15" maxlength="240" placeholder="Enter text here">
    
<hr/>
    
<textarea rows="25" cols="40">
    I threw a wish in the well,
    Don't ask me, I'll never tell
    PlaceTheCursorUnderTheFirstLettersOfThisLineAndMakeSureItDoesntTrailOnThePreviousLine
    I looked to you as it fell,
    And now you're in my way
    And	tabs	are	handled	just	fine		
    Except in IE9.
</textarea>

<br/>

<label>
    <input type="checkbox" id="mirrorDivDisplay" onchange="toggleMirrorDivDisplay(this)">Show mirror div
</label>

<h3><a href="https://github.com/component/textarea-caret-position">textarea-caret-position</a> Features</h3>
<ul>
    <li>pixel precision
    <li>no dependencies whatsoever
        <li>browser compatibility: Chrome, Safari, Firefox (despite <a href="https://bugzilla.mozilla.org/show_bug.cgi?id=753662">two</a> <a href="https://bugzilla.mozilla.org/show_bug.cgi?id=984275">bugs</a> it has), Opera, IE9+
    <li>supports any font family and size, as well as text-transforms
    <li>the text area can have arbitrary padding or borders
    <li>not confused by horizontal or vertical scrollbars in the textarea
    <li>supports hard returns, tabs (except in IE) and consecutive spaces in the text
    <li>correct position on lines longer than the columns in the text area
    <li>no <a href="https://github.com/component/textarea-caret-position/blob/06d2197f85f96405b43724e56dc56f220c0092a5/test/position_off_after_wrapping_with_whitespace_before_EOL.gif">"ghost" position in the empty space</a> at the end of a line when wrapping long words
</ul>
    
<p>PS: The cursor appearing within the top border if you scroll down then move the cursor up is a <a href="https://code.google.com/p/chromium/issues/detail?id=353036">Chrome bug</a>.
</p>

<script>
    function toggleMirrorDivDisplay(checkbox) {
      showMirrorDiv = checkbox.checked;
    }
    ['input[type="text"]', 'textarea'].forEach(function (selector) {

      var element = document.querySelector(selector);
      var fontSize = getComputedStyle(element).getPropertyValue('font-size');
      
      var rect = document.createElement('div');
      document.body.appendChild(rect);
      rect.style.position = 'absolute';
      rect.style.backgroundColor = 'red';
      rect.style.height = fontSize;
      rect.style.width = '1px';
      
      ['keyup', 'click', 'scroll'].forEach(function (event) {
       element.addEventListener(event, update);
      });
      
      function update() {
        var coordinates = getCaretCoordinates(element, element.selectionEnd);
        console.log('(top, left) = (%s, %s)', coordinates.top, coordinates.left);
        rect.style.top = element.offsetTop
          - element.scrollTop
          + coordinates.top
          + 'px';
        rect.style.left = element.offsetLeft
          - element.scrollLeft
          + coordinates.left
          + 'px';
      }
    });  
</script>
```

```js
// The properties that we copy into a mirrored div.
// Note that some browsers, such as Firefox,
// do not concatenate properties, i.e. padding-top, bottom etc. -> padding,
// so we have to do every single property specifically.
var properties = [
  'boxSizing',
  'width',  // on Chrome and IE, exclude the scrollbar, so the mirror div wraps exactly as the textarea does
  'height',
  'overflowX',
  'overflowY',  // copy the scrollbar for IE

  'borderTopWidth',
  'borderRightWidth',
  'borderBottomWidth',
  'borderLeftWidth',

  'paddingTop',
  'paddingRight',
  'paddingBottom',
  'paddingLeft',

  // https://developer.mozilla.org/en-US/docs/Web/CSS/font
  'fontStyle',
  'fontVariant',
  'fontWeight',
  'fontStretch',
  'fontSize',
  'lineHeight',
  'fontFamily',

  'textAlign',
  'textTransform',
  'textIndent',
  'textDecoration',  // might not make a difference, but better be safe

  'letterSpacing',
  'wordSpacing'
];

var isFirefox = !(window.mozInnerScreenX == null);
var mirrorDivDisplayCheckbox = document.getElementById('mirrorDivDisplay');
var mirrorDiv, computed, style;

getCaretCoordinates = function (element, position) {
  // mirrored div
  mirrorDiv = document.getElementById(element.nodeName + '--mirror-div');
  if (!mirrorDiv) {
    mirrorDiv = document.createElement('div');
    mirrorDiv.id = element.nodeName + '--mirror-div';
    document.body.appendChild(mirrorDiv);
  }

  style = mirrorDiv.style;
  computed = getComputedStyle(element);

  // default textarea styles
  style.whiteSpace = 'pre-wrap';
  if (element.nodeName !== 'INPUT')
    style.wordWrap = 'break-word';  // only for textarea-s

  // position off-screen
  style.position = 'absolute';  // required to return coordinates properly
  style.top = element.offsetTop + parseInt(computed.borderTopWidth) + 'px';
  style.left = "400px";
  style.visibility = mirrorDivDisplayCheckbox.checked ? 'visible' : 'hidden';  // not 'display: none' because we want rendering

  // transfer the element's properties to the div
  properties.forEach(function (prop) {
    style[prop] = computed[prop];
  });

  if (isFirefox) {
    style.width = parseInt(computed.width) - 2 + 'px'  // Firefox adds 2 pixels to the padding - https://bugzilla.mozilla.org/show_bug.cgi?id=753662
    // Firefox lies about the overflow property for textareas: https://bugzilla.mozilla.org/show_bug.cgi?id=984275
    if (element.scrollHeight > parseInt(computed.height))
      style.overflowY = 'scroll';
  } else {
    style.overflow = 'hidden';  // for Chrome to not render a scrollbar; IE keeps overflowY = 'scroll'
  }  

  mirrorDiv.textContent = element.value.substring(0, position);
  // the second special handling for input type="text" vs textarea: spaces need to be replaced with non-breaking spaces - http://stackoverflow.com/a/13402035/1269037
  if (element.nodeName === 'INPUT')
    mirrorDiv.textContent = mirrorDiv.textContent.replace(/\s/g, "\u00a0");

  var span = document.createElement('span');
  // Wrapping must be replicated *exactly*, including when a long word gets
  // onto the next line, with whitespace at the end of the line before (#7).
  // The  *only* reliable way to do that is to copy the *entire* rest of the
  // textarea's content into the <span> created at the caret position.
  // for inputs, just '.' would be enough, but why bother?
  span.textContent = element.value.substring(position) || '.';  // || because a completely empty faux span doesn't render at all
  span.style.backgroundColor = "lightgrey";
  mirrorDiv.appendChild(span);

  var coordinates = {
    top: span.offsetTop + parseInt(computed['borderTopWidth']),
    left: span.offsetLeft + parseInt(computed['borderLeftWidth'])
  };

  return coordinates;
}
````

```css
input[type="text"], textarea {
  font-family: 'Times New Roman';  /* a proportional font makes it more difficult to calculate the position */
  font-size: 14px;
  line-height: 16px;
  padding: 24px 32px 16px 8px;    /* different paddings so position computations don't accidentally return a "correct" result */
  text-transform: uppercase;      /* this drastically changes character width on proportional fonts */
  text-indent: 20px;
  border: 16px lightblue dotted;  /* needs to be accounted for when returning the final position */
  border-right-width: 24px;       /* discourage naive border arithmetic */
  background: lightyellow;
}
```

## Copy text from textarea

```html
<button onclick="copy()">Copy</button>
<textarea id="myTextarea" class="form-control" rows="21" cols="40" name="text">
</textarea>
```

```js
function copy() {
  let textarea = document.getElementById("myTextarea");
  textarea.select();
  document.execCommand("copy");
}
```

## Clear text in textarea

```html
<button onclick="clear()">Clear</button>
<textarea id="myTextarea" class="form-control" rows="21" cols="40" name="text">
</textarea>
```

```js
function clear() {
  let textarea = document.getElementById('myTextarea');
  textarea.value = '';
}
```