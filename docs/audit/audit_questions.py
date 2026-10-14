#!/usr/bin/env python3
"""問題データの機械的検査(読み取り専用)。事実の正誤は判定しない。
使い方: python3 docs/audit/audit_questions.py > docs/audit/audit_result.json
"""
import json, re, sys, collections, itertools, unicodedata

def load(p):
    return [json.loads(l) for l in open(p, encoding='utf-8') if l.startswith('{')]

Q = load('assets/questions/info_security.jsonl')
T = load('assets/terms/info_security.jsonl')
res = collections.defaultdict(list)

def norm(s):
    s = unicodedata.normalize('NFKC', s)
    return re.sub(r'[\s、。,.「」『』（）()・]', '', s).lower()

def bigrams(s):
    s = norm(s)
    return {s[i:i+2] for i in range(len(s)-1)} or {s}

ABS = ['すべて', '全て', '必ず', '常に', '絶対', '一切', '決して', '無条件', '完全に防', '100%', '100％', 'のみ', 'だけ', '一度も', 'いかなる', '永久', '万全']
NEG = re.compile(r'(適切でない|適切でな|誤っている|誤り|不適切|該当しない|当てはまらない|含まれない|ふさわしくない|問題があるもの|避けるべき|行ってはならない)')

for q in Q:
    qid, ch, a = q['qid'], q['choices'], q['answerIndex']
    if not isinstance(a, int) or not (0 <= a < len(ch)):
        res['answer_out_of_range'].append(qid); continue
    # 選択肢の重複
    ns = [norm(c) for c in ch]
    if len(set(ns)) < len(ns):
        res['dup_choices'].append(qid)
    # 空の選択肢
    if any(not c.strip() for c in ch):
        res['empty_choice'].append(qid)
    # 類似(同義疑い): 正解と他選択肢のbigram Jaccard
    cb = bigrams(ch[a])
    for i, c in enumerate(ch):
        if i == a: continue
        b = bigrams(c)
        j = len(cb & b) / max(1, len(cb | b))
        if j >= 0.6:
            res['similar_to_correct'].append((qid, i, round(j, 2)))
    # 解説と正解の食い違い疑い: 解説が不正解選択肢の全文(6字以上)を含み正解全文を含まない
    ex = q['explanation']
    nex = norm(ex)
    wrong_hits = [i for i, c in enumerate(ch) if i != a and len(norm(c)) >= 6 and norm(c) in nex]
    right_hit = len(norm(ch[a])) >= 6 and norm(ch[a]) in nex
    if wrong_hits and not right_hit:
        res['explanation_quotes_wrong_choice_only'].append((qid, wrong_hits))
    # 解説内に「正解は X」「答えは X」型
    m = re.search(r'(正解|答え)は[「]?([^。、」]{1,30})', ex)
    if m:
        res['explanation_states_answer'].append((qid, m.group(2)))
    # 否定形の設問(解説との整合は人手確認用の列挙)
    if NEG.search(q['prompt']):
        res['negative_prompt'].append(qid)
    # 断定語
    absc = [i for i, c in enumerate(ch) if any(w in c for w in ABS)]
    if absc:
        res['absolute_words'].append((qid, absc, a))
    # 長さ
    L = [len(c) for c in ch]
    mx = max(L)
    top_idx = [i for i, l in enumerate(L) if l == mx]
    if L[a] == mx:
        res['correct_longest_incl_tie'].append(qid)
        if len(top_idx) == 1:
            res['correct_longest_strict'].append(qid)
    others = sorted([l for i, l in enumerate(L) if i != a], reverse=True)
    if L[a] >= 1.5 * others[0]:
        res['correct_ge_1.5x_runnerup'].append(qid)
    # 空白・全角英数
    for c in [q['prompt']] + ch + [ex]:
        if re.search(r'[Ａ-Ｚａ-ｚ０-９]', c):
            res['fullwidth_alnum'].append(qid); break
# 問題文の重複
cnt = collections.Counter(norm(q['prompt']) + '|' + '|'.join(sorted(norm(c) for c in q['choices'])) for q in Q)
dups = [k for k, v in cnt.items() if v > 1]
for q in Q:
    k = norm(q['prompt']) + '|' + '|'.join(sorted(norm(c) for c in q['choices']))
    if k in dups: res['duplicate_question'].append(q['qid'])
pc = collections.Counter(norm(q['prompt']) for q in Q)
for q in Q:
    if pc[norm(q['prompt'])] > 1: res['same_prompt'].append(q['qid'])
