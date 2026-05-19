# Codex Remote Control Setup on Windows

이 문서는 Windows PC의 Codex Desktop을 ChatGPT 모바일 앱의 Codex에서 원격 제어 대상으로 연결한 절차를 기록한다.

## 환경

- OS: Windows
- Codex Desktop 설치 경로 예시:
  - `C:\Program Files\WindowsApps\OpenAI.Codex_26.513.4821.0_x64__2p2nqsd0c76g0`
- Codex CLI 경로 예시:
  - `C:\Users\HP\AppData\Local\OpenAI\Codex\bin\76ac88818493fc45\codex.exe`
- Codex 설정 경로:
  - `C:\Users\HP\.codex\config.toml`
- Codex 로컬 상태 DB:
  - `C:\Users\HP\.codex\sqlite\codex-dev.db`

## 최종 성공 절차

1. Codex CLI에서 `remote_control` 실험 기능을 켠다.

   ```powershell
   & C:\Users\HP\AppData\Local\OpenAI\Codex\bin\76ac88818493fc45\codex.exe features enable remote_control
   ```

2. 기능 상태를 확인한다.

   ```powershell
   & C:\Users\HP\AppData\Local\OpenAI\Codex\bin\76ac88818493fc45\codex.exe features list
   ```

   확인할 항목:

   ```text
   remote_control    under development    true
   ```

3. `C:\Users\HP\.codex\config.toml`에 다음 값이 있는지 확인한다.

   ```toml
   [features]
   remote_control = true
   ```

4. Codex 로컬 상태 DB에도 `remote_control` 활성화 값을 넣는다.

   ```powershell
   C:\Users\HP\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe -c "import sqlite3, time; path=r'C:\Users\HP\.codex\sqlite\codex-dev.db'; con=sqlite3.connect(path); con.execute('insert or replace into local_app_server_feature_enablement(feature_name, enabled, updated_at) values (?, ?, ?)', ('remote_control', 1, int(time.time()*1000))); con.commit(); print(con.execute('select feature_name, enabled, updated_at from local_app_server_feature_enablement').fetchall()); con.close()"
   ```

   기대 출력 예시:

   ```text
   [('remote_control', 1, 1779091878248)]
   ```

5. Codex Desktop 앱을 완전히 종료한다.

   작업 표시줄에서 Codex를 선택한 뒤 `작업 끝내기`로 종료했다.

6. Codex Desktop 앱을 다시 실행한다.

   앱 재시작 후 모바일 ChatGPT 앱의 Codex 화면에서 자동으로 연결 승인 화면이 표시되었다.

7. 핸드폰에서 연결 승인을 완료한다.

## 관찰된 증상과 해결

처음에는 ChatGPT 모바일 앱에서 Codex를 열면 다음 상태에 머물렀다.

```text
데스크톱을 기다리는 중...
연결하려면 데스크톱 앱의 안내를 따르세요
```

Codex Desktop의 `Settings > Connections`에는 아래 항목만 보였다.

```text
SSH connections from this PC
MCP servers
```

이 상태에서는 `remote_control` CLI 플래그는 켜져 있었지만, 데스크톱 앱 내부의 로컬 상태 DB에는 `remote_control` 활성화 값이 없었다.

로컬 상태 DB의 `local_app_server_feature_enablement` 테이블에 다음 값을 넣고 앱을 재시작하자 모바일 연결 승인 플로우가 표시되었다.

```text
feature_name = remote_control
enabled = 1
```

## 참고한 실패 케이스

아래 명령은 Windows에서 동작하지 않았다.

```powershell
& C:\Users\HP\AppData\Local\OpenAI\Codex\bin\76ac88818493fc45\codex.exe remote-control
```

오류:

```text
Error: codex app-server daemon lifecycle is only supported on Unix platforms
```

아래 명령도 같은 이유로 실패했다.

```powershell
& C:\Users\HP\AppData\Local\OpenAI\Codex\bin\76ac88818493fc45\codex.exe app-server daemon enable-remote-control
```

오류:

```text
Error: codex app-server daemon lifecycle is only supported on Unix platforms
```

## 재현용 체크리스트

- `features list`에서 `remote_control`이 `true`인지 확인한다.
- `config.toml`의 `[features]` 아래 `remote_control = true`가 있는지 확인한다.
- `C:\Users\HP\.codex\sqlite\codex-dev.db`의 `local_app_server_feature_enablement` 테이블에 `remote_control`, `1` 값이 있는지 확인한다.
- Codex Desktop을 완전히 종료 후 다시 실행한다.
- ChatGPT 모바일 앱에서 Codex를 열고 연결 승인 화면이 뜨는지 확인한다.

## 원클릭 실행 파일

이 폴더에 일반 사용자가 더블클릭할 수 있는 실행 파일을 추가했다.

- `Enable-CodexMobileRemote.cmd`
- `Enable-CodexMobileRemote-OneClick.cmd`
- `Enable-CodexMobileRemote.ps1`

일반 사용자는 `Enable-CodexMobileRemote.cmd`를 더블클릭하면 된다. 이 버전은 Codex Desktop 재시작 전에 확인 질문을 띄운다.

완전 원클릭으로 처리하려면 `Enable-CodexMobileRemote-OneClick.cmd`를 더블클릭하면 된다. 이 버전은 확인 질문 없이 Codex Desktop을 종료하고 다시 실행한다.

내부적으로 다음 작업을 수행한다.

1. 터미널에서 `codex.exe --help`가 실제로 실행되는지 확인한다.
2. 터미널에서 `codex.exe`가 없거나 실행되지 않으면 알려진 Codex CLI 설치 경로를 PATH에 임시 추가한 뒤 다시 확인한다.
   - Codex Desktop 경로: `C:\Users\<user>\AppData\Local\OpenAI\Codex\bin\...\codex.exe`
   - winget portable CLI 경로: `C:\Users\<user>\AppData\Local\Microsoft\WinGet\Packages\OpenAI.Codex_...\codex-x86_64-pc-windows-msvc.exe`
3. 그래도 실행되지 않으면 Codex CLI 패키지 `OpenAI.Codex`를 `winget`으로 설치한다.
4. 다시 터미널에서 `codex.exe --help`가 실행되는지 확인한다.
5. `codex features enable remote_control`을 실행한다.
6. `C:\Users\HP\.codex\config.toml`에 `remote_control = true`를 보장한다.
7. `C:\Users\HP\.codex\sqlite\codex-dev.db`의 `local_app_server_feature_enablement` 테이블에 `remote_control = 1`을 기록한다.
8. Codex Desktop을 종료하고 `--enable remote_control` 옵션으로 다시 실행한다.

Codex Desktop 앱 설치 여부는 자동 설치 대상으로 보지 않는다. Desktop 앱은 사용자가 직접 로그인해야 하고, 이 스크립트에 필요한 자동화 전제 조건은 터미널에서 동작하는 `codex.exe` 명령이다.

따라서 사용자는 Codex Desktop 앱을 직접 설치하고 로그인해 둔 상태여야 한다.

진짜 `.exe`가 필요하면 이 `.ps1` 스크립트를 그대로 래핑하면 된다. 단, `.exe`로 포장해도 실제 핵심 동작은 동일하며, 보안 경고가 더 강하게 보일 수 있다.

## 주의

이 기능은 현재 실험 기능이다. Windows에서는 일부 CLI daemon 명령이 Unix 전용 오류를 내며 동작하지 않았다. 실제로 성공한 핵심은 CLI 기능 플래그와 로컬 상태 DB 값을 모두 켠 뒤 Codex Desktop을 재시작한 것이다.
