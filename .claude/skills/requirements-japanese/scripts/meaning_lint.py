# /// script
# requires-python = ">=3.10"
# dependencies = [
#     "sudachipy>=0.6.8",
#     "sudachidict-core>=20240409",
# ]
# ///
"""meaning_lint.py — 「誰が・何を・どうした」を復元しにくい文の疑いを機械的に挙げる。

natural-japanese の lint.py が見る表層の癖とは別に、意味の欠落につながりやすい
形を拾う。直すかどうかはエージェントが文脈を見て決める。検出件数に関わらず
exit code は 0、ファイルが読めないなどの入力エラーだけ 1 にする(lint.py と同じ)。

使い方:
    uv run scripts/meaning_lint.py <file.md> [--json]

各文を「要件本文」(〜こと。で終わる文、要件 ID で始まる行)と「説明」に分け、
要件本文で見つかった装飾の疑いは severity を critical に上げる。
"""

from __future__ import annotations

import argparse
import dataclasses
import json
import re
import sys
from pathlib import Path

# 比喩に使われやすい動詞(辞書形)。どれも字義どおりに使う文脈があるので、疑いとして挙げるだけにする
METAPHOR_VERBS = {
    "倒す", "倒れる", "壊す", "壊れる", "効く", "効かせる", "添える", "引き返す",
    "寄せる", "振る", "握る", "握りつぶす", "溶かす", "溶ける", "回す", "刺さる",
    "畳む", "育つ", "育てる", "噛ませる", "跨ぐ", "吐く", "叩く", "投げる",
    "捌く", "潰す", "寝かせる", "逃がす", "拾う", "死ぬ", "生きる", "走らせる",
    "浮く", "沈む", "滲む", "寄り添う", "紐付く", "痩せる", "太る",
}

# 動作を名詞に包んで、何をするかが消えやすい言い方
ABSTRACT_ACTION_RE = re.compile(
    r"(担保|実現|寄与|推進|強化|醸成|促進|高度化|最適化|具現化|下支え)(する|します|し[てた]|させ|を図)"
)

# 要件本文で検証できなくなる曖昧語
VAGUE_REQUIREMENT_RE = re.compile(
    r"適切に|適切な|適宜|柔軟に|迅速に|速やかに|必要に応じて|十分な|十分に|可能な限り|"
    r"なるべく|容易に|簡単に|効率的に|直感的に|スムーズに|シームレスに|等|など"
)

# 「片方」「残さない側」のように、何を指すかが文の外にある言い方
# 「受け取る側」のように役割を指す「側」は残し、「〜側に倒す」のように向きとして使う「側に・側へ」だけを拾う
VAGUE_REFERENCE_RE = re.compile(r"もう片方|片方|(?:[ぁ-ん])側(?=[にへ])")

REQUIREMENT_ID_RE = re.compile(r"^\s*(?:\|\s*)?[A-Z]{1,4}[-_]?\d{1,4}\b")
NEGATIVE_END_RE = re.compile(r"(ない|ません|ず|ぬ|なかった|ませんでした)$")
SENTENCE_END_RE = re.compile(r"(?<=[。！？!?])")
SHORT_SENTENCE_LEN = 16
EMPHATIC_PHRASE_LEN = 5

# 対句の判定で、共通語として数えない語(辞書形)
COUPLET_STOP_LEMMAS = {"する", "ある", "いる", "なる", "できる", "こと", "もの", "ため", "よう"}

SEVERITY_ORDER = {"info": 0, "warn": 1, "critical": 2}


@dataclasses.dataclass
class Sentence:
    text: str
    line: int
    paragraph: int
    kind: str  # "requirement" | "explanation"
    in_table: bool


@dataclasses.dataclass
class Finding:
    rule: str
    severity: str
    line: int
    kind: str
    excerpt: str
    detail: str
    fix: str


_tokenizer = None


def tokenize(text: str):
    global _tokenizer
    if _tokenizer is None:
        from sudachipy import Dictionary

        _tokenizer = Dictionary().tokenizer()
    return _tokenizer.tokenize(text)


def strip_markup(line: str) -> str:
    """見出し記号・箇条書き記号・表の区切り・強調記号を外し、文だけを残す。"""
    s = re.sub(r"^\s*#{1,6}\s+", "", line)
    s = re.sub(r"^\s*(?:[-*+]|\d+[.)])\s+(?:\[[ xX]\]\s+)?", "", s)
    s = re.sub(r"^\s*>\s?", "", s)
    s = s.replace("**", "").replace("__", "")
    s = re.sub(r"`[^`]*`", "", s)
    s = re.sub(r"\[([^\]]*)\]\([^)]*\)", r"\1", s)
    if s.strip().startswith("|"):
        cells = [c.strip() for c in s.strip().strip("|").split("|")]
        if all(re.fullmatch(r":?-{2,}:?", c) for c in cells if c):
            return ""
        s = "。".join(c for c in cells if c)
    return s.strip()


