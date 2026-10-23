#!/usr/bin/env python3
"""
Convert a UCSC-style IGV hub (hub.txt + groups.txt) into the legacy IGV 2.x
"Load from Server" XML format.

Parsing and grouping rules mirror org.igv.ucsc.hub.HubParser / Stanza / TrackDbHub
so the resulting Category tree matches the containers IGV builds for the hub.
"""
import re
import sys
import os
from xml.sax.saxutils import quoteattr

WS = re.compile(r"\s+")

SUPPORTED_TYPES = {"bigbed", "bigwig", "biggenepred", "vcftabix", "refgene",
                   "bam", "sampleinfo", "vcf.list", "ucscsnp", "bed", "tdf", "gff", "gff3", "gtf", "vcf",
                   "vcfphasedtrio", "bigdbsnp", "rmask", "genepred", "wig", "bedgraph", "interact", "broadpeak",
                   "narrowpeak", "gappedpeak", "gistic", "seg", "mut", "bigpsl"}
FILTER_TRACKS = {"cytoBandIdeo", "assembly"}

PARENT_OVERRIDE = {"visibility", "priority", "group"}
NON_INHERITABLE = {"track", "type", "shortLabel", "longLabel", "bigDataUrl",
                   "parent", "superTrack", "priority", "compositeTrack", "view", "compositeContainer"}
LABEL_KEYS = {"shortLabel", "longLabel", "metadata", "label"}


def first_word(s):
    return WS.split(s.strip())[0]


class Stanza:
    def __init__(self, stype, name):
        self.type = stype
        self.name = name
        self.props = {}
        self.parent = None

    def own(self, key):
        return self.props.get(key)

    def has_own(self, key):
        return self.props.get(key) is not None

    def get(self, key):
        if "noInherit" in self.props:
            return self.own(key)
        if key in PARENT_OVERRIDE and self.parent is not None and self.parent.has(key):
            return self.parent.get(key)
        if key in self.props:
            return self.props[key]
        if self.parent is not None and key not in NON_INHERITABLE:
            return self.parent.get(key)
        return None

    def has(self, key):
        return self.get(key) is not None

    def format(self):
        t = self.own("type")
        return first_word(t) if t else None


def load_stanzas(path):
    nodes = []
    current = None
    start_new = True
    with open(path) as f:
        lines = f.read().split("\n")
    i = 0
    while i < len(lines):
        line = lines[i]
        i += 1
        if line.startswith("#"):
            continue
        while line.endswith("\\") and i < len(lines):
            line = line[:-1] + " " + lines[i].strip()
            i += 1
        indent = len(line) - len(line.lstrip(" \t"))
        sp = line.find(" ", indent)
        if sp < 0:
            start_new = True
            continue
        key = line[indent:sp]
        if key.startswith("#"):
            continue
        value = line[sp + 1:].strip()
        if key == "type":
            value = WS.split(value)[0]
        elif key in ("color", "altColor"):
            # HubParser keeps only the first token, which mangles "r, g, b" with spaces; keep the whole value
            value = value.replace(" ", "")
        elif key not in LABEL_KEYS:
            value = WS.split(value)[0]
        if start_new:
            current = Stanza(key, value)
            nodes.append(current)
            start_new = False
        current.props[key] = value
    # resolveParents: last stanza with a given name wins in the lookup map
    node_map = {}
    for n in nodes:
        node_map[n.name] = n
    for n in nodes:
        if "parent" in n.props:
            pname = first_word(n.props["parent"])
            n.parent = node_map.get(pname)
            n.props["parent"] = pname
    return nodes


def get_priority(s):
    try:
        toks = s.strip().split(".")
        p = int(toks[0]) * 100
        if len(toks) > 1:
            p += int(toks[1]) * 10
        if len(toks) > 2:
            p += int(toks[2])
        return p
    except Exception:
        return 2 ** 31 - 1


RAW = {}


class Container:
    def __init__(self, name, label, priority):
        self.name = name
        self.label = label
        self.priority = priority
        self.tracks = []
        self.children = []

    def is_empty(self):
        return not self.tracks and all(c.is_empty() for c in self.children)


