# This fork

`yurigalindo/the-tower`: RegiByte's tower plus a few commits so it runs on Linux under WSL2 (Windows 11). Upstream is
macOS-only; nothing here changes how it behaves on a Mac.

## Branches and remotes

- `wsl-linux`, the default branch: the newest upstream release tag, then this fork's commits, one per feature:
  1. Run on Linux (WSL2): `ps e` for environments, Explorer reveal through `wslpath`, doctor accepts Linux.
  2. The page's favicon and web app manifest, so Edge installs the page as an app.
  3. Shut down Ubuntu: `POST /shutdown` (the API's minor +1), a button in the sidebar's footer; stops the tower
     cleanly, then `wsl.exe --terminate <distro>`.
- `origin` is this fork, `upstream` is RegiByte's. A worker's worktree is cut from `origin/wsl-linux`, and its work
  has landed once merged into `wsl-linux` here.

## Changing it

- Gate what is Linux's or WSL's on `process.platform === 'linux'` or `inWsl()`: macOS behaviour stays upstream's.
- One feature, one commit on top of the release, so each rebases alone and can be offered upstream alone. Say so when
  a change would serve every platform: it belongs upstream.
- Commits here are public: no personal emails, paths, usernames, config or session content.
- Never call `/shutdown`, or restart the host or terms, without asking: either ends the user's live sessions. Say
  which daemon a change needs restarted; the tower view is free to restart (`tower down tower && tower up tower`).
- A known gap: orphans are found by re-parenting to launchd (PID 1). In WSL they go to a `Relay` process, so none is
  flagged.

## Updating to a new upstream release

Never `tower update`: it checks the tag out detached and drops this fork's commits. Instead:

```sh
git fetch --tags upstream
git rebase --onto <new tag> <old tag> wsl-linux
npm ci && npm run typecheck && npm test
tower down tower && tower up tower
git push --force-with-lease origin wsl-linux
```

Merge or finish open worker branches first: they sit on the old history. On a conflict keep each commit's intent;
`npm run schema:board` regenerates the board's schema, and the API version is upstream's plus one minor. Read the
releases' CHANGELOG entries for what they ask (a host restart, a config change), and check the new code for anything
macOS-only (`ps -E`, `open`, launchd, `lsof` flags) to gate the same way.
