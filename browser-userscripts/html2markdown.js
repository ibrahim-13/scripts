// ==UserScript==
// @name         HTML to Markdown
// @namespace    __gh_ibrahim13_html2markdown
// @version      1.0.0
// @author       github/ibrahim-13
// @description  Convert the current page (or pasted HTML) into clean, readable Markdown
// @match        *://*/*
// @noframes
// @grant        GM_registerMenuCommand
// @grant        GM_setClipboard
// ==/UserScript==

(function () {
  "use strict";

  /*****************************************
            START: Converter
  *******************************************/

  // Tags whose content should never appear in the output.
  const SKIP = new Set([
    "script", "style", "noscript", "head", "meta", "link", "title",
    "svg", "canvas", "iframe", "object", "embed", "template",
  ]);

  // Block-level tags. Used to decide whether unknown containers get
  // surrounded by blank lines (block) or are rendered inline.
  const BLOCK = new Set([
    "address", "article", "aside", "blockquote", "details", "dd", "div",
    "dl", "dt", "fieldset", "figcaption", "figure", "footer", "form",
    "header", "hgroup", "main", "nav", "ol", "p", "section", "table",
    "ul", "li", "pre", "hr", "h1", "h2", "h3", "h4", "h5", "h6",
  ]);

  /**
   * Escape characters that would otherwise be interpreted as Markdown.
   * Kept intentionally moderate so common text (e.g. file_name) is not
   * peppered with backslashes.
   * @param {string} s
   * @returns {string}
   */
  function escapeText(s) {
    // Single pass over the markdown-significant characters (backslash first via
    // the character class, so nothing gets double-escaped).
    return s.replace(/[\\`*\[\]]/g, "\\$&");
  }

  /**
   * Wrap inline content with a delimiter while keeping any surrounding
   * whitespace outside of the delimiters (so "**bold** word" renders right).
   * @param {string} content
   * @param {string} delim
   * @returns {string}
   */
  function wrapInline(content, delim) {
    if (!content) return "";
    const trimmed = content.trim();
    if (!trimmed) return content;
    const leading = content.match(/^\s*/)[0];
    const trailing = content.match(/\s*$/)[0];
    return leading + delim + trimmed + delim + trailing;
  }

  /**
   * Convert an HTML node tree into Markdown.
   * @param {Node} root node whose children will be converted
   * @param {string} baseUrl base URL used to resolve relative links/images
   * @returns {string} markdown
   */
  function convertNode(root, baseUrl, opts) {
    if (!root) return "";
    opts = opts || {};
    const resolve = (url) => {
      if (!url) return url || "";
      try {
        return new URL(url, baseUrl).href;
      } catch (_) {
        return url;
      }
    };

    // Wrap a block: separate it from its neighbours with blank lines.
    const block = (s) => "\n\n" + String(s).trim() + "\n\n";

    function process(node) {
      let out = "";
      for (const child of node.childNodes) {
        if (child.nodeType === 3) {
          // Text node: collapse runs of whitespace to a single space.
          out += escapeText(child.nodeValue.replace(/\s+/g, " "));
        } else if (child.nodeType === 1) {
          out += replace(child);
        }
      }
      return out;
    }

    function replace(el) {
      const tag = el.tagName.toLowerCase();
      if (SKIP.has(tag)) return "";
      // Never include this script's own dialog when converting the page.
      if (el.id && el.id === PREFIX + "_dialog") return "";

      switch (tag) {
        case "h1":
        case "h2":
        case "h3":
        case "h4":
        case "h5":
        case "h6": {
          const level = Number(tag.charAt(1));
          const text = process(el).trim().replace(/\s*\n\s*/g, " ");
          if (!text) return "";
          return block("#".repeat(level) + " " + text);
        }

        case "p":
          return block(process(el).trim());

        case "br":
          return "  \n";

        case "hr":
          return block("---");

        case "b":
        case "strong":
          return wrapInline(process(el), "**");

        case "i":
        case "em":
          return wrapInline(process(el), "_");

        case "s":
        case "strike":
        case "del":
          return wrapInline(process(el), "~~");

        case "code": {
          // Inline code. Pick a backtick fence long enough to not clash
          // with backticks inside the code itself.
          const code = el.textContent;
          if (!code) return "";
          let ticks = "`";
          while (code.includes(ticks)) ticks += "`";
          const pad = /^`|`$|^\s|\s$/.test(code) ? " " : "";
          return ticks + pad + code + pad + ticks;
        }

        case "pre": {
          // Fenced code block. Read raw text and try to detect a language.
          const codeEl = el.querySelector("code");
          let text = (codeEl || el).textContent.replace(/\n$/, "");
          let lang = "";
          if (codeEl) {
            const m = (codeEl.className || "").match(/language-([\w-]+)/);
            if (m) lang = m[1];
          }
          let fence = "```";
          while (text.includes(fence)) fence += "`";
          return block(fence + lang + "\n" + text + "\n" + fence);
        }

        case "blockquote": {
          let inner = process(el).trim();
          if (!inner) return "";
          inner = inner.replace(/\n/g, "\n> ");
          return block("> " + inner);
        }

        case "ul":
        case "ol": {
          const ordered = tag === "ol";
          let i = ordered ? parseInt(el.getAttribute("start") || "1", 10) || 1 : 0;
          let items = "";
          for (const child of el.children) {
            if (child.tagName.toLowerCase() !== "li") continue;
            const marker = ordered ? i++ + ". " : "- ";
            const indent = " ".repeat(marker.length);
            let liContent = process(child).trim().replace(/\n{2,}/g, "\n");
            liContent = liContent.replace(/\n/g, "\n" + indent);
            items += marker + liContent + "\n";
          }
          return block(items.replace(/\n+$/, ""));
        }

        case "a": {
          const content = process(el);
          let href = el.getAttribute("href");
          if (!href) return content;
          href = resolve(href);
          const title = el.getAttribute("title");
          const text = content.trim() || href;
          return "[" + text + "](" + href + (title ? ' "' + title + '"' : "") + ")";
        }

        case "img": {
          const src = resolve(el.getAttribute("src") || "");
          if (!src) return "";
          const alt = (el.getAttribute("alt") || "").replace(/\n/g, " ");
          const title = el.getAttribute("title");
          return "![" + alt + "](" + src + (title ? ' "' + title + '"' : "") + ")";
        }

        case "table":
          return block(convertTable(el));

        case "dt":
          return block("**" + process(el).trim() + "**");

        case "dd":
          return block(": " + process(el).trim());

        default: {
          const content = process(el);
          return BLOCK.has(tag) ? block(content) : content;
        }
      }
    }

    // Render a <table> as GitHub-Flavored Markdown, faithfully mirroring the
    // Go library's table plugin: header detection, alignment, colspan/rowspan
    // (spanned cells are left empty and siblings shifted right) and the
    // space-padding that makes columns line up.
    function convertTable(table) {
      const isCell = (c) => c.nodeType === 1 && /^(td|th)$/i.test(c.tagName);
      const cellsOf = (row) => Array.from(row.children).filter(isCell);
      const runeLen = (s) => [...String(s)].length;

      // Layout tables (role="presentation") and tables whose cells contain
      // block content (newlines) cannot be a Markdown table — render the rows
      // as plain blocks instead.
      function fallback() {
        return Array.from(table.querySelectorAll("tr"))
          .map((tr) => cellsOf(tr).map((c) => process(c).trim()).join(" "))
          .filter((line) => line.length > 0)
          .join("\n\n");
      }

      if ((table.getAttribute("role") || "") === "presentation") {
        return fallback();
      }

      // --- header / normal row selection ---
      let headerRow = null;
      const thead = table.querySelector("thead");
      if (thead) headerRow = thead.querySelector("tr");
      if (!headerRow) {
        const th = table.querySelector("th");
        if (th) headerRow = th.closest("tr");
      }

      const normalRows = [];
      (function walk(node) {
        for (const child of node.children) {
          const name = child.tagName.toLowerCase();
          // Don't descend into nested tables — their rows are not ours.
          if (name === "table") continue;
          if (name === "tr" && child !== headerRow) normalRows.push(child);
          walk(child);
        }
      })(table);

      // --- collect cell contents + colspan/rowspan modifications ---
      const numAttr = (el, name) => {
        const n = parseInt(el.getAttribute(name) || "", 10);
        return isNaN(n) || n < 1 ? 1 : n;
      };

      let sawNewline = false;
      function collectCells(rowIndex, rowNode) {
        const cells = [];
        const mods = [];
        cellsOf(rowNode).forEach((cell, index) => {
          let content = process(cell).trim();
          if (content.indexOf("\n") !== -1) sawNewline = true;
          content = content.replace(/\|/g, "\\|");
          cells.push(content);

          const colSpan = numAttr(cell, "colspan");
          const rowSpan = numAttr(cell, "rowspan");
          if (colSpan <= 1 && rowSpan <= 1) return;
          // Spanned positions are inserted as empty cells.
          for (let dx = 1; dx < colSpan; dx++) {
            mods.push({ y: rowIndex, x: index + dx, data: "" });
          }
          for (let dy = 1; dy < rowSpan; dy++) {
            for (let dx = 0; dx < colSpan; dx++) {
              mods.push({ y: rowIndex + dy, x: index + dx, data: "" });
            }
          }
        });
        return { cells, mods };
      }

      const rows = [];
      const grouped = [];
      if (headerRow) {
        const { cells, mods } = collectCells(0, headerRow);
        rows.push(cells);
        grouped.push(mods);
      } else {
        // A header row is required for the table to be recognized; use an
        // empty one when there is no <thead>/<th>.
        rows.push([]);
      }
      normalRows.forEach((rn, i) => {
        const { cells, mods } = collectCells(i + 1, rn);
        rows.push(cells);
        grouped.push(mods);
      });

      if (sawNewline) return fallback();

      // Apply span modifications in reverse group order so overlapping spans
      // shift cells correctly.
      grouped
        .slice()
        .reverse()
        .forEach((mods) => {
          mods.forEach((mod) => {
            while (rows.length <= mod.y) rows.push([]);
            const row = rows[mod.y];
            while (row.length < mod.x) row.push("");
            row.splice(mod.x, 0, mod.data);
          });
        });

      // When enabled, promote the first row to the header if the table has no
      // <thead>/<th> (the header row is then the empty placeholder).
      if (opts.promoteHeader && rows.length > 0 && rows[0].every((c) => !c)) {
        rows.shift();
      }

      // --- column widths (min width 1 so the table is recognized) ---
      const counts = [];
      rows.forEach((cells) => {
        cells.forEach((cell, i) => {
          if (i >= counts.length) counts.push(1);
          const len = runeLen(cell);
          if (len > counts[i]) counts[i] = len;
        });
      });
      if (counts.length === 0) return ""; // truly empty table -> nothing

      rows.forEach((cells) => {
        while (cells.length < counts.length) cells.push("");
      });

      // --- alignment from the first row's cells ---
      const firstRow = headerRow || normalRows[0] || null;
      const alignments = firstRow
        ? cellsOf(firstRow).map((c) => c.getAttribute("align") || "")
        : [];

      const writeRow = (cells) => {
        let line = "|";
        cells.forEach((cell, i) => {
          const filler = counts[i] - runeLen(cell);
          line += " " + cell + (filler > 0 ? " ".repeat(filler) : "") + " |";
        });
        return line;
      };
      const writeUnderline = () => {
        let line = "|";
        counts.forEach((maxLen, i) => {
          const align = alignments[i] || "";
          line += align === "left" || align === "center" ? ":" : "-";
          line += "-".repeat(maxLen);
          line += align === "right" || align === "center" ? ":" : "-";
          line += "|";
        });
        return line;
      };

      const lines = [writeRow(rows[0]), writeUnderline()];
      for (let r = 1; r < rows.length; r++) lines.push(writeRow(rows[r]));
      let out = lines.join("\n");

      const captionNode = table.querySelector("caption");
      if (captionNode) {
        const cap = process(captionNode).trim();
        if (cap) out += "\n\n" + cap;
      }
      return out;
    }

    return process(root)
      .replace(/[ \t]+\n/g, (m) => (m.endsWith("  \n") ? "  \n" : "\n")) // keep hard breaks
      .replace(/\n{3,}/g, "\n\n")
      .trim();
  }

  /**
   * Convert an HTML string into Markdown.
   * @param {string} html
   * @param {string} baseUrl
   * @returns {string}
   */
  function convertString(html, baseUrl, opts) {
    if (!html) return "";
    const doc = new DOMParser().parseFromString(String(html), "text/html");
    return doc && doc.body ? convertNode(doc.body, baseUrl, opts) : "";
  }

  /*****************************************
            END: Converter
  *******************************************/

  /*****************************************
            START: UI
  *******************************************/

  const PREFIX = "h2md_" + Math.floor(Math.random() * 10e7);
  let built = false;
  /** @type {HTMLDialogElement} */
  let elemDialog;
  /** @type {HTMLHeadingElement} */
  let elemTitle;
  /** @type {HTMLTextAreaElement} */
  let elemInput;
  /** @type {HTMLTextAreaElement} */
  let elemOutput;
  /** @type {HTMLButtonElement} */
  let elemCopy;
  /** @type {HTMLInputElement} */
  let elemPromote;

  // Setting: promote the first row to the header for tables without a header.
  let optPromote = false;
  // The last conversion, re-run when an option changes.
  let reconvert = null;

  const convertOpts = () => ({ promoteHeader: optPromote });

  const STYLE = `
#{{id}} {
  width: min(900px, 92vw);
  max-height: 88vh;
  padding: 0;
  border: 1px solid #444;
  border-radius: 10px;
  background: #1e1e1e;
  color: #eaeaea;
  font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
}
#{{id}}::backdrop {
  background: rgba(0, 0, 0, 0.55);
}
#{{id}} .h2md-body {
  display: flex;
  flex-direction: column;
  gap: 10px;
  padding: 18px 20px 20px;
  box-sizing: border-box;
}
#{{id}} h2 {
  margin: 0;
  font-size: 18px;
  font-weight: 600;
}
#{{id}} label {
  font-size: 12px;
  color: #9a9a9a;
  margin-bottom: -4px;
}
#{{id}} textarea {
  width: 100%;
  box-sizing: border-box;
  min-height: 130px;
  resize: vertical;
  padding: 9px 10px;
  border: 1px solid #444;
  border-radius: 6px;
  background: #111;
  color: #ddd;
  font-family: ui-monospace, SFMono-Regular, Menlo, Consolas, monospace;
  font-size: 13px;
  line-height: 1.5;
}
#{{id}} textarea:focus {
  outline: none;
  border-color: #2563eb;
}
#{{id}} .h2md-row {
  display: flex;
  flex-wrap: wrap;
  gap: 8px;
}
#{{id}} button {
  cursor: pointer;
  padding: 7px 14px;
  border: 1px solid #555;
  border-radius: 6px;
  background: #2d2d2d;
  color: #fff;
  font-size: 14px;
}
#{{id}} button:hover {
  background: #3a3a3a;
}
#{{id}} button.h2md-primary {
  background: #2563eb;
  border-color: #2563eb;
}
#{{id}} button.h2md-primary:hover {
  background: #1d4fd0;
}
#{{id}} label.h2md-check {
  display: flex;
  align-items: center;
  gap: 6px;
  margin: 0;
  color: #cfcfcf;
  cursor: pointer;
}
#{{id}} label.h2md-check input {
  cursor: pointer;
}
`;

  function mkButton(label, className) {
    const b = document.createElement("button");
    b.textContent = label;
    if (className) b.className = className;
    return b;
  }

  function ensureUI() {
    if (built) return;
    built = true;

    const style = document.createElement("style");
    style.textContent = STYLE.replaceAll("{{id}}", PREFIX + "_dialog");
    (document.head || document.documentElement).appendChild(style);

    elemDialog = document.createElement("dialog");
    elemDialog.id = PREFIX + "_dialog";

    const body = document.createElement("div");
    body.className = "h2md-body";

    elemTitle = document.createElement("h2");
    elemTitle.textContent = "HTML to Markdown";

    const inLabel = document.createElement("label");
    inLabel.textContent = "HTML input";
    elemInput = document.createElement("textarea");
    elemInput.placeholder = "Paste or type HTML here, then press Convert…";

    const actionRow = document.createElement("div");
    actionRow.className = "h2md-row";
    const btnConvert = mkButton("Convert", "h2md-primary");
    const btnClear = mkButton("Clear");
    elemCopy = mkButton("Copy Markdown");
    const btnClose = mkButton("Close");
    actionRow.append(btnConvert, btnClear, elemCopy, btnClose);

    const optionRow = document.createElement("div");
    optionRow.className = "h2md-row";
    const promoteLabel = document.createElement("label");
    promoteLabel.className = "h2md-check";
    elemPromote = document.createElement("input");
    elemPromote.type = "checkbox";
    elemPromote.checked = optPromote;
    promoteLabel.append(
      elemPromote,
      document.createTextNode("Promote first row to header (tables without a header row)")
    );
    optionRow.appendChild(promoteLabel);

    const outLabel = document.createElement("label");
    outLabel.textContent = "Markdown output";
    elemOutput = document.createElement("textarea");
    elemOutput.readOnly = true;
    elemOutput.placeholder = "The converted Markdown will appear here.";

    body.append(elemTitle, inLabel, elemInput, actionRow, optionRow, outLabel, elemOutput);
    elemDialog.appendChild(body);
    document.body.appendChild(elemDialog);

    // ----- Behaviour -----
    btnConvert.addEventListener("click", () => {
      reconvert = () => convertString(elemInput.value, location.href, convertOpts());
      elemOutput.value = reconvert();
    });

    elemPromote.addEventListener("change", () => {
      optPromote = elemPromote.checked;
      if (reconvert) elemOutput.value = reconvert();
    });

    btnClear.addEventListener("click", () => {
      elemInput.value = "";
      elemOutput.value = "";
      elemInput.focus();
    });

    elemCopy.addEventListener("click", () => {
      const ok = copyToClipboard(elemOutput.value);
      const original = elemCopy.dataset.label || elemCopy.textContent;
      elemCopy.dataset.label = original;
      elemCopy.textContent = ok ? "Copied!" : "Copy failed";
      setTimeout(() => {
        elemCopy.textContent = original;
      }, 1200);
    });

    btnClose.addEventListener("click", () => elemDialog.close());

    // Close when clicking on the backdrop (outside the body).
    elemDialog.addEventListener("click", (e) => {
      if (e.target === elemDialog) elemDialog.close();
    });
  }

  function copyToClipboard(text) {
    if (typeof GM_setClipboard === "function") {
      try {
        GM_setClipboard(text, { type: "text", mimetype: "text/plain" });
        return true;
      } catch (_) {
        // fall through to the DOM-based fallback
      }
    }
    return domCopy(text);
  }

  // DOM-based clipboard fallback: write the text into a throwaway, off-screen
  // <textarea>, select it, run execCommand("copy"), then restore any selection
  // the user already had. Works without the GM_setClipboard grant.
  function domCopy(text) {
    const ta = document.createElement("textarea");
    ta.value = text;
    ta.setAttribute("readonly", "");
    Object.assign(ta.style, {
      position: "fixed",
      top: "-9999px",
      left: "-9999px",
      width: "1px",
      height: "1px",
      padding: "0",
      border: "none",
      opacity: "0",
    });
    document.body.appendChild(ta);

    const sel = document.getSelection();
    const prevRange = sel && sel.rangeCount > 0 ? sel.getRangeAt(0) : null;

    ta.focus();
    ta.select();
    if (typeof ta.setSelectionRange === "function") {
      ta.setSelectionRange(0, ta.value.length);
    }

    let ok = false;
    try {
      ok = document.execCommand("copy");
    } catch (_) {
      ok = false;
    }

    document.body.removeChild(ta);
    if (prevRange && sel) {
      sel.removeAllRanges();
      sel.addRange(prevRange);
    }
    return ok;
  }

  /*****************************************
            END: UI
  *******************************************/

  /*****************************************
            START: Menu commands
  *******************************************/

  function onConvertPage() {
    ensureUI();
    elemTitle.textContent = "Page → Markdown";
    elemInput.value = "";
    reconvert = () => convertNode(document.body, location.href, convertOpts());
    elemOutput.value = reconvert();
    elemDialog.showModal();
  }

  function onOpenInputDialog() {
    ensureUI();
    elemTitle.textContent = "HTML text → Markdown";
    elemInput.value = "";
    elemOutput.value = "";
    reconvert = () => convertString(elemInput.value, location.href, convertOpts());
    elemDialog.showModal();
    elemInput.focus();
  }

  if (typeof GM_registerMenuCommand === "function") {
    GM_registerMenuCommand("📄 Convert this page to Markdown", onConvertPage);
    GM_registerMenuCommand("📝 Convert HTML text to Markdown…", onOpenInputDialog);
  }

  /*****************************************
            END: Menu commands
  *******************************************/
})();
