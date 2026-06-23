import fs from 'fs';
import path from 'path';

const root = path.resolve('force-app/main/default/objects');

const objects = [
  {
    label: '取引先',
    api: 'Account',
    standardRows: [
      ['取引先名', 'Name', 'Text', 'はい', '-'],
      ['(標準項目)', 'Id', 'Id', 'はい', '-'],
    ],
  },
  {
    label: '商談',
    api: 'Opportunity',
    dir: 'Opportunity/fields',
    standardRows: [
      ['(標準項目)', 'Id', 'Id', 'はい', '-'],
      ['(標準項目)', 'Name', 'Text', 'はい', '-'],
      ['(標準項目)', 'AccountId', 'Lookup → Account', 'いいえ', '-'],
    ],
  },
  {
    label: '商品',
    api: 'Product2',
    dir: 'Product2/fields',
    standardRows: [
      ['(標準項目)', 'Id', 'Id', 'はい', '-'],
      ['(標準項目)', 'Name', 'Text', 'はい', '-'],
      ['(標準項目)', 'UnitPrice', 'Currency', 'いいえ', '-'],
    ],
  },
  { label: '請求アカウント', api: 'BillingAccount__c', dir: 'BillingAccount__c/fields' },
  { label: '契約サービス', api: 'ContractService__c', dir: 'ContractService__c/fields' },
  { label: '契約履歴', api: 'ContractHistory__c', dir: 'ContractHistory__c/fields' },
  { label: '契約商品', api: 'ContractProduct__c', dir: 'ContractProduct__c/fields' },
  { label: '請求商品', api: 'InvoiceProduct__c', dir: 'InvoiceProduct__c/fields' },
  { label: '見積備考マスタ', api: 'EstimateNoteMaster__c', dir: 'EstimateNoteMaster__c/fields' },
];

function tag(xml, name) {
  const m = xml.match(new RegExp(`<${name}>([\\s\\S]*?)</${name}>`));
  return m ? m[1].trim() : '';
}

function picklist(xml) {
  const values = [...xml.matchAll(/<value>\s*<fullName>([^<]+)<\/fullName>/g)].map((m) => m[1]);
  if (values.length) return values.join(' / ');
  const gvs = tag(xml, 'valueSetName');
  return gvs ? `(グローバル値セット: ${gvs})` : '-';
}

function dataType(xml) {
  const type = tag(xml, 'type');
  if (type === 'Lookup' || type === 'MasterDetail') {
    return `${type} → ${tag(xml, 'referenceTo')}`;
  }
  if (type === 'Summary') {
    return `Summary (${tag(xml, 'summaryOperation')} of ${tag(xml, 'summarizedField')})`;
  }
  if (type === 'Number' || type === 'Currency' || type === 'Percent') {
    const parts = [type];
    const p = tag(xml, 'precision');
    const s = tag(xml, 'scale');
    if (p) parts.push(`精度${p}`);
    if (s) parts.push(`小数${s}`);
    return parts.length > 1 ? `${parts[0]} (${parts.slice(1).join(', ')})` : type;
  }
  if (type === 'Text' || type === 'TextArea' || type === 'LongTextArea') {
    const len = tag(xml, 'length');
    return len ? `${type} (最大${len}文字)` : type;
  }
  return type;
}

function required(xml) {
  const type = tag(xml, 'type');
  if (type === 'MasterDetail') return 'はい';
  return tag(xml, 'required') === 'true' ? 'はい' : 'いいえ';
}

function parseField(filePath) {
  const xml = fs.readFileSync(filePath, 'utf8');
  const type = tag(xml, 'type');
  return [
    tag(xml, 'label'),
    tag(xml, 'fullName'),
    dataType(xml),
    required(xml),
    type === 'Picklist' || type === 'MultiselectPicklist' ? picklist(xml) : '-',
  ];
}

function objectMeta(api) {
  const p = path.join(root, api, `${api}.object-meta.xml`);
  if (!fs.existsSync(p)) return '';
  const xml = fs.readFileSync(p, 'utf8');
  const label = tag(xml, 'label');
  const nameLabel = xml.match(/<nameField>[\s\S]*?<label>([^<]+)<\/label>/)?.[1] ?? '';
  const nameType = xml.match(/<nameField>[\s\S]*?<type>([^<]+)<\/type>/)?.[1] ?? '';
  const sharing = tag(xml, 'sharingModel');
  return `  ラベル: ${label} / 名前項目: ${nameLabel} (${nameType}) / 共有: ${sharing}`;
}

const lines = [];
lines.push('見積作成 LWC / Apex 必要オブジェクト・項目一覧');
lines.push('（EstimateCreateController, estimateCreateWizard 他 関連 Apex / Trigger / LWC から抽出）');
lines.push('');

for (const obj of objects) {
  lines.push('='.repeat(100));
  lines.push(`【${obj.label}】 オブジェクトAPI名: ${obj.api}`);
  const meta = objectMeta(obj.api);
  if (meta) lines.push(meta);
  lines.push('-'.repeat(100));
  lines.push(['項目名', 'API名', 'データ型', '必須', '選択リスト値'].join('\t'));
  lines.push('-'.repeat(100));

  for (const row of obj.standardRows ?? []) {
    lines.push(row.join('\t'));
  }

  if (obj.dir) {
    const dir = path.join(root, obj.dir);
    if (fs.existsSync(dir)) {
      for (const file of fs.readdirSync(dir).filter((f) => f.endsWith('.field-meta.xml')).sort()) {
        lines.push(parseField(path.join(dir, file)).join('\t'));
      }
    }
  }
  lines.push('');
}

function parseCustomMetadata(filePath) {
  const xml = fs.readFileSync(filePath, 'utf8');
  const label = tag(xml, 'label');
  const values = [...xml.matchAll(/<values>\s*<field>([^<]+)<\/field>\s*<value[^>]*>([^<]*)<\/value>/g)]
    .map((m) => `${m[1]}=${m[2]}`)
    .join(' / ');
  return { api: path.basename(filePath, '.md-meta.xml'), label, values };
}

const cmdtDir = path.resolve('force-app/main/default/customMetadata');
if (fs.existsSync(cmdtDir)) {
  lines.push('='.repeat(100));
  lines.push('【カスタムメタデータ レコード一覧】（Apex 実行時に参照）');
  lines.push('-'.repeat(100));
  lines.push(['レコードAPI名', 'ラベル', '設定値'].join('\t'));
  lines.push('-'.repeat(100));
  for (const file of fs.readdirSync(cmdtDir).filter((f) => f.endsWith('.md-meta.xml')).sort()) {
    const rec = parseCustomMetadata(path.join(cmdtDir, file));
    lines.push([rec.api, rec.label, rec.values].join('\t'));
  }
  lines.push('');
}

const out = path.resolve('docs/lwc-apex-required-fields.txt');
fs.mkdirSync(path.dirname(out), { recursive: true });
fs.writeFileSync(out, lines.join('\n'), 'utf8');
console.log(out);
console.log(`Total lines: ${lines.length}`);
