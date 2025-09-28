/**
 * @typedef {object} ConfirmCtrl controller proxy for confirm dialog
 * @property {boolean} show show or hide dialog
 * @property {boolean} noOp no operation mode, only show Yes button and callback is not invoked
 * @property {string} message message to show in the dialog
 * @property {string} textYes text for button Yes
 * @property {string} textNo text for button No
 * @property {(confirm: boolean) => void} callback callback function that will be triggered
 * @property {(confirm: boolean) => void} exec used internally to execute callback
 */
/**
 * Create confirmation dialog
 * @param {string} prefix prefix used to generate id, random number is used if emptz
 * @returns {ConfirmCtrl} Proxy to control confirm dialog
 */
function CreateConfirmDialog(prefix) {
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
  #{{idForm}} button {
    padding: 3px;
  }
</style>
<p id="{{idMsg}}">Are you sure?</p>
<button id="{{idNo}}">Cancel</button>
<button id="{{idYes}}">Ok</button>
`;

  const _htmlPolicy = trustedTypes.createPolicy("myEscapePolicy", {
    createHTML: (str) => str,
  });

  const _prefix = String(!!prefix ? prefix : Math.floor(Math.random() * 10e7));
  const idDialog = "confirmDialog_" + _prefix;
  const idMsg = "message_" + _prefix;
  const idYes = "yesBtn_" + _prefix;
  const idNo = "noBtn_" + _prefix;
  /**
   * @type {HTMLDialogElement}
   */
  let elemDialog = undefined;
  /**
   * @type {HTMLParagraphElement}
   */
  let elemMsg = undefined;
  /**
   * @type {HTMLButtonElement}
   */
  let elemYes = undefined;
  /**
   * @type {HTMLButtonElement}
   */
  let elemNo = undefined;
  let hasLoaded = false;

  /**
   * @type {ConfirmCtrl}
   */
  const dialogState = {
    show: false,
    message: "Are you sure?",
    textYes: "Yes",
    textNo: "No",
    noOp: false,
    callback: () => { },
    exec: function (param) {
      if (typeof this.callback == 'function') {
        this.callback(param);
      }
    },
  };

  /**
   * @type {ConfirmCtrl}
   */
  const dialogProxy = new Proxy(dialogState, {
    set(target, prop, value) {
      if (!hasLoaded) return Reflect.set(target, prop, value);

      if (prop === 'message' && !!elemMsg) {
        elemMsg.innerText = String(value);
      }
      if (prop === 'show' && !!elemDialog) {
        if (!!value) {
          elemDialog.showModal();
        } else {
          elemDialog.close();
        }
      }
      if (prop === 'textYes' && !!elemYes) {
        elemYes.innerText = String(value);
      }
      if (prop === 'textNo' && !!elemNo) {
        elemNo.innerText = String(value);
      }
      if (prop === 'noOp' && !!elemNo) {
        if(!!value) {
          elemNo.style.display = 'none';
        } else  {
          elemNo.style.display = 'initial';
        }
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
      .replaceAll("{{idYes}}", idYes)
      .replaceAll("{{idNo}}", idNo));
    document.body.appendChild(elemDialog);
    elemMsg = document.getElementById(idMsg);
    elemYes = document.getElementById(idYes);
    elemNo = document.getElementById(idNo);

    hasLoaded = true;

    elemYes.addEventListener('click', () => {
      dialogProxy.show = false;
      dialogProxy.show = false;
      if (!dialogProxy.noOp) {
        dialogProxy.exec.apply(dialogProxy, [true]);
      }
    });

    elemNo.addEventListener('click', () => {
      dialogProxy.show = false;
      if (!dialogProxy.noOp) {
        dialogProxy.exec.apply(dialogProxy, [false]);
      }
    });

    dialogProxy.message = dialogProxy.message;
    dialogProxy.show = dialogProxy.show;
  };

  if (document.readyState === 'complete' || document.readyState == 'interactive') {
    init();
  } else {
    document.addEventListener('readystatechange', init);
  }

  return dialogProxy;
}