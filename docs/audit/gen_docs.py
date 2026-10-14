#!/usr/bin/env python3
"""audit_result.json と問題/用語データから docs の表を生成する(再生成用)。
使い方: python3 docs/audit/audit_questions.py > docs/audit/audit_result.json && python3 docs/audit/gen_docs.py
"""
import json, re, collections

def load(p): return [json.loads(l) for l in open(p, encoding='utf-8') if l.startswith('{')]
Q = load('assets/questions/info_security.jsonl')
T = load('assets/terms/info_security.jsonl')
R = json.load(open('docs/audit/audit_result.json', encoding='utf-8'))
short = lambda q: q.replace('info_security-', '')

# ---- topic -> 推定シラバス区分(推定。IPA一次資料で要確認) ----
TOPIC = {
 'sec_concept': ('1 情報セキュリティ(推定)', '1-1 情報セキュリティの概念(三要素等)'),
 'risk':        ('1 情報セキュリティ(推定)', '1-2 リスクマネジメント(アセスメント・対応)'),
 'mgmt':        ('1 情報セキュリティ(推定)', '1-3 情報セキュリティ管理・組織・運用'),
 'isms':        ('1 情報セキュリティ(推定)', '1-4 ISMS・マネジメントシステム'),
 'audit':       ('1 情報セキュリティ(推定)', '1-5 監査・内部統制'),
 'incident':    ('1 情報セキュリティ(推定)', '1-6 インシデント対応・事業継続'),
 'human':       ('1 情報セキュリティ(推定)', '1-7 人的対策・教育'),
 'physical':    ('1 情報セキュリティ(推定)', '1-8 物理・環境的対策'),
 'threat':      ('2 技術・対策(推定)', '2-1 脅威・攻撃手法'),
 'measure':     ('2 技術・対策(推定)', '2-2 技術的対策(認証・暗号・アクセス制御等)'),
 'network':     ('2 技術・対策(推定)', '2-3 ネットワーク・通信'),
 'secure_dev':  ('2 技術・対策(推定)', '2-4 セキュアな開発・Webアプリ'),
 'cloud_iot':   ('2 技術・対策(推定)', '2-5 クラウド・IoT・テレワーク'),
 'it_basics':   ('2 技術・対策(推定)', '2-6 IT基礎(DB・稼働率等)'),
 'law':         ('3 法務・規格・標準(推定)', '3-1 法令・制度'),
 'standards':   ('3 法務・規格・標準(推定)', '3-2 規格・ガイドライン'),
}
for k in list(set(q['topicId'] for q in Q)):
    if k.startswith('case_'):
        TOPIC[k] = ('科目B 事例(推定)', 'B-' + k[5:] + ' 事例問題')

# ---- 用語集の有無: 関連問題のtopicで集計 ----
qd = {q['qid']: q for q in Q}
topic_terms = collections.defaultdict(set)
for t in T:
    for qid in t['relatedQuestionIds']:
        if qid in qd: topic_terms[qd[qid]['topicId']].add(t['termId'])
by_topic = collections.defaultdict(list)
for q in Q: by_topic[q['topicId']].append(q)

# ---- フラグ集約 ----
flags = collections.defaultdict(set)
for x in R['correct_ge_1.5x_runnerup']: flags[x].add('長さ1.5倍')
for x in R['same_prompt']: flags[x].add('設問重複')
for x in R['negative_prompt']: flags[x].add('否定設問')
for x in R['correct_longest_strict']: flags[x].add('正解最長')
for x in R['similar_to_correct']: flags[x[0]].add('選択肢類似')
for x in R['absolute_words']:
    flags[x[0]].add('断定語(正解)' if x[2] in x[1] else '断定語(誤答)')

NUM = re.compile(r'[0-9０-９]|JIS|ISO|法|条|規格|ガイドライン')

def tier(q):
    t = q['topicId']; f = flags[q['qid']]
    if t in ('law', 'standards', 'isms', 'case_standards') or '長さ1.5倍' in f or '設問重複' in f: return 1
    if t in ('risk', 'audit', 'incident', 'mgmt', 'it_basics') or t.startswith('case_') or NUM.search(q['prompt'] + ''.join(q['choices'])): return 2
    return 3

