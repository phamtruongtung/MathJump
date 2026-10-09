// Mô phỏng cơ chế "quỹ thời gian" của Math Jump để chọn thông số.
// Chạy: dán toàn bộ file vào tab Console của trình duyệt, rồi gọi
//   console.table(report(PARAMS))
// hoặc `node tools/simulate_timebank.js` nếu máy có Node.js.
//
// Mô hình (khớp với code game):
//  - Độ khó câu (giây suy nghĩ của người lớn): cộng trừ 0,8 + 0,7 × (số chữ số − 1)
//    (+0,3 nếu trừ); nhân chia theo thừa số lớn nhất; câu điền dấu +0,4.
//    → Question.difficulty trong lib/game/question.dart
//  - Thời gian riêng của câu = (1 + độ khó) × tốc độ chuẩn của hạng × hệ số level
//    (siết 25% từ level 1 → 20, sau đó ×0,97 mỗi level, tối thiểu 1,2 giây).
//    → Rank.questionTime trong lib/game/rank.dart
//  - Đúng sớm: phần dư cộng vào quỹ; quá giờ: trừ vào quỹ. Thua khi sai hoặc quỹ = 0.
//  - Người chơi: thời gian giải = (1 + độ khó × hệ số "lạ") × tốc độ người chơi,
//    nhiễu log-normal; tỉ lệ sai tăng khi câu lạ với người chơi.

const RANKS = [ // [addStart, addEnd, fMin, fStart, fEnd, weights, subFrom, mulFrom, divFrom, promoteLevel, promoteScore]
  [10, 50, 2, 2, 2, [50, 50, 0, 0], 2, 1e9, 1e9, 8, 500],
  [10, 100, 2, 5, 9, [40, 40, 12, 8], 2, 4, 6, 10, 700],
  [20, 200, 2, 9, 10, [35, 35, 18, 12], 1, 2, 3, 12, 1000],
  [50, 500, 2, 10, 12, [30, 30, 22, 18], 1, 1, 1, 14, 1300],
  [100, 1000, 3, 12, 15, [25, 25, 25, 25], 1, 1, 1, 16, 1650],
  [200, 2000, 4, 15, 20, [25, 25, 25, 25], 1, 1, 1, 18, 2050],
  [500, 5000, 6, 20, 25, [25, 25, 25, 25], 1, 1, 1, null, null],
];
const NAMES = ['Tân Binh', 'Đồng', 'Bạc', 'Vàng', 'Bạch Kim', 'Kim Cương', 'Huyền Thoại'];

const PLAYERS = {
  'Bé lớp 1': { speed: 3.2, comfortAdd: 20, knowsMul: 0, err: 0.035 },
  'Bé lớp 3': { speed: 2.0, comfortAdd: 100, knowsMul: 9, err: 0.022 },
  'Người lớn': { speed: 1.15, comfortAdd: 1000, knowsMul: 10, err: 0.012 },
  'Cao thủ': { speed: 0.75, comfortAdd: 10000, knowsMul: 15, err: 0.006 },
};

// Thông số đã chốt (phiên bản dùng quỹ thời gian).
const PARAMS = {
  S: [4.0, 2.4, 1.8, 1.4, 1.15, 0.95, 0.85], // Rank.speed
  levelTighten: 0.25, lateDecay: 0.97, floor: 1.2,
  bank0: 20, levelBonus: 5, rankBonus: 20,
};

function makeRng(seed) { let s = seed >>> 0; return () => ((s = (s * 1664525 + 1013904223) >>> 0) / 4294967296); }
function gauss(r) { return Math.sqrt(-2 * Math.log(r() || 1e-9)) * Math.cos(2 * Math.PI * r()); }
const prog = (L) => Math.min(1, (L - 1) / 19);

function pickOp(rank, L, r) {
  const R = RANKS[rank];
  const w = [R[5][0], L >= R[6] ? R[5][1] : 0, L >= R[7] ? R[5][2] : 0, L >= R[8] ? R[5][3] : 0];
  let x = r() * w.reduce((a, b) => a + b);
  for (let i = 0; i < 4; i++) { if (x < w[i]) return i; x -= w[i]; }
  return 0;
}

