/**
 * @typedef {object} Option Option for selection
 * @property {string} label Label for option
 * @property {string} value Value for option
 */
/**
 * @typedef {object} OptionCtrl controller proxy for selection dialog
 * @property {boolean} show show or hide dialog
 * @property {string} message message to show in the dialog
 * @property {Array<Option>} options list of options for selection
 * @property {(value: string | undefined) => void} callback callback function that will be triggered
 * @property {(value: string | undefined) => void} exec used internally to execute callback
 */
/**
 * Create confirmation dialog
 * @param {string} prefix prefix used to generate id, random number is used if emptz
 * @returns {OptionCtrl} Proxy to control confirm dialog
 */
function CreateOptionDialog(prefix) {
  const __confirmDialogInner = `
<style>
  #{{idDialog}} {
    position: fixed;
    top: -75%;
    background-color: black;
    color: white;
    border: 1px solid white;
    font-size: 1.5rem;
  }
  #{{idDialog}} button {
    margin: 7px;
  }
  #{{idMsg}} {
    margin-bottom: 5px;
  }
  #{{idForm}} label {
    padding: 3px;
  }
</style>
<p id="{{idMsg}}">Select an option:</p>
<form id="{{idForm}}">
  <div></div>
  <button id="{{idCancel}}">Cancel</button>
  <button type="submit">Ok</button>
</form>
`;

  const _htmlPolicy = trustedTypes.createPolicy("myEscapePolicy", {
    createHTML: (str) => str,
  });

  const _prefix = String(!!prefix ? prefix : Math.floor(Math.random() * 10e7));
  const idDialog = "confirmDialog_" + _prefix;
  const idMsg = "message_" + _prefix;
  const idForm = "option_form_" + _prefix;
  const idCancel = "option_cancel_" + _prefix;
  const nameOption = "option_" + _prefix;
  /**
   * @type {HTMLDialogElement}
   */
  let elemDialog = undefined;
  /**
   * @type {HTMLParagraphElement}
   */
  let elemMsg = undefined;
  /**
   * @type {HTMLFormElement}
   */
  let elemForm = undefined;
  /**
   * @type {HTMLButtonElement}
   */
  let elemCancel = undefined;
  let hasLoaded = false;

  /**
   * @type {OptionCtrl}
   */
  const dialogState = {
    show: false,
    message: "Select an option:",
    options: [],
    callback: () => { },
    exec: function (param) {
      if (typeof this.callback == 'function') {
        this.callback(param);
      }
    },
  };

  /**
   * @type {OptionCtrl}
   */
  const dialogProxy = new Proxy(dialogState, {
    set(target, prop, value) {
      if (!hasLoaded) return Reflect.set(target, prop, value);

      if (prop === 'message' && !!elemMsg) {
        elemMsg.innerText = String(value);
      }
      if (prop === 'show' && !!elemDialog) {
        if (!!value) {
          for(const elem of document.querySelectorAll('#' + idForm + ' div input')) {
            if(elem.checked) {
              elem.checked = false;
            }
          }
          elemDialog.showModal();
        } else {
          elemDialog.close();
        }
      }
      if (prop === 'options' && Array.isArray(value) && !!elemForm) {
        const div = document.querySelector('#' + idForm + ' div');
        div.innerHTML = _htmlPolicy.createHTML('');
        value.forEach(i => {
          const input = document.createElement('input');
          input.type = 'radio';
          input.name = nameOption;
          input.value = i.value;
          const label = document.createElement('label');
          label.appendChild(input);
          label.append(i.label);
          div.appendChild(label);
        });
      }

      return Reflect.set(target, prop, value);
    }
  });

  const init = () => {
    if (hasLoaded) return;
    if (!(document.readyState === 'complete' || document.readyState === 'interactive')) return;

    elemDialog = document.createElement('dialog');
    elemDialog.id = idDialog;
    elemDialog.innerHTML = _htmlPolicy.createHTML(__confirmDialogInner.replaceAll("{{idDialog}}", idDialog)
      .replaceAll("{{idMsg}}", idMsg)
      .replaceAll("{{idForm}}", idForm)
      .replaceAll("{{idCancel}}", idCancel));
    document.body.appendChild(elemDialog);
    elemMsg = document.getElementById(idMsg);
    elemForm = document.getElementById(idForm);
    elemCancel = document.getElementById(idCancel);

    hasLoaded = true;

    elemForm.addEventListener('submit', (e) => {
      dialogProxy.show = false;
      e.preventDefault();
      e.stopPropagation();
      const data = new FormData(e.target);
      dialogProxy.exec.apply(dialogProxy, [data.get(nameOption)]);
    });

    elemCancel.addEventListener('click', (e) => {
      dialogProxy.show = false;
      e.preventDefault();
      e.stopPropagation();
    });

    dialogProxy.message = dialogProxy.message;
    dialogProxy.show = dialogProxy.show;
    dialogProxy.options = dialogProxy.options;
  };

  if (document.readyState === 'complete' || document.readyState == 'interactive') {
    init();
  } else {
    document.addEventListener('readystatechange', init);
  }

  return dialogProxy;
}