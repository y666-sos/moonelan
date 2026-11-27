"""Derive EAF 3.0 grammar facts from a hash-pinned upstream schema (not bundled)."""
import argparse, hashlib, json, re
from pathlib import Path
import xml.etree.ElementTree as ET
NS = '{http://www.w3.org/2001/XMLSchema}'
SHA = '59e76f90d5840813314b1e635480d044287b811ebd63a40e25cb4e73c6ad72bb'
def main():
 p=argparse.ArgumentParser();p.add_argument('schema',type=Path);p.add_argument('--check',action='store_true');args=p.parse_args()
 data=args.schema.read_bytes();assert hashlib.sha256(data).hexdigest()==SHA,'Unpinned schema'
 root=ET.fromstring(data);types={x.get('name'):x for x in root.findall(NS+'complexType')};groups={x.get('name'):x for x in root.findall(NS+'attributeGroup')}
 rules={}
 type_names={}
 def attr_rules(node):
  result=[]
  for child in node:
   if child.tag==NS+'attributeGroup':result+=attr_rules(groups[child.get('ref')])
   elif child.tag==NS+'attribute':
    choices=[c.get('value') for c in child.iter(NS+'enumeration')]
    kind=child.get('type','xsd:string').split(':')[-1]
    result.append((child.get('name'),kind,child.get('use')=='required',choices))
  return result
 def visit(el):
  name=el.get('name');type_names[name]=el.get('type','');typ=types.get(el.get('type'));typ=typ if typ is not None else el.find(NS+'complexType')
  if typ is None:rules[name]=([],[],True);return
  simple=typ.find(NS+'simpleContent');container=simple.find(NS+'extension') if simple is not None else typ
  attrs=attr_rules(container);content=[]
  def particle(x):
   tag=x.tag.removeprefix(NS)
   if tag=='element':
    visit(x);content.append(([x.get('name')],int(x.get('minOccurs','1')), -1 if x.get('maxOccurs')=='unbounded' else int(x.get('maxOccurs','1'))))
   elif tag=='choice':
    nodes=x.findall(NS+'element')
    assert len(nodes)==len([c for c in x if c.tag!=NS+'annotation'])
    for n in nodes:visit(n)
    content.append(([n.get('name') for n in nodes],int(x.get('minOccurs','1')),-1 if x.get('maxOccurs')=='unbounded' else int(x.get('maxOccurs','1'))))
   elif tag=='sequence':
    for c in x:particle(c)
  for c in container:
   if c.tag in (NS+'sequence',NS+'choice'):particle(c)
  rule=(attrs,content,simple is not None)
  if name in rules:assert rules[name]==rule,name
  rules[name]=rule
 for el in root.findall(NS+'element'):visit(el)
 q=lambda x:json.dumps(x,ensure_ascii=False)
 lines=['// Generated grammar facts; do not edit. Not counted as production LOC.', '// EAF 3.0 schema SHA-256: '+SHA, '///|', 'fn eaf30_rule(name : String) -> SchemaRule? {', '  match name {']
 for name,(attrs,content,textual) in sorted(rules.items()):
  aa=['{ name: '+q(n)+', kind: '+q(k)+', required: '+str(req).lower()+', choices: '+q(ch)+' }' for n,k,req,ch in attrs]
  cc=['{ names: '+q(ns)+', minimum: '+str(mi)+', maximum: '+str(ma)+' }' for ns,mi,ma in content]
  lines+=['    '+q(name)+' => Some({ type_name: '+q(type_names[name])+', attributes: ['+', '.join(aa)+'], children: ['+', '.join(cc)+'], textual: '+str(textual).lower()+' })']
 lines+=['    _ => None','  }','}'];out='\n'.join(lines)+'\n';path=Path(__file__).resolve().parents[1]/'eaf30_generated.mbt'
 # The formatter is applied separately; compare semantic facts via a retained JSON digest.
 if args.check:
  tokenize=lambda s: [t for t in re.findall(r'"(?:\\.|[^"\\])*"|[^\s]',s) if t!=',']
  assert tokenize(path.read_text(encoding='utf-8-sig'))==tokenize(out), 'Generated rules differ from pinned schema'
 else:path.write_text(out,encoding='utf8')
 print(json.dumps({'elements':len(rules),'attributes':sum(len(r[0]) for r in rules.values()),'schema_sha256':SHA,'element_names':sorted(rules)}))
if __name__=='__main__':main()
