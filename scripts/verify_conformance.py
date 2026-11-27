"""Independent EAF 3.0 acceptance and lossless semantic roundtrip matrix.

Inputs are constructed in Python, validated by lxml's upstream XSD, then fed
into the PUBLIC MoonBit file API. Invalid cases are independently XSD-invalid
except for separately-labelled reference/security cases. No self-roundtrip
alone is treated as proof of conformance. Generated runner is never published.
"""
import argparse
import copy
import json
import re
import shutil
import subprocess
from pathlib import Path
from lxml import etree as E
from pympi import Eaf
from verify_interop import load_schemas

ROOT = Path(__file__).resolve().parents[1]
BASE = '''<ANNOTATION_DOCUMENT AUTHOR="甲 &amp; 乙" DATE="2026-11-27T24:00:00.000+14:00" VERSION="3.0" FORMAT="3.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:noNamespaceSchemaLocation="https://example.org/eaf.xsd">
<LICENSE LICENSE_URL="https://example.org/license">测试许可</LICENSE>
<HEADER MEDIA_FILE="legacy.wav" TIME_UNITS="milliseconds"><MEDIA_DESCRIPTOR MEDIA_URL="file:///a.wav" RELATIVE_MEDIA_URL="./a.wav" MIME_TYPE="audio/wav" TIME_ORIGIN="-9223372036854775808" EXTRACTED_FROM="file:///b.wav"/><LINKED_FILE_DESCRIPTOR LINK_URL="file:///metadata.txt" RELATIVE_LINK_URL="./metadata.txt" MIME_TYPE="text/plain" TIME_ORIGIN="9223372036854775807" ASSOCIATED_WITH="file:///a.wav"/><PROPERTY NAME="notes">空白 &#9;&#10;&#13; &amp; 中文</PROPERTY></HEADER>
<TIME_ORDER><TIME_SLOT TIME_SLOT_ID="起点1" TIME_VALUE="2147483648"/><TIME_SLOT TIME_SLOT_ID="终点2" TIME_VALUE="4294967295"/><TIME_SLOT TIME_SLOT_ID="未对齐3"/></TIME_ORDER>
<TIER TIER_ID="根 tier" PARTICIPANT="speaker" ANNOTATOR="annotator" LINGUISTIC_TYPE_REF="root" DEFAULT_LOCALE="zh" EXT_REF="er" LANG_REF="zho"><ANNOTATION><ALIGNABLE_ANNOTATION ANNOTATION_ID="根1" EXT_REF="er ecv" LANG_REF="zho" CVE_REF="entry" TIME_SLOT_REF1="起点1" TIME_SLOT_REF2="终点2" SVG_REF="shape.svg"><ANNOTATION_VALUE>名词</ANNOTATION_VALUE></ALIGNABLE_ANNOTATION></ANNOTATION></TIER>
<TIER TIER_ID="ref" LINGUISTIC_TYPE_REF="ref" PARENT_REF="根 tier"><ANNOTATION><REF_ANNOTATION ANNOTATION_ID="r1" ANNOTATION_REF="根1" EXT_REF="er" LANG_REF="zho" CVE_REF="entry"><ANNOTATION_VALUE>名词</ANNOTATION_VALUE></REF_ANNOTATION></ANNOTATION><ANNOTATION><REF_ANNOTATION ANNOTATION_ID="r2" ANNOTATION_REF="根1" PREVIOUS_ANNOTATION="r1"><ANNOTATION_VALUE>二</ANNOTATION_VALUE></REF_ANNOTATION></ANNOTATION></TIER>
<LINGUISTIC_TYPE LINGUISTIC_TYPE_ID="root" TIME_ALIGNABLE="true" GRAPHIC_REFERENCES="false" CONTROLLED_VOCABULARY_REF="词表" EXT_REF="er" LEXICON_REF="lex"/><LINGUISTIC_TYPE LINGUISTIC_TYPE_ID="ref" TIME_ALIGNABLE="0" CONSTRAINTS="Symbolic_Subdivision" CONTROLLED_VOCABULARY_REF="词表"/>
<LOCALE LANGUAGE_CODE="zh" COUNTRY_CODE="CN" VARIANT="variant"/>
<LANGUAGE LANG_ID="zho" LANG_DEF="https://example.org/zho" LANG_LABEL="中文"/><LANGUAGE LANG_ID="eng"/>
<CONSTRAINT STEREOTYPE="Symbolic_Subdivision" DESCRIPTION="按原文保留 &amp; 不替换"/>
<CONTROLLED_VOCABULARY CV_ID="词表"><DESCRIPTION LANG_REF="zho">词性</DESCRIPTION><CV_ENTRY_ML CVE_ID="entry" EXT_REF="er"><CVE_VALUE LANG_REF="zho" DESCRIPTION="类别">名词</CVE_VALUE><CVE_VALUE LANG_REF="eng">noun</CVE_VALUE></CV_ENTRY_ML><CV_ENTRY_ML CVE_ID="verb"><CVE_VALUE LANG_REF="zho">动词</CVE_VALUE><CVE_VALUE LANG_REF="eng">verb</CVE_VALUE></CV_ENTRY_ML></CONTROLLED_VOCABULARY>
<CONTROLLED_VOCABULARY CV_ID="external" EXT_REF="ecv"/>
<LEXICON_REF LEX_REF_ID="lex" NAME="lexicon" TYPE="test" URL="https://example.org/lex" LEXICON_ID="lex-id" LEXICON_NAME="Name" DATCAT_ID="dc" DATCAT_NAME="Category"/>
<REF_LINK_SET LINK_SET_ID="links" LINK_SET_NAME="links" EXT_REF="er ecv" LANG_REF="zho" CV_REF="词表"><CROSS_REF_LINK REF1="根1" REF2="r1" DIRECTIONALITY="unidirectional" REF_LINK_ID="cross" REF_LINK_NAME="pair" EXT_REF="er" LANG_REF="zho" CVE_REF="entry" REF_TYPE="relation">相关</CROSS_REF_LINK><GROUP_REF_LINK REFS="cross 根1 r2" REF_LINK_ID="group" REF_LINK_NAME="set" EXT_REF="er" LANG_REF="zho" CVE_REF="entry" REF_TYPE="collection">组</GROUP_REF_LINK></REF_LINK_SET>
<EXTERNAL_REF EXT_REF_ID="er" TYPE="resource_url" VALUE="https://example.org/resource"/><EXTERNAL_REF EXT_REF_ID="ecv" TYPE="ecv" VALUE="https://example.org/vocab.ecv"/>
</ANNOTATION_DOCUMENT>'''
ECV = '''<CV_RESOURCE DATE="-0004-02-29T00:00:00Z" AUTHOR="作者" VERSION="0.2"><LANGUAGE LANG_ID="zho"/><LANGUAGE LANG_ID="eng"/><CONTROLLED_VOCABULARY CV_ID="external"><DESCRIPTION LANG_REF="eng">External</DESCRIPTION><CV_ENTRY_ML CVE_ID="remote"><CVE_VALUE LANG_REF="zho" DESCRIPTION="远程词">远程</CVE_VALUE><CVE_VALUE LANG_REF="eng">remote</CVE_VALUE></CV_ENTRY_ML></CONTROLLED_VOCABULARY></CV_RESOURCE>'''

