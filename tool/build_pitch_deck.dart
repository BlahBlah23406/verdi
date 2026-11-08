// Legacy deck generator. Current VC deck: docs/Verdi-VC-Product-Update.pptx.
// Generates a self-contained, printable deck from the reviewed Markdown source.
import 'dart:convert';
import 'dart:io';

void main() {
  const escape = HtmlEscape();
  final source = File('docs/PITCH_DECK.md').readAsStringSync();
  final slides = source.split(RegExp(r'(?=## Slide \d+ — )')).skip(1).toList();
  if (slides.length != 11) throw StateError('Expected 11 slides.');
  final sections = <String>[];
  for (var i = 0; i < slides.length; i++) {
    final lines = const LineSplitter().convert(slides[i]);
    final title = lines.first.replaceFirst(RegExp(r'## Slide \d+ — '), '');
    final headline = lines.firstWhere((line) => line.startsWith('**'));
    final bullets = lines.where((line) => line.startsWith('- '));
    final notes = lines.firstWhere((line) => line.startsWith('Speaker note:'));
    final evidence = lines.firstWhere((line) => line.startsWith('Evidence:'));
    sections.add('''<section class="slide" id="slide-${i + 1}">
<div class="top"><span>VERDI / ${escape.convert(title)}</span><span>${i + 1} / 11</span></div>
<h1>${escape.convert(headline.replaceAll('**', ''))}</h1>
<ul>${bullets.map((line) => '<li>${escape.convert(line.substring(2))}</li>').join()}</ul>
<details><summary>Presenter notes &amp; repository evidence</summary><p>${escape.convert(notes)}</p><p>${escape.convert(evidence)}</p></details>
<div class="bottom">WORKING PROTOTYPE · ${i == 0 ? 'PERSONAL CARBON TRACKING' : 'IMPLEMENTED FEATURES AND ROADMAP ARE DISTINGUISHED'}</div>
</section>''');
  }
  File('docs/PITCH_DECK.html').writeAsStringSync('''<!doctype html>
<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Verdi — Pitch deck (11 slides)</title>
<style>
*{box-sizing:border-box}html{scroll-snap-type:y proximity}body{margin:0;background:#e6ecdf;color:#174c38;font:20px/1.5 system-ui,sans-serif}.slide{min-height:100vh;max-width:1400px;margin:auto;padding:65px 8vw;display:flex;flex-direction:column;scroll-snap-align:start;border-bottom:1px solid #cad6c9;background:#f6f7f2}.slide:nth-child(3n+1){background:#174c38;color:#f6f7f2}.top,.bottom{display:flex;justify-content:space-between;font-size:12px;letter-spacing:2px}.bottom{margin-top:auto;padding-top:25px;font-size:10px}h1{font-size:clamp(32px,4.3vw,62px);line-height:1.13;letter-spacing:-2px;font-weight:600;max-width:1000px;margin:50px 0 30px}ul{padding-left:24px;max-width:1000px;margin-bottom:30px}li{margin:14px 0}details{font-size:13px;opacity:.85;margin:10px 0 20px}summary{cursor:pointer}p{overflow-wrap:anywhere}nav{position:fixed;bottom:14px;right:20px;display:flex;gap:8px}button{font:14px system-ui;border:1px solid #174c38;border-radius:4px;background:#fff;color:#174c38;padding:8px 14px;cursor:pointer}button:focus-visible,summary:focus-visible{outline:3px solid #ba7a2d;outline-offset:4px}@media(max-width:650px){.slide{padding:35px 24px 70px}body{font-size:17px}.top{font-size:10px;gap:20px}h1{letter-spacing:-1px}.bottom{letter-spacing:1px}}@media print{@page{size:landscape;margin:0}html{scroll-snap-type:none}body{background:white;font-size:16pt;-webkit-print-color-adjust:exact;print-color-adjust:exact}.slide{height:100vh;min-height:0;max-width:none;break-after:page;padding:30px 55px;border:0;overflow:hidden}.slide:last-of-type{break-after:auto}h1{font-size:32pt;margin:30px 0 18px}li{margin:8px 0}details,nav{display:none}.bottom{font-size:8pt}}
</style></head><body>${sections.join('\n')}
<nav aria-label="Slides"><button id="previous" aria-label="Previous slide">←</button><button id="next" aria-label="Next slide">→</button><button onclick="window.print()">Print / PDF</button></nav>
<script>
const slides=[...document.querySelectorAll('.slide')];
function move(delta){const index=slides.reduce((best,s,i)=>Math.abs(s.getBoundingClientRect().top)<Math.abs(slides[best].getBoundingClientRect().top)?i:best,0);const target=slides[Math.max(0,Math.min(slides.length-1,index+delta))];target.scrollIntoView();history.replaceState(null,'','#'+target.id);}
document.getElementById('previous').onclick=()=>move(-1);document.getElementById('next').onclick=()=>move(1);
document.addEventListener('keydown',e=>{if(['ArrowRight','PageDown','ArrowLeft','PageUp'].includes(e.key)){e.preventDefault();move(['ArrowRight','PageDown'].includes(e.key)?1:-1);}});
</script></body></html>''');
  stdout.writeln('Generated docs/PITCH_DECK.html: 11 slides.');
}