qc = collections.Counter(q['qid'] for q in Q)
res['dup_qid'] = [k for k, v in qc.items() if v > 1]

# 表記ゆれ
alltext = {q['qid']: ' '.join([q['prompt'], q['explanation']] + q['choices']) for q in Q}
alltext.update({t['termId']: ' '.join([t['term'], t['headline'], t['definition']]) for t in T})
VAR = {
 'ウイルス/ウィルス': ['ウイルス', 'ウィルス'],
 'サーバ/サーバー': [r'サーバ(?!ー)', 'サーバー'],
 'ユーザ/ユーザー': [r'ユーザ(?!ー)', 'ユーザー'],
 'コンピュータ/コンピューター': [r'コンピュータ(?!ー)', 'コンピューター'],
 'ブラウザ/ブラウザー': [r'ブラウザ(?!ー)', 'ブラウザー'],
 'ファイアウォール/ファイヤーウォール': ['ファイアウォール', 'ファイヤー?ウォール'],
 'フィッシング/フィシング': ['フィッシング', 'フィシング'],
 'ログイン/ログオン': ['ログイン', 'ログオン'],
 'バックアップ/バックアップ': ['バックアップ', 'バックアツプ'],
 'CSRF': ['CSRF', 'クロスサイトリクエストフォージェリ', 'XSRF', 'Cross-?Site Request Forgery'],
 'XSS': ['XSS', 'クロスサイトスクリプティング'],
 'ISMS': ['ISMS', '情報セキュリティマネジメントシステム'],
 'ISO/IEC 27001': [r'ISO/IEC ?27001', r'ISO ?27001', r'JIS ?Q ?27001', r'ISO/IEC27001'],
 'SQLインジェクション': [r'SQLインジェクション', r'SQL インジェクション', r'SQLi\b'],
 'ランサムウェア': ['ランサムウェア', 'ランサムウエア'],
 'マルウェア': ['マルウェア', 'マルウエア'],
 'ソフトウェア': ['ソフトウェア', 'ソフトウエア'],
 'ハードウェア': ['ハードウェア', 'ハードウエア'],
 'Wi-Fi': [r'Wi-?Fi', 'WiFi', 'ワイファイ'],
 'ID/パスワード': ['パスワード', 'パスワ-ド', 'パスコード'],
 '二要素/二段階/2要素/2段階': ['二要素認証', '2要素認証', '二段階認証', '2段階認証', '多要素認証'],
 'PDCA': ['PDCA'],
 'BCP': ['BCP', '事業継続計画'],
 '脆弱性/ぜい弱性': ['脆弱性', 'ぜい弱性'],
 '暗号化/暗号科': ['暗号化'],
 'ゼロデイ': ['ゼロデイ', 'ゼロディ'],
 'DoS': [r'DoS', r'DDoS'],
 'WAF/IDS/IPS': ['WAF', 'IDS', 'IPS'],
}
varrep = {}
for name, pats in VAR.items():
    d = {}
    for p in pats:
        ids = [k for k, t in alltext.items() if re.search(p, t)]
        if ids: d[p] = ids
    varrep[name] = d
res['variants'] = varrep

# 用語集の未収録候補(略語・カタカナ語)
gl = ' '.join(norm(t['term']) + ' ' + norm(t['headline']) for t in T)
glterms = {norm(t['term']) for t in T}
qtext = ' '.join(alltext[q['qid']] for q in Q)
cand = collections.Counter(re.findall(r'[A-Z][A-Za-z0-9]{1,}(?:[/-][A-Z0-9][A-Za-z0-9]*)*', qtext))
miss = {}
for w, n in cand.items():
    if norm(w) not in gl:
        miss[w] = n
res['acronyms_not_in_glossary'] = miss
res['_counts'] = {'questions': len(Q), 'terms': len(T)}

# 科目別サマリ
summ = {}
for sid in ('kamoku_a', 'kamoku_b'):
    qs = [q for q in Q if q['subjectId'] == sid]
    ids = {q['qid'] for q in qs}
    summ[sid] = {
        'n': len(qs),
        'correct_longest_incl_tie': sum(1 for x in res['correct_longest_incl_tie'] if x in ids),
        'correct_longest_strict': sum(1 for x in res['correct_longest_strict'] if x in ids),
        'correct_ge_1.5x': sum(1 for x in res['correct_ge_1.5x_runnerup'] if x in ids),
    }
res['_subject_summary'] = summ
json.dump(res, sys.stdout, ensure_ascii=False, indent=1, default=list)
