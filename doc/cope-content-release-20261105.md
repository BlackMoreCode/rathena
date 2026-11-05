# CopeRO 콘텐츠 이식 적용 기록 — 2026-11-05

## 기준과 범위

- 기준 커밋: cef8fd69a. 작업 브랜치: codex/episode20-port. 배포 브랜치: codex/rathena-update-20261031.
- 참조: hayakawakaki/rathena-script-collection b76eb85, AoShinRO/brHades cffe264. 각 자료를 선별 병합했으며 fork 전체 코어로 교체하지 않는다.
- EP20/EP21, Chapter 1 및 Zerocell, Tomb of Remorse, Memory of Thanatos, Constellation Tower, Fall of Glast Heim, Old Glast Heim Hard, Biosphere Depth1/Abyss, Garden of Time의 Lake of Fire/Hall of Life.
- 원래 rAthena 콘텐츠가 이미 있는 경우 해당 기반을 유지했다. Garden의 기존 스토리·일일 의뢰·상점은 보존하고 두 인스턴스 입구를 연결했다. Body Changer는 사용자 요청대로 제외한다.

## 구조와 중요한 수정

- DB 변경은 db/import 중심이다. 기존 Isgard 평판 ID4/RepPointsIsgard는 유지하고 White Cat Alliance는 별도 ID5, EP21은13–19를 쓴다. 기존 아이템 ID를 재사용하고 이름 참조를 맞췄다.
- db/re/quest_db.yml의 일부 원래 쿨다운 정의도 수정했다. 상세 표는 2026-11-05-ported-dungeon-cooldowns.md. Fall 일반2시간, Hard 및 이식 던전 주요 재입장4시간. Lake quest12611은 +4h. Hall 주간 보상12612는 주간 그대로, 재도전12619는1시간 유지. 이미 DB에 저장된 만료시각은 자동 소급 변경하지 않는다.
- npc/custom/warper.txt는 에피소드 밖 콘텐츠의 공개 입구를 제공한다. 퀘스트/레벨/파티/열쇠/쿨다운 검사는 실제 입장 NPC에 남겨 둔다. Garden은 t_garden166,230, Biosphere Abyss는 ba_maison241,128.
- EP21 Final Battle은 엔딩이 누락된 구현 대신 Hayakawa 스크립트를 기반으로 연결했다. 메인12656 완료→18349, 티켓90개/평판110 저장. Hard 입장 평판 검사 및 Normal 만료 quest ID 수정.
- StoryGroupWalk에서 unitwalk를 논리식 밖으로 분리했다. rAthena 스크립트 논리식의 부작용 때문에 이미 도착한 NPC가 중복 집계되어 다음 장면이 일찍 실행되는 문제를 해결했다. 수정 후 실제 보스 공격→원래 시간의 엔딩→보상 체크포인트 시험에 강제 이동 경고가 없다.
- 공용 inc_instance_var가 증가시킨 값을 반환하도록 고쳤다. Garden은 이 반환값으로 전투 단계와 함정 순서를 결정한다.
- Lake #boss_control 이름을 #cope_lake_boss로 바꿔 기존 Airship Destruction NPC와 충돌을 제거했다. 입구 Dimension Prison 이름을 기존 참조와 통일했다.
- Hall 자료는 보상표가1–13단계까지만 있다. 진입/증가는13단계로 제한하고14–20 미정의 보상은 지급·주간권 차감 전에 거절한다. 기존 높은 각인 아이템 자체를 삭제하지 않는다. 보상 인벤토리 여유 확인, 각인 상승 조건 및 권리 차감 순서를 수정했다.
- src/map/skills/custom/cope_garden.hpp와 custom factory에 Garden NPC 스킬11개 구현. 현재 rAthena SkillImpl 구조에 맞췄다. 추가5상태는 SC_COPE_*로 분리하고 기존 상태 번호 뒤에 추가했다. Zerocell2상태도 별도 이름을 쓴다.
- src/map/skill.cpp에는 그림자 장비 해제와 Seedtrap 만료 폭발만 추가했다. 전역 DamageTaken 단위를 바꾸는 fork 패치는 적용하지 않았다. 기존 몬스터의 피해 백분율 계산은 유지한다.
- src/common/mmo.hpp MAX_SKILL은1664. 같은 소스로 login/char/map/web 모두 빌드해야 한다. 이전 EXE와 혼합 실행하면 안 된다. 기존 inventory900, PACKETVER20250716 정책은 유지한다.
- src/map/script.cpp specialeffect에 숫자GID 대상 지원. 기존 문자열NPC 인자 지원 유지. doc/script_commands.txt에 반영.
- 기존 잘못된 mob_skill_db Pneuma 중복 행 제거 및 Thanatos HELMBRAKE4행 발동 조건 보완. 이식 바터3파일은 현재 BARTER_DB v2로 명시했다.
- 컷인은 GRF 압축 인덱스로 확인했다. Chapter1의 magi→maggi, EP20 god02→존재하는 같은 장면 god01로 참조를 수정했다. GRF/CopeRO.exe를 이 작업에서 변경하지 않았다.

