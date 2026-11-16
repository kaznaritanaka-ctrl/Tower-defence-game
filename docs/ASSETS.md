# アセット・プラグイン候補

確認日：2026-11-16。公式ページと公開ファイル一覧による調査。購入、3D素材の導入、エンジンでの再生確認は行っていない。Godot 4 は候補であり未確定。

## 弓塔・魔法塔の最短構成案

**KayKit の人型・動作・地下建築部品を組み合わせ、足りない部分だけ作る案を第一候補とする。** 「塔の上のエルフが弓を撃つ」「塔の上の魔術師が魔法を撃つ」という完成済み施設のセットを確認したわけではない。

| 部品 | 弓塔 | 魔法塔 |
| --- | --- | --- |
| 塔本体・足場 | Dungeon Pack の床・壁を使う屋根なし射撃台を組む | 同じ土台を共用し、祭壇・装飾・色で区別する |
| 搭乗者 | Adventurers の Ranger を基に検証。エルフの耳・外観は必要に応じて制作 | Adventurers の Mage を候補にする |
| 人物の動作 | Character Animations の弓の照準・射撃カテゴリ | 同パックの魔法・詠唱カテゴリ |
| 発射物 | 配布されている矢モデルを候補にする | 琥珀色の魔法弾・発光・着弾表現を制作する |
| ゲーム側の処理 | 敵の選択、旋回、射撃時点、矢の移動、命中、再装填を実装 | 敵の選択、旋回、詠唱と発射の同期、弾と命中処理を実装 |

塔の外観、搭乗者、発射物、照準・射撃処理は別部品として扱う。ダンジョン Lv1 の外観を先に作り、強化時の装飾差分と性能・消費資源のデータは分離する。搭乗者を見た目だけにするか、配下の配置人数と連動させるかは未決事項。

## 比較したアセット6件

| 公式候補 | 人型・種族 | 弓射撃／魔法詠唱 | 塔上部への配置 | 形式・ライセンス表示 | 無料／有料 |
| --- | --- | --- | --- | --- | --- |
| [KayKit Adventurers](https://kaylousberg.itch.io/kaykit-adventurers) | Ranger は弓付きと作者が明記。ただしエルフと明記なし。Mage は公式旧配布のモデル一覧で確認 | 基本動作付き。弓・魔法の動作は次行の専用パックを組み合わせて確認する | 人物を別部品として足場に載せる。塔は含まれない | FBX・glTF、CC0 | 基本版無料。Extra・Source は有料 |
| [KayKit Character Animations](https://kaylousberg.itch.io/kaykit-character-animations) | KayKit 人型向け。モデル本体とは別 | 公式本文に弓の照準・射撃、magic/spellcasting を明記。掘削・つるはし・槌打ちもある | 人物の動作のみ。塔は含まれない | FBX・glTF、CC0 | 動作は無料。Blender ソースは有料 |
| [KayKit Dungeon Pack](https://kaylousberg.itch.io/kaykit-dungeon-pack) | 人型ではなく地下建築部品 | 対象外 | 床・壁・階段がある。射手用の足場・低い胸壁を組む案。完成した搭乗塔や寸法は未検証 | FBX・glTF・OBJ、CC0 | 基本版無料。Extra・Source は有料 |
| [Kenney Castle Kit](https://kenney.nl/assets/castle-kit) | 城の3D部品候補。射手同梱は未確認 | 個別の射撃・詠唱動作は未確認 | 塔の外観候補。屋根の分離、上面の広さ、射手を置ける寸法は未確認 | 公式ページは3D・CC0と表示。配布アーカイブ内の形式は未確認 | 無料 |
| [Quaternius Ultimate Animated Character Pack](https://quaternius.com/packs/ultimatedanimatedcharacter.html) | [公式カタログ](https://quaternius.com/)の分類に elf・wizard がある。希望するエルフ外観は要確認 | アニメーション付き。弓射撃・詠唱の個別収録は未確認 | 人物のみを別の足場へ組み合わせる候補 | FBX・OBJ・Blend、商品ページに CC0 表示 | 無料 |
| [Quaternius Characters - Fantasy Races](https://quaternius.itch.io/characters-fantasy-races) | エルフ系を含む種族モデルの候補。人型リグ付き | **アニメーションなし**と作者が明記。衣装も別途適合確認が必要 | 人物のみ。足場・弓・動作を別途組む | [公式製品説明](https://quaternius.com/packs/charactersfantasyraces.html)に FBX・GLB、[QAL](https://quaternius.com/license.html)。CC0ではない | Standard 無料枠、Source 有料。必要なエルフが無料枠に含まれるか未確認 |

Ranger の根拠は[作者による無料更新の告知](https://itch.io/e/35257060/kay-lousberg-updated-kaykit-character-pack-adventurers)。職業名から人間・エルフを断定しない。Mage と矢は[作者の旧公式配布](https://github.com/KayKit-Game-Assets/KayKit-Character-Pack-Adventures-1.0)のファイル一覧で `Characters/gltf/Mage.glb`、`Assets/gltf/arrow.gltf` の存在を確認した。この旧配布には Ranger がなく、現在の itch.io 配布と内容・リグを同一視しない。

Quaternius は商品によって CC0 と QAL の表示が分かれる。QAL はゲームへの組込みを認める一方、素材自体の再配布を制限するため、公開リポジトリへの素材配置は採用した配布物の条件を個別に確認する。

## 追加制作と未検証事項

人物全体、弓、すべての動作を最初から作る必要性は低い。まず無料の KayKit 部品で射撃を試し、エルフらしい耳や衣装、射手が見える塔上面、琥珀色の魔法表現、施設強化の見た目を不足分として作る。Kenney や Quaternius は外観が合う場合の比較候補であり、現段階で有料パックを購入する必要はないという判断である。

未検証は、実際の収録クリップ名、人物と動作のリグ対応、弓と手・弦・矢の整合、発射イベントの時点、塔上面の寸法、胸壁との干渉、スマホ表示での見やすさと負荷。公式ファイルのアニメーション一覧を取得できていないため、具体的なクリップ名は記載しない。Rig_Medium と Rig_Large の収録範囲は同一とは限らず、他シリーズへ動作を移す場合はリターゲットと調整が必要。

コボルド、ドワーフ、デーモン、サキュバスの外観は今回の調査では確定していない。購入や導入の際は、取得元 URL、版、採用ファイル、同梱ライセンスを記録する。

## 従来のAI候補

[Beehave](https://github.com/bitbrain/beehave) は Godot 用のビヘイビアツリーアドオンで、公式リポジトリは MIT 表示。採掘・移動・迎撃・退避の優先順位を組む候補として継続する。塔モデル、射撃アニメーション、矢・魔法弾、経路探索を一式提供するアセットではない。採用エンジンの版との互換性と負荷は導入時に確認する。

`prototypes/landscape-ui.html` は操作検討用の2Dラフである。上記3D素材・アニメーション・AIアドオンを組み込んだゲームではなく、これらの素材はまだ同梱していない。

## UIラフに同梱したもの

オフラインでも表示できるよう、画面ラフには Lucide 1.8.0 の装飾アイコン4個を埋め込んでいる。使用したアイコンは `book-open`、`shield`、`sword`、`shield-half`。由来をHTML内に記録し、配布物に含まれる正式なライセンス全文を [prototypes/LICENSE.lucide](../prototypes/LICENSE.lucide) に保存した。
