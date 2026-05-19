# Codex Windows Mobile Remote Control

Windows PC의 Codex Desktop을 ChatGPT 모바일 앱의 Codex에서 원격으로 사용할 수 있게 설정하는 스크립트입니다.

## 준비물

- Windows PC
- Codex Desktop 앱
- Codex Desktop 앱에서 ChatGPT 로그인 완료
- ChatGPT 모바일 앱
- 인터넷 연결

Codex Desktop 앱은 사용자가 직접 설치하고 로그인해야 합니다. 이 스크립트는 앱 로그인까지 자동으로 처리하지 않습니다.

## 설치 및 실행

1. 이 저장소를 다운로드합니다.

   GitHub 페이지에서 `Code > Download ZIP`을 누른 뒤 압축을 풉니다.

2. 압축을 푼 폴더에서 아래 파일을 더블클릭합니다.

   ```text
   Enable-CodexMobileRemote.cmd
   ```

3. 스크립트가 Codex Desktop을 재시작할지 물으면 `Y`를 입력합니다.

4. Codex Desktop이 다시 열릴 때까지 기다립니다.

5. 핸드폰에서 ChatGPT 앱을 열고 Codex로 들어갑니다.

6. 연결 승인 화면이 뜨면 승인합니다.

## 실행 순서

권장 순서는 다음과 같습니다.

1. PC에서 `Enable-CodexMobileRemote.cmd` 실행
2. Codex Desktop 재시작 완료 확인
3. 핸드폰 ChatGPT 앱에서 Codex 열기
4. 연결 승인

핸드폰에서 먼저 Codex를 켜고 기다리고 있어도 될 수 있습니다. 다만 승인 화면이 바로 뜨지 않으면 모바일 Codex 화면을 나갔다가 다시 들어가세요.

## 스크립트가 하는 일

스크립트는 다음 작업을 자동으로 수행합니다.

1. 터미널에서 실행 가능한 Codex CLI를 찾습니다.
2. `codex.exe --help`가 실행되는지 확인합니다.
3. Codex CLI가 없으면 `winget`으로 `OpenAI.Codex`를 설치합니다.
4. `remote_control` 기능 플래그를 켭니다.
5. `config.toml`에 `remote_control = true`를 보장합니다.
6. Codex 로컬 SQLite 상태 DB에 `remote_control = 1`을 기록합니다.
7. Codex Desktop을 재시작합니다.

## 필요한 파일

일반 사용자는 아래 두 파일을 같은 폴더에 두면 됩니다.

```text
Enable-CodexMobileRemote.cmd
Enable-CodexMobileRemote.ps1
```

`.cmd` 파일은 더블클릭용 실행 파일이고, `.ps1` 파일은 실제 설정 작업을 수행합니다.

## 문제 해결

### 승인 화면이 안 뜨는 경우

1. PC의 Codex Desktop을 완전히 종료합니다.
2. Codex Desktop을 다시 실행합니다.
3. 핸드폰 ChatGPT 앱에서 Codex 화면을 나갔다가 다시 들어갑니다.

### `codex.exe`를 찾을 수 없다는 메시지가 나오는 경우

PowerShell에서 아래 명령을 실행한 뒤, 새 터미널을 열고 스크립트를 다시 실행하세요.

```powershell
winget install --id OpenAI.Codex --exact --source winget --accept-package-agreements --accept-source-agreements
```

### Codex Desktop 로그인이 안 된 경우

Codex Desktop 앱을 직접 열고 ChatGPT 계정으로 로그인한 뒤 다시 실행하세요.

## 주의

이 기능은 Codex의 실험적 remote control 기능을 사용합니다. Codex 업데이트에 따라 동작이 바뀔 수 있습니다.