def track_config(s):
    cfg = {}
    cfg["name"] = s.get("shortLabel")
    cfg["path"] = s.get("bigDataUrl")
    long_label = s.own("longLabel")
    if long_label is None:
        ll = s.get("longLabel")
        long_label = ll if ll and len(ll) > len(cfg["name"]) else cfg["name"]
    cfg["description"] = long_label if long_label != cfg["name"] else None
    cfg["hyperlink"] = s.get("html")
    cfg["url"] = s.get("url")
    label_fields = s.get("defaultLabelFields") if s.has("defaultLabelFields") else s.get("labelFields")
    cfg["labelField"] = label_fields.split(",")[0] if label_fields else None
    color = s.get("color")
    cfg["color"] = color.replace(" ", "") if color and "," in color else color
    if s.has("bigDataIndex"):
        cfg["index"] = s.get("bigDataIndex")

    tl = []
    vw = None
    if s.has("maxWindowToDraw"):
        vw = min(int(s.get("maxWindowToDraw")), 2 ** 31 - 1)
    if s.has("maxWindowCoverage"):
        vw = min(int(s.get("maxWindowCoverage")), 2 ** 31 - 1)
    if vw is not None:
        tl.append("visibilityWindow=%d" % vw)
    if s.has("viewLimits"):
        tl.append("viewLimits=" + s.get("viewLimits"))
    if s.has("autoScale"):
        tl.append("autoScale=" + s.get("autoScale").lower())
    if s.has("maxHeightPixels"):
        tl.append("maxHeightPixels=" + s.get("maxHeightPixels"))
    cfg["trackLine"] = " ".join(tl) if tl else None
    return cfg


def group_tracks(track_stanzas, group_stanzas, hub_name):
    containers = []
    lookup = {}
    null_container = Container(hub_name, hub_name, 0)
    containers.append(null_container)
    unsupported = []

    for g in group_stanzas:
        name = g.get("name")
        pri = get_priority(g.get("priority")) if g.has("priority") else 2 ** 31 - 2
        c = Container(name, g.get("label"), pri)
        lookup[name] = c
        containers.append(c)

    for s in track_stanzas:
        is_container = ((s.has_own("superTrack") and not s.has_own("bigDataUrl")) or
                        s.has_own("compositeTrack") or s.has_own("view") or
                        (s.has_own("container") and s.own("container") == "multiWig"))
        parent = None
        if s.has_own("parent"):
            parent = lookup.get(s.own("parent"))
        if parent is None and s.has("group"):
            gname = s.get("group")
            if gname in lookup:
                parent = lookup[gname]
            else:
                parent = Container(gname, gname, 1000)
                lookup[gname] = parent
                containers.append(parent)

        if is_container:
            name = s.get("track")
            pri = get_priority(s.get("priority")) if s.has("priority") else 2 ** 31 - 2
            ll = s.get("longLabel")
            label = ll if ll is not None and len(ll) < 50 else s.get("shortLabel")
            c = Container(name, label, pri)
            if name in lookup:
                raise RuntimeError("Duplicate track container: " + name)
            lookup[name] = c
            if parent is None:
                containers.append(c)
            else:
                parent.children.append(c)
        elif (s.name not in FILTER_TRACKS and s.has("bigDataUrl") and s.format() is not None
              and s.format().lower() in SUPPORTED_TYPES
              and not s.get("bigDataUrl").lower().endswith(".bigpsl")):  # IGV 2.x does not recognize the extension
            cfg = track_config(s)
            target = parent if parent is not None else null_container
            target.tracks.append(cfg)
            RAW.setdefault(id(target), []).append(s)
        elif s.name not in FILTER_TRACKS and s.has("bigDataUrl"):
            unsupported.append((s.name, s.format()))

    containers = [c for c in containers if not c.is_empty()]
    containers.sort(key=lambda c: c.priority)
    return containers, unsupported


ATTR_ORDER = ["name", "path", "description", "hyperlink", "url", "labelField", "color", "index", "trackLine"]