TIERNAME = {1: 'P1 最優先(法令・規格・制度、または機械検査で偏り/重複が出たもの)',
            2: 'P2 高(計算・手順・事例・数値/規格番号を含むもの)',
            3: 'P3 通常(技術用語・一般知識)'}

def viewpoint(q):
    t = q['topicId']; v = []
    if t in ('law', 'case_standards') or '法' in q['prompt']: v.append('法令名・条文・施行状況が現行か')
    if t in ('standards', 'isms'): v.append('規格番号・版・JIS/ISOの対応が正しいか')
    if t.startswith('case_'): v.append('事例の最適解が一意か(次善が成立しないか)')
    if t in ('risk', 'it_basics') or re.search(r'[0-9０-９]', q['prompt']): v.append('計算・数値・定義式が正しいか')
    v.append('正解の事実性' if t not in ('law','standards','isms') else '制度の現行性')
    v.append('誤答が確実に誤りか')
    f = flags[q['qid']]
    if '長さ1.5倍' in f: v.append('正解だけ突出して長い(調整要否)')
    if '設問重複' in f: v.append('他問と設問重複(統合/差別化)')
    if '否定設問' in f: v.append('否定設問の読み違いなし')
    return '・'.join(dict.fromkeys(v))

# ================= シラバス対応表 =================
out = []
w = out.append
w('# シラバス対応表(枠・推定版)\n')
w('> **重要**: IPA 公表の出題範囲(シラバス)の一次資料が手元に無いため、大分類・中分類は **筆者の知識による推定** です。IPA の最新シラバスと突き合わせて **要確認**(欄が「要確認」「空欄」の箇所は未確認)。問題データの `topicId` を機械的に区分へ割り当てただけで、シラバスの項目番号とは一致しません。\n')
w(f'- 対象: 問題 {len(Q)} 問(科目A {sum(q["subjectId"]=="kamoku_a" for q in Q)} / 科目B {sum(q["subjectId"]=="kamoku_b" for q in Q)})、用語集 {len(T)} 語')
w('- 「用語集の有無」は、そのトピックの問題に紐づく用語(`relatedQuestionIds`)の語数。0 は未紐づけ(要確認)。\n')
w('## 対応表\n')
w('| 大分類(推定) | 中分類(推定) | 細目(IPAシラバス) | topicId | 科目 | 問題数 | 問題ID範囲 | 紐づく用語数 | 用語集の有無 | シラバス照合 |')
w('|---|---|---|---|---|---|---|---|---|---|')
order = list(TOPIC)
for tid in order:
    qs = by_topic.get(tid, [])
    if not qs: continue
    subj = '/'.join(sorted({'A' if q['subjectId']=='kamoku_a' else 'B' for q in qs}))
    ids = sorted(short(q['qid']) for q in qs)
    nt = len(topic_terms[tid])
    big, mid = TOPIC[tid]
    w(f'| {big} | {mid} | 要確認 | {tid} | {subj} | {len(qs)} | {ids[0]}〜{ids[-1]}(飛び番あり) | {nt} | {"あり" if nt else "要確認"} | 要確認 |')