## 검증 범위와 한계

- Release x64 전체 솔루션 빌드 성공: migration-audit/ep20-validation/garden-build-2.log.
- 기존 콘텐츠 회귀16개 묶음 종료코드0: release-regression-20261105.json. 진입 제한, 퀘스트 체크포인트, 보상/평판 저장, 바터, 쿨다운, 보스 체크포인트 등을 포함한다.
- 인스턴스27개 생성/초기화/삭제 통과: dialog-052031d2. 이것은27개 던전의 정상 난이도 완주를 뜻하지 않는다.
- Garden 상태전환 실제 스킬 캐스팅 시험: dialog-67575687. Marker→Seal→Explosion, Warm Shield의 Frost 차단, Frost/Lightning, Aimed/Blazing, Trap/Groggy/Reset 실행. Warm Shield는 테스트에서 상태를 직접 부여했으며 아이템을 실제 소비한 시험은 아니다. 그림자 장비를 실제 착용 후 해제하는 시험은 아직 없다.
- EP21 엔딩 수정 후 회귀: dialog-27af4f06. 실제 공격으로 HP1 보스 처치, 원래 컷신 시간과 원래 보상 경로, DB 저장. 강제 이동 경고0.
- Lake 실제 입장→HP1 보스 공격→보상/중복 방지 저장: dialog-a991ed90의 Lake 구간. Hall은 dialog-41d8bd56에서 두 단계 실제 공격, 열쇠 소비, Circul_Of_Life15개와12612/12619 저장, 재클릭 무지급 확인. Hall 시험은 회복/무적 및 일부 타이머·부하 몬스터 중지를 사용한 보상 체크포인트 시험이며 정상 전투 패턴 완주가 아니다. 앞선 실패 로그도 감사 폴더에 보존한다.
- 최신 네이티브 전체 로드 오류0: zerocell-native-validation.json. SQL은 임시 cope_ep20test_* / cope_leveltest_* 스키마만 사용했고 테스트 종료 후 삭제했다.
- 기존 커스텀 tool_dealer의 매입/판매 가격 역전 경고3개는 이번 변경 범위 밖이며 남아 있다. 빈 테스트 roulette 테이블은 사과 대체 경고가 나온다. 모든 로그가 무경고라는 뜻은 아니다.
- 모든 퀘스트를 최초 상태부터 정상 난이도로 플레이하고 그래픽 클라이언트의 컷인/이펙트/UI까지 보는 전체 완주 검증은 완료하지 않았다. 이번 결과는 자동 로드·진입·체크포인트·상태전환 검증이다. 공개 운영 전 이 차이를 고려해야 한다.

## 적용 방법

1. 운영 머신의 서버4개를 종료하고 기존 DB 백업을 유지한다.
2. C:/Users/sehor/Desktop/CopeRO에서 codex/rathena-update-20261031 브랜치를 fast-forward pull한다.
3. rAthena.sln의 Release x64로 전체 Rebuild하거나, 이번 릴리스와 일치하는 server-runtime의4개 EXE를 함께 복사한다. EXE를 Git에 포함시키지 않는다.
4. conf/import와 cope-network의 IP/DB 비밀번호는 그대로 둔다. 이번 릴리스에는 해당 파일이나 SQL 마이그레이션이 없다. 기존 계정/캐릭터/아이템/퀘스트 데이터를 초기화하지 않는다.
5. Server-start.bat로 시작하고 로그인/캐릭터/맵/웹4개 프로세스 연결을 확인한다. 새 인스턴스를 만든 뒤 테스트한다.
6. 클라이언트는 이미 업데이트한20250716 CopeRO.exe와 data.grf/SystemEN을 유지한다. 이번 서버 이식만으로 WARP 재패치나 런처 manifest 재생성은 필요하지 않다.

운영 머신은 이 세션에서 직접 실행한 머신이 아니다. 공유 폴더는 전달용이며 실제 운영 파일은 서버 머신의 로컬 경로에 둔다. 서버용 실행 파일을 LauncherWEB의 exe 폴더에 올리지 않는다.

## 변경 파일 전체 목록

각 파일의 SHA256/크기는 RoDocu/tracking/content-release-20261105-files.json에 기록한다. 아래 경로는 rAthena 루트 기준이다.