function question(rank, L, op, p, r) {
  const R = RANKS[rank];
  const addMax = R[0] + (R[1] - R[0]) * prog(L);
  const fMax = R[3] + (R[4] - R[3]) * prog(L);
  let base, hard = 1;
  if (op <= 1) {
    const n = addMax * (0.4 + 0.6 * r());
    const digits = Math.max(1, Math.ceil(Math.log10(n + 1)));
    base = 0.8 + 0.7 * (digits - 1) + (op === 1 ? 0.3 : 0);
    if (n > p.comfortAdd) hard = 1 + Math.log2(n / p.comfortAdd);
  } else {
    const f = R[2] + (fMax - R[2]) * r();
    base = f <= 5 ? 1.0 : f <= 10 ? 1.4 : f <= 12 ? 2.0 : 2.5 + (f - 12) * 0.5;
    if (op === 3) base += 0.4;
    if (f > p.knowsMul) hard = p.knowsMul === 0 ? 4 : 1 + (f - p.knowsMul) * 0.35;
  }
  if (r() < 0.2) base += 0.4;
  return { base, hard };
}

function qTime(P, rank, base, L) {
  let k = 1 - P.levelTighten * prog(L);
  if (L > 20) k *= Math.pow(P.lateDecay, L - 20);
  return Math.max(P.floor, (1 + base) * P.S[rank] * k);
}

function playGame(P, p, startRank, r) {
  let rank = startRank, L = 1, score = 0, lp = 0, bank = P.bank0, elapsed = 0, answered = 0, promotions = 0, maxBank = bank;
  for (let guard = 0; guard < 5000; guard++) {
    const op = pickOp(rank, L, r);
    const q = question(rank, L, op, p, r);
    const t = (1 + q.base * q.hard) * p.speed * Math.exp(0.35 * gauss(r));
    const T = qTime(P, rank, q.base, L);
    if (t > T && t - T >= bank) { elapsed += T + bank; return { why: 'time', elapsed, answered, rank, L, promotions, maxBank }; }
    elapsed += t;
    if (r() < Math.min(0.5, p.err * q.hard)) return { why: 'wrong', elapsed, answered, rank, L, promotions, maxBank };
    bank += T - t; answered++;
    const gain = 10 + Math.round(Math.max(0, (T - t) / T) * 5);
    score += gain; lp += gain;
    const goal = 30 + (L - 1) * 10;
    if (lp >= goal) { lp -= goal; L++; bank += P.levelBonus; }
    const R = RANKS[rank];
    if (R[9] && L >= R[9] && score >= R[10]) { rank++; promotions++; L = 1; score = 0; lp = 0; bank += P.rankBonus; }
    maxBank = Math.max(maxBank, bank);
  }
  return { why: 'cap', elapsed, answered, rank, L, promotions, maxBank };
}

const median = a => { const s = [...a].sort((x, y) => x - y); return s[Math.floor(s.length / 2)]; };
const pct = (a, q) => { const s = [...a].sort((x, y) => x - y); return s[Math.floor(s.length * q)]; };

function report(P = PARAMS, games = 1500) {
  const rows = [];
  for (const [name, p] of Object.entries(PLAYERS)) {
    for (let rank = 0; rank < 7; rank++) {
      const r = makeRng(7 + rank * 101 + name.length * 13);
      const res = Array.from({ length: games }, () => playGame(P, p, rank, r));
      const mins = res.map(x => x.elapsed / 60);
      rows.push({
        'người chơi': name, 'hạng': NAMES[rank],
        'phút (trung vị)': +median(mins).toFixed(1),
        'phút (90%)': +pct(mins, 0.9).toFixed(1),
        'câu đúng': median(res.map(x => x.answered)),
        'level cuối': median(res.map(x => x.L)),
        'thăng hạng %': Math.round(100 * res.filter(x => x.promotions > 0).length / games),
        'thua vì hết giờ %': Math.round(100 * res.filter(x => x.why === 'time').length / games),
        'quỹ lớn nhất': Math.round(median(res.map(x => x.maxBank))),
      });
    }
  }
  return rows;
}

if (typeof module !== 'undefined' && require.main === module) console.table(report());
if (typeof module !== 'undefined') module.exports = { report, PARAMS };
