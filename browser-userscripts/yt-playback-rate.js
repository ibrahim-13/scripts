// ==UserScript==
// @name        YT Playback
// @namespace   __personal_yt_playback_rate
// @match       https://*.youtube.com/*
// @grant       none
// @version     2024.07.21
// @author      ibrahim.khan
// @description Increase playback rate of YouTube
// @noframes
// ==/UserScript==

var _conf = {
  elem: {
    video: "#movie_player > div.html5-video-container > video",
    channel: "#owner #upload-info #channel-name yt-formatted-string a",
  },
  isEnabled: true,
  default_playback_rate: 1.5,
    override_playback: false,
    override_playback_rate: 1,
    preset: {
      // channel_relative_url: playback_rate,
      // ex: "/@yt": 1.25,
    },
};

/**
 * UI
 **/

function inject_ui() {
  let isDragging = false;

  const settings = document.createElement("div");
  settings.style.background = "black";
  settings.style.color = "green";
  settings.style.fontSize = "13px";
  settings.style.border = "1px solid yellow";
  settings.style.padding = "7px";
  settings.style.position = "absolute";
  settings.style.top = "0px";
  settings.style.width = "150px";
  settings.style.height = "150px";
  settings.style.zIndex = 99993;
  settings.style.background = "black";
  settings.style.display = "none";

  function util_create_text(type, text) {
    const elem = document.createElement(type);
    elem.innerText = text;
    settings.appendChild(elem);
  }

  util_create_text("h2", "settings");
  util_create_text("label", "enable:");

  const settings_input_enable = document.createElement("input");
  settings_input_enable.type = "checkbox";
  settings_input_enable.checked = _conf.isEnabled;
  settings.appendChild(settings_input_enable);
  settings_input_enable.addEventListener("change", function(e) {_conf.isEnabled = e.target.checked})
  settings.appendChild(document.createElement("br"))

  util_create_text("label", "default speed:");

  const settings_span_playback_rate = document.createElement("label");
  settings_span_playback_rate.innerText = _conf.override_playback ? _conf.override_playback_rate : _conf.default_playback_rate;
  settings.appendChild(settings_span_playback_rate);
  settings.appendChild(document.createElement("br"))

  util_create_text("label", "override:");

  const settings_btn_reset = document.createElement("button");
  settings_btn_reset.style.background = "green";
  settings_btn_reset.innerText = "reset";
  settings_btn_reset.onclick = function() {
    _conf.override_playback_rate = _conf.default_playback_rate;
    _conf.override_playback = false;
    settings_span_playback_rate.innerText = _conf.default_playback_rate;
  }
  settings.appendChild(settings_btn_reset);

  function util_create_rate_btn(rate) {
    const btn = document.createElement("button");
    btn.style.background = "green";
    btn.innerText = String(rate);
    btn.onclick = function() {
      _conf.override_playback_rate = rate;
      _conf.override_playback = true;
      settings_span_playback_rate.innerText = _conf.override_playback_rate;
    }
    settings.appendChild(btn);
  }

  util_create_rate_btn(0.75);
  util_create_rate_btn(1);
  util_create_rate_btn(1.25);
  util_create_rate_btn(1.5);
  util_create_rate_btn(1.75);

  document.body.appendChild(settings);

  const overlay = document.createElement("div");
  overlay.style.position = "absolute";
  overlay.style.cursor = "pointer";
  overlay.style.top = "0px";
  overlay.style.left = "0px";
  overlay.style.width = "100%";
  overlay.style.height = "100%";
  overlay.style.zIndex = 99992;
  overlay.style.opacity = 0.7;
  overlay.style.background = "black";
  overlay.style.display = "none";
  document.body.appendChild(overlay);
  overlay.addEventListener("click", function() {
    settings.style.display = "none";
    overlay.style.display = "none";
  });

  const settings_btn = document.createElement("div");
  settings_btn.style.background = "black";
  settings_btn.style.color = "green";
  settings_btn.style.fontSize = "13px";
  settings_btn.style.fontWeight = "bold";
  settings_btn.style.border = "1px solid yellow";
  settings_btn.style.position = "absolute";
  settings_btn.style.cursor = "pointer";
  settings_btn.style.userSelect = "none";
  settings_btn.style.top = "15px";
  settings_btn.style.left = "175px";
  settings_btn.style.borderRadius = "50%";
  settings_btn.style.padding = "3px";
  settings_btn.style.width = "24px";
  settings_btn.style.height = "24px";
  settings_btn.style.textAlign = "center";
  settings_btn.style.alignContent = "center";
  settings_btn.style.zIndex = 99991;
  settings_btn.innerText = "spd";
  settings_btn.addEventListener("click", function() {
    settings.style.left = String((innerWidth - 150) / 2) + "px";
    settings.style.display = "block";
    overlay.style.display = "block";
  });
  settings_btn.addEventListener("mousedown", function() {isDragging = true;});
  document.addEventListener("mouseup", function() {isDragging = false;});
  document.addEventListener("mousemove", function(e) {
    if (!isDragging) return;
    settings_btn.style.top = e.pageY + "px";
    settings_btn.style.left = e.pageX + "px";
  });
  document.body.appendChild(settings_btn);
}

function with_debounce(func) {
  var prev_timeout_id;
  return function(mutations) {
    if(!_conf.isEnabled) return;
    clearTimeout(prev_timeout_id);
    prev_timeout_id = setTimeout(func, 500);
  };
}

function yt_set_playback_rate() {
  var elem_vid = document.querySelector(_conf.elem.video);
  var elem_channel = document.querySelector(_conf.elem.channel);
  if (elem_vid && elem_channel) {
    var pbr = _conf.preset[elem_channel.getAttribute("href")] || _conf.default_playback_rate;
    if(_conf.override_playback) {
      pbr = _conf.override_playback_rate;
    }
    if(pbr != elem_vid.playbackRate) {
      elem_vid.playbackRate = pbr;
    }
  }
}

(function() {
  "use strict";

    const observer = new MutationObserver(with_debounce(yt_set_playback_rate));

    // use document.documentElement in case of this "parameter 1 is not of type 'Node'"
    observer.observe(document.body, {
      childList: true,
      subtree: true
    });

    inject_ui();
})();