- `db/import/const.yml`
- `db/import/instance_db.yml`
- `db/import/item_combos.yml`
- `db/import/item_db.yml`
- `db/import/item_enchant.yml`
- `db/import/map_drops.yml`
- `db/import/mercenary_db.yml`
- `db/import/mob_db.yml`
- `db/import/mob_skill_db.txt`
- `db/import/quest_db.yml`
- `db/import/reputation.yml`
- `db/import/skill_db.yml`
- `db/import/status.yml`
- `db/re/quest_db.yml`
- `doc/script_commands.txt`
- `npc/custom/warper.txt`
- `npc/re/chapter1/CH1.txt`
- `npc/re/chapter1/Dark_Whisper.txt`
- `npc/re/chapter1/Extension.txt`
- `npc/re/chapter1/Mapflags.txt`
- `npc/re/chapter1/barter/chapter1.yml`
- `npc/re/chapter1/barter/zerocell.yml`
- `npc/re/chapter1/scripts_athena.conf`
- `npc/re/cope_dungeons/Hall_Of_Life.txt`
- `npc/re/cope_dungeons/Lake_Of_Fire.txt`
- `npc/re/cope_dungeons/barter/constellation.yml`
- `npc/re/cope_dungeons/barter/remorse.yml`
- `npc/re/cope_dungeons/barter/thanatos.yml`
- `npc/re/cope_dungeons/constellation.txt`
- `npc/re/cope_dungeons/fall_of_glastheim.txt`
- `npc/re/cope_dungeons/instance_helpers.txt`
- `npc/re/cope_dungeons/old_glast_heim_hard.txt`
- `npc/re/cope_dungeons/old_glast_heim_hard_merchant.txt`
- `npc/re/cope_dungeons/remorse.txt`
- `npc/re/cope_dungeons/scripts_athena.conf`
- `npc/re/cope_dungeons/thanatos.txt`
- `npc/re/ep20/instances/CanyonExploration.txt`
- `npc/re/ep20/instances/DriftIceZone.txt`
- `npc/re/ep20/instances/Immortal.txt`
- `npc/re/ep20/instances/NestOfTwigs.txt`
- `npc/re/ep20/instances/SeparateSanctuary.txt`
- `npc/re/ep20/instances/StickySea.txt`
- `npc/re/ep20/mapflag/mapflags.txt`
- `npc/re/ep20/mobs/ep20_spawn.txt`
- `npc/re/ep20/other/Global_Functions.txt`
- `npc/re/ep20/quests/quests_20_daily.txt`
- `npc/re/ep20/quests/quests_20_main.txt`
- `npc/re/ep20/quests/quests_20_misc.txt`
- `npc/re/ep20/quests/quests_20_side_quests.txt`
- `npc/re/ep20/scripts_athena.conf`
- `npc/re/ep20/warps/ep20_warps.txt`
- `npc/re/ep21/instances/Final_Battle.txt`
- `npc/re/ep21/instances/Ghost_Ship_Captain.txt`
- `npc/re/ep21/instances/Gimli_Infiltration.txt`
- `npc/re/ep21/instances/Mysterious_Ghostship.txt`
- `npc/re/ep21/instances/Secret_Altar.txt`
- `npc/re/ep21/instances/Silent_Sanctuary.txt`
- `npc/re/ep21/mapflag/mapflags.txt`
- `npc/re/ep21/merchants/Kaiwobolage_Exchange_Shop.txt`
- `npc/re/ep21/merchants/barter/quest_21_misc.yml`
- `npc/re/ep21/merchants/barter/yorscalp.yml`
- `npc/re/ep21/mobs/ep21_spawn.txt`
- `npc/re/ep21/other/Global_Functions.txt`
- `npc/re/ep21/quests/21_Heroes_Age.txt`
- `npc/re/ep21/scripts_athena.conf`
- `npc/re/mapflag/nobranch.txt`
- `npc/re/mapflag/noicewall.txt`
- `npc/re/mapflag/nomemo.txt`
- `npc/re/mapflag/nosave.txt`
- `npc/re/mapflag/noteleport.txt`
- `npc/re/mapflag/nowarp.txt`
- `npc/re/mapflag/nowarpto.txt`
- `npc/re/mapflag/partylock.txt`
- `npc/re/mapflag/restricted.txt`
- `npc/re/merchants/barters.yml`
- `npc/re/merchants/barters/biosphere_abyss.yml`
- `npc/re/merchants/barters/biosphere_depth1.yml`
- `npc/re/merchants/biosphere_depth1.txt`
- `npc/re/mobs/dungeons/bl_depth1.txt`
- `npc/re/quests/biosphere_abyss.txt`
- `npc/re/quests/biosphere_depth1.txt`
- `npc/re/quests/garden_of_time.txt`
- `npc/re/scripts_athena.conf`
- `npc/re/scripts_monsters.conf`
- `src/common/mmo.hpp`
- `src/map/script.cpp`
- `src/map/script_constants.hpp`
- `src/map/skill.cpp`
- `src/map/skills/custom/cope_garden.hpp`
- `src/map/skills/custom/skill_factory_custom.cpp`
- `src/map/status.hpp`
