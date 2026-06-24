# Justificativa do `runFullTrust` — submissão no Partner Center

Cole o texto em inglês abaixo no campo **"Submission options" → "Restricted capabilities"**
do Partner Center, ao submeter o pacote (lá ele detecta o `runFullTrust` e pede
a explicação). Os revisores da Microsoft leem em inglês — por isso o texto-alvo é
em inglês. Abaixo dele há a explicação em PT do porquê de cada ponto.

---

## TEXTO PARA COLAR (inglês)

> **Why this app requires the `runFullTrust` restricted capability**
>
> TecnoAssist is a remote support (remote desktop) client for Windows. It is the
> packaged build of a Win32 desktop application (Rust core + Flutter UI). It needs
> `runFullTrust` because its core functionality relies on classic Win32/Desktop
> APIs that are not available to AppContainer (sandboxed) packages:
>
> 1. **Screen capture** via the DirectX **Desktop Duplication API** (DXGI
>    `IDXGIOutputDuplication`) to stream the local desktop to the supporting
>    technician. The brokered/UWP capture surfaces do not support this app's
>    real-time, full-desktop, low-latency capture path.
> 2. **Input simulation** via Win32 `SendInput` so the technician can move the
>    mouse and type on the user's machine during an authorized session.
> 3. **Direct TCP/UDP networking** to the support relay/rendezvous server.
> 4. Loading native libraries (`librustdesk.dll`, hardware video codecs) and
>    standard Win32 process behavior that an AppContainer would restrict.
>
> **This build is intentionally limited to reduce risk:**
> - It is an **incoming-only** client: it can only *be controlled*; it cannot
>   initiate outgoing connections to control other machines.
> - Every session requires the local user to share a **temporary, on-screen
>   password** with the technician. There is no permanently embedded password and
>   no silent/unattended access in this client build.
> - It installs **no Windows service** and does **not** start automatically at
>   boot; remote access is only possible while the user has the app window open.
> - It runs at the standard (medium integrity) user level — it cannot capture or
>   control the secure desktop (UAC prompts, the lock/login screen) or elevated
>   windows.
>
> The capability is used solely to provide consensual, user-initiated remote
> technical support, consistent with other remote desktop tools.

---

## Por que cada ponto está aí (PT)

- **DXGI Desktop Duplication + SendInput + sockets** = exatamente as 3 APIs Win32
  que o AppContainer bloquearia. Esse é o argumento técnico central: o app PRECISA
  de full-trust porque o sandbox UWP cegaria a captura e o controle. Sem isso o app
  não funciona — não é "conveniência".
- **incoming-only / senha temporária / sem serviço / sem boot / sem secure desktop**
  = os mitigadores. Mostram ao revisor que NÃO é uma ferramenta de acesso silencioso
  (o medo dele com "RAT"). Tudo é consentido e visível ao usuário. Esses 4 pontos
  são verdadeiros para o `variant=client` (incoming-only via HARD_SETTINGS, senha
  por OVERWRITE_SETTINGS `approve-mode=password`+`use-temporary-password`, sem
  serviço/boot, Medium IL).

⚠️ **Coerência obrigatória:** a descrição da loja, os screenshots e a política de
privacidade têm que contar a MESMA história ("suporte remoto consentido por senha
temporária"). Divergência entre o que o app faz e o que você declara é o caminho
mais rápido pra reprovação.
