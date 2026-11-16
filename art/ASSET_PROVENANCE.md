# 実素材の入手元と再現方法

確認日：2026-11-16。Lv1プレビュー用に、作者の公式配布から無料の3Dモデルと動作を取得した。選択した原本は `art/source-assets/` に保存し、原本のバイト列を維持している。配布ZIP全体は同梱しない。

## 採用した配布物

| 配布物 | 取得元と固定情報 | 保存したもの | ライセンス |
| --- | --- | --- | --- |
| KayKit Dungeon Remastered 1.0 | [作者の公式GitHub](https://github.com/KayKit-Game-Assets/KayKit-Dungeon-Remastered-1.0/tree/b0ca9bd96a8072ab36a3a5464f00ed1e06a16d07)、commit `b0ca9bd96a8072ab36a3a5464f00ed1e06a16d07` | 石床、低い壁、瓦礫、暗い木床、松明、石の土台のGLB 6個。ファイル名の末尾を `.gltf.glb` から `.glb` に短縮しただけで内容は同一 | [元のLICENSE.txt](source-assets/kaykit-dungeon-remastered-1.0/LICENSE.txt)：CC0 |
| KayKit Adventurers Character Pack 2.0 FREE | [作者のitch.io](https://kaylousberg.itch.io/kaykit-adventurers)、無料配布 `Free 2.0`、upload ID `15363167` | Ranger、Mage、弓、矢、staff、wandと必要なbin・テクスチャ。Mageと杖は追加施設候補で、Lv1初期配置には含めない | [同梱License.txt](source-assets/kaykit-adventurers-2.0-free/License.txt)：CC0 |
| KayKit Character Animations 1.1 FREE | [作者のitch.io](https://kaylousberg.itch.io/kaykit-character-animations)、無料配布 `Free 1.1`、upload ID `15799903` | `Rig_Medium_CombatRanged.glb`。弓の構え・引き・放つ動作と、魔法の詠唱・発射動作 | [同梱License.txt](source-assets/kaykit-character-animations-1.1/License.txt)：CC0 |

作者は **Kay Lousberg（[kaylousberg.com](https://www.kaylousberg.com/)）**。有料の Extra / Source パックは取得していない。Dungeon は現行商品カバーと同じ版だとは扱わず、上記の公開1.0を固定して使用する。

ファイルとライセンスを合わせて **22ファイル、2,203,200バイト（約2.10 MiB）**。ファイルごとのSHA-256、原本のパス、ZIPのSHA-256、依存関係は [ASSET_MANIFEST.json](ASSET_MANIFEST.json) に記録した。人物とDungeonのGLBはテクスチャを内包し、弓・矢・杖のglTFには相対参照するbinとPNGを同梱した。

## 再取得と検証

リポジトリのルートから、Python 3.10以降の標準ライブラリだけで実行できる。

```sh
python3 art/fetch_assets.py --verify-only
python3 art/fetch_assets.py
```

前者は通信せず、同梱ファイルのSHA-256を確認する。後者は不足ファイルだけを再取得する。既存ファイルが台帳と異なる場合は上書きしない。itch.ioでは通常の無料ダウンロード手順を使い、無料ページに固定したupload IDと版名があること、取得ZIPのハッシュが一致することを確認してから選択ファイルだけを取り出す。購入や有料版への代替は行わない。公式配布が変わった場合は停止するので、台帳を確認して更新する。

## 原本と本作の表現を分ける

Rangerは公式モデル名であり、配布元がエルフと明記しているとは扱わない。エルフの耳や衣装調整、コボルド、塔の組立、琥珀色の魔力、洞窟の色と照明は本作側の制作・調整対象。原本を直接書き換えず、描画処理で加工した部分と自作部分を区別する。

RangerとMageのGLB自体に動作は入っていない。別のCombatRanged GLBに収録された実クリップ名を台帳で記録している。たとえば `Ranged_Bow_Aiming_Idle`、`Ranged_Bow_Draw`、`Ranged_Bow_Release`、`Ranged_Magic_Spellcasting`、`Ranged_Magic_Shoot` の存在をGLBのJSONで確認した。収録確認だけで射撃処理やゲーム内の動作同期を完成と扱わない。

取得した原本、同じカメラ・照明から作る2.5Dの派生画像、ゲーム側の挙動はそれぞれ別の成果物として扱う。エンジン本体は未確定であり、この取得記録はGodotへの導入・実機動作の検証を意味しない。

## Lv1の派生描画での使い分け

`art/render_lv1.py` は原本を読み込み、画面とスプライト向けの構成を作る。原本への変更は保存しない。

| 表現 | 既製素材の使用部分 | 本作側の追加・変更 |
| --- | --- | --- |
| 石床・防壁・岩・木の足場・松明・土台 | Dungeonの選択GLB 6個 | 石と木の色調、配置、照明 |
| 弓塔のエルフ射手 | Ranger、bow_withString、arrow_bow、`Ranged_Bow_Aiming_Idle` の6フレーム目のポーズ | 尖った耳、塔の梯子・支柱・角の部品。人物の元テクスチャは保持 |
| 追加候補の魔法塔 | Mage、`Ranged_Magic_Spellcasting` の6フレーム目のポーズ | 描画中の杖・魔力の破片は自作形状。取得済みstaff/wand原本と混同しない |
| コボルド | 今回のKayKit選択原本には該当人物なし | 鼻先・耳・尾を含む人物、つるはし |
| 魔力井・鉱脈・罠 | 土台などにDungeon部品を使用 | 琥珀色の結晶、導管・縁・竪穴の細部、鉱石片、罠の棘板 |

動作ファイルから取った静止ポーズであり、ゲーム中に射撃アニメーションを再生しているという意味ではない。描画時にはBlenderのインポーターが作る骨操作用のIcosphere補助オブジェクトを除外する。
