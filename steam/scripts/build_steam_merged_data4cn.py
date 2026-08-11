from __future__ import annotations
import hashlib,importlib.util,json,shutil,sys
from pathlib import Path
PROJECT=Path(r'P:\AI\Codex\projects\dies_irae_steam_kr_v1')
STEAM=Path(r'Y:\SteamLibrary\steamapps\common\Dies irae ~Amantes amentes~')
KDATA5=Path(r'P:\AI\Codex\game_localization\Dies_irae_DX_KR\release\candidate_1.0.0-rc1-ui-final_20260811T234729KST\Dies_irae_DX_KR_1.0.0-rc1-ui-final\files\data5.dat')
AUDIT=Path(r'C:\Users\CadriacLord\Documents\Codex\2026-08-08\f-down-dies-irae-dx-package\work\audits\toolbar_archive_diff_audit_20260810.py')
PACK=Path(r'C:\Users\CadriacLord\Documents\Codex\2026-08-08\f-down-dies-irae-dx-package\work\final_pipeline\build_malie_overlay_release.py')
ROOT=PROJECT/'merged_overlay_v1'; TREE=ROOT/'input'; OUT=ROOT/'data4.cn.dat'; MAN=ROOT/'merge_build_manifest.json'
def sha(b):return hashlib.sha256(b).hexdigest().upper()
def shaf(p):
 h=hashlib.sha256()
 with p.open('rb') as f:
  for b in iter(lambda:f.read(8*1024*1024),b''):h.update(b)
 return h.hexdigest().upper()
def mod_from_source(path,name,relax=False):
 src=path.read_text(encoding='utf-8')
 if relax:
  src=src.replace('    if any(header_padding):\n        raise ValueError("nonzero plaintext header padding")\n','')
  src=src.replace('            if n["flags"] != FILE_FLAG:\n                raise ValueError(f"unexpected file flags at {node_index}: 0x{n[\'flags\']:08X}")\n','')
  src=src.replace('        if n["flags"] != 0:\n            raise ValueError(f"unexpected directory flags at {node_index}: 0x{n[\'flags\']:08X}")\n','')
  src=src.replace('        if e["allocation_size"] <= 0 or e["padding_size"] < 0:\n            raise ValueError(f"overlapping/nonpositive allocation for {e[\'path\']}")\n','')
 spec=importlib.util.spec_from_loader(name,loader=None);m=importlib.util.module_from_spec(spec);sys.modules[name]=m;exec(compile(src,str(path),'exec'),m.__dict__);return m
def safe(root,virtual):
 parts=virtual.replace('\\','/').split('/')
 if not parts or parts[0]!='data' or any(x in ('','.', '..') for x in parts):raise RuntimeError('unsafe '+virtual)
 p=root.joinpath(*parts); rp=p.resolve(); rr=root.resolve()
 if rr not in rp.parents:raise RuntimeError('escape '+virtual)
 return p
def extract(aud,archive,name,root,overwrite):
 parsed=aud.parse_index(archive,name); rows={};written=0;common=changed=0
 with archive.open('rb') as f:
  for i,e in enumerate(parsed['entries']):
   data=aud.read_decrypted(f,e['absolute_offset'],e['size'],aud.ROTATE_KEYS[name]); h=sha(data); key=e['path'].casefold(); p=safe(root,e['path'])
   if p.exists():
    common+=1
    if shaf(p)!=h: changed+=1
    if not overwrite:raise RuntimeError('unexpected duplicate '+e['path'])
   p.parent.mkdir(parents=True,exist_ok=True);p.write_bytes(data);rows[key]={'path':e['path'],'size':len(data),'sha256':h,'owner':name};written+=1
   if (i+1)%500==0:print(name,i+1,'/',len(parsed['entries']),flush=True)
 return parsed,rows,{'written':written,'common':common,'changed':changed}
def main():
 if ROOT.exists():raise RuntimeError('fresh root exists '+str(ROOT))
 TREE.mkdir(parents=True)
 aud=mod_from_source(AUDIT,'steam_merge_aud',True); key=aud.ROTATE_KEYS['data5.dat'];aud.ROTATE_KEYS['data4.cn.dat']=key
 p4,r4,s4=extract(aud,STEAM/'data4.cn.dat','data4.cn.dat',TREE,False)
 p5,r5,s5=extract(aud,KDATA5,'data5.dat',TREE,True)
 chosen=dict(r4);chosen.update(r5)
 actual=[]
 for p in TREE.rglob('*'):
  if p.is_file():actual.append(p)
 if len(actual)!=len(chosen):raise RuntimeError(f'count {len(actual)} != {len(chosen)}')
 for k,row in chosen.items():
  p=safe(TREE,row['path'])
  if p.stat().st_size!=row['size'] or shaf(p)!=row['sha256']:raise RuntimeError('tree mismatch '+row['path'])
 pack=mod_from_source(PACK,'steam_merge_pack',False);scheme=pack.SCHEMES['amantes'];ref=pack.validate_reference_archive(STEAM/'data1.dat',scheme)
 plain,indices,files=pack.build_plain_archive(TREE);encrypted=pack.crypt_archive(plain,scheme);verification=pack.verify_archive(encrypted,scheme,files);pack.atomic_write(OUT,encrypted,False)
 doc={'schema':'dies-irae-steam-kr.merged-data4cn.v1','status':'PASS','source_data4cn':{'path':str(STEAM/'data4.cn.dat'),'size':(STEAM/'data4.cn.dat').stat().st_size,'sha256':shaf(STEAM/'data4.cn.dat'),'files':len(r4)},'korean_data5':{'path':str(KDATA5),'size':KDATA5.stat().st_size,'sha256':shaf(KDATA5),'files':len(r5)},'merge':{'common':s5['common'],'changed_common':s5['changed'],'result_files':len(chosen),'korean_precedence':True},'output':{'path':str(OUT),'size':OUT.stat().st_size,'sha256':shaf(OUT),'index_count':len(indices),'file_count':len(files)},'reference':ref,'verification':verification}
 MAN.write_text(json.dumps(doc,ensure_ascii=False,indent=2)+'\n',encoding='utf-8');print(json.dumps(doc,ensure_ascii=False,indent=2))
if __name__=='__main__':main()
