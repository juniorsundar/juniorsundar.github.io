#!/usr/bin/env node
// The Tailored CV picker: a local web page with the CV PDF beside it, rebuilt on every change.
// See "Decide how the Tailored CV picker is run" (issue #24). Run it with `nix run .#pick`.
//
// Nothing is written into the repo: the PDF lives in a temp dir and Selection files live outside the repo.
// Phone/address are read from CV_PHONE/CV_ADDRESS and never saved. The server listens on 127.0.0.1 only.
import { createServer } from "node:http";
import { execFileSync } from "node:child_process";
import { mkdtempSync, mkdirSync, writeFileSync, readFileSync, readdirSync, existsSync } from "node:fs";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { tmpdir, homedir } from "node:os";
import { spawn } from "node:child_process";

const ROOT = resolve(process.env.CV_ROOT || join(dirname(fileURLToPath(import.meta.url)), ".."));
const PORT = 8765;
const DOC = "cv/cv.typ";
const OUT = mkdtempSync(join(tmpdir(), "tailored-cv-"));
const PDF = join(OUT, "cv.pdf");
const SAVED = join(process.env.XDG_DATA_HOME || join(homedir(), ".local", "share"), "cv-selections");
const PARTS = ["highlights", "tags", "compact"];

const typst = (...args) =>
  execFileSync("typst", [...args, "--root", "."], { cwd: ROOT, stdio: ["ignore", "pipe", "ignore"] }).toString();
// json.encode() yields a JSON string, which typst prints as a string literal: hence the two parses.
const projects = JSON.parse(JSON.parse(typst("eval", 'json.encode(yaml("/data/projects.yaml"))')));
// Private details come from the environment, are shown in the page while the toggle is on, and are never saved.
const privateDetails = (key) => process.env[key] || "";
const slugsMissing = (picks) => picks.map((p) => p.slug).filter((s) => !projects.some((p) => p.slug === s));

function build(picks, withPrivate) {
  const pass = [
    "--input", `selection=${JSON.stringify(picks)}`,
    "--input", `phone=${withPrivate ? privateDetails("CV_PHONE") : ""}`,
    "--input", `address=${withPrivate ? privateDetails("CV_ADDRESS") : ""}`,
  ];
  typst("compile", ...pass, DOC, PDF);
  // typst eval takes its context file via --in, and evaluates it before the expression.
  const { pages, fill } = JSON.parse(typst("eval", "query(<pages>).first().value", ...pass, "--in", DOC));
  return { pages, fill, dropped: slugsMissing(picks) };
}

const selections = () => (existsSync(SAVED) ? readdirSync(SAVED).filter((f) => f.endsWith(".json")) : []);

function save(name, data) {
  // A Selection is the recipe only: no PDF, no phone or address values.
  mkdirSync(SAVED, { recursive: true });
  writeFileSync(join(SAVED, `${name}.json`), JSON.stringify(data, null, 2) + "\n");
}
const load = (name) => {
  // Loading never fails on a Project that has since been removed or renamed: those slugs come back as `dropped`.
  const s = JSON.parse(readFileSync(join(SAVED, `${name}.json`)));
  return { ...s, dropped: slugsMissing(s.picks || []) };
};

