// CV rendered from ../data/cv.yaml (the single source of truth, also read by Hugo's About page).
// Public build:   typst compile --root .. cv.typ cv.pdf
// Private extras: typst compile --root .. --input phone="…" --input address="…" cv.typ cv-full.pdf
#import "@preview/modern-cv:0.9.0": *
#import "@preview/cmarker:0.1.6": render as md

#let cv = yaml("/data/cv.yaml")
#let opt(key) = { let v = sys.inputs.at(key, default: ""); if v == "" { none } else { v } }
#let inline(s) = md(s)

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
#section("Projects", "projects")
#section("Professional Certification", "certifications")
#section("Publications", "publications")
#section("Education", "education")

= Languages
#for l in cv.languages {
  resume-skill-item(l.category, l.items.map(i => if i.strong { strong(i.name) } else { i.name }))
}
