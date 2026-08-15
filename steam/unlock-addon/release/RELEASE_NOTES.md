# Dies irae Steam 개방 애드온 1.0.0

대상: Steam AppID `644540`, build `21665074`

## 개요

기존 Steam 한국어패치 `1.0.3-steam-aa4` 위에 Acta est Fabula 한국어 개방판을 추가합니다. 공식 `dies_irae_r18_patch.zip`은 포함하지 않으며 설치 시 사용자가 보유한 정확한 ZIP에서 필요한 원본을 검증·추출합니다.

## 사용법

1. 애드온 ZIP을 풉니다.
2. 공식 `dies_irae_r18_patch.zip`을 애드온 폴더에 둡니다.
3. `1_개방_한국어_설치.cmd`를 실행합니다.
4. `3_개방_설치_검증.cmd`로 확인합니다.
5. `2_개방_한국어_실행.cmd`로 실행합니다.

## 검증

- 설치 및 설치 파일 해시 검증: PASS
- 중복 설치·잘못된 ZIP·잘못된 기준 빌드·혼합 상태 거부: PASS
- 설치 파일 및 백업 변조 감지: PASS
- 제거 후 기존 Steam 한국어패치 보존 및 정확 복원: PASS
- 실제 Steam 설치·검증 및 사용자 개방판 실행 확인: PASS
- ZIP CRC·항목 목록·17개 매니페스트 파일 SHA-256: PASS
- Microsoft Defender: 위협 없음

Steam 플레이 버튼은 기존 Amantes amentes용이며 개방판은 별도 실행기를 사용합니다.

## 배포 파일

- `Dies_irae_Steam_KR_Unlock_Addon_1.0.0_20260816.zip` — 205,502,150 bytes
- `Dies_irae_Steam_KR_Unlock_Addon_1.0.0_20260816.zip.json`

ZIP SHA-256: `B5E94F0F3B3BF8C16DBDD0A65696FB525A03EDAA326D56B8F280C3BE649986BA`