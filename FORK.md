# This fork

`yurigalindo/the-tower`: RegiByte's tower plus a few commits for running it from Windows 11. Upstream runs on WSL 2
itself since v1.80.0 (`src/platform.ts`, decision `platforms`); this fork adds only what a Windows user of it wants
beyond that. Nothing here changes how the tower behaves on a Mac.

## Branches and remotes

- `wsl-linux`, the default branch: the newest upstream release tag, then this fork's commits, one per feature:
  1. The page's favicon and web app manifest, so Edge installs the page as an app. The manifest's `name`,
     `start_url` and `scope` are the installed app's identity: changing one gives the app a new id, and whatever
     launches it by that id (a Windows shortcut, say) must change with it.
  2. Shut down Ubuntu: `POST /shutdown` (the API's minor +1) and `board.shutdown`, a button in the sidebar's footer;
     stops the tower cleanly, then `wsl.exe --terminate <distro>`. Offered only where `wslDistro()`
     (`src/machine.ts`) names one: upstream's platform is WSL and `WSL_DISTRO_NAME` is set.
  3. Updating itself on a cold start: `scripts/fork-update.sh`, below.
- `origin` is this fork, `upstream` is RegiByte's. A worker's worktree is cut from `origin/wsl-linux`, and its work
  has landed once merged into `wsl-linux` here.

## Changing it

- What differs on WSL goes through upstream's `src/platform.ts` (`detected()`, `platform()`): don't detect it again.
  macOS behaviour stays upstream's.
- One feature, one commit on top of the release, so each rebases alone and can be offered upstream alone. Say so when
  a change would serve every platform: it belongs upstream, and the fork gets smaller when it lands there.
- Commits here are public: no personal emails, paths, usernames, config or session content.
- Never call `/shutdown`, or restart the host or terms, without asking: either ends the user's live sessions. Say
  which daemon a change needs restarted; the tower view is free to restart (`tower down tower && tower up tower`).

## Updating to a new upstream release

Never `tower update`: it checks the tag out detached and drops this fork's commits.

It happens on its own when the tower starts from cold. The Windows launcher runs `scripts/fork-update.sh due`, and
when that says an update is due (every daemon down, the checkout clean on `wsl-linux`, a newer release upstream) it
runs `scripts/fork-update.sh run` in a minimised window before `tower up`. That does the steps below except the page
boot, and puts everything back if one fails; it then keeps a draft on the floor saying where it stopped, which is the
prompt for doing it by hand. It also keeps one when the new releases' CHANGELOG asks for a config change. Its output
is `~/.tower/fork-update.log`, and the branch before each update is kept as `backup/wsl-linux-<old tag>`.

By hand:

```sh
git fetch --tags upstream
git rebase --onto <new tag> <old tag> wsl-linux
npm ci && npm run typecheck && npm test && npm run test:page-boot   # page boot: Chrome at $CHROME
tower down tower && tower up tower
git push --force-with-lease origin wsl-linux
```

Merge or finish open worker branches first: they sit on the old history. If a release takes over one of this fork's
features, drop that commit in the rebase (`git rebase --onto <new tag> <dropped commit> wsl-linux`, or skip it on its
conflict). On a conflict keep each commit's intent on upstream's current code: take upstream's side of the file, then
place the commit's hunks again (`git show <commit> -- <file>`). The shutdown commit touches the page (`index.html`,
`kit.js`, `page.js`), the verb table (`src/shared/api.ts`, `src/shared/flows.ts`), the dispatch and the board's
publisher (`src/tower/dispatch.ts`, `src/tower/publisher.ts`) and `test/server.test.ts`; a typecheck failure after a
rebase is often a table that now wants an entry per verb. `npm run schema:board` regenerates the board's schema, and
the API version is upstream's plus one minor. Read the releases' CHANGELOG entries for what they ask (a host restart, a
config change, `npm install`).
