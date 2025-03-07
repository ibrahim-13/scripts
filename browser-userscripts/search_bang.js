// ==UserScript==
// @name        Search!
// @namespace   __gh_ibrahim13_search_bang
// @version     2025.3.7
// @author      github/ibrahim-13
// @description Search with a bang!
// @include *
// @noframes
// ==/UserScript==

var _search_engines = [
  {
    key: "bi",
    name: "Bing",
    url: "https://www.bing.com/search?q={{{s}}}",
  },
  {
    key: "bv",
    name: "Brave",
    url: "https://search.brave.com/search?q={{{s}}}",
    default: true,
  },
  {
    key: "rd",
    name: "Reddit",
    url: "https://www.reddit.com/search/?q={{{s}}}",
  },
  {
    key: "gg",
    name: "Google",
    url: "https://www.google.com/search?q={{{s}}}",
  },
  {
    key: "yt",
    name: "YouTube",
    url: "https://www.youtube.com/results?search_query={{{s}}}",
  },
];


function search_prompt() {
  const query = prompt("Search:");
  if (!query) return;

  const match = query.match(/!(\S+)/i);
  const bangCandidate = (match || {1:""})[1].toLowerCase();
  const engine = _search_engines.find(i => i.key == bangCandidate) || _search_engines.find(i => !!i.default);
  if (!engine) {
    alert("error: could not find search engine for bang command");
    return;
  }
  const cleanQuery = query.replace(/!\S+\s*/i, "").trim();
  const searchUrl = engine.url.replace(
    "{{{s}}}",
    // Replace %2F with / to fix formats like "!ghr+t3dotgg/unduck"
    encodeURIComponent(cleanQuery).replace(/%2F/g, "/")
  );
  if (!searchUrl) return null;
  window.location.replace(searchUrl);
}

(function() {
  "use strict";

  window.document.addEventListener('keydown', function(e) {
    if (event.ctrlKey && event.keyCode === 13) {
    search_prompt();
  }
  });

})();