w('')
w('各トピックの問題ID全件は `assets/questions/info_security.jsonl` の `topicId` で引ける。科目内の件数(問題数)は上表の合計=全問。\n')
w('## 用語集に未収録の語(候補)\n')
w('問題文・選択肢・解説に出現するが、用語集の見出し語(`term`)に無い語を機械抽出し、略語/別名で既収録のもの(例: BIA=事業影響度分析、DMARC=送信元ドメイン認証、DAC=任意アクセス制御、SoA=適用宣言書、STRIDE≒脅威モデリング、SLE/ARO≒ALE)を除いたもの。依頼で挙げられた「未収録21語」の元リストは手元に無いため **同一とは限らない**(要突合)。\n')
MISS = [
 ('CSRF', 'CSRF'), ('ファジング', 'ファジング'), ('CASB', 'CASB'), ('委託先管理', '委託先管理'),
 ('バックアップ3-2-1', '3-2-1'), ('ISO/IEC 15408', '15408'),
 ('UTM', 'UTM'), ('HSM', 'HSM'), ('SASE / SD-WAN', 'SASE'), ('IdP', 'IdP'), ('CWE', 'CWE'), ('JVN', 'JVN'),
 ('DevSecOps', 'DevSecOps'), ('PCI DSS', 'PCI DSS'), ('NIST CSF', 'NIST'), ('WPA2 / WPA3', 'WPA3'),
 ('IPsec', 'IPsec'), ('SFTP / FTPS', 'SFTP'), ('ARP(ARPスプーフィング)', 'ARP'), ('CDN', 'CDN'), ('OT/ICS', 'OT/ICS'),
 ('(追加候補)SameSite Cookie', 'SameSite'), ('(追加候補)PGP', 'PGP'), ('(追加候補)SNMP', 'SNMP'),
 ('(追加候補)ITIL', 'ITIL'), ('(追加候補)COSO', 'COSO'), ('(追加候補)SOX/HIPAA', 'HIPAA'), ('(追加候補)IaaS/PaaS/SaaS', 'PaaS'),
]
w('| # | 語 | 出現問題ID(最大5件) | 出現問題数 | 備考 |')
w('|---|---|---|---|---|')
alltxt = {q['qid']: q['prompt'] + ' ' + q['explanation'] + ' ' + ' '.join(q['choices']) for q in Q}
for i, (label, key) in enumerate(MISS, 1):
    ids = sorted(short(k) for k, v in alltxt.items() if key in v)
    note = '問題に出現なし(出題範囲として追加要否を要確認)' if not ids else ''
    w(f'| {i} | {label} | {", ".join(ids[:5])} | {len(ids)} | {note} |')
open('docs/syllabus_mapping.md', 'w', encoding='utf-8').write('\n'.join(out) + '\n')

# ================= チェックリスト =================
o = []; w = o.append
w('# 問題コンテンツ 専門確認チェックリスト\n')
w('> 全 %d 問は **仮データ**(自作・正誤の専門確認が未了)。本書は専門家(情報セキュリティ分野の有識者・試験対策の実務者)による確認の **手順書** であり、確認済みを意味しない。判定欄は空欄(未確認)。\n' % len(Q))
w('## 手順\n')
w('1. 優先順(P1→P2→P3)に従い、表の問題を `assets/questions/info_security.jsonl` と見比べる。')
w('2. 各問を次の観点で確認する: (a) 正解が事実として正しい (b) 他の3択が確実に誤り(正解が一意) (c) 解説が正解と矛盾せず事実として正しい (d) 用語・表記が試験で通用する (e) 法令・規格は現行(改正・版)に合っている (f) IPA 出題範囲の項目に対応している。')
w('3. 判定欄に記号を記入: `OK`(修正不要) / `修正`(内容修正が必要。修正案を備考へ) / `削除`(出題に不適) / `保留`(要追加調査)。')
w('4. 1問ごとに確認者・確認日・根拠(一次資料名と版)を備考に書く。**根拠を示せない場合は OK にしない**。')
w('5. 判定が出た問題だけ別PRでデータ修正する(`contentVer` を更新)。公開前の判断は運営者が行う。')
w('6. 機械検査の結果は [`docs/content_audit_report.md`](content_audit_report.md) を参照(「確認観点」の付記はその検査由来)。\n')
w('## 優先度の基準(公開リスクが高い順)\n')
for k in (1, 2, 3): w(f'- {TIERNAME[k]}')
w('')
w('判定欄の凡例: OK / 修正 / 削除 / 保留。空欄=未確認。\n')
cnt = collections.Counter(tier(q) for q in Q)
w('件数: ' + ' / '.join(f'P{k} {cnt[k]}問' for k in (1,2,3)) + '\n')
for k in (1, 2, 3):
    w(f'## {TIERNAME[k]}({cnt[k]}問)\n')
    w('| 問題ID | 科目 | 分野(topicId) | 機械検査の付記 | 確認観点 | 判定 | 確認者/日付 | 根拠・備考 |')
    w('|---|---|---|---|---|---|---|---|')
    rows = [q for q in Q if tier(q) == k]
    rows.sort(key=lambda q: (q['topicId'], q['qid']))
    for q in rows:
        fl = '・'.join(sorted(flags[q['qid']])) or '-'
        w(f'| {short(q["qid"])} | {"A" if q["subjectId"]=="kamoku_a" else "B"} | {q["topicId"]} | {fl} | {viewpoint(q)} | | | |')
    w('')
open('docs/content_review_checklist.md', 'w', encoding='utf-8').write('\n'.join(o) + '\n')
print(cnt)
