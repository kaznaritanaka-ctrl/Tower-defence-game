# ダンジョンLv1・侵攻側と模擬戦

2026-11-16／HTML Canvas試作

既存の[Lv1プレビュー](../prototypes/landscape-ui.html)に「模擬襲撃」を追加。歩兵2体・弓兵2体が2方向から時間差で侵攻し、弓塔・魔法塔・罠が自動迎撃する。侵入方向と外周の出現地点は襲撃開始時にランダム決定し、開始前に固定マークを表示しない。四角形の10×8マップでは4方向Dijkstra経路探索を使い、防壁は高コストの通行障害として扱う。壁で完全に塞いだ場合は突破するまで攻撃する。敵と施設にHPがあり、中枢（魔力井）破壊で敗北、全敵撃破で勝利となる。

**侵攻側の表示は現時点でCanvas描画の仮モデル**（歩兵＝剣・盾、弓兵＝弓のシルエット）。本作向けの3D差替えは[KayKit Adventurers 2.0](https://kaylousberg.itch.io/kaykit-adventurers)のKnight・Rangerを候補とする。リポジトリにあるRangerモデルは守備側で使用済みだが、Knight 2.0モデルの追加・Blenderレンダリング・リグと射撃アニメーションの再生は未実装。現行2.5DのKayKit防衛施設はそのまま活用している。

補助アセット候補： [KayKit Skeletons](https://kaylousberg.itch.io/kaykit-skeletons)（CC0の剣士・射手等）、[Kenney Modular Dungeon Kit](https://kenney.nl/assets/modular-dungeon-kit)（CC0）、[Cryptstone Dungeon Kit](https://elliottfhotmailfr.itch.io/cryptstone-dungeon-kit)（CC0）、[Dreadhollow](https://leeman69.itch.io/dreadhollow-300-dark-fantasy-low-poly-3d-assets)（独自商用ライセンス、素材の再配布制限あり）。

実装は試験用であり、戦闘で資源・資金を獲得せず、ダメージはゲーム保存に反映しない。経路上の他施設の厳密な衝突、敵同士の衝突、完全な射線遮蔽、敵AI戦術、全体魔法、正式なGodotプロジェクトは未実装。スマホ実機・実ブラウザでの戦闘統合テストはこれからである。Lv1の毎時6・魔力上限70と研究・保存処理は変更していない。

## 現行仕様との関係（2026-11-17追記）

この模擬襲撃は[全体設計](OVERALL_DESIGN.md)を決める前に作った。現行仕様と一致する点と異なる点は次のとおり。

- 一致する点：出現位置を開始時に抽選し予告しないこと、防壁を高コストの通行障害として扱い完全封鎖時は壊して進むこと、中枢の破壊で敗北すること。中枢は現行仕様のダンジョンコア（魔力タンク）に当たる。
- 異なる点：盤面が10×8であること（現行は初期7×7程度）、配下への移動指示と全体魔法がないこと、戦闘中に魔力が湧かないこと、wave の解禁・資金の報酬・資材の獲得がないこと、開始前に編成と方向の数を表示しないこと。
