# Steam R-18 한국어 애드온

대상: Steam AppID `644540`, build `21665074`  
버전: `1.0.0-steam-r18-addon`

이 애드온은 기존 Steam 한국어패치 `1.0.3-steam-aa4`에 **Acta est Fabula R-18** 실행 항목을 추가합니다.

## 필요한 파일

1. Steam판 *Dies irae ~Amantes amentes~*
2. 설치된 Steam 한국어패치 `1.0.3-steam-aa4`
3. 사용자가 정식으로 받은 `dies_irae_r18_patch.zip`
4. GitHub Release의 R-18 애드온 ZIP

공식 R-18 ZIP과 그 안의 `data4.dat`, 원본 `malie_fabula.exe`는 이 저장소와 애드온 배포 파일에 포함하지 않습니다. 설치기가 공식 ZIP의 SHA-256과 내부 파일을 검증하고 한국어 호환 실행 파일을 로컬에서 생성합니다.

## 패치 방법

1. Steam 게임과 관련 실행 파일을 모두 종료합니다.
2. [R-18 애드온 Release](https://github.com/sirecoymarsh/dies-irae-dx-korean-patch/releases/tag/steam-r18-addon-v1.0.0) ZIP을 받아 원하는 폴더에 풉니다.
3. 정식 `dies_irae_r18_patch.zip`을 풀지 않은 채 애드온 폴더에 둡니다. 다른 위치에 있다면 설치 중 파일 선택창에서 지정할 수 있습니다.
4. `1_R18_한국어_설치.cmd`를 실행합니다.
5. `3_R18_설치_검증.cmd`로 설치 상태를 검사합니다.
6. `2_R18_한국어_실행.cmd`로 Acta est Fabula R-18 한국어판을 실행합니다.

Steam의 기존 **플레이** 버튼은 Amantes amentes 한국어판을 계속 실행합니다. R-18판은 별도 실행기를 사용하며 기존 `malie.exe`와 `steam_api.dll`을 변경하지 않습니다.

## 제거

`4_R18_한국어_제거.cmd`를 실행하면 R-18 애드온 파일만 설치 전 상태로 복원합니다. 기존 Steam 한국어패치는 유지됩니다.

## 설치되는 파일

- `data4.dat`: 공식 R-18 ZIP에서 검증 후 추출
- `malie_fabula.exe`: 공식 실행 파일에 UTF-8 공급자와 퀵/자동 저장 라벨만 대상 고유 패치
- `data6.dat`: Acta est Fabula 한국어 오버레이

## 지원 범위와 안전장치

- Steam AppID `644540`, build `21665074` 전용
- 기존 Steam 한국어패치 `1.0.3-steam-aa4` 해시 필수
- 공식 R-18 ZIP SHA-256 필수
- 다른 빌드, 변조된 파일, 혼합 설치 상태는 쓰기 전에 거부
- 설치·검증·변조 감지·제거·원상복구 fixture 시험 완료
- 실제 Steam 설치와 R-18 실행 확인 완료

기술 매니페스트는 [`manifests`](./manifests), 실행 증거는 [`evidence`](./evidence)에 있습니다.
