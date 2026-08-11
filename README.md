# Dies irae DX 한국어 패치

*Dies irae ~Amantes amentes~*와 *Dies irae ~Acta est Fabula~*의 한국어 패치입니다.

## 다운로드

대용량 패치 ZIP은 [GitHub Releases](https://github.com/sirecoymarsh/dies-irae-dx-korean-patch/releases)에서 받으십시오.

현재 배포 후보: 1.0.0-rc1-ui-final

## 설치

압축을 푼 뒤 PowerShell에서 실행합니다.

`powershell
powershell.exe -ExecutionPolicy Bypass -File .\install_ko.ps1 -GameDir 'D:\Games\Dies irae DX package'
`

검증:

`powershell
powershell.exe -ExecutionPolicy Bypass -File .\verify_ko.ps1 -GameDir 'D:\Games\Dies irae DX package'
`

제거 및 원상 복원:

`powershell
powershell.exe -ExecutionPolicy Bypass -File .\uninstall_ko.ps1 -GameDir 'D:\Games\Dies irae DX package'
`

## 상태

- 시나리오·시스템 문자열·이미지 UI·설정 화면·영상·배경·글꼴 한국어화
- AA UI 실제 실행 화면 사용자 승인 및 동결
- 음성 카드 비선택 테두리는 원본 프레임 픽셀 유지
- data5/data6 아카이브 round-trip 및 SHA-256 결박
- 설치·검증·변조 감지·제거·강제 복원 테스트 통과
- AEF 별도 최종 런타임 재검증은 남아 있어 현재 릴리스는 RC로 표시

## 무결성

elease/SHA256SUMS.txt와 manifests/의 기록을 확인하십시오. 대용량 DAT와 ZIP은 Git 기록에 넣지 않고 GitHub Release 자산으로 제공합니다.
