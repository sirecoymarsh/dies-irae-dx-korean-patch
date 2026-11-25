# Dies irae DX 한국어 패치

*Dies irae ~Amantes amentes~*와 *Dies irae ~Acta est Fabula~*의 한국어 패치입니다.

## 다운로드

대용량 패치 ZIP은 [GitHub Releases](https://github.com/sirecoymarsh/dies-irae-dx-korean-patch/releases)에서 받으십시오.

- DX 패키지판: [`v1.0.0-rc1`](https://github.com/sirecoymarsh/dies-irae-dx-korean-patch/releases/tag/v1.0.0-rc1) (`1.0.0-rc1-ui-final`)
- Steam판: [`steam-v1.0.3-aa4`](https://github.com/sirecoymarsh/dies-irae-dx-korean-patch/releases/tag/steam-v1.0.3-aa4)
- Steam판 Acta est Fabula 개방 애드온: [`steam-unlock-addon-v1.0.0`](https://github.com/sirecoymarsh/dies-irae-dx-korean-patch/releases/tag/steam-unlock-addon-v1.0.0) (prerelease)

## 추가·변경 사항

이 절은 원본 게임과 비교해 이 패치가 무엇을 바꾸는지 커밋 기록, 매니페스트, 설치 스크립트, 릴리스 노트를 근거로 정리한 것입니다. 괄호 안은 근거(커밋 해시, 파일, 릴리스 태그)이며, 확실하지 않은 내용은 「(추정)」으로 표시했습니다.

Steam판과 개방 애드온의 스크립트·매니페스트는 아직 병합되지 않은 PR #1(`agent/steam-build21665074` 브랜치)에 있고, 배포 파일은 위 Release에 올라 있습니다.

### 번역 범위

- **대상 작품**: *Amantes amentes*(AA, `malie.exe`)와 *Acta est Fabula*(AEF, `malie_fabula.exe`) 두 편을 모두 다룹니다 (`manifests/release_manifest.json`의 `target.editions`).
- **번역 기준**: 영어판(en-US) 텍스트를 기준으로 한국어(ko-KR)로 옮겼습니다. 음성은 일본어(ja-JP) 원본 그대로입니다 (`release_manifest.json`의 `source_locale`, `audio_locale`).
- **시나리오 본문**: 번역 묶음 632/632개, AA 텍스트 슬롯 67,661/67,661개, AEF 추가분 텍스트 슬롯 8,452/8,452개를 모두 채웠고, 전체 검수를 1회 거쳤습니다 (`release_manifest.json`의 `coverage`).
- **인물명·선택지**: 한국어로 표시됩니다. 실제 실행 검사 항목에 인물명·선택지 한국어 표시가 들어 있습니다 (`release_manifest.json`의 `required_runtime_checks`, Steam판 `steam-v1.0.3-aa4` 릴리스 노트).
- **시스템 문자열**: 게임 실행 파일 안에 박혀 있던 저장 슬롯 이름표 `Quick.`을 `퀵.`으로, ` Auto.`를 ` 자동.`으로 바꿨습니다 (`release_manifest.json`의 `patched_executables`, `scripts/install_ko.ps1`).
- **이미지 UI**: UI 이미지 파일을 공통 2,879개, AEF 전용 1,876개 한국어화했습니다. 타이틀 상단 메뉴(툴바), 게임·텍스트·사운드·음성 설정 화면, 음성 설정의 캐릭터 카드(일반·선택 상태) 이름표가 포함됩니다 (`release_manifest.json`의 `ui_payload_files`, `manifests/ui_final_user_acceptance.json`).
- **영상**: 영상 파일을 공통 47개(약 349MB), AEF 전용 37개(약 184MB) 교체했습니다. 영상 안의 글자(제목·자막 등)를 한국어로 바꾼 것으로 보입니다 (추정) (`release_manifest.json`의 `movie_payload_files`, `asset_evidence`).
- **배경 이미지**: 글자가 들어간 배경 이미지를 공통 79개, AEF 전용 44개 교체했습니다 (`release_manifest.json`의 `background_payload_files`).
- **글꼴**: 게임이 쓰는 글꼴 `anticcezannepro.otf`와 `tsukugopro-m.otf`를 현대 한글 전체(11,172자)를 담은 같은 한국어 글꼴로 바꿨습니다. 두 파일은 바이트 단위로 같습니다. 배포 ZIP에 `licenses/OFL.txt`가 있어 SIL Open Font License 글꼴로 보입니다 (추정) (`release_manifest.json`의 `font_qa`, `files`).
- **아카이브 규모**: 한국어 오버레이 `data5.dat`(AA·공통)에 3,009개, `data6.dat`(AEF)에 2,004개 파일이 들어 있습니다 (`release_manifest.json`의 `runtime_first_settings_repair.archive_deltas`).

### 편의 기능

원판에 없던 새 편의 기능은 추가하지 않았습니다. 바뀌는 것은 표시 언어(본문·UI·영상·글꼴)와 저장 슬롯 이름표뿐입니다 (`scripts/install_ko.ps1`).

### 화면·그래픽 개선

- 설정 화면 UI는 원본 그림을 다시 그리거나 색·크기를 바꾸지 않고, 원본 프레임 픽셀을 그대로 둔 채 글자 부분만 한국어로 바꾸는 방식으로 만들었습니다. 음성 카드의 비선택 테두리는 원본 프레임 픽셀을 유지합니다 (`manifests/ui_final_build_summary.json`의 `method`, UI 동결본 「v14 original-border rollback」, `docs/BUILD_AND_QA.md`).
- 일반 상태 이미지 49개만 고쳤고, 선택·마우스오버 상태 이미지와 초상화·이름판 안쪽은 건드리지 않았습니다 (`ui_final_build_summary.json`의 `scope`).
- 해상도·와이드·전체화면 같은 화면 설정 변경은 없습니다.

### 버그 수정 (이전 작업본에서 사용자가 보고한 결함)

- 텍스트 설정 화면에서 한국어 글자가 이전 영어 글자 위에 겹쳐 보이던 문제를 고쳤습니다.
- 영어 글자의 검은 그림자가 남아 보이던 문제를 고쳤습니다.
- 둥근 버튼 테두리가 일그러지던 문제를 고쳤습니다.
- 선택·마우스오버 상태 강조가 납작해지거나 사라지던 문제를 고쳤습니다.

(근거: `release_manifest.json`의 `runtime_first_settings_repair.user_reported_defects_addressed`)

- **Steam판**: 처음 만든 Steam판 후보에서는 본문만 한국어가 되고 인물명과 선택지가 영어로 되돌아갔습니다. `data4.cn.dat`의 영어 슬롯이 나중에 다시 덮어쓰는 우선순위 문제였고, aa4에서 이 슬롯도 한국어 스크립트로 바꿔 해결했습니다 (`steam-v1.0.3-aa4` 릴리스 노트, PR #1의 `4e0a465`).

### 설치·제거 방식

**DX 패키지판** (`scripts/install_ko.ps1`, `scripts/verify_ko.ps1`, `scripts/uninstall_ko.ps1`)

- **원본 확인**: 설치 전에 원본 `data1.dat`~`data4.dat`, `malie.exe`, `malie_fabula.exe`, `malie.ini`의 SHA-256을 확인합니다. 하나라도 다르면 아무것도 바꾸지 않고 멈춥니다. 패치 파일 자체의 해시도 확인합니다.
- **실행 파일 패치**: 두 실행 파일을 각각 세 곳씩, 정해진 위치의 바이트가 예상값과 같을 때만 고칩니다. 고치는 내용은 한국어 `translation.csv`를 UTF-8로 읽게 하는 것과 저장 슬롯 이름표(퀵·자동) 두 가지입니다. 고친 뒤 해시가 예상값과 같은지 다시 확인합니다.
- **설치하는 파일**: `malie.ini`를 한국어판 설정(`malie_kr.ini`)으로 바꾸고, `data5.dat`·`data6.dat` 오버레이와 `data\font\` 글꼴 두 개를 넣습니다. 원본 `data1~4.dat`는 고치지 않습니다. `malie_kr.ini`에서 무엇이 바뀌는지는 이 저장소에 원문이 없습니다 (추정: 오버레이·글꼴을 읽게 하는 설정).
- **백업·복원**: 바꾸기 전 파일을 `%LOCALAPPDATA%\DiesIraeDXKR\<게임 경로 ID>\backups\`에 백업하고, 설치 기록(`active_manifest.json`)을 남깁니다. 설치 도중 실패하면 자동으로 원래대로 되돌립니다.
- **안전장치**: 게임이 실행 중이면 설치·제거를 거부합니다. 이미 설치된 상태에서 다시 설치하는 것, 원래 `data5.dat`/`data6.dat`가 있는 경우(`-AllowBackupExistingOverlays`를 주면 백업 후 진행), 링크·재분석 지점이 낀 경로를 거부합니다. `-StateRoot`로 백업 위치를 바꿀 수 있습니다.
- **검증**: `verify_ko.ps1`은 설치된 파일의 해시가 설치 기록과 같은지 확인합니다.
- **제거**: `uninstall_ko.ps1`은 백업 해시를 확인한 뒤 설치 전 상태로 정확히 되돌리고, 원래 없던 파일은 지웁니다. 설치 후 패치 파일이 바뀌었거나 없어졌으면 멈추며, `-ForceRestore`를 주면 그래도 복원합니다.
- **시험 결과**: 정상 설치, 중복 설치 거부, 해시 검증, 변조 감지, 변조된 원본·패치·백업 거부, 정확한 복원, 중복 제거 거부, 기존 오버레이 백업·복원, 누락 파일 감지, 강제 복원을 모두 통과했습니다. 이 시험은 게임을 실행하지 않은 정적 시험입니다 (`manifests/install_restore_qa_summary.json`).
- **지원 판본**: 위 해시와 같은 「Dies irae DX package」판 전용입니다. 정확한 유통처(패키지·다운로드판)는 저장소에 적혀 있지 않습니다.

**Steam판** (`steam-v1.0.3-aa4`, PR #1의 `steam/`)

- Steam AppID `644540`, 빌드 `21665074`의 *Amantes amentes* 전용입니다.
- 게임 폴더는 레지스트리와 `libraryfolders.vdf`에서 자동으로 찾고, 필요할 때만 `-GameDir`로 지정합니다. 빌드 번호가 다르면 설치를 거부합니다 (`install_ko_steam.ps1`).
- DX 최종 한국어 스크립트를 Steam `data3.dat`의 `data/system/exec.dat`와 `data4.cn.dat`의 영어 슬롯 `data/system/patch.en.dat`에 넣고, DX판 `data5.dat`, 한국어 글꼴을 함께 설치합니다. 아카이브의 다른 항목과 배치 순서는 그대로 둡니다 (`steam/manifests/data3_validation.json`, `data4_validation.json`).
- Steam 실행 파일은 Steamless로 보호 래퍼를 벗기고 체크섬을 다시 계산한 뒤 DX판과 같은 세 가지(UTF-8 공급자, 퀵·자동 이름표)를 고칩니다. Steam API 연동은 그대로 둡니다 (`steam/manifests/steam_executable_port.json`).
- 게임 언어 메뉴에서 **English**를 고르면 한국어가 나오고, **Chinese**는 원래 중국어 그대로 남습니다 (`steam/manifests/language_contract.json`).
- 백업 위치는 `%LOCALAPPDATA%\DiesIraeSteamKR`이고, `verify_ko_steam.ps1`로 검증, `uninstall_ko_steam.ps1`로 원래대로 되돌립니다.

**Steam판 Acta est Fabula 개방 애드온** (`steam-unlock-addon-v1.0.0`, PR #1의 `steam/unlock-addon/`)

- Steam 한국어 패치 `1.0.3-steam-aa4`가 설치된 상태에서, 사용자가 정식으로 받은 공식 `dies_irae_r18_patch.zip`을 해시로 확인한 뒤 그 안의 `data4.dat`와 `malie_fabula.exe`를 꺼내 씁니다. 공식 ZIP은 배포 파일에 들어 있지 않습니다.
- 꺼낸 `malie_fabula.exe`에 UTF-8 공급자와 퀵·자동 이름표 패치만 하고, 한국어 AEF 오버레이 `data6.dat`를 설치합니다.
- 기존 `malie.exe`, `steam_api.dll`, Steam 플레이 버튼(AA 실행)은 바꾸지 않습니다. 개방판은 동봉한 `2_개방_한국어_실행.cmd`로 따로 실행합니다.
- 설치(`1_개방_한국어_설치.cmd`), 실행(`2_…`), 검증(`3_개방_설치_검증.cmd`), 제거(`4_개방_한국어_제거.cmd`) 배치 파일을 제공합니다. 제거하면 애드온 파일만 되돌리고 Steam 한국어 패치는 남깁니다. 백업 위치는 `%LOCALAPPDATA%\DiesIraeSteamKRR18`입니다.

### 판(버전)별 변경 기록

- **2026-08-11 · `v1.0.0-rc1` (DX 패키지판 1.0.0 RC1)** (`bc1aca5`, `8f2d8fc`): 첫 공개판입니다. AA/AEF 한국어 오버레이 `data5`/`data6`, 상단 메뉴와 게임·텍스트·사운드·음성 설정 UI 수정, 음성 카드 원본 프레임 보존과 한국어 이름표, AA 실제 실행 화면 사용자 승인 후 UI 동결, 설치·검증·변조 감지·제거·강제 복원 시험 통과. AEF 실행 재검증이 남아 있어 RC로 표시했습니다.
- **2026-08-12 · Steam 빌드 21665074 RC7** (PR #1의 `6558ace`, 릴리스 없음): 처음에는 Steam 실행 파일이 `data5.dat`를 읽지 않는다고 보고, 실행 파일을 고치지 않은 채 공식 `data4.cn.dat` 1,379개 항목과 한국어 3,009개 항목을 합친 `data4.cn.dat`를 설치하는 방식을 시도했습니다. 실제 실행 확인 전 후보였고, 이후 aa4 방식으로 바뀌었습니다.
- **2026-08-12 · `steam-v1.0.3-aa4` (Steam판 최종)** (PR #1의 `4e0a465`): 위 방식을 버리고 `data3.dat`·`data4.cn.dat` 영어 슬롯·`data5.dat` 세 곳에 같은 스크립트를 넣는 방식으로 바꿨습니다. 실행 파일 호환 패치를 넣고, 인물명·선택지가 영어로 되돌아가던 문제를 고쳤습니다. 실제 Steam 실행에서 본문·인물명(「카스미」)·선택지 한국어 표시와 중국어 슬롯 보존을 확인했습니다. RC7과 aa4 사이의 중간 후보(본문만 바뀌던 「실패 후보」 등)는 릴리스로 남아 있지 않습니다.
- **2026-08-16 · `steam-unlock-addon-v1.0.0` (Steam 개방 애드온, prerelease)** (PR #1의 `5b6ae74`, `9916b82`): Acta est Fabula 한국어 개방판 애드온을 추가했습니다. 처음 이름은 「R-18 애드온」이었다가 「개방 애드온」으로 바꿨습니다. 실제 Steam 설치·검증과 사용자 실행 확인을 마쳤습니다.

### 알려진 문제

- **DX판 AEF 실행 재검증 미완료**: AA는 실제 실행 화면으로 승인했지만, AEF는 따로 다시 실행해 확인하지 않아서 `v1.0.0-rc1`이 RC로 남아 있습니다 (`release/RELEASE_NOTES.md`, `release_manifest.json`의 `runtime_blocker`).
- **실행 검증 항목 미완료**: 릴리스 매니페스트의 `runtime_verification_valid`가 `false`입니다. 세이브·로드 왕복, 한글 글자 깨짐(두부 문자) 없음, 영상 표시, AEF 메뉴·본문·인물명·선택지 같은 항목은 이 판에서 실행으로 모두 확인한 기록이 없습니다 (`required_runtime_checks`).
- **UI 동결**: 사용자 승인 뒤 UI 자산을 동결했으므로, UI를 바꾸려면 새 버전으로 내야 합니다 (`docs/BUILD_AND_QA.md`).
- **Steam판 제약**: 빌드 `21665074`가 아니면 설치되지 않습니다. 한국어를 보려면 게임 언어를 **English**로 둬야 하고, 개방판은 Steam 플레이 버튼이 아니라 동봉한 실행기로 켜야 합니다.
- Steam판·개방 애드온의 스크립트와 문서는 아직 `main`에 병합되지 않았습니다(PR #1).

## 설치

압축을 푼 뒤 PowerShell에서 실행합니다. `<게임 폴더>`에는 게임이 설치된 폴더 경로를 넣습니다.

```powershell
powershell.exe -ExecutionPolicy Bypass -File .\install_ko.ps1 -GameDir '<게임 폴더>'
```

검증:

```powershell
powershell.exe -ExecutionPolicy Bypass -File .\verify_ko.ps1 -GameDir '<게임 폴더>'
```

제거 및 원상 복원:

```powershell
powershell.exe -ExecutionPolicy Bypass -File .\uninstall_ko.ps1 -GameDir '<게임 폴더>'
```

## 상태

- 시나리오·시스템 문자열·이미지 UI·설정 화면·영상·배경·글꼴 한국어화
- AA UI 실제 실행 화면 사용자 승인 및 동결
- 음성 카드 비선택 테두리는 원본 프레임 픽셀 유지
- data5/data6 아카이브 round-trip 및 SHA-256 결박
- 설치·검증·변조 감지·제거·강제 복원 테스트 통과
- AEF 별도 최종 런타임 재검증은 남아 있어 현재 릴리스는 RC로 표시

## 무결성

`release/SHA256SUMS.txt`와 `manifests/`의 기록을 확인하십시오. 대용량 DAT와 ZIP은 Git 기록에 넣지 않고 GitHub Release 자산으로 제공합니다.
