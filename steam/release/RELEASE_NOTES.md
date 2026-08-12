# Dies irae Steam 한국어 패치 1.0.3-steam-aa4

대상: Steam AppID `644540`, build `21665074`

## 최종 수정

- DX 최종 한국어 스크립트를 Steam `data3.dat`의 `data/system/exec.dat`에 이식했습니다.
- Steam `data4.cn.dat`의 영어 슬롯 `data/system/patch.en.dat`에도 같은 스크립트를 배치해 인물명과 선택지가 영어로 되돌아가던 문제를 해결했습니다.
- DX 승인 `data5.dat`, 한국어 글꼴, 실행 파일 호환 처리를 함께 패키징했습니다.
- Chinese 슬롯의 원본 중국어 데이터는 보존했습니다.

## 사용법

1. ZIP을 풉니다.
2. 게임을 종료합니다.
3. `install_ko_steam.ps1`을 실행합니다.
4. 게임의 언어 메뉴에서 **English**를 선택합니다.

```powershell
powershell.exe -ExecutionPolicy Bypass -File .\install_ko_steam.ps1
```

제거는 `uninstall_ko_steam.ps1`, 무결성 검사는 `verify_ko_steam.ps1`을 사용합니다.

## 검증 결과

- 한국어 본문: PASS
- 한국어 인물명: PASS
- 한국어 선택지: PASS
- Chinese 슬롯 보존: PASS
- Steam API import 보존: PASS
- 설치·검증·제거·원본 복원: PASS
- ZIP CRC 및 파일 트리 SHA-256: PASS
- Microsoft Defender: 위협 없음

## 배포 파일

- `Dies_irae_Steam_KR_1.0.3-steam-aa4_final_20260812.zip`
- `Dies_irae_Steam_KR_1.0.3-steam-aa4_final_20260812.zip.json`

ZIP SHA-256: `96B8F2218BBAF4E0EB7EC18D55C89C7AA833FEE2A62D1E0831FA9FAA5A37A149`