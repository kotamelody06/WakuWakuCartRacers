# iPad（iPad mini）に入れる方法

iPad 用のアプリを作るには **Mac と Xcode** が必要です（Apple の決まりで、Windows や Android では作れません）。
Apple ID があれば無料で自分の iPad に入れられます（無料の場合は7日ごとに入れ直しが必要。年額の Apple Developer Program に入ると1年有効）。

## 用意するもの

* Mac（Xcode が動くもの）と USB ケーブル
* Xcode（App Store から無料）
* Godot 4.3 以降（Mac 版）と、エクスポートテンプレート
* Apple ID

## 手順

1. Mac で Godot を開き、このプロジェクトをインポート
2. 「エディター → エクスポートテンプレートの管理」でテンプレートをダウンロード
3. 「プロジェクト → エクスポート」でプリセット **iPad** を選ぶ
   * `App Store Team ID` に自分のチームIDを入れる（Xcode → Settings → Accounts で Apple ID を追加すると「Personal Team」が使えます）
   * `Bundle Identifier` は自分だけの名前に変えてもOK（例：`com.yourname.wakuwakukart`）
4. 「プロジェクトのエクスポート」で書き出す（Xcode のプロジェクトができます）
5. できた `.xcodeproj` を Xcode で開き、iPad を USB でつないで ▶ で実行
6. 初回は iPad の「設定 → 一般 → VPNとデバイス管理」で開発元を「信頼」する

## LAN対戦で使うときの注意

* はじめて「みんなで対戦」を開くと **「ローカルネットワーク上のデバイスの検索と接続」の許可** が出ます。必ず「許可」を押してください
  （あとから変えるときは「設定 → プライバシーとセキュリティ → ローカルネットワーク」）
* iPad では「見つかった部屋」の自動表示が出ないことがあります（Apple の制限）。
  そのときは **親機の画面に出ている「部屋番号」を入力** すれば入れます
* 古い iPad mini（2・3世代）は動きが重くなることがあります。その場合は iPad を子機にして、親機は Android スマホにするのがおすすめです
