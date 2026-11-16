# アセット・プラグイン

確認日：2026-11-16。Lv1プレビュー向けに、作者の公式配布から無料の実素材を取得した。調査候補と取得済みの原本を下記で区別する。Godot 4 は候補であり未確定。

## 取得した実素材

| 配布物 | 選択した原本 | 状態 |
| --- | --- | --- |
| KayKit Dungeon Remastered 1.0 | 石床・低い壁・瓦礫・暗い木床・松明・石の土台のGLB 6個 | 作者の公開GitHubをcommit固定。現行商品画像と同じ版とは扱わない |
| KayKit Adventurers 2.0 FREE | Ranger、Mage、弓、矢、staff、wandと依存するbin・PNG | 現在の無料ZIP内で実ファイルを確認。Rangerの種族は断定しない。Mageと杖は追加施設候補 |
| KayKit Character Animations 1.1 FREE | `Rig_Medium_CombatRanged.glb` | 弓の構え・引き・射撃、魔法の詠唱・発射の実クリップ名を確認 |

いずれも取得した配布物の同梱ライセンスでCC0を確認し、元のライセンスを保存した。有料Extra・Sourceは取得していない。[入手元・固定版・再取得手順](../art/ASSET_PROVENANCE.md)と[ファイル別のSHA-256台帳](../art/ASSET_MANIFEST.json)を参照。原本の取得と、派生画像の描画・ゲーム内挙動の実装を混同しない。

## 公式プレビューと見た目