def xml(root): return E.tostring(root, encoding='unicode')
def parsed(text): return E.fromstring(text.encode('utf8'))
def semantic(e):
    # Element-only indentation isn't EAF data, simple content whitespace IS.
    return (e.tag, sorted(e.attrib.items()), (e.text or '') if not len(e) else '', [semantic(c) for c in e])

def build_cases(schema):
    valid=[('all-fields', BASE), ('external-resource', ECV), ('minimal','<ANNOTATION_DOCUMENT AUTHOR="" DATE="2000-01-01T00:00:00" VERSION="3.0"><HEADER/><TIME_ORDER/></ANNOTATION_DOCUMENT>'), ('minimal-resource','<CV_RESOURCE><CONTROLLED_VOCABULARY CV_ID=""/></CV_RESOURCE>')]
    invalid=[]
    def variation(label, path, key, value, good=True, base=BASE):
        r=parsed(base); n=r if path=='.' else r.find(path)
        if value is None: n.attrib.pop(key, None)
        else: n.set(key,value)
        (valid if good else invalid).append((label,xml(r)))
    for unit in ['milliseconds','NTSC-frames','PAL-frames']:
        variation('unit-'+unit,'HEADER','TIME_UNITS',unit)
    for t in ['0','0000','2147483647','2147483648','4294967295','  004294967295  ']: variation('time-'+t,'TIME_ORDER/TIME_SLOT','TIME_VALUE',t)
    for t in ['-1','4294967296','1.5','1e3','+','1 2','999999999999999999999999999']: variation('bad-time-'+t,'TIME_ORDER/TIME_SLOT','TIME_VALUE',t,False)
    for origin in ['-9223372036854775808','9223372036854775807','+0009223372036854775807','-0','  20  ']:
        for tag in ['MEDIA_DESCRIPTOR','LINKED_FILE_DESCRIPTOR']: variation('long-'+tag+origin,'HEADER/'+tag,'TIME_ORIGIN',origin)
    for origin in ['-9223372036854775809','9223372036854775808','4.0']:
        for tag in ['MEDIA_DESCRIPTOR','LINKED_FILE_DESCRIPTOR']: variation('bad-long-'+tag+origin,'HEADER/'+tag,'TIME_ORIGIN',origin,False)
    for date in ['2000-02-29T00:00:00Z','-0004-02-29T00:00:00Z','12000-02-29T24:00:00','2026-01-01T00:00:00.123456789-14:00','2026-11-27T24:00:00.000Z']: variation('date-'+date,'.','DATE',date)
    for date in ['0000-01-01T00:00:00Z','02026-01-01T00:00:00Z','1900-02-29T00:00:00','2026-11-27T24:00:00.1Z','2026-01-01T12:00:60','2026-01-01T00:00:00+14:01','2026-11-31T00:00:00']: variation('bad-date-'+date,'.','DATE',date,False)
    for b in ['true','false','0','1','  1  ']: variation('bool-'+b,'LINGUISTIC_TYPE','GRAPHIC_REFERENCES',b)
    variation('bad-boolean','LINGUISTIC_TYPE','GRAPHIC_REFERENCES','True',False)
    for value in ['iso12620','ecv','cve_id','lexen_id','resource_url']: variation('external-enum-'+value,'EXTERNAL_REF','TYPE',value)
    variation('bad-external-enum','EXTERNAL_REF','TYPE','unknown',False)
    for value in ['undirected','unidirectional','bidirectional']: variation('direction-'+value,'REF_LINK_SET/CROSS_REF_LINK','DIRECTIONALITY',value)
    variation('bad-direction','REF_LINK_SET/CROSS_REF_LINK','DIRECTIONALITY','forward',False)
    # Every required attr deletion must fail; every optional deletion must succeed.
    xsd=E.parse(str(ROOT/'_build/oracle-schemas/eaf3.0.xsd')); ns={'x':'http://www.w3.org/2001/XMLSchema'}
    types={t.get('name'):t for t in xsd.findall('x:complexType',ns)}
    groups={t.get('name'):t for t in xsd.findall('x:attributeGroup',ns)}
    declarations={}
    def attrs(t):
        if t is None:return []
        result=list(t.findall('x:attribute',ns))
        for g in t.findall('x:attributeGroup',ns): result+=attrs(groups[g.get('ref')])
        for ext in t.findall('x:simpleContent/x:extension',ns):result+=attrs(ext)
        return result
    for el in xsd.findall('.//x:element',ns):
        t=types.get(el.get('type')); t=t if t is not None else el.find('x:complexType',ns)
        declarations[el.get('name')]=attrs(t)
    covered=set(); elements=set()
    for source in [BASE,ECV]:
        r=parsed(source)
        for n in r.iter():
            elements.add(n.tag)
            covered.update((n.tag,k) for k in n.attrib if not k.startswith('{'))
    expected={(tag,a.get('name')) for tag, aa in declarations.items() for a in aa}
    assert covered==expected,(sorted(expected-covered),sorted(covered-expected))
    assert elements==set(declarations)
    for tag, aa in declarations.items():
        source=ECV if tag=='CV_RESOURCE' else BASE
        if tag=='CV_RESOURCE': source=ECV
        for attr in aa:
            key=attr.get('name'); r=parsed(source)
            nodes=list(r.iter(tag)); assert nodes,tag
            n=next((n for n in nodes if key in n.attrib),None)
            if n is None: # optional attr on second CV or reference in the base
                raise AssertionError((tag,key))
            n.attrib.pop(key)
            good=attr.get('use')!='required'
            # Removing IDs referenced elsewhere is independently invalid too.
            good=good and schema.validate(r)
            (valid if good else invalid).append(('omit-'+tag+'@'+key,xml(r)))
    variation("attribute-whitespace", ".", "AUTHOR", "tab\tline\nreturn\r")
    variation("non-xml-space-time", "TIME_ORDER/TIME_SLOT", "TIME_VALUE", "\u00a01\u00a0", False)
    variation("non-xml-space-origin", "HEADER/MEDIA_DESCRIPTOR", "TIME_ORIGIN", "\u00a01\u00a0", False)
    # Required child cardinalities and ordering, unsupported child/attr and text.
    for label,mutate in [
      ('missing-header',lambda r:r.remove(r.find('HEADER'))),
      ('missing-time-order',lambda r:r.remove(r.find('TIME_ORDER'))),
      ('duplicate-header',lambda r:r.insert(2,copy.deepcopy(r.find('HEADER')))),
      ('unknown-element',lambda r:E.SubElement(r,'UNKNOWN')),
      ('unknown-attribute',lambda r:r.set('UNKNOWN','x')),
      ('text-in-container',lambda r:setattr(r.find('TIME_ORDER'),'text','invalid')),
      ('missing-value',lambda r:r.find('.//ALIGNABLE_ANNOTATION').remove(r.find('.//ANNOTATION_VALUE'))),
      ('duplicate-value',lambda r:r.find('.//ALIGNABLE_ANNOTATION').append(copy.deepcopy(r.find('.//ANNOTATION_VALUE')))),
      ('wrong-order',lambda r:r.insert(0,r.find('HEADER'))),
      ('duplicate-id',lambda r:r.find('.//REF_ANNOTATION').set('ANNOTATION_ID','根1')),
    ]:
        r=parsed(BASE);mutate(r);invalid.append((label,xml(r)))
    variation('dangling-parent','TIER','PARENT_REF','missing',False)
    variation('dangling-slot','.//ALIGNABLE_ANNOTATION','TIME_SLOT_REF1','missing',False)
    variation('dangling-type','TIER','LINGUISTIC_TYPE_REF','missing',False)
    variation('dangling-cv','LINGUISTIC_TYPE','CONTROLLED_VOCABULARY_REF','missing',False)
    variation('dangling-language','.//CVE_VALUE','LANG_REF','missing',False)
    variation('bad-id','TIME_ORDER/TIME_SLOT','TIME_SLOT_ID','1invalid',False)
    # Standard permits custom constraint declarations and non-monotonic/zero spans
    # at interchange level; these must not be rejected by graph-editing policies.
    variation('custom-constraint','CONSTRAINT','DESCRIPTION','自定义描述，不得覆盖')
    r=parsed(BASE);r.find('CONSTRAINT').set('STEREOTYPE','Custom');r.findall('LINGUISTIC_TYPE')[1].set('CONSTRAINTS','Custom');valid.append(('custom-stereotype',xml(r)))
    variation('zero-span','.//ALIGNABLE_ANNOTATION','TIME_SLOT_REF2','起点1')
    variation('unaligned-start','.//ALIGNABLE_ANNOTATION','TIME_SLOT_REF1','未对齐3')
    variation('unaligned-both','.//ALIGNABLE_ANNOTATION','TIME_SLOT_REF2','未对齐3',base=valid[-1][1])
    r=parsed(BASE);r.set('{http://www.w3.org/2001/XMLSchema-instance}noNamespaceSchemaLocation','https://example.org/eaf.xsd');r.find('TIER').set('{http://www.w3.org/2001/XMLSchema-instance}type','tierType');valid.append(('inherited-xsi',xml(r)))
    r=parsed(BASE);r.find('.//ANNOTATION_VALUE').text='literal <!DOCTYPE and <!ENTITY';valid.append(('literal-markup-text',xml(r)))
    cdata=BASE.replace('<ANNOTATION_VALUE>名词</ANNOTATION_VALUE>', '<ANNOTATION_VALUE><![CDATA[literal <!DOCTYPE and <!ENTITY]]></ANNOTATION_VALUE>',1);valid.append(('cdata-markup-literal',cdata))
    for name,text in valid:
        try: schema.assertValid(parsed(text))
        except Exception as e: raise AssertionError(name) from e
    for name,text in invalid: assert not schema.validate(parsed(text)),name
    return valid,invalid,{'element_declarations':len(elements),'attribute_declarations':len(covered),'covered_attributes':[t+'@'+a for t,a in sorted(covered)]}