def iter_paragraphs(text: str):
    """(段落の文字列, 先頭行の番号) を返す。見出し・箇条書きの1項目・表の1行は単独の段落にする。"""
    lines = text.splitlines()
    in_fence = False
    in_front_matter = bool(lines) and lines[0].strip() == "---"
    in_comment = False
    buf: list[str] = []
    buf_start = 0

    def flush():
        nonlocal buf
        if buf:
            yield_value = (" ".join(buf), buf_start)
            buf = []
            return yield_value
        return None

    for no, raw in enumerate(lines, start=1):
        stripped = raw.strip()
        if in_front_matter:
            if no > 1 and stripped == "---":
                in_front_matter = False
            continue
        if in_comment:
            if "-->" in stripped:
                in_comment = False
            continue
        if stripped.startswith("<!--"):
            if "-->" not in stripped:
                in_comment = True
            continue
        if stripped.startswith("```") or stripped.startswith("~~~"):
            in_fence = not in_fence
            if (v := flush()):
                yield v
            continue
        if in_fence:
            continue
        if not stripped:
            if (v := flush()):
                yield v
            continue
        is_block_item = bool(
            re.match(r"^\s*(#{1,6}\s|[-*+]\s|\d+[.)]\s|\|)", raw)
        )
        if is_block_item:
            if (v := flush()):
                yield v
            yield (raw, no)
            continue
        if not buf:
            buf_start = no
        buf.append(stripped)
    if (v := flush()):
        yield v


def classify(raw_line: str, sentence: str) -> str:
    body = sentence.rstrip("。．. 　")
    if body.endswith("こと") or REQUIREMENT_ID_RE.match(raw_line):
        return "requirement"
    return "explanation"


def split_sentences(text: str) -> list[Sentence]:
    sentences: list[Sentence] = []
    for p_index, (raw, line) in enumerate(iter_paragraphs(text)):
        cleaned = strip_markup(raw)
        if not cleaned:
            continue
        for part in SENTENCE_END_RE.split(cleaned):
            part = part.strip()
            if not part or not re.search(r"[ぁ-んァ-ヶ一-龠]", part):
                continue
            sentences.append(Sentence(part, line, p_index, classify(raw, part), raw.lstrip().startswith("|")))
    return sentences


def bare_len(sentence: str) -> int:
    return len(re.sub(r"[、。，．,.！？!?\s]", "", sentence))


def content_lemmas(sentence: str) -> set[str]:
    lemmas = set()
    for m in tokenize(sentence):
        pos = m.part_of_speech()
        if pos[0] in ("名詞", "動詞", "形容詞") and pos[1] != "数詞":
            lemma = m.dictionary_form()
            if lemma in COUPLET_STOP_LEMMAS:
                continue
            if pos[0] == "動詞" or len(lemma) > 1:
                lemmas.add(lemma)
    return lemmas


def raise_for_requirement(severity: str, kind: str) -> str:
    return "critical" if kind == "requirement" else severity


def check_sentence(s: Sentence) -> list[Finding]:
    found: list[Finding] = []

    for m in tokenize(s.text):
        if m.part_of_speech()[0] == "動詞" and m.dictionary_form() in METAPHOR_VERBS:
            found.append(Finding(
                "metaphor_verb", raise_for_requirement("warn", s.kind), s.line, s.kind,
                f"{m.surface()}（{m.dictionary_form()}）",
                "比喩に使われやすい動詞。何を・どう変えるのかを読み手が補うことになっていないか",
                "主体・対象・動作を、本文にある名前と字義どおりの動詞で書く。字義どおりの用法や、書き言葉として定着した技術用語(「キャッシュが効く」)なら残す",
            ))

    for m in VAGUE_REFERENCE_RE.finditer(s.text):
        found.append(Finding(
            "vague_reference", raise_for_requirement("warn", s.kind), s.line, s.kind,
            s.text[max(0, m.start() - 6): m.end() + 2],
            "指すものが文の外にある言い方。「片方」「〜側」が何かを読み手が推測することになる",
            "指している対象を名前で書く(「開発速度」「保存しない項目」など)。本文から言えなければ【要確認】で聞く",
        ))

    m = re.match(r"([^、]{1,%d})を、" % EMPHATIC_PHRASE_LEN, s.text)
    if m:
        found.append(Finding(
            "emphatic_comma", raise_for_requirement("warn", s.kind), s.line, s.kind,
            s.text[: m.end() + 8],
            "文頭の短い目的語の直後の読点。区切りの位置ではなく強調として打たれている疑い",
            "読点を外し、目的語と動詞をつなげて読めるかを確かめる。動作の主体が抜けていれば補う",
        ))

    for m in ABSTRACT_ACTION_RE.finditer(s.text):
        found.append(Finding(
            "abstract_action", "warn" if s.kind == "requirement" else "info", s.line, s.kind,
            s.text[max(0, m.start() - 8): m.end()],
            "動作を抽象的な名詞に包んだ言い方。誰が何をすれば達成になるのかが見えない",
            "「〜を担保する」「〜を実現する」を、具体的な操作や状態(何を保存する、何秒以内に返す)に書き直す",
        ))

    if s.kind == "requirement":
        for m in VAGUE_REQUIREMENT_RE.finditer(s.text):
            found.append(Finding(
                "vague_requirement_term", "warn", s.line, s.kind, m.group(0),
                "要件本文の曖昧語。満たしたかどうかを第三者が判定できない",
                "数値・条件・列挙で置き換える(「迅速に」→「5秒以内に」、「等」→対象を列挙)。値が決まっていなければ【要確認】で残す",
            ))
    return found


