# Steam판 한국어 패치

대상: Steam AppID 644540, build 21665074  
후보: `1.0.0-steam-build21665074-rc7`

Steam 실행 파일은 `data5.dat`를 열지 않고 `data4.cn.dat`까지만 읽습니다. 이 포트는 공식 Steam `data4.cn.dat` 1,379개 항목을 보존하고, 최종 DX 한국어 빌드의 3,009개 항목을 한국어 우선순위로 병합한 4,386개 항목의 `data4.cn.dat`를 설치합니다.

- Steam `malie.exe` 수정 없음
- 병합 `data4.cn.dat`: `096AE9AB25CF611187E83043A8DD80BAB6E8CB32249FA2E6FC95E0FCD6E82DB3`
- 배포 ZIP: `EA3FF99242CFB2A15C308548B2BD11BD4A27B460EC5B2493C381CE3E1E067AAD`
- LIBP 추출·재패킹·전 항목 round-trip: PASS
- 설치·검증·원상복원 스크립트 정적 검사: PASS
- 실제 Steam 런타임: 로그인 후 검증 대기

대용량 `data4.cn.dat`와 ZIP은 Git 기록에 넣지 않고 GitHub Release 자산으로 배포합니다.

## 설치

```powershell
powershell.exe -ExecutionPolicy Bypass -File .\install_ko.ps1 -GameDir 'Y:\SteamLibrary\steamapps\common\Dies irae ~Amantes amentes~'
```

동일한 `-GameDir`로 `verify_ko.ps1`을 실행해 검증하고, `uninstall_ko.ps1`로 원본을 복원합니다.