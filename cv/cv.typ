// CV rendered from ../data/cv.yaml (also read by Hugo's About page) and ../data/projects.yaml (the Project source).
// Public CV:      typst compile --root .. cv.typ cv.pdf
// Tailored CV:    add --input selection='[{slug, parts}]' (parts: compact, tags, highlights); cv/pick.mjs drives this.
// Private extras: add --input phone="…" --input address="…"
#import "@preview/modern-cv:0.9.0": *
#import "@preview/cmarker:0.1.6": render as md

#let cv = yaml("/data/cv.yaml")
#let projects = yaml("/data/projects.yaml")
#let opt(key) = { let v = sys.inputs.at(key, default: ""); if v == "" { none } else { v } }
#let inline(s) = md(s)

// Selection = the recipe for one Tailored CV (see GLOSSARY.md).
// No selection = every Project in full: the Public CV.
// parts: compact (one line, grouped after the full entries), tags, highlights. Role, dates and summary always show.
#let picks = {
  let s = opt("selection")
  if s == none { projects.map(p => (slug: p.slug, parts: ("tags", "highlights"))) }
  else { json(bytes(s)) }
}
#let chosen = picks.map(s => (p: projects.find(p => p.slug == s.slug), parts: s.parts)).filter(x => x.p != none)
#let month(s) = { let (y, m) = s.split("-"); datetime(year: int(y), month: int(m), day: 1).display("[month repr:long] [year]") }
#let span(p) = month(p.start) + " - " + if "end" in p { month(p.end) } else { "Present" }
// Newest first. A negated YYYYMM key sorts descending while keeping equal dates in source order (sorted is stable;
// sorting ascending then .rev() would flip the ties).
#let newest_first(xs) = xs.sorted(key: x => -int(x.p.start.replace("-", "")))

#let author = (
  firstname: cv.name.split(" ").first(),
  lastname: cv.name.split(" ").slice(1).join(" "),
  email: cv.email,
  github: cv.github,
  linkedin: cv.linkedin,
  positions: cv.positions,
)
#for key in ("phone", "address") { if opt(key) != none { author.insert(key, opt(key)) } }

#show: resume.with(
  author: author,
  profile-picture: none,
  date: datetime.today().display(),
  language: "en",
  colored-headers: true,
  show-footer: false,
  paper-size: "a4",
)

#let entry(e) = {
  // As in the original CV: GitHub repos sit in the location slot, other links (certificates, papers) on the title.
  let gh = "link" in e and e.link.starts-with("https://github.com/")
  resume-entry(
    title: e.title,
    location: if gh { github-link(e.link.trim("https://github.com/", at: start)) } else { e.at("location", default: "") },
    date: e.at("date", default: ""),
    description: e.at("description", default: ""),
    ..if "link" in e and not gh { (title-link: e.link) } else { (:) },
  )
  let tags = ("skills", "hardware", "software").filter(k => k in e)
  if "highlights" in e or tags.len() > 0 {
    resume-item[
      #for h in e.at("highlights", default: ()) [- #inline(h)
      ]
      #for k in tags [*#upper(k.first())#k.slice(1)*: #e.at(k).join(" · ")

      ]
    ]
  }
}

= Professional Brief
#resume-item[
  #for s in cv.summary [- #inline(s)
  ]
]

#let section(title, key) = if key in cv [
  = #title
  #for e in cv.at(key) { entry(e) }
]

#section("Experience", "experience")

= Projects
#let full = newest_first(chosen.filter(x => "compact" not in x.parts))
#let compact = newest_first(chosen.filter(x => "compact" in x.parts))
#for x in full {
  let (p, parts) = (x.p, x.parts)
  let gh = p.link.starts-with("https://github.com/")
  resume-entry(
    title: p.at("title", default: p.name),
    location: if gh { github-link(p.link.trim("https://github.com/", at: start)) } else { "" },
    date: span(p),
    description: p.at("role", default: ""),
    ..if not gh { (title-link: p.link) } else { (:) },
  )
  let bullets = (p.summary,) + if "highlights" in parts { p.at("highlights", default: ()) } else { () }
  resume-item[
    #for h in bullets [- #inline(h)
    ]
    // parbreak: without a list to end the paragraph, the tags line would run on after the summary
    #if "tags" in parts and "tags" in p [#parbreak()*Tags*: #p.tags.join(" · ")]
  ]
}
// one line each: linked title · summary, dates on the right. The short name replaces a title that won't fit.
#for x in compact {
  let (p, parts) = (x.p, x.parts)
  let date = span(p)
  layout(size => {
    let long = [#link(p.link)[*#p.at("title", default: p.name)*] · #p.summary]
    let short = [#link(p.link)[*#p.name*] · #p.summary]
    let gap = measure[#h(2em)].width  // measured, so the gutter stays in em and still compares in pt
    let fits = measure(long).width + measure(date).width + gap <= size.width
    block(above: 0.6em, below: 0.6em, grid(columns: (1fr, auto), column-gutter: 1em,
      if fits { long } else { short }, text(size: 0.9em, fill: luma(90), date)))
  })
}
#section("Professional Certification", "certifications")
#section("Publications", "publications")
#section("Education", "education")

= Languages
#for l in cv.languages {
  resume-skill-item(l.category, l.items.map(i => if i.strong { strong(i.name) } else { i.name }))
}

// Page count and how full the last page is, for the picker's budget feedback (issue #20).
#context [#metadata((pages: counter(page).final().first(), fill: int(calc.round(here().position().y / page.height * 100)))) <pages>]
// Which Projects the CV actually contains, in order.
#metadata((full + compact).map(x => x.p.slug)) <chosen>
