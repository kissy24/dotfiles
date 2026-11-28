# 保守手順

[導入と復元](../README.md) · [日常の使い方](usage.md)

## 設定の変更と配備

日常利用のcheckoutは信頼済みの `main` に保ちます。リンク先のファイルはアプリが設定を読み直した時点で反映されるため、開発やレビューは別worktreeで行います。

```sh
git fetch origin
git worktree add -b docs/example ../dotfiles-review origin/main
```

worktreeは実行環境を共有します。未信頼PRのスクリプトやNeovim設定の動作確認には、認証情報のない使い捨てVMまたはCI runnerを使用してください。

管理対象の追加や旧スナップショットからの移行には、日常利用のcheckoutで `./scripts/deploy-config.sh` を実行します。Herdrを起動したままリンクを更新でき、パッケージ導入は行いません。依存関係やLSPも変更した場合は `./setup.sh` を実行します。

- `~/.config` 全体がリンクの構成では親リンクを保持し、その下のリンク作成・削除をスキップします。Herdrのソケットやログも保持します。
- 旧 `${XDG_DATA_HOME:-~/.local/share}/dotfiles/current/` を指す既知のリンクはバックアップしてcheckoutへ張り直します。旧スナップショットは残ります。
- 以前のセットアップが作った `~/.config/gh` のディレクトリリンクは、通常のディレクトリと `config.yml` 単体のリンクへ移行します。`hosts.yml` などは権限を保ってコピーし、旧リンクを退避します。独自のディレクトリリンクは保持します。
- 旧プロンプトを使っていた端末は `~/.zprofile` などの `starship init zsh` を取り除きます。対話シェルでは管理対象の `.zshrc` がHomebrewを初期化します。

## 依存関係を変更する場所

| 対象 | 宣言・更新方法 |
| --- | --- |
| 共通CLI・Ubuntuの前提パッケージ | [Brewfile](../Brewfile)、[packages/apt.txt](../packages/apt.txt) |
| Homebrewの固定配布物 | [bottleロック](../packages/homebrew-bottles.json)、[Intel Mac・Sonoma用](../packages/homebrew-bottles-intel.json)。導入済みformulaは通常維持する |
| Homebrewの初期導入・pre-commit | [bootstrap.json](../packages/bootstrap.json)、[固定wheel](../packages/bootstrap-wheels.json)。PyPIの公開日時とSHA256を検証したwheelからインストールする |
| Bun管理のLSP | [manifestとロック](../packages/bun-lsp/)。このディレクトリで `bun update --minimum-release-age 604800 --lockfile-only --ignore-scripts` を実行 |
| ネイティブLSP | [native-lsp.json](../packages/native-lsp.json)。LuaLS・Marksmanは検証済みasset、goplsは固定bottleから導入 |
| Neovim・Sheldon | [Neovimの設定](../.config/nvim/lua/plugins/)、[lazy-lock.json](../.config/nvim/lazy-lock.json)、[Sheldonの設定](../.config/sheldon/plugins.toml) |

Neovimプラグインの更新は隔離した環境で `:Lazy update` を実行し、変更した `lazy-lock.json` を作業用worktreeへ戻して検証します。初回のlazy.nvimも固定コミットから読み込みます。セットアップは管理対象の設定で `Lazy! restore` と `sheldon lock` を実行します。

## ローカル検証とCI

リポジトリのルートで実行します。セットアップ前の検査は単独で実行でき、セットアップ後の検査は管理設定とCLIを導入済みの環境を使います。

```sh
./tests/smoke-test.sh --before-setup
./tests/smoke-test.sh --after-setup
pre-commit run --all-files
```

引数なしの `./tests/smoke-test.sh` で両段階を実行できます。CIは使い捨てのmacOS・Ubuntu runnerで完全セットアップを行い、設定の保持・復元、CLIの動作、ヘッドレスNeovimとLSPを検証します。Herdrの対話UI、Windows版WezTermの起動、GUI表示、GitHub認証は手動確認の対象です。[スモークテスト](../tests/smoke-test.sh)・[検証ワークフロー](../.github/workflows/validate.yml)

Betterleaksはコミット時にステージ済みの変更、CIでは作業ツリーとGit履歴も走査します。ローカルで履歴を確認するには `pre-commit run betterleaks-history --hook-stage manual --all-files` を使います。

依存変更時は次の2検査を実行します。EOL検査はHomebrewのdeprecated・disabledとGitHubリポジトリのarchived・disabledを調べます。関連ファイルのPRと毎週月曜日にも実行されます。

```sh
GITHUB_TOKEN="$(gh auth token)" ./scripts/check-dependency-eol.sh
GITHUB_TOKEN="$(gh auth token)" ./scripts/check-dependency-cooldown.sh
```

