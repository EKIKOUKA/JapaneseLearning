# 📺 日本語シャドーイング練習アプリ

## 📝 概要
このアプリは、日本語学習者向けに開発した動画ベースの学習アプリです。
YouTube動画を利用し、字幕・ルビ（ふりがな）・再生機能を組み合わせて、効率的なシャドーイング学習を実現します。

動画の再生だけでなく、単語検索、再生速度調整、視聴進捗の保存など、学習体験を最適化する機能を提供しています。

---

## ✨ 主な機能（Features）

- 🎬 動画ストリーミング再生（HLS / m3u8）
- 📝 字幕表示＋ルビ（ふりがな）対応
- 🔍 単語タップでシステム辞書検索
- ⏱ 再生速度、字幕のサイズ、字幕の色変更
- 📌 視聴進捗の自動保存・復元
- 🔔 動画処理完了後に通知
- 🎨 サムネイルを活用した美しいブラー背景UI
- 🇺🇸 英語字幕に対する音標（発音記号）対応

---

## ⚙️ 処理フロー（Pipeline）

1. ユーザーが動画リンクを入力、またはリストから動画を選択
2. バックエンドAPIにリクエストを送信し、動画情報をデータベースに登録
3. `yt-dlp` を使用して動画をダウンロード
4. `FFmpeg` により動画を6秒ごとのセグメント（.ts）に分割
5. 分割された動画を Cloudflare R2 にアップロード（HLS形式）
6. 字幕データを生成し、Yahooのルビ振りAPIで漢字にふりがなを付与（https://jlp.yahooapis.jp/FuriganaService/V2/furigana）
7. 字幕JSONをR2にアップロード
8. 動画処理完了後、アプリに通知を送信
9. ユーザーは動画を再生し、再生速度や進捗がデータベースに保存される
10. 次回再生時に視聴位置を復元

---

バックエンドからフロントエンドまでの処理フローを以下に示します。
## 🧩 システム構成（Architecture）

```mermaid
flowchart TD

    A[YouTube URL入力 / 動画選択]
    B[Cloudflare Workers API]
    C[yt-dlp ダウンロード]
    D[FFmpeg セグメント分割]
    E["Cloudflare R2 (HLS: m3u8 + ts)"]
    F[字幕生成]
    G[Yahoo ルビAPI]
    H["字幕JSON (R2)"]
    I["iOS App (AVPlayer)"]
    J[再生・視聴進捗保存]

    A --> B
    B --> C
    C --> D
    D --> E
    C --> F
    F --> G
    G --> H
    E --> I
    H --> I
    I --> J
```

---

## 🛠 技術スタック（Tech Stack）

- 📦 動画ストレージ：Cloudflare R2
- 🗄 データベース：Cloudflare D1
- ⚙️ バックエンド：Cloudflare Workers
- 🔤 ルビ振りAPI：Yahoo Furigana API
- 📱 アプリケーション：Swift（SwiftUI）
- 🎥 動画処理：FFmpeg / yt-dlp

---

## 📱 画面プレビュー

| | | |
|---|---|---|
| <img src="https://github.com/user-attachments/assets/3ec35715-d9a9-45ed-af65-0d10f56de1f6" width="300"/> | <img src="https://github.com/user-attachments/assets/69b08372-1202-4462-98fc-350ce7262469" width="300"/> | <img src="https://github.com/user-attachments/assets/4d0854cc-fd40-4048-a558-ec2c20856775" width="300"/> |
| <img src="https://github.com/user-attachments/assets/fd1d34cc-9f9c-405a-b121-baffe3c0fe0a" width="300"/> | <img src="https://github.com/user-attachments/assets/6e1574b4-6220-4e84-b799-33d7c023ecc4" width="300"/> | <img src="https://github.com/user-attachments/assets/229be712-3423-42f4-80a1-fb0b7c4c4766" width="300"/> |
| <img src="https://github.com/user-attachments/assets/55a06de7-0daf-4ec3-a51a-dc87d7ca1564" width="300"/> | <img src="https://github.com/user-attachments/assets/0cf06bba-930b-419f-8495-1c12864f6d84" width="300"/> |  |

---

## ⚠️ 注意事項（Disclaimer）

本アプリは個人の学習および技術検証を目的として開発されたものです。
動画コンテンツの著作権は各権利者に帰属します。
取得した動画データについては、長期保存を行わず、一定期間経過後に削除しています。

YouTube等の外部サービスから取得したコンテンツの利用については、各サービスの利用規約および関連法令を遵守する必要があります。

本プロジェクトは教育・研究用途のサンプルとして公開しており、第三者への配布や商用利用は想定していません。