const html = () => `<!doctype html><meta charset=utf-8><title>Tailored CV</title>
<style>
body{margin:0;display:grid;grid-template-columns:27rem 1fr;height:100vh;font:14px system-ui;background:#282c34;color:#bbc2cf}
aside{padding:1rem;overflow:auto}.p{padding:.5rem;border-radius:4px}.p:hover{background:#3f444a}.inc{display:block;cursor:pointer}
small{display:block;opacity:.7;margin-left:1.6rem}.parts{display:none;margin:.4rem 0 .2rem 1.6rem;gap:.2rem .9rem;flex-wrap:wrap;font-size:12px}
.p.sel .parts{display:flex}.parts label{cursor:pointer}.parts .na{opacity:.35}
#count{font-size:1.2rem;margin:.5rem 0 1rem}#count.over{color:#ff6c6b}
#priv{margin:.6rem 0}.bar{display:flex;gap:.4rem;margin:.6rem 0;flex-wrap:wrap}
button,input,select{font:inherit;background:#3f444a;color:inherit;border:1px solid #565c64;border-radius:4px;padding:.2rem .4rem}
iframe{width:100%;height:100%;border:0}
</style>
<aside>
  <b>Tailored CV</b><div id=count>building…</div>
  <div class=bar><input id=sel-name placeholder="selection name" size=14><button id=save>Save</button>
  <select id=saved><option value="">load…</option></select></div>
  <p id=priv><label><input type=checkbox id=privtoggle ${privateDetails("CV_PHONE") || privateDetails("CV_ADDRESS") ? "" : "disabled"}> include phone &amp; address</label>
  <small id=privvalues></small></p>
</aside><iframe id=pdf></iframe>
<script>
const PARTS=${JSON.stringify(PARTS)};
let projects=[], dropped=[];
const picks=()=>[...document.querySelectorAll(".p")].filter(p=>p.querySelector(".on").checked)
  .map(p=>({slug:p.dataset.slug,parts:[...p.querySelectorAll(".parts input:checked")].map(i=>i.value)}));
async function refresh(){
  [...document.querySelectorAll(".p")].forEach(p=>p.classList.toggle("sel",p.querySelector(".on").checked));
  privvalues.textContent=${JSON.stringify(privateDetails("CV_PHONE") || privateDetails("CV_ADDRESS") ? "reads CV_PHONE/CV_ADDRESS; never saved · " : "set CV_PHONE/CV_ADDRESS to enable")}
    +(privtoggle.checked?${JSON.stringify([privateDetails("CV_PHONE"), privateDetails("CV_ADDRESS")].filter(Boolean).join(" · ") || "(nothing set)")}:"");
  const res=await (await fetch("/build",{method:"POST",body:JSON.stringify({picks:picks(),private:privtoggle.checked})})).json();
  const gone=[...new Set([...dropped,...res.dropped])];
  count.textContent=res.pages+" page"+(res.pages>1?"s":"")+", last page "+res.fill+"% full"+(res.pages>2?"  ⚠ over 2-page budget":"")
    +(gone.length?"  ·  dropped: "+gone.join(", "):"");
  count.className=res.pages>2?"over":"";pdf.src="/cv.pdf?"+Date.now();
}
function row(p){const has={highlights:!!(p.highlights||[]).length,tags:!!(p.tags||[]).length,compact:true};
  const part=k=>'<label class="'+(has[k]?"":"na")+'"><input type=checkbox value='+k+(k!=="compact"&&has[k]?" checked":"")+(k!=="compact"&&!has[k]?" disabled":"")+'>'+k+'</label>';
  return '<div class=p data-slug="'+p.slug+'"><label class=inc><input type=checkbox class=on> '+(p.title||p.name)
    +'<small>'+p.start+(p.end?" – "+p.end:" – now")+' · '+p.summary+'</small></label>'
    +'<div class=parts>'+PARTS.map(part).join("")+'</div></div>'}
const sidebar=document.querySelector("aside");
async function init(){const st=await (await fetch("/state")).json();projects=st.projects;
  sidebar.insertAdjacentHTML("beforeend",projects.map(row).join(""));
  saved.insertAdjacentHTML("beforeend",st.selections.map(n=>'<option>'+n+'</option>').join(""));
  document.querySelectorAll("aside input").forEach(i=>i.onchange=refresh);
  document.getElementById("save").onclick=async()=>{const n=document.getElementById("sel-name").value.trim();if(!n)return;
    const res=await (await fetch("/save",{method:"POST",body:JSON.stringify({name:n,picks:picks(),private:privtoggle.checked})})).json();
    if(res.error){alert(res.error);return}
    if(![...saved.options].some(o=>o.value===n))saved.insertAdjacentHTML("beforeend",'<option>'+n+'</option>');
    saved.value=n};
  saved.onchange=()=>saved.value&&load(saved.value);refresh()}
async function load(name){const s=await (await fetch("/selection?name="+encodeURIComponent(name))).json();
  document.querySelectorAll(".p").forEach(p=>{const pick=s.picks.find(x=>x.slug===p.dataset.slug);p.querySelector(".on").checked=!!pick;
    p.querySelectorAll(".parts input").forEach(i=>i.checked=!!pick&&pick.parts.includes(i.value))});
  dropped=s.dropped||[];privtoggle.checked=!!s.private;refresh()}
init();
</script>`;

const json = (res, data, code = 200) => { res.writeHead(code, { "content-type": "application/json" }); res.end(JSON.stringify(data)); };
const body = (req) => new Promise((done) => { let b = ""; req.on("data", (d) => (b += d)).on("end", () => done(b ? JSON.parse(b) : {})); });

const server = createServer(async (req, res) => {
  const url = new URL(req.url, "http://127.0.0.1");
  try {
    if (url.pathname === "/") return res.writeHead(200, { "content-type": "text/html; charset=utf-8" }).end(html());
    if (url.pathname === "/cv.pdf") return res.writeHead(200, { "content-type": "application/pdf" }).end(readFileSync(PDF));
    if (url.pathname === "/state") return json(res, {
      projects,
      selections: selections().map((f) => f.slice(0, -5)),
      private: { phone: privateDetails("CV_PHONE"), address: privateDetails("CV_ADDRESS") },
    });
    if (url.pathname === "/build") { const b = await body(req); return json(res, build(b.picks || [], !!b.private)); }
    if (url.pathname === "/save") {
      const b = await body(req);
      if (!/^[\w .-]+$/.test(b.name || "")) return json(res, { error: "name must be 1-40 word characters" }, 400);
      save(b.name, { picks: b.picks || [], private: !!b.private });
      return json(res, { saved: b.name });
    }
    if (url.pathname === "/selection") {
      const name = url.searchParams.get("name") || "";
      if (!/^[\w .-]+$/.test(name)) return json(res, { error: "bad name" }, 400);
      return json(res, load(name));
    }
    res.writeHead(404).end(); // e.g. /favicon.ico
  } catch (err) {
    json(res, { error: String(err.message || err) }, 500);
  }
});

server.on("error", (err) => {
  console.error(err.code === "EADDRINUSE" ? `port ${PORT} is taken; stop whatever is using it and retry` : String(err));
  process.exit(1);
});
server.listen(PORT, "127.0.0.1", () => {
  const url = `http://127.0.0.1:${PORT}`;
  console.log(url);
  if (process.stdout.isTTY) spawn("xdg-open", [url], { detached: true, stdio: "ignore" }).unref();
});
