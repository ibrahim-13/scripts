# Dialog

## Adding a dialog

```html
<button id="open-dialog-btn" onclick="document.getElementById('my-dialog').showModal()"><b>Open dialog</b></button>
<dialog id="my-dialog" onclick="if(event.target===this)this.close()">
  <button autofocus onclick="document.getElementById('my-dialog').close()"><b>Close</b></button>
  <div>This is the content of the dialog</div>
</dialog>
```

```css
#my-dialog::backdrop {
  background-color: black;
}
```