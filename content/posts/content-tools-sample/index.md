---
title: "Content tools sample"
date: 2026-10-11
summary: "Draft that exercises bundled media, garden links, maths and Mermaid."
tags: [meta]
draft: true
---

A [garden note](garden:pages/bootloader), a [garden heading](garden:pages/bootloader/#intro), a [leading-slash garden link](garden:/pages/uses), an [internal link](/about/), and an [external link](https://gohugo.io).

This [unsafe link](javascript:alert(1)) must be neutralised by the link hook.

![A bundled GIF](demo.gif)

{{< video src="demo.mp4" >}}

Inline $\alpha$ and display:

$$ c(d) = 252\, e^{-\alpha (d - r)} $$

```mermaid
graph LR; a[Post] --> b[Garden]
```