def check_couplets(sentences: list[Sentence]) -> list[Finding]:
    """同じ段落で隣り合う短文の組のうち、否定→肯定の対比か、語を入れ替えた対句を挙げる。"""
    found: list[Finding] = []
    for a, b in zip(sentences, sentences[1:]):
        # 表の1行はセルを文として並べているだけなので、対句として見ない
        if a.paragraph != b.paragraph or a.in_table:
            continue
        if bare_len(a.text) > SHORT_SENTENCE_LEN or bare_len(b.text) > SHORT_SENTENCE_LEN:
            continue
        a_body = a.text.rstrip("。！？!?")
        negative_first = bool(NEGATIVE_END_RE.search(a_body))
        shared = content_lemmas(a.text) & content_lemmas(b.text)
        if not negative_first and not shared:
            continue
        kind = "requirement" if "requirement" in (a.kind, b.kind) else "explanation"
        reason = "短い否定文で次の短文を強めている" if negative_first else f"同じ語({'・'.join(sorted(shared))})を入れ替えた対句になっている"
        found.append(Finding(
            "short_couplet", raise_for_requirement("critical" if negative_first else "warn", kind), a.line, kind,
            f"{a.text}{b.text}",
            f"{reason}。内容より調子が先に立ち、対象・条件・主体が省かれやすい",
            "2文の関係(理由・条件・対比)が本文から言えるなら1文につなぎ、省かれた対象・条件・主体を本文から補う。言えなければ分けたまま、関係と欠けた要素を【要確認】で聞く。元にない接続の言葉は足さない",
        ))
    return found


def run(text: str) -> tuple[list[Finding], dict]:
    sentences = split_sentences(text)
    findings: list[Finding] = []
    for s in sentences:
        findings.extend(check_sentence(s))
    findings.extend(check_couplets(sentences))
    findings.sort(key=lambda f: (f.line, -SEVERITY_ORDER[f.severity]))
    stats = {
        "sentences": len(sentences),
        "requirement_sentences": sum(1 for s in sentences if s.kind == "requirement"),
        "by_rule": {},
        "by_kind": {"requirement": 0, "explanation": 0},
        "requirement_critical": sum(1 for f in findings if f.kind == "requirement" and f.severity == "critical"),
    }
    for f in findings:
        stats["by_rule"][f.rule] = stats["by_rule"].get(f.rule, 0) + 1
        stats["by_kind"][f.kind] += 1
    return findings, stats


def main() -> int:
    parser = argparse.ArgumentParser(description="意味の欠落につながりやすい文の形を挙げる")
    parser.add_argument("file", type=Path)
    parser.add_argument("--json", action="store_true", help="機械可読な JSON で出力する")
    args = parser.parse_args()

    if not args.file.is_file():
        print(f"エラー: ファイルが見つかりません: {args.file}", file=sys.stderr)
        return 1
    try:
        text = args.file.read_text(encoding="utf-8")
    except (OSError, UnicodeDecodeError) as e:
        print(f"エラー: 読み込めません: {args.file}: {e}", file=sys.stderr)
        return 1

    findings, stats = run(text)
    if args.json:
        print(json.dumps(
            {"file": str(args.file), "stats": stats, "findings": [dataclasses.asdict(f) for f in findings]},
            ensure_ascii=False, indent=2,
        ))
        return 0

    label = {"info": "情報", "warn": "警告", "critical": "重要"}
    kind_label = {"requirement": "要件本文", "explanation": "説明"}
    print(f"=== meaning_lint: {args.file} ===")
    print(f"文の数: {stats['sentences']}(うち要件本文 {stats['requirement_sentences']})")
    print(f"検出件数: {len(findings)}(要件本文の重要 {stats['requirement_critical']})")
    for rule, n in sorted(stats["by_rule"].items()):
        print(f"  - {rule}: {n}")
    for f in findings:
        print(f"\n[{label[f.severity]}] L{f.line} ({f.rule} / {kind_label[f.kind]})")
        print(f"    該当箇所: {f.excerpt}")
        print(f"    詳細    : {f.detail}")
        print(f"    直し方  : {f.fix}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
