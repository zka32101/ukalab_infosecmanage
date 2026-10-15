#!/usr/bin/env python3
"""問題・用語データの整合チェック(読み取り専用)。件数、ID重複、正解の範囲、選択肢の重複、
正解位置・正解の長さ・断定語の偏り、用語集の参照切れを確認する。
使い方: python3 docs/audit/verify_expansion.py [基準コミット(例: 5a36cac)]
基準コミットを渡すと、そのコミット時点の件数と比較し、既存問題が変更されていない(追加のみ)ことも確認する。
"""
import collections, json, subprocess, sys

QP, TP = 'assets/questions/info_security.jsonl', 'assets/terms/info_security.jsonl'

def parse(text):
    return [json.loads(l) for l in text.splitlines() if l.startswith('{')]

def load(path): return parse(open(path, encoding='utf-8').read())

Q, T = load(QP), load(TP)
base = sys.argv[1] if len(sys.argv) > 1 else None
ok = True

def fail(msg):
    global ok
    ok = False
    print('NG:', msg)

def count(qs, label):
    a = sum(q['subjectId'] == 'kamoku_a' for q in qs)
    b = sum(q['subjectId'] == 'kamoku_b' for q in qs)
    print(f'{label}: 合計 {len(qs)} (科目A {a} / 科目B {b})')
    return collections.Counter((q['subjectId'], q['topicId']) for q in qs)

newq = Q
if base:
    old = parse(subprocess.check_output(['git', 'show', f'{base}:{QP}'], text=True))
    oldt = parse(subprocess.check_output(['git', 'show', f'{base}:{TP}'], text=True))
    c0 = count(old, f'変更前({base})')
    print(f'用語: 変更前 {len(oldt)} -> 変更後 {len(T)}')
    oq = {q['qid']: q for q in old}
    for q in Q:
        if q['qid'] in oq and q != oq[q['qid']]:
            fail(f'既存問題が変更されている: {q["qid"]}')
    ot = {t['termId']: t for t in oldt}
    for t in T:
        if t['termId'] in ot:
            o = ot[t['termId']]
            # relatedQuestionIds への追記(既存IDを保ったまま末尾に足す)だけは許容する
            same = {k: v for k, v in t.items() if k != 'relatedQuestionIds'} == {k: v for k, v in o.items() if k != 'relatedQuestionIds'}
            kept = t['relatedQuestionIds'][:len(o['relatedQuestionIds'])] == o['relatedQuestionIds']
            if not (same and kept):
                fail(f'既存用語が変更されている: {t["termId"]}')
    newq = [q for q in Q if q['qid'] not in oq]
c1 = count(Q, '変更後')
if base:
    print('追加分:', len(newq))
    print('分野別の追加件数:')
    for k, v in sorted((c1 - c0).items()):
        print(f'  {k[0]}/{k[1]}: +{v}')
print('分野別の総数:')
for k, v in sorted(c1.items()):
    print(f'  {k[0]}/{k[1]}: {v}')

ids = [q['qid'] for q in Q]
dups = [k for k, v in collections.Counter(ids).items() if v > 1]
if dups: fail(f'qid重複: {dups}')
tids = [t['termId'] for t in T]
if len(set(tids)) != len(tids): fail('termId重複')
qset = set(ids)
for q in Q:
    ch = q['choices']
    if len(ch) != 4: fail(f'選択肢が4つでない: {q["qid"]}')
    if not (isinstance(q['answerIndex'], int) and 0 <= q['answerIndex'] < len(ch)): fail(f'正解が範囲外: {q["qid"]}')
    if len(set(ch)) != len(ch) or any(not c.strip() for c in ch): fail(f'選択肢の重複/空: {q["qid"]}')
    if q['subtopicId'] != f'{q["subjectId"]}-{q["topicId"]}': fail(f'subtopicId不整合: {q["qid"]}')
for q in newq:
    if q['subjectId'] == 'kamoku_b' and not any(t.startswith('scenario:s') for t in q.get('tags', [])): fail(f'追加した科目Bにscenarioタグなし: {q["qid"]}')
for t in T:
    for r in t['relatedQuestionIds']:
        if r not in qset: fail(f'用語 {t["termId"]} の relatedQuestionIds が存在しない: {r}')
    for r in t['relatedTermIds']:
        if r not in set(tids): fail(f'用語 {t["termId"]} の relatedTermIds が存在しない: {r}')
print('qid重複:', len(dups), '/ 4択でない・正解範囲外・選択肢重複: 上記NGを参照(無ければ0)')

ABS = ['すべて', '全て', '必ず', '常に', '絶対', '一切', '決して', '無条件', 'のみ', 'だけ', 'いかなる', '永久', '万全', 'あらゆる', '全く', '全員', '全従業員', '一度']
def bias(qs, label):
    pos = collections.Counter(q['answerIndex'] for q in qs)
    longest = sum(1 for q in qs if len(q['choices'][q['answerIndex']]) == max(map(len, q['choices'])))
    ge = sum(1 for q in qs if len(q['choices'][q['answerIndex']]) >= 1.5 * max(len(c) for i, c in enumerate(q['choices']) if i != q['answerIndex']))
    ac = aw = 0
    for q in qs:
        for i, c in enumerate(q['choices']):
            if any(w in c for w in ABS):
                if i == q['answerIndex']: ac += 1
                else: aw += 1
    n = len(qs)
    if n == 0:
        print(f'{label}(0問): 対象なし')
        return
    print(f'{label}({n}問): 正解位置 {[pos[i] for i in range(4)]} / 正解が最長(同率込み) {longest} ({longest/n:.0%}) / 次点の1.5倍以上 {ge} / 断定語を含む選択肢 正解{ac}・誤答{aw}')
bias(newq, '追加分')
bias([q for q in newq if q['subjectId'] == 'kamoku_a'], '追加分 科目A')
bias([q for q in newq if q['subjectId'] == 'kamoku_b'], '追加分 科目B')
print('結果:', 'OK' if ok else 'NG')
sys.exit(0 if ok else 1)