## 依存関係の公開後待機ルール

判定対象は「最新版」ではなく、導入する正確な版・SHA・配布物です。信頼できる公開日時から7日経過していれば、このリポジトリで初めて採用する版も即時に候補にできます。新しい版が出ても、固定した候補の待機はリセットしません。共通の日時判定は`scripts/release_age.py`で管理し、各配布元の取得処理から公開日時または`null`を受け取ります。

| 対象 | 判定と証拠 |
| --- | --- |
| Bunのnpm依存（ロック内の直接・間接依存） | npmの`time[version]`と`dist.integrity`をロックのSHA512と照合。独自URL・integrityなしは拒否 |
| Git依存（Actions、pre-commit hook、Neovim、Sheldon、Homebrew installer） | GitHubの変更不能なReleaseの`published_at`とタグの解決先SHAが固定SHAと一致すれば、その公開日時から7日 |
| 公開日時とSHAの対応を証明できないGit依存 | 公開リポジトリの実在コミットとdefault branch履歴への到達可能性を確認した初回観測から7日 |
| pre-commit本体 | PyPIの固定版の配布ファイル公開日時。後から追加された配布ファイルも考慮し、yanked・配布なしは拒否 |
| Homebrewの自動更新 | [日常の更新手順](usage.md#パッケージの更新)を参照。日時不明は`published_at=null`として通知し、保留 |

GitHub Releaseの`created_at`、Gitのauthor/committer/tagger日時は公開日時として使いません。変更可能なタグとReleaseの古い日付だけでは、現在のコードが以前から公開されていた証明にならないため、実物確認付き観測へ回します。ネットワーク・APIの失敗を「7日経過済み」として扱いません。

依存関係の観測はmain専用の `Observe Dependency Versions` が行います。mainと公開PRの宣言をデータとして読み、公開リポジトリのdefault branchから到達できるSHAとリポジトリIDを検証します。検証できた組み合わせをActionsのジョブに記録し、GitHubが付与したジョブ完了時刻から7日を数えます。検査時にも依存先の公開状態、SHA、リポジトリID、観測元workflow、実行ブランチとmain履歴への到達可能性を照合します。Actionsの観測履歴が失われた場合は再観測が必要です。

移行承認の対象は固定コミット `a83ade427f8c29ca2399615e5f74a112362f5cdb` にあるGit依存だけです。旧観測ブランチは判定・更新の対象外です。観測はmainへのPush時、6時間ごとの定期実行、mainからの手動実行で行います。

セットアップはパッケージ導入・設定配備より先に管理対象のGit/npm/PyPI検査を実行し、失敗なら停止します。CIの完全セットアップも同じ入口を使います。秘密情報履歴CIもhookの導入前に検査します。APIトークンはセットアップの検査子プロセスにだけ渡し、依存のインストール処理には引き継ぎません。GitHub API制限に達する場合は、`gh auth login`済みの環境または検査用の`GITHUB_TOKEN`を利用してください。

初回セットアップのHomebrew用ロックは `packages/homebrew-bottles.json` です。更新PRのCIは公式レジストリのパッケージ版ID、登録日時、索引のSHA256を照合します。セットアップではロックの日時と索引を検証し、索引に記録されたbottleのSHA256と依存関係を使います。UbuntuでHomebrew自体がない場合は固定リリースからインストールします。Homebrewが指定するportable RubyのSHA256も、公開日時を確認した公式OCI索引と照合します。LuaLS・MarksmanはGitHubのrelease asset ID・SHA256・公開日時と更新日時を確認し、goplsは固定bottle内の単体実行ファイルを使います。APTはOSの署名済みリポジトリとセキュリティ更新方針に従います。すでに端末にあるツールは既存の信頼対象です。

緊急セキュリティ修正は、ユーザーの明示承認を得て`packages/dependency-exceptions.json`へ正確な対象・理由・承認PR URL・期限（最大7日）を記録します。Gitは`owner/repo@完全SHA`、npmは`npm:名前@固定版`、PyPIは`pypi:pre-commit@固定版`をキーとし、値には`reason`、`approval_url`、`expires_at`（タイムゾーン付きISO 8601）を指定します。検査は**main上の承認済みファイルだけ**を参照するため、依存変更PRで追加した自己承認は効きません。例外で省略できるのは待機時間だけで、存在・公開状態・integrityの検証は省略しません。

待機条件だけが未達の候補は、他の検証結果と未達理由を明記したDraft PRとして提案できます。実物観測が必要ならmainのobserverを実行し、表示された期限後に同じSHAでCIを再実行します。待機中は完全セットアップCIが停止することが正常で、成功・導入完了とは報告しません。

手動で観測を開始するには `gh workflow run dependency-observations.yml --ref main` を使用します。