| 素材 | 公式画像 | 見た目の特徴 |
| --- | --- | --- |
| [KayKit Adventurers](https://kaylousberg.itch.io/kaykit-adventurers) | [現行カバー画像](https://img.itch.zone/aW1nLzIzODA4Mjg4LnBuZw==/original/WI%2FL4z.png) | 頭身が低く丸みのある、かわいらしいローポリ人物。紫の帽子・ローブに杖と本を持つ魔術師、茶髪・青いマントで弓を持つ射手が見える |
| [KayKit Dungeon Pack](https://kaylousberg.itch.io/kaykit-dungeon-pack) | [現行カバー画像](https://img.itch.zone/aW1nLzI4NTI5NzA1LnBuZw==/original/dFv80t.png) | 厚みのある灰色の石壁と、暖色の木製の樽・家具・本棚・宝箱・罠など。人物と合わせやすい、形がはっきりした地下建築部品 |

上記は現行公式商品ページの紹介画像で、**有料 Extra の内容も含む。映っている素材がすべて無料版に入るとは扱わない。** 商品ページのアニメーション紹介画像を、キャラクターの収録一覧として扱わない。

本作の外観は、このかわいらしいローポリの絵柄を土台に、射手の耳・衣装をエルフらしく整え、魔法を琥珀色に統一する。洞窟・岩盤は暗い青灰色に寄せつつ、人物と施設を判別できる明るさを保つ。紹介画像に映る全素材を取得したという意味ではなく、実際に選択した原本は上表の範囲である。

## 弓塔・魔法塔の最短構成案

**KayKit の人型・動作・地下建築部品を組み合わせ、足りない部分だけ作る案を第一候補とする。** 「塔の上のエルフが弓を撃つ」「塔の上の魔術師が魔法を撃つ」という完成済み施設のセットを確認したわけではない。

| 部品 | 弓塔 | 魔法塔 |
| --- | --- | --- |
| 塔本体・足場 | Dungeon Pack の床・壁を使う屋根なし射撃台を組む | 同じ土台を共用し、祭壇・装飾・色で区別する |
| 搭乗者 | 取得したAdventurers 2.0のRanger。エルフの耳・外観は本作側で調整 | 取得したAdventurers 2.0のMage |
| 人物の動作 | 取得したCharacter Animationsの弓の照準・射撃クリップ | 同ファイルの魔法・詠唱クリップ |
| 発射物 | 取得した `arrow_bow.gltf` | 琥珀色の魔法弾・発光・着弾表現を制作する |
| ゲーム側の処理 | 敵の選択、旋回、射撃時点、矢の移動、命中、再装填を実装 | 敵の選択、旋回、詠唱と発射の同期、弾と命中処理を実装 |

塔の外観、搭乗者、発射物、照準・射撃処理は別部品として扱う。ダンジョン Lv1 の外観を先に作り、強化時の装飾差分と性能・消費資源のデータは分離する。搭乗者を見た目だけにするか、配下の配置人数と連動させるかは未決事項。

## 比較したアセット6件

| 公式候補 | 人型・種族 | 弓射撃／魔法詠唱 | 塔上部への配置 | 形式・ライセンス表示 | 無料／有料 |
| --- | --- | --- | --- | --- | --- |
| [KayKit Adventurers](https://kaylousberg.itch.io/kaykit-adventurers) | 無料2.0のRanger・Mageを実ファイルで確認。ただしRangerはエルフと明記なし | 人物GLBと動作ファイルは別。弓・魔法の動作は次行の専用パックを組み合わせる | 人物を別部品として足場に載せる。塔は含まれない | FBX・glTF、CC0。今回はGLBとglTFを選択 | 基本版無料。Extra・Source は有料 |
| [KayKit Character Animations](https://kaylousberg.itch.io/kaykit-character-animations) | KayKit 人型向け。モデル本体とは別 | 無料1.1のCombatRanged GLBで弓の照準・射撃、魔法・詠唱の実クリップを確認。掘削などは今回は取得していない | 人物の動作のみ。塔は含まれない | FBX・glTF、CC0。今回はGLBを選択 | 動作は無料。Blender ソースは有料 |
| [KayKit Dungeon Pack](https://kaylousberg.itch.io/kaykit-dungeon-pack) | 人型ではなく地下建築部品 | 対象外 | 床・壁・階段がある。射手用の足場・低い胸壁を組む案。完成した搭乗塔や寸法は未検証 | FBX・glTF・OBJ、CC0 | 基本版無料。Extra・Source は有料 |
| [Kenney Castle Kit](https://kenney.nl/assets/castle-kit) | 城の3D部品候補。射手同梱は未確認 | 個別の射撃・詠唱動作は未確認 | 塔の外観候補。屋根の分離、上面の広さ、射手を置ける寸法は未確認 | 公式ページは3D・CC0と表示。配布アーカイブ内の形式は未確認 | 無料 |
| [Quaternius Ultimate Animated Character Pack](https://quaternius.com/packs/ultimatedanimatedcharacter.html) | [公式カタログ](https://quaternius.com/)の分類に elf・wizard がある。希望するエルフ外観は要確認 | アニメーション付き。弓射撃・詠唱の個別収録は未確認 | 人物のみを別の足場へ組み合わせる候補 | FBX・OBJ・Blend、商品ページに CC0 表示 | 無料 |
| [Quaternius Characters - Fantasy Races](https://quaternius.itch.io/characters-fantasy-races) | エルフ系を含む種族モデルの候補。人型リグ付き | **アニメーションなし**と作者が明記。衣装も別途適合確認が必要 | 人物のみ。足場・弓・動作を別途組む | [公式製品説明](https://quaternius.com/packs/charactersfantasyraces.html)に FBX・GLB、[QAL](https://quaternius.com/license.html)。CC0ではない | Standard 無料枠、Source 有料。必要なエルフが無料枠に含まれるか未確認 |

Rangerの無料追加は[作者の告知](https://itch.io/e/35257060/kay-lousberg-updated-kaykit-character-pack-adventurers)でも確認できる。今回は旧1.0のRogueをRangerとして扱わず、無料2.0 ZIP内の `Characters/gltf/Ranger.glb`、`Mage.glb`、`Assets/gltf/arrow_bow.gltf` を実際に取得した。職業名から人間・エルフを断定しない。

Quaternius は商品によって CC0 と QAL の表示が分かれる。QAL はゲームへの組込みを認める一方、素材自体の再配布を制限するため、公開リポジトリへの素材配置は採用した配布物の条件を個別に確認する。

## 追加制作と未検証事項

人物全体、弓、すべての動作を最初から作る必要性は低い。まず無料の KayKit 部品で射撃を試し、エルフらしい耳や衣装、射手が見える塔上面、琥珀色の魔法表現、施設強化の見た目を不足分として作る。Kenney や Quaternius は外観が合う場合の比較候補であり、現段階で有料パックを購入する必要はないという判断である。

取得した `Rig_Medium_CombatRanged.glb` のJSONで、`Ranged_Bow_Aiming_Idle`、`Ranged_Bow_Draw`、`Ranged_Bow_Release`、`Ranged_Magic_Spellcasting`、`Ranged_Magic_Shoot` などを確認した。全20クリップは台帳に記録している。Ranger・Mageの人物GLB自体にはアニメーションがないため、別の動作ファイルを組み合わせる。

ゲームとして未検証なのは、リグの動的再生、弓と手・弦・矢の整合、発射イベントの時点、胸壁との干渉、スマホ実機の見やすさと負荷。静止ポーズを描画できても、射撃ゲーム処理の完成とは扱わない。Rig_Medium と Rig_Large の収録範囲は同一とは限らず、他シリーズへ動作を移す場合はリターゲットと調整が必要。

今回の取得素材に本作用のコボルドは含まれないため、Lv1用のモデルを自作した。デーモンは4本腕でバフォメットを思わせる姿、サキュバスは女性のキャラクターという方向が決まった（2026-11-17）。該当する素材は未取得で、ドワーフの外観は未確定。追加導入時も取得元URL、版、採用ファイル、同梱ライセンスを記録する。

## 従来のAI候補

[Beehave](https://github.com/bitbrain/beehave) は Godot 用のビヘイビアツリーアドオンで、公式リポジトリは MIT 表示。採掘・移動・迎撃・退避の優先順位を組む候補として継続する。塔モデル、射撃アニメーション、矢・魔法弾、経路探索を一式提供するアセットではない。採用エンジンの版との互換性と負荷は導入時に確認する。

`prototypes/landscape-ui.html` は、実素材由来の2.5D画像を組み込んだLv1の操作・経済プレビューである。3D原本を同梱したことを、エンジン本体・戦闘・AIアドオンの実装済みという意味には扱わない。

## UIラフに同梱したもの

オフラインでも表示できるよう、画面ラフには Lucide 1.8.0 の装飾アイコン4個を埋め込んでいる。使用したアイコンは `book-open`、`shield`、`sword`、`shield-half`。由来をHTML内に記録し、配布物に含まれる正式なライセンス全文を [prototypes/LICENSE.lucide](../prototypes/LICENSE.lucide) に保存した。
