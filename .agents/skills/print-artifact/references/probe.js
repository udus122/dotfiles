// 版面の検証用。<head> の末尾に注入し、DOM ダンプから <pre id="METRICS"> を読む。
// はみ出し・最小フォント・安全域違反・ブロック高さ・画像解像度・キャプションの溢れを一度に出す。
(() => {
  const TRIM_MM = 3;   // 塗り足し
  const SAFE_MM = 5;   // 仕上がり線から内側に確保する余白
  window.addEventListener('load', () => setTimeout(() => {
    const MM = 96 / 25.4, mm = p => +(p / MM).toFixed(1), pt = p => +(p * 72 / 96).toFixed(1);
    const EDGE = (TRIM_MM + SAFE_MM) * MM;
    const sheets = [...document.querySelectorAll('.sheet')].map((s, i) => {
      const r = s.getBoundingClientRect();
      let minPt = 99, minEl = '', viol = [];
      s.querySelectorAll('*').forEach(el => {
        if (![...el.childNodes].some(n => n.nodeType === 3 && n.textContent.trim())) return;
        const b = el.getBoundingClientRect();
        const p = pt(parseFloat(getComputedStyle(el).fontSize));
        if (p < minPt) { minPt = p; minEl = (el.className || el.tagName) + ':' + el.textContent.trim().slice(0, 14); }
        const m = Math.min(b.left - r.left, r.right - b.right, b.top - r.top, r.bottom - b.bottom);
        if (m < EDGE) viol.push({ el: el.className || el.tagName, mm: +mm(m).toFixed(1), txt: el.textContent.trim().slice(0, 20) });
      });
      const blocks = [...s.children].map(c => ({ cls: c.className, h: mm(c.getBoundingClientRect().height) }));
      return {
        page: i + 1, size: [mm(r.width), mm(r.height)],
        overflow: mm(s.scrollHeight - s.clientHeight),
        minPt, minEl, viol: viol.slice(0, 8), blocks,
        total: +blocks.reduce((a, b) => a + b.h, 0).toFixed(1),
      };
    });
    const imgs = [...document.querySelectorAll('img')].map(im => ({
      src: (im.getAttribute('src') || '').slice(0, 60),
      nat: im.naturalWidth, mmW: mm(im.getBoundingClientRect().width),
      dpi: im.naturalWidth ? Math.round(im.naturalWidth / (im.getBoundingClientRect().width / MM) * 25.4) : 0,
    }));
    // overflow: hidden の中で溢れている行（nowrap のキャプションなど）
    const clipped = [...document.querySelectorAll('*')]
      .filter(el => el.scrollWidth - el.clientWidth > 2 && el.textContent.trim())
      .map(el => ({ el: el.className || el.tagName, over: mm(el.scrollWidth - el.clientWidth) }))
      .slice(0, 8);
    const pre = document.createElement('pre');
    pre.id = 'METRICS';
    pre.textContent = JSON.stringify({ sheets, imgs, clipped });
    document.body.appendChild(pre);
  }, 2000));
})();
