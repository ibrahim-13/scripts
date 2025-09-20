/**
 * @typedef {object} ConfirmCtrl controller proxy for confirm dialog
 * @property {boolean} show show or hide dialog
 * @property {string} message message to show in the dialog
 * @property {(boolean) => void} callback callback function that will be triggered
 * @property {(boolean) => void} exec used internally to execute callback
 */
/**
 * Create confirmation dialog
 * @param {string} prefix prefix used to generate id, random number is used if emptz
 * @returns {Promise<ConfirmCtrl>} Proxy to control confirm dialog
 */
function CreateFloatingMenu(prefix) {
  const __confirmDialogInner = `
<style>
  #{{idDialog}} {
    position: fixed;
  top: -75%;
  background-color: black;
  border: 1px solid white;
    }
  #{{idDialog}} button {
    margin: 7px;
    }
</style>
<p id="{{idMsg}}">Are you sure?</p>
<button id="{{idYes}}">Yes</button>
<button id="{{idNo}}">No</button>
`;

  const _prefix = String(!!prefix ? prefix : Math.floor(Math.random() * 10e7));
  const idDialog = "confirmDialog_" + _prefix;
  const idMsg = "message_" + _prefix;
  const idYes = "yesBtn_" + _prefix;
  const idNo = "noBtn_" + _prefix;
  let hasLoaded = false;

  /**
   * @type {ConfirmCtrl}
   */
  const dialogState = {
    show: true,
    message: "Are you sure?",
    callback: () => { },
    exec: function (param) {
      if (typeof this.callback == 'function') {
        this.callback(param);
      }
    },
  };
  return new Promise(resolve => {

    const init = () => {
      if (hasLoaded) return;
      if (!(document.readyState === 'complete' || document.readyState === 'interactive')) return;

      const elemDialog = document.createElement('dialog');
      elemDialog.id = idDialog;
      elemDialog.innerHTML = __confirmDialogInner.replaceAll("{{idDialog}}", idDialog)
        .replaceAll("{{idMsg}}", idMsg)
        .replaceAll("{{idYes}}", idYes)
        .replaceAll("{{idNo}}", idNo);
      document.body.appendChild(elemDialog);
      const elemMsg = document.getElementById(idMsg);
      const elemYes = document.getElementById(idYes);
      const elemNo = document.getElementById(idNo);

      /**
       * @type {ConfirmCtrl}
       */
      const dialogProxy = new Proxy(dialogState, {
        set(target, prop, value) {
          if (!hasLoaded) return Reflect.set(target, prop, value);

          if (prop === 'message') {
            elemMsg.innerText = String(value);
          }
          if (prop === 'show') {
            if (!!value) {
              elemDialog.showModal();
            } else {
              elemDialog.close();
            }
          }
          return Reflect.set(target, prop, value);
        }
      });
      hasLoaded = true;

      elemYes.addEventListener('click', () => {
        dialogProxy.exec.apply(dialogProxy, [true]);
        dialogProxy.show = false;
      });

      elemNo.addEventListener('click', () => {
        dialogProxy.exec.apply(dialogProxy, [false]);
        dialogProxy.show = false;
      });

      dialogProxy.message = dialogProxy.message;
      dialogProxy.show = dialogProxy.show;

      resolve(dialogProxy);
    };

    if (document.readyState === 'complete' || document.readyState == 'interactive') {
      init();
    } else {
      document.addEventListener('readystatechange', init);
    }
  });
}