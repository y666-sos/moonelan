"""Schema + independent reader checks for optional timing and multilingual CVs."""
import argparse
import csv
import io
import json
from pathlib import Path
import subprocess
import tempfile
from lxml import etree
from pympi import Eaf
from verify_interop import load_schemas


def verify(block, index, schemas, directory):
    text, rest = block.lstrip("\r\n").split("MOONELAN_XML_END\n", 1)
    dataset, csv_text = rest.split("MOONELAN_JSON_END\n", 1)
    root = etree.fromstring(text.encode("utf8"))
    schemas[root.get("VERSION")].assertValid(root)
    path = directory / (str(index) + ".eaf")
    path.write_text(text, encoding="utf8")
    independent = Eaf(str(path))
    language = ["zho", "eng"][index % 2]
    mode = (index // 2) % 4
    expected = {
        "utterance1": (0 if mode < 2 else None, 1000 if mode < 3 else None),
        "w1": (0 if mode < 2 else None, 400 if mode == 0 else None),
        "w2": (400 if mode == 0 else None, 1000 if mode < 3 else None),
        "p1": (0 if mode < 2 else None, 400 if mode == 0 else None),
    }
    data = json.loads(dataset)
    assert data["schema"] == "moonelan.corpus.v2"
    assert len(data["rows"]) == 4
    csv_rows = list(csv.DictReader(io.StringIO(csv_text, newline="")))
    for row, csv_row in zip(data["rows"], csv_rows):
        lo, hi = expected[row["id"]]
        assert (row["start_ms"], row["end_ms"]) == (lo, hi)
        assert csv_row["start_ms"] == ("" if lo is None else str(lo))
        assert csv_row["end_ms"] == ("" if hi is None else str(hi))
        assert row["path"][-1] == row["id"]
        assert row["root"] == "utterance1"
        assert row["value"] == csv_row["value"]
        align, refs, _, _ = independent.tiers[row["tier"]]
        if row["id"] in align:
            start, end, value, _ = align[row["id"]]
            assert (independent.timeslots[start], independent.timeslots[end]) == (lo, hi)
        else:
            target, value, _, _ = refs[row["id"]]
            assert row["parent"] == target
        assert row["value"] == value
    cv = independent.controlled_vocabularies["POS"]
    assert len(cv[1]) == 2
    assert set(independent.languages) == {"zho", "eng"}
    assert independent.media_descriptors[0]["TIME_ORIGIN"] == "-100"
    assert independent.linked_file_descriptors[0]["TIME_ORIGIN"] == "-20"
    assert independent.lexicon_refs["lex"]["LEXICON_ID"] == "lex1"
    tag = root.find(".//REF_ANNOTATION[@ANNOTATION_ID='p1']")
    assert tag.get("CVE_REF") == "verb" and tag.get("LANG_REF") == language
    assert tag.findtext("ANNOTATION_VALUE") == ("动词" if language == "zho" else "verb")
    if root.get("VERSION") == "3.0":
        assert root.find(".//CROSS_REF_LINK").get("REF1") == "utterance1"
    return len(data["rows"])


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--target", default="wasm-gc")
    parser.add_argument("--schema-dir", type=Path, default=Path("_build/oracle-schemas"))
    args = parser.parse_args()
    schemas = load_schemas(args.schema_dir)
    output = subprocess.check_output(["moon", "run", "examples/compatibility", "--target", args.target], encoding="utf8")
    cases = output.split("MOONELAN_CASE_END")
    assert len(cases) == 17 and not cases[-1].strip()
    with tempfile.TemporaryDirectory(prefix="moonelan-compatibility-") as temp:
        count = sum(verify(block, i, schemas, Path(temp)) for i, block in enumerate(cases[:-1]))
    foreign_xml = subprocess.check_output(["moon", "run", "examples/foreign", "--target", args.target], encoding="utf8")
    foreign_root = etree.fromstring(foreign_xml.encode("utf8"))
    schemas["3.0"].assertValid(foreign_root)
    assert "TIME_VALUE" not in foreign_root.find("TIME_ORDER/TIME_SLOT").attrib
    assert foreign_root.find(".//ANNOTATION_VALUE").text == "完成"
    assert foreign_root.find(".//ALIGNABLE_ANNOTATION").get("CVE_REF") == "done"
    print(json.dumps({"passed": True, "foreign_generated_documents": 1, "target": args.target, "documents": 16,
                      "annotations": count, "pympi": "1.70.2", "versions": ["2.8", "3.0"]}))


if __name__ == "__main__":
    main()