def write_resource(out, cfg, indent):
    pad = " " * indent
    attrs = [(k, cfg[k]) for k in ATTR_ORDER if cfg.get(k)]
    out.append("%s<Resource %s" % (pad, "name=%s" % quoteattr(attrs[0][1])))
    for k, v in attrs[1:]:
        out.append("%s          %s=%s" % (pad, k, quoteattr(v)))
    out[-1] += "/>"


def write_container(out, c, indent):
    pad = " " * indent
    out.append("%s<Category name=%s>" % (pad, quoteattr(c.label)))
    for t in c.tracks:
        write_resource(out, t, indent + 4)
    for child in c.children:
        if not child.is_empty():
            write_container(out, child, indent + 4)
    out.append("%s</Category>" % pad)


def dump_container(out, c, pad, raw):
    out.append(pad + "C " + c.label)
    for s in raw.get(id(c), []):
        cfg = track_config(s)
        vw = cfg["trackLine"] and re.search(r"visibilityWindow=(\d+)", cfg["trackLine"])
        vl = s.get("viewLimits")
        if vl:
            toks = vl.split(":")
            mn, mx = (None, float(toks[0])) if len(toks) == 1 else (float(toks[0]), float(toks[1]))
        else:
            mn, mx = None, None
        mh = s.get("maxHeightPixels")
        mh = ([int(x) for x in mh.split(":")] + [None, None, None])[:3] if mh else [None, None, None]
        auto = ("on" == s.get("autoScale").lower()) if s.has("autoScale") else None
        color = s.get("color")
        color = ("rgb(" + color + ")") if color and "," in color else color
        out.append(pad + "  T " + "|".join(str(x) for x in [
            cfg["name"], cfg["path"], s.get("longLabel"), cfg["hyperlink"], cfg["url"], cfg["labelField"], color,
            vw.group(1) if vw else None, "%s:%s" % (mn, mx), auto, "%s:%s:%s" % tuple(mh)]))
    for ch in c.children:
        if not ch.is_empty():
            dump_container(out, ch, pad + "  ", raw)


def main(hub_path, out_path):
    stanzas = load_stanzas(hub_path)
    hub = next(s for s in stanzas if s.type == "hub")
    hub_name = hub.get("shortLabel") or hub.get("hub")
    hub_dir = os.path.dirname(hub_path)
    if hub.has("genomesFile"):
        # Multi-file hub: genome stanzas in genomesFile, each naming a trackDb (first genome is used)
        genome = next(s for s in load_stanzas(os.path.join(hub_dir, hub.get("genomesFile"))) if s.type == "genome")
        track_stanzas = [s for s in load_stanzas(os.path.join(hub_dir, genome.get("trackDb"))) if s.type == "track"]
    else:
        genome = next(s for s in stanzas if s.type == "genome")
        track_stanzas = [s for s in stanzas if s.type == "track"]
    group_stanzas = None
    if genome.has("groups"):
        group_stanzas = load_stanzas(os.path.join(hub_dir, genome.get("groups")))

    containers, unsupported = group_tracks(track_stanzas, group_stanzas or [], hub_name)

    out = ['<?xml version="1.0" encoding="UTF-8"?>', '<Global name="Annotations" version="1">', ""]
    for c in containers:
        if c.name == hub_name:
            for t in c.tracks:
                write_resource(out, t, 4)
        else:
            write_container(out, c, 4)
        out.append("")
    out.append("</Global>")
    with open(out_path, "w") as f:
        f.write("\n".join(out) + "\n")
    if len(sys.argv) > 3:
        d = []
        for c in containers:
            dump_container(d, c, "", RAW)
        with open(sys.argv[3], "w") as f:
            f.write("\n".join(d) + "\n")

    n = sum(len(c.tracks) + sum(len(ch.tracks) for ch in c.children) for c in containers)
    print("Wrote %s: %d categories, %d resources" % (out_path, len(containers), n))
    for c in containers:
        print("  %-45s tracks=%d subcategories=%d" % (c.label, len(c.tracks), len([x for x in c.children if not x.is_empty()])))
        for ch in c.children:
            if not ch.is_empty():
                print("      %-41s tracks=%d" % (ch.label, len(ch.tracks)))
    if unsupported:
        print("Dropped (unsupported type):")
        for name, fmt in unsupported:
            print("  %s (%s)" % (name, fmt))


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
