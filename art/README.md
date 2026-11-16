# Lv1の素材と描画を再現する

操作画面は [prototypes/landscape-ui.html](../prototypes/landscape-ui.html) をブラウザで開けば表示できる。画像はHTML内に埋め込み済みで、実行時の通信やBlenderは不要。

元の3Dモデルは `source-assets/`、出典・ライセンスは [ASSET_PROVENANCE.md](ASSET_PROVENANCE.md)、個別ハッシュは [ASSET_MANIFEST.json](ASSET_MANIFEST.json) に保存した。使用した原本の内容を変更せず、描画時に色・姿勢・部品を調整する。

## 再生成

リポジトリのルートで実行する。検証した描画環境はBlender 4.3.2、CyclesのCPU描画。Python側のPNG最適化にはPillowが必要。

```sh
python3 art/fetch_assets.py --verify-only
blender -b -t 2 --python art/render_lv1.py -- --sprites --scene
python3 art/optimize_png.py
python3 art/embed_preview_assets.py
```

不足する原本だけを取り直す場合は `python3 art/fetch_assets.py` を使う。取得元や版が変わって台帳と一致しない場合は停止する。

`render_lv1.py` は実モデルを読み込み、石材・木材の色と照明を調整し、コボルド・琥珀結晶・塔の細部を追加する。弓の構えと詠唱は配布アニメーションから取った静止ポーズ。ゲーム中のアニメーション再生・射撃処理は含まない。

`optimize_png.py` は完全透明画素の不要RGBだけを除き、PNGの容量と選択境界を整える。見える画素と全画素のalphaが変わらないことを確認する。`embed_preview_assets.py` はPNGと座標をオフラインHTMLへ埋め込む。同じ入力で繰り返してもHTMLの内容は変わらない。

## 出力と役割

| 出力 | 用途 |
| --- | --- |
| [sprites.json](../prototypes/assets/lv1/sprites.json) と同階層のPNG10点 | 操作画面で使う画像、接地点、透過境界 |
| [盤面の描画例](../docs/images/lv1-asset-playfield.png) | 実際の操作画面と同じCanvasコードをnative Canvasで描画した確認画像。HUDとCSS全体のスクリーンショットではない |
| [3D配置見本](generated/lv1-dark-assets.webp) | 同じ初期配置をBlenderでまとめて描画した外観資料。操作画面とは照明計算が異なる |

カメラは正投影、画面の盤面に合わせて高さ／幅の比を0.47とする。初期状態は魔力井1基・弓塔1基・防壁2枚・コボルド1体。外周の岩は外観用で、通行や施設の配置可能マスを制限しない。

この環境のBlenderにはOpenImageDenoiseがなく、3D配置見本の照明部分には粒状感が残る。主な操作確認には、個別スプライトを使うHTML版を用いる。ブラウザ全体のCSS描画とスマートフォン実機操作は別途確認する。
