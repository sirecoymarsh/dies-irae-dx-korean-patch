# Dies irae Steam R-18 한국어 애드온 1.0.0

대상: Steam AppID `644540`, build `21665074`

## 개요

기존 Steam 한국어패치 `1.0.3-steam-aa4` 위에 Acta est Fabula R-18 한국어판을 추가합니다. 공식 R-18 ZIP은 포함하지 않으며 설치 시 사용자가 보유한 정확한 ZIP에서 필요한 원본을 검증·추출합니다.

## 사용법

1. 애드온 ZIP을 풉니다.
2. 공식 `dies_irae_r18_patch.zip`을 애드온 폴더에 둡니다.
3. `1_R18_한국어_설치.cmd`를 실행합니다.
4. `3_R18_설치_검증.cmd`로 확인합니다.
5. `2_R18_한국어_실행.cmd`로 실행합니다.

## 검증

- 설치 및 설치 파일 해시 검증: PASS
- 중복 설치·잘못된 ZIP·잘못된 기준 빌드·혼합 상태 거부: PASS
- 설치 파일 및 백업 변조 감지: PASS
- 제거 후 기존 Steam 한국어패치 보존 및 정확 복원: PASS
- 실제 Steam 설치·검증 및 사용자 R-18 실행 확인: PASS
- ZIP CRC·항목 목록·17개 매니페스트 파일 SHA-256: PASS
- Microsoft Defender: 위협 없음

Steam 플레이 버튼은 기존 Amantes amentes용이며 R-18은 별도 실행기를 사용합니다.

## 배포 파일

- `Dies_irae_Steam_KR_R18_Addon_1.0.0_20260816.zip` — 205,576,966 bytes
- `Dies_irae_Steam_KR_R18_Addon_1.0.0_20260816.zip.json`

ZIP SHA-256: `12605DE6094DCB438F199CB6C6F86EC855D022694AE409A73287FF12D32B56E8`