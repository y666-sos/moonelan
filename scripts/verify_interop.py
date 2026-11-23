"""Independent schema, pympi and CSV checks on original generated corpora."""
import argparse
import csv
import hashlib
import io
import json
import subprocess
import tempfile
import urllib.request
from pathlib import Path

from lxml import etree
from pympi import Eaf

SCHEMA_REV = "4e9eb6e0e70e549471816ee30096138ce166a7c3"
SCHEMAS = {
    "2.8": "0cc4790ef04882a7f4acaaf1faad62d38a2c4eeea7396d1ea4255654fcaa4326",
    "3.0": "59e76f90d5840813314b1e635480d044287b811ebd63a40e25cb4e73c6ad72bb",
}


def load_schemas(directory):
    result = {}
    directory.mkdir(parents=True, exist_ok=True)
    for version, digest in SCHEMAS.items():
        path = directory / ("eaf" + version + ".xsd")
        if not path.exists():
            url = ("https://raw.githubusercontent.com/chschenk/ELAN/" + SCHEMA_REV +
                   "/src/main/resources/mpi/eudico/resources/EAFv" + version + ".xsd")
            with urllib.request.urlopen(url, timeout=40) as response:
                data = response.read()
            if hashlib.sha256(data).hexdigest() != digest:
                raise ValueError("schema download hash mismatch")
            path.write_bytes(data)
        data = path.read_bytes()
        if hashlib.sha256(data).hexdigest() != digest:
            raise ValueError("schema cache hash mismatch")
        result[version] = etree.XMLSchema(etree.fromstring(data))
    return result


def expected_span(seed, aid):
    # Closed form from fixture construction, independent of graph resolution.
    if aid.startswith("utterance_"):
        utterance, part = 0, "whole"
    elif aid == "a1":
        utterance, part = 1, "whole"
    elif aid.startswith("tr"):
        utterance, part = int(aid[2:]), "whole"
    elif aid.startswith("g"):
        utterance, part = int(aid[1:]), "gesture"
    else:
        word = aid.split("_")[1] if aid.startswith(("pos_", "morph_")) else aid
        utterance, part = int(word[1]), int(word[2])
    lo = seed * 4000 + utterance * 1500
    mid = lo + 300 + seed % 100
    start, end = {
        "whole": (lo, lo + 1000), "gesture": (lo + 100, lo + 200),
        0: (lo, mid), 1: (mid, lo + 1000),
    }[part]
    return start * 3 // 2 + seed, end * 3 // 2 + seed


def verify_case(seed, text, dataset, csv_text, schemas, directory):
    xml = etree.fromstring(text.encode("utf-8"))
    schemas[xml.attrib["VERSION"]].assertValid(xml)
    path = directory / (str(seed) + ".eaf")
    path.write_text(text, encoding="utf-8")
    independent = Eaf(str(path))
    assert set(independent.get_tier_names()) == {
        "speech", "words", "translation", "morphology", "pos", "gesture"}
    assert dataset["schema"] == "moonelan.corpus.v2"
    rows = dataset["rows"]
    assert len(rows) == 22
    csv_rows = list(csv.DictReader(io.StringIO(csv_text, newline="")))
    assert len(csv_rows) == len(rows)
    for row, csv_row in zip(rows, csv_rows):
        aid, tier = row["id"], row["tier"]
        aligned, references, attrs, _ = independent.tiers[tier]
        assert row["participant"] == attrs.get("PARTICIPANT", "")
        start, end = expected_span(seed, aid)
        assert (row["start_ms"], row["end_ms"]) == (start, end)
        if aid in aligned:
            lo, hi, value, _ = aligned[aid]
            assert (independent.timeslots[lo], independent.timeslots[hi]) == (start, end)
        else:
            target, value, previous, _ = references[aid]
            assert row["parent"] == target
            if tier == "morphology":
                assert row["sibling_index"] == int(aid[-1])
                assert (previous or None) == (None if aid.endswith("0") else aid[:-1] + "0")
        assert row["value"] == value
        assert row["path"][0] == row["root"]
        assert row["path"][-1] == aid
        for field in ("tier", "participant", "id", "root", "value"):
            assert csv_row[field] == row[field]
        assert csv_row["parent"] == (row["parent"] or ""), (aid, csv_row["parent"], row["parent"])
        for field in ("start_ms", "end_ms", "sibling_index"):
            assert int(csv_row[field]) == row[field]
    speech = sorted(independent.get_annotation_data_for_tier("speech"))
    translated = sorted(independent.get_ref_annotation_data_for_tier("translation"))
    assert [(a, b) for a, b, _ in speech] == [(a, b) for a, b, _, _ in translated]
    assert independent.media_descriptors[0]["MIME_TYPE"] == "audio/x-wav"
    return len(rows)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--target", default="wasm-gc", choices=["wasm-gc", "wasm", "js", "native"])
    parser.add_argument("--schema-dir", type=Path, default=Path("_build/oracle-schemas"))
    args = parser.parse_args()
    schemas = load_schemas(args.schema_dir)
    output = subprocess.check_output(
        ["moon", "run", "examples/oracle", "--target", args.target], encoding="utf-8")
    cases = output.split("MOONELAN_CASE_END")
    assert len(cases) == 41 and not cases[-1].strip()
    annotations = 0
    with tempfile.TemporaryDirectory(prefix="moonelan-interop-") as temp:
        for seed, block in enumerate(cases[:-1]):
            text, rest = block.lstrip("\r\n").split("MOONELAN_XML_END\n", 1)
            dataset, csv_text = rest.split("MOONELAN_JSON_END\n", 1)
            annotations += verify_case(seed, text, json.loads(dataset), csv_text, schemas, Path(temp))
    report = {"target": args.target, "documents": 40, "annotations": annotations,
              "schema_versions": list(SCHEMAS), "pympi": "1.70.2", "passed": True}
    print(json.dumps(report, sort_keys=True))


if __name__ == "__main__":
    main()
