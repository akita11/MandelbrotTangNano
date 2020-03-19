# MandelM5 with MandelbrotTangNano

MandelbrotTangNanoを実装したFPGAにM5Stackをつないで、マンデルブロ集合をぐりぐり閲覧します。

# 用意するもの

- SiPEED社の[TangNano](https://jp.seeedstudio.com/Sipeed-Tang-Nano-FPGA-board-powered-by-GW1N-1-FPGA-p-4304.html)
- M5Stack (Basicなど)
- M5Stack用Joystick UNIT
- ジャンパ線など、TangNanoとM5Stackを接続する配線(3本)

# 実装
- MandelbrotTangNanoをTangNanoに実装（コンパイルして内蔵フラッシュに書き込み）します。
- VSCode+platformIOで、M5Stack用のプログラムをビルドし、書き込みします
- M5Stackの16番(RXD2)をTangNanoの39番ピンに、M5Stackの17番(TXD2)をTangNanoの40番ピンに、それぞれ接続し、両者のGNDを接続します。
- M5StackにJoystick UNITを接続します
- M5Stack, TangNanoをUSBケーブルでPCにつなぎます。※TangNanoの仕様上、USBケーブルでPCに接続しないと内蔵クロックが生成されないため、ACアダプタ等で給電するだけではだめなようです。
- マンデルブロ集合を描画します
  - M5StackのBボタン：初期位置（-2.0-1.0i - +1.0+1.0iの範囲）
  - M5StackのAボタン：拡大
  - M5StackのCボタン：縮小
  - Joytick：描画範囲を上下左右に移動

# Author

@akita11 (akita@ifdl.jp)