def run(target):
    schema=load_schemas(ROOT/'_build/oracle-schemas')['3.0']
    valid,invalid,coverage=build_cases(schema)
    runner=ROOT/'examples/conformance_batch'
    assert runner.resolve().parent==(ROOT/'examples').resolve()
    assert not runner.exists(), 'Runner directory already exists; do not overwrite'
    runner.mkdir()
    try:
        (runner/'moon.pkg').write_text('import { "y666-sos/moonelan" @eaf, }\npkgtype(kind: "executable")\n',encoding='utf8')
        q=lambda x:json.dumps(x,ensure_ascii=False)
        source=['fn main raise {']
        for i,(name,text) in enumerate(valid):
            source+=['  { let f = @eaf.parse_file('+q(text)+'); println(@eaf.write_file(f)); println("CASE_END") }']
        for name,text in invalid:
            source+=['  try @eaf.parse_file('+q(text)+') catch { _ => println("REJECT") } noraise { _ => abort('+q('accepted invalid '+name)+') }']
        # Mutations are checked by the independent XML reader, not by the same library.
        source+=['  let f = @eaf.parse_file('+q(BASE)+')',
                 '  @eaf.file_validate_vocabularies(f)',
                 '  let f = @eaf.file_rename_annotation(f, "根1", "changed1")',
                 '  let f = @eaf.file_select_cv(f, "changed1", "verb", "eng")',
                 '  let f = @eaf.file_set_time(f, "未对齐3", Some(4294967295L))',
                 '  @eaf.file_validate_vocabularies(f)',
                 '  println(@eaf.write_file(f)); println("CASE_END")',
                 '  let ext = @eaf.parse_file('+q(ECV)+')',
                 '  println(@eaf.file_cv_value(f, "external", "remote", "zho", resource=Some(ext)))',
                 '  try @eaf.file_cv_value(f, "external", "remote", "zho") catch { _ => println("UNRESOLVED") } noraise { _ => abort("unresolved external CV fabricated") }',
                 '  try @eaf.file_rename_annotation(f, "changed1", "r1") catch { _ => println("COLLISION") } noraise { _ => abort("duplicate ID accepted") }',
                 '  println(@eaf.write_file(@eaf.parse_file('+q(BASE)+'))); println("CASE_END")','}']
        (runner/'main.mbt').write_text('\n'.join(source),encoding='utf8')
        result=subprocess.run(['moon','run','examples/conformance_batch','--target',target],cwd=ROOT,capture_output=True,text=True,encoding='utf8',check=True)
        output=result.stdout; blocks=output.split('CASE_END\n'); assert len(blocks)==len(valid)+3,len(blocks)
        for (name,text),actual in zip(valid,blocks):
            r=parsed(actual.strip());schema.assertValid(r)
            assert semantic(r)==semantic(parsed(text)),name
        tail=blocks[len(valid)]; assert tail.count('REJECT\n')==len(invalid)
        edited=parsed(tail.replace('REJECT\n','').strip());schema.assertValid(edited)
        a=edited.find('.//ALIGNABLE_ANNOTATION');assert a.get('ANNOTATION_ID')=='changed1'
        assert a.get('CVE_REF')=='verb' and a.get('LANG_REF')=='eng' and a.findtext('ANNOTATION_VALUE')=='verb'
        assert edited.find('.//CROSS_REF_LINK').get('REF1')=='changed1'
        assert 'changed1' in edited.find('.//GROUP_REF_LINK').get('REFS').split()
        assert all(n.get('ANNOTATION_REF')=='changed1' for n in edited.findall('.//REF_ANNOTATION'))
        assert edited.find(".//TIME_SLOT[@TIME_SLOT_ID='未对齐3']").get('TIME_VALUE')=='4294967295'
        assert edited.find('CONSTRAINT').get('DESCRIPTION')=='按原文保留 & 不替换'
        last=blocks[len(valid)+1];assert last.startswith('远程\nUNRESOLVED\nCOLLISION\n')
        original=parsed(last.split('\n',3)[3].strip());assert semantic(original)==semantic(parsed(BASE))
        workflow=subprocess.run(['moon','run','examples/conformance','--target',target],cwd=ROOT,capture_output=True,text=True,encoding='utf8',check=True).stdout
        doc,ecv=workflow.split('EAF30_WORKFLOW_END\n')
        saved=parsed(doc.strip()); schema.assertValid(saved); schema.assertValid(parsed(ecv.strip()))
        for i,text in enumerate([BASE,xml(edited),doc.strip()]):
            path=ROOT/'_build'/('eaf30-reader-'+str(i)+'.eaf');path.write_text(text,encoding='utf8')
            independent=Eaf(str(path))
            assert 4294967295 in independent.timeslots.values()
            assert independent.media_descriptors[0]['TIME_ORIGIN']=='-9223372036854775808'
            assert independent.adocument['VERSION']=='3.0'
        assert independent.header['TIME_UNITS']=='PAL-frames'
        assert independent.tiers['speech'][0]['utterance_1'][2]=='noun'
        assert saved.find('HEADER').get('TIME_UNITS')=='PAL-frames'
        assert saved.find('.//ALIGNABLE_ANNOTATION').get('CVE_REF')=='noun'
        assert saved.findtext('.//ANNOTATION_VALUE')=='noun'
        evidence={'independent_reader_documents':3,'external_edit_workflow':True,'target':target,'valid_xsd_cases':len(valid),'invalid_xsd_cases':len(invalid),'mutated_workflow':True,'external_resource_resolution':True,'source_unchanged':True,**coverage}
        out=ROOT/'_build'/('eaf30-conformance-'+target+'.json');out.write_text(json.dumps(evidence,ensure_ascii=False,indent=2),encoding='utf8')
        print(json.dumps(evidence,ensure_ascii=False))
    finally:
        assert runner.resolve()==(ROOT/'examples/conformance_batch').resolve() and runner.parent.resolve()==(ROOT/'examples').resolve()
        shutil.rmtree(runner)
if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--target',default='wasm-gc');run(p.parse_args().target)
