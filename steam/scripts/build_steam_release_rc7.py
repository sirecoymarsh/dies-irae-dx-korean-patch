from __future__ import annotations

import hashlib
import json
import re
import shutil
import zipfile
from datetime import datetime, timezone, timedelta
from pathlib import Path

P = Path(r"P:\AI\Codex\projects\dies_irae_steam_kr_v1")
FINAL = Path(r"P:\AI\Codex\game_localization\Dies_irae_DX_KR\release\candidate_1.0.0-rc1-ui-final_20260811T234729KST\Dies_irae_DX_KR_1.0.0-rc1-ui-final")
TEMPLATE = Path(r"P:\AI\Codex\projects\dies_irae_steam_kr_v1\release\candidate_1.0.0-steam-build21665074-rc2_20260812T004635KST\Dies_irae_KR_1.0.0-steam-build21665074-rc2")
MERGED = P / "merged_overlay_v1"
VERSION = "1.0.0-steam-build21665074-rc7"
STAMP = datetime.now(timezone(timedelta(hours=9))).strftime("%Y%m%dT%H%M%SKST")
CAND = P / "release" / f"candidate_{VERSION}_{STAMP}"
ROOT = CAND / f"Dies_irae_KR_{VERSION}"
ZIP = CAND / f"Dies_irae_KR_{VERSION}.zip"

BASE = {
    "data1.dat": "2EFE8AA9FFD16E23A6B80A098946079FA6E124F16C4264657685097238D576A2",
    "data2.dat": "D900B788306D1F7016FDAA592D3839E0E0845529435B1E8D73931E9D3F17AB39",
    "data3.dat": "582E3A2DE4DFA9AFE0FE6550FE735F817433E49A9E551E6EA97D3DB68F8F7269",
    "data4.cn.dat": "A00FAB55E1E8FD1C49E2D13AA8E5F399D7CA958FB369891633B0CAE2FB89584B",
    "malie.exe": "CFDAA598422245A36B2333F1E923C8E808412D0360C86EF83D914ADF4D6EA926",
    "malie.ini": "6C84095D163250297A506EFA191BA930DD2D87440758C40DF45A3F0D88E24B94",
}
PAY = {
    "data4.cn.dat": "096AE9AB25CF611187E83043A8DD80BAB6E8CB32249FA2E6FC95E0FCD6E82DB3",
    r"data\font\anticcezannepro.otf": "BD505B1E18E9F3484011CE1014C0CF7FC73CC1338C790FA1AAB1A3027856638F",
    r"data\font\tsukugopro-m.otf": "BD505B1E18E9F3484011CE1014C0CF7FC73CC1338C790FA1AAB1A3027856638F",
    "malie_kr.ini": "97FC23AA552A07F4811BE9A2F14C4567B37C34B5D30B442D8B90D7A2ECF7CDEC",
}
TRACK = ["malie.ini", "data4.cn.dat", r"data\font\anticcezannepro.otf", r"data\font\tsukugopro-m.otf"]


def sha(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for block in iter(lambda: f.read(8 * 1024 * 1024), b""):
            h.update(block)
    return h.hexdigest().upper()


def between(text: str, start: str, end: str, replacement: str) -> str:
    i = text.index(start)
    j = text.index(end, i)
    return text[:i] + replacement + text[j:]


def ps_hash_table(name: str, rows: dict[str, str], indent: str = "") -> str:
    body = "\n".join(f"{indent}    '{k}' = '{v}'" for k, v in rows.items())
    return f"{indent}${name} = [ordered]@{{\n{body}\n{indent}}}\n"


def install_script() -> str:
    s = (TEMPLATE / "install_ko.ps1").read_text(encoding="utf-8-sig")
    s = re.sub(r"\$ReleaseVersion = '[^']+'", f"$ReleaseVersion = '{VERSION}'", s, count=1)
    s = between(s, "function Hex-Bytes", "Assert-NoReparsePoint $PackageRoot", "")
    s = s.replace(
        "foreach ($relative in @('malie.exe', 'malie.ini', 'data5.dat', 'data\\font\\anticcezannepro.otf', 'data\\font\\tsukugopro-m.otf'))",
        "foreach ($relative in @('malie.exe', 'malie.ini', 'data4.cn.dat', 'data\\font\\anticcezannepro.otf', 'data\\font\\tsukugopro-m.otf'))",
    )
    s = between(s, "$baseline = [ordered]@{", "foreach ($entry in $baseline.GetEnumerator())", ps_hash_table("baseline", BASE))
    s = between(s, "$packageHashes = [ordered]@{", "foreach ($entry in $packageHashes.GetEnumerator())", ps_hash_table("packageHashes", PAY))
    s = between(s, "foreach ($name in @('data5.dat'))", "$timestamp =", "")
    tracked = ", ".join(f"'{x}'" for x in TRACK)
    s = between(s, "$tracked = @(", "$states = @()", f"$tracked = @({tracked})\n")
    s = s.replace(
        "Install-VerifiedFile (Join-Path $FilesRoot 'data5.dat') (Join-Path $GameDir 'data5.dat') $packageHashes['data5.dat']",
        "Install-VerifiedFile (Join-Path $FilesRoot 'data4.cn.dat') (Join-Path $GameDir 'data4.cn.dat') $packageHashes['data4.cn.dat']",
    )
    installed = {
        "malie.ini": "$packageHashes['malie_kr.ini']",
        "data4.cn.dat": "$packageHashes['data4.cn.dat']",
        r"data\font\anticcezannepro.otf": "$packageHashes['data\\font\\anticcezannepro.otf']",
        r"data\font\tsukugopro-m.otf": "$packageHashes['data\\font\\tsukugopro-m.otf']",
    }
    block = "$installedHashes = [ordered]@{\n" + "\n".join(f"        '{k}' = {v}" for k, v in installed.items()) + "\n    }\n"
    s = between(s, "$installedHashes = [ordered]@{", "    foreach ($entry in $installedHashes.GetEnumerator())", block)
    stale = ["data5.dat", "malie_fabula", "Patch-Executable", "data6.dat"]
    for token in stale:
        if token in s:
            raise RuntimeError(f"stale installer token: {token}")
    return s


def verify_script() -> str:
    s = (TEMPLATE / "verify_ko.ps1").read_text(encoding="utf-8-sig")
    tracked = ", ".join(f"'{x}'" for x in TRACK)
    s = re.sub(r"\$expectedTracked = @\([^\n]+\)", lambda _: f"$expectedTracked = @({tracked})", s, count=1)
    immutable = {k: v for k, v in BASE.items() if k in {"data1.dat", "data2.dat", "data3.dat", "malie.exe"}}
    s = between(s, "$originalArchives = [ordered]@{", "foreach ($entry in $originalArchives.GetEnumerator())", ps_hash_table("originalArchives", immutable))
    s = re.sub(r"Write-Host '[^'\r\n]*'\s*$", "Write-Host '\uc124\uce58\ub41c \ud328\uce58 \ud30c\uc77c\uc774 \uc815\ud655\ud558\uba70 data1~data3 \ubc0f \uc2e4\ud589 \ud30c\uc77c\uc740 \uc6d0\ubcf8 \uadf8\ub300\ub85c\uc785\ub2c8\ub2e4.'\n", s)
    for token in ("data5.dat", "data6.dat", "malie_fabula"):
        if token in s:
            raise RuntimeError(f"stale verify token: {token}")
    return s


def uninstall_script() -> str:
    s = (TEMPLATE / "uninstall_ko.ps1").read_text(encoding="utf-8-sig")
    tracked = ", ".join(f"'{x}'" for x in TRACK)
    s = re.sub(r"\$expectedTracked = @\([^\n]+\)", lambda _: f"$expectedTracked = @({tracked})", s, count=1)
    for token in ("data5.dat", "data6.dat", "malie_fabula"):
        if token in s:
            raise RuntimeError(f"stale uninstall token: {token}")
    return s


def write_docs() -> None:
    (ROOT / "README_KO.md").write_text(
        f"""# Dies irae ~Amantes amentes~ ?쒓뎅???⑥튂 ??Steam ?꾩슜\n\n??? Steam AppID 644540 / build 21665074  \n由대━?? `{VERSION}`\n\n## 諛⑹떇\nSteam ?ㅽ뻾 ?뚯씪? `data5.dat`瑜??쎌? ?딄퀬 `data1.dat`~`data3.dat`? `data4.cn.dat`留??쎌뒿?덈떎. ?곕씪??怨듭떇 Steam `data4.cn.dat`??1,379媛???ぉ??蹂댁〈???? 寃利앸맂 理쒖쥌 ?쒓뎅??鍮뚮뱶??3,009媛???ぉ???쒓뎅???곗꽑?쒖쐞濡?蹂묓빀??`data4.cn.dat`瑜??ㅼ튂?⑸땲?? ?ㅽ뻾 ?뚯씪? ?섏젙?섏? ?딆뒿?덈떎.\n\n## ?ㅼ튂\n```powershell\npowershell -ExecutionPolicy Bypass -File .\\install_ko.ps1 -GameDir \"Y:\\SteamLibrary\\steamapps\\common\\Dies irae ~Amantes amentes~\"\n```\n寃利앹? `verify_ko.ps1`, ?먯긽蹂듭썝? `uninstall_ko.ps1`??媛숈? `-GameDir`???ъ슜?⑸땲?? ?ㅼ튂湲곕뒗 ?먮낯 `data4.cn.dat`, `malie.ini`, ?몃? 湲瑗??곹깭瑜??⑦궎吏 諛??곹깭 ?대뜑??諛깆뾽?섍퀬 ?댁떆瑜?寃利앺빀?덈떎.\n\n## ?명솚??n?ㅻⅨ Steam 鍮뚮뱶??蹂議곕맂 ?먮낯? ?댁떆 遺덉씪移섎줈 ?ㅼ튂媛 以묐떒?⑸땲?? Quick/Auto ?ㅽ뻾 ?뚯씪 ?⑥튂??Steam DRM ?뚮Ц???ы븿?섏? ?딆뒿?덈떎. ?뺤쟻 寃利??꾨즺 ?곹깭?대ŉ ?ㅼ젣 Steam ?고???寃利??꾩뿉??諛고룷 ?밴꺽?섏? ?딆뒿?덈떎.\n""",
        encoding="utf-8",
    )
    (ROOT / "QA_STATUS.md").write_text(
        "# QA STATUS\n\n`PASS_STATIC_STEAM_MERGED_DATA4CN_RUNTIME_PENDING`\n\n"
        "- Steam build/hash binding: PASS\n"
        "- merged data4.cn 4,386 entries / LIBP roundtrip: PASS\n"
        "- Korean exec exact SHA and 39,945 messages: PASS\n"
        "- Steam executable byte-identical: PASS\n"
        "- actual Steam install/runtime: pending\n",
        encoding="utf-8",
    )


def release_manifest() -> dict:
    rows = []
    for p in sorted((x for x in ROOT.rglob("*") if x.is_file()), key=lambda x: x.relative_to(ROOT).as_posix().casefold()):
        rows.append({"path": p.relative_to(ROOT).as_posix(), "size": p.stat().st_size, "sha256": sha(p)})
    return {
        "schema": "dies-irae-steam-kr.release-manifest.v2",
        "release_version": VERSION,
        "status": "PASS_STATIC_STEAM_MERGED_DATA4CN_RUNTIME_PENDING",
        "steam": {"appid": 644540, "buildid": 21665074},
        "compatibility": {
            "source_exec_sha256": "1887ACB482A0793460E972A78B0501AE16C69298ECAE1D72DF8DF51F9B021A1E",
            "exact_source_exec_reuse": True,
            "message_count": 39945,
            "c0_topology_equal": True,
            "korean_exec_sha256": "6284DCA98E02C7B91CAC1706D8A8951EAC10B7259ABBBD166EBCEB4269430003",
            "original_exe_sha256": BASE["malie.exe"],
            "executable_modified": False,
            "installed_exe_sha256": BASE["malie.exe"],
            "steam_loads_data5": False,
            "merge_result_files": 4386,
            "merged_data4cn_sha256": PAY["data4.cn.dat"],
        },
        "baseline": BASE,
        "installed_payload": PAY,
        "files": rows,
    }


def main() -> None:
    if CAND.exists():
        raise RuntimeError(f"candidate exists: {CAND}")
    if sha(MERGED / "data4.cn.dat") != PAY["data4.cn.dat"]:
        raise RuntimeError("merged data4.cn hash mismatch")
    (ROOT / "files" / "data" / "font").mkdir(parents=True)
    (ROOT / "manifests").mkdir()
    (ROOT / "evidence").mkdir()
    (ROOT / "licenses").mkdir()
    copies = {
        MERGED / "data4.cn.dat": ROOT / "files" / "data4.cn.dat",
        FINAL / "files" / "malie_kr.ini": ROOT / "files" / "malie_kr.ini",
        FINAL / "files" / "data" / "font" / "anticcezannepro.otf": ROOT / "files" / "data" / "font" / "anticcezannepro.otf",
        FINAL / "files" / "data" / "font" / "tsukugopro-m.otf": ROOT / "files" / "data" / "font" / "tsukugopro-m.otf",
    }
    for source, target in copies.items():
        shutil.copy2(source, target)
    for relative, expected in PAY.items():
        actual = sha(ROOT / "files" / Path(relative.replace("\\", "/")))
        if actual != expected:
            raise RuntimeError(f"payload mismatch: {relative}: {actual}")
    (ROOT / "install_ko.ps1").write_text(install_script(), encoding="utf-8-sig")
    (ROOT / "verify_ko.ps1").write_text(verify_script(), encoding="utf-8-sig")
    (ROOT / "uninstall_ko.ps1").write_text(uninstall_script(), encoding="utf-8-sig")
    write_docs()
    shutil.copy2(FINAL / "THIRD_PARTY_NOTICES.md", ROOT / "THIRD_PARTY_NOTICES.md")
    shutil.copytree(FINAL / "licenses", ROOT / "licenses", dirs_exist_ok=True)
    shutil.copy2(P / "exec_port" / "exec_comparison.json", ROOT / "evidence" / "exec_comparison.json")
    shutil.copy2(P / "analysis" / "steam_vs_korean_data5_summary.json", ROOT / "evidence" / "steam_archive_comparison.json")
    shutil.copy2(MERGED / "merge_build_manifest.json", ROOT / "evidence" / "merge_build_manifest.json")
    manifest_path = ROOT / "manifests" / "release_manifest.json"
    manifest_path.write_text(json.dumps(release_manifest(), ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    with zipfile.ZipFile(ZIP, "w", zipfile.ZIP_DEFLATED, compresslevel=9) as zf:
        for p in sorted((x for x in ROOT.rglob("*") if x.is_file()), key=lambda x: x.relative_to(ROOT.parent).as_posix().casefold()):
            info = zipfile.ZipInfo(p.relative_to(ROOT.parent).as_posix(), (2026, 8, 12, 0, 0, 0))
            info.compress_type = zipfile.ZIP_DEFLATED
            info.external_attr = 0o100644 << 16
            zf.writestr(info, p.read_bytes(), compress_type=zipfile.ZIP_DEFLATED, compresslevel=9)
    result = {
        "schema": "dies-irae-steam-kr.build-result.v2",
        "status": "PASS_STATIC_STEAM_MERGED_DATA4CN_RUNTIME_PENDING",
        "candidate": str(CAND),
        "release_root": str(ROOT),
        "zip": {"path": str(ZIP), "size": ZIP.stat().st_size, "sha256": sha(ZIP)},
        "release_manifest_sha256": sha(manifest_path),
        "data4cn_sha256": sha(ROOT / "files" / "data4.cn.dat"),
        "data4cn_size": (ROOT / "files" / "data4.cn.dat").stat().st_size,
        "merge_result_files": 4386,
        "steam_executable_modified": False,
        "steam_build": 21665074,
    }
    (CAND / "BUILD_RESULT.json").write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(result, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
