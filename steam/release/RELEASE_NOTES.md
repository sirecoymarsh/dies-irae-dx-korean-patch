# Steam build 21665074 RC7

## 변경 사항

- Steam 실행 파일의 실제 로드 경로를 역확인하여 무시되던 `data5.dat` 방식 폐기
- 공식 `data4.cn.dat`와 최종 한국어 오버레이를 하나의 LIBP 아카이브로 병합
- 원본 Steam 실행 파일 SHA-256 완전 보존
- 잘못된 빌드·변조 원본·중복 설치를 거부하는 해시 결박 설치기 제공
- 설치 전 원본 `data4.cn.dat`, INI, 글꼴 백업 및 검증·원상복원 제공

현재 상태는 `PASS_STATIC_STEAM_MERGED_DATA4CN_RUNTIME_PENDING`입니다. Steam 로그인 상태에서 실제 런타임 확인 후 Release 자산으로 승격합니다.