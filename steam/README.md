# Steam판 한국어 패치

대상: Steam AppID `644540`, build `21665074`
최종 버전: `1.0.3-steam-aa4`

## 다운로드

대용량 DAT와 ZIP은 Git 기록에 넣지 않습니다. 완성된 설치 패키지는
[GitHub Release `steam-v1.0.3-aa4`](https://github.com/sirecoymarsh/dies-irae-dx-korean-patch/releases/tag/steam-v1.0.3-aa4)에서 받으십시오.

## 언어 계약

- 게임에서 **English** 선택: 한국어 본문·인물명·선택지·UI
- **Chinese** 선택: Steam판 중국어 보존
- 일본어 음성 보존

## 최종 구조

Steam판은 시나리오 본문과 인물명·선택지가 서로 다른 초기화 경로를 사용합니다.
최종 aa4는 다음 세 위치에 동일한 DX 최종 스크립트를 배치합니다.

1. `data3.dat` → `data/system/exec.dat`
2. `data4.cn.dat` → 영어 슬롯 `data/system/patch.en.dat`
3. DX 승인 `data5.dat` → `data/system/exec.dat`

실패 후보에서는 1번만 변경하여 `data4.cn.dat`의 영어 슬롯이 인물명과 선택지를 다시 영어로 덮어썼습니다.
aa4는 실제 우선순위에 맞춰 2번까지 교체하여 해결했습니다.

## 검증

- 한국어 본문: PASS
- 한국어 인물명 `카스미`: PASS
- 한국어 선택지: PASS
- 중국어 슬롯 보존: PASS
- Steam API import 보존: PASS
- 설치 → 검증 → 제거 → 원본 복원: PASS
- ZIP CRC 및 전체 엔트리 SHA-256 대조: PASS
- Microsoft Defender: 위협 없음

실제 실행 증거는 [`steam/evidence`](./evidence)에 있습니다.

## 설치

1. Steam에서 게임을 종료합니다.
2. Release ZIP을 원하는 폴더에 풉니다.
3. PowerShell에서 다음 명령을 실행합니다. 게임 경로는 자동 감지되며, 필요할 때만 `-GameDir`을 지정합니다.

```powershell
powershell.exe -ExecutionPolicy Bypass -File .\install_ko_steam.ps1
```

경로를 직접 지정하는 예:

```powershell
powershell.exe -ExecutionPolicy Bypass -File .\install_ko_steam.ps1 -GameDir '<SteamLibrary>\steamapps\common\Dies irae ~Amantes amentes~'
```

## 검증

```powershell
powershell.exe -ExecutionPolicy Bypass -File .\verify_ko_steam.ps1
```

## 제거 및 원본 복원

```powershell
powershell.exe -ExecutionPolicy Bypass -File .\uninstall_ko_steam.ps1
```

게임을 실행한 뒤 언어 메뉴에서 **English**를 선택하면 한국어가 표시됩니다.

## 무결성

[`steam/release/SHA256SUMS.txt`](./release/SHA256SUMS.txt)와 [`steam/manifests`](./manifests)를 확인하십시오.