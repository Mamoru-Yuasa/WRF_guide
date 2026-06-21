# WRF Container Guide: Podman and Apptainer

このガイドでは、`Dockerfile.wrf` から WRF/WPS 実行環境を作成し、Podman と Apptainer の両方で利用する手順を示します。

この Dockerfile は Ubuntu ベースのコンテナ内で、WRF 依存ライブラリ、WRF、WPS をソースからビルドします。ビルドにはネットワーク接続、十分なディスク容量、長いコンパイル時間が必要です。

## 前提

ホスト側に以下のどちらか、または両方が必要です。

- Podman
- Apptainer

推奨リソースの目安です。

- CPU: 4 cores 以上
- RAM: 8 GB 以上
- 空きディスク: 30 GB 以上
- ネットワーク: WRF/WPS と依存ライブラリの取得に必要

作業ディレクトリは、このリポジトリのルートを想定します。

```bash
cd /path/to/WRF_guide
```

## Dev Container で使う場合

`.devcontainer/devcontainer.json` は、ビルド済みの `wrf-ubuntu:4.7.1` イメージに入る設定です。Dev Container 起動時には、以下の bind mount を行います。

- このリポジトリ: `/workspace/WRF_guide`
- ホスト側 `/mnt/work`: コンテナ側 `/workspace/work`

WRF/WPS の入力データや実行結果をホスト側 `/mnt/work` に置きたい場合は、コンテナ内では `/workspace/work` を使います。

```bash
cd /workspace/work
```

VS Code で Dev Container を開く前に、ホスト側の作業ディレクトリが存在することを確認してください。

```bash
mkdir -p /mnt/work
```

## 1. Podman でイメージをビルドする

基本形です。

```bash
podman build -f Dockerfile.wrf -t wrf-ubuntu:4.7.1 . 2>&1 | tee logs/build_wrf.log
```

並列ビルド数を指定する場合は、`WRF_DEP_JOBS` と `WRF_BUILD_JOBS` を調整します。

```bash
podman build -f Dockerfile.wrf -t wrf-ubuntu:4.7.1 \
  --build-arg WRF_DEP_JOBS=8 \
  --build-arg WRF_BUILD_JOBS=4 \
  . 2>&1 | tee logs/build_wrf.log
```　

WRF/WPS のバージョンを変える場合は、Dockerfile の build arg を指定します。

```bash
podman build -f Dockerfile.wrf -t wrf-ubuntu:custom \
  --build-arg WRF_VERSION=v4.7.1 \
  --build-arg WPS_VERSION=v4.6.0 \
  --build-arg WRF_CONFIGURE_OPTION=34 \
  --build-arg WRF_NESTING_OPTION=1 \
  --build-arg WPS_CONFIGURE_OPTION=3 \
  . 2>&1 | tee logs/build_wrf.log
```

`WRF_CONFIGURE_OPTION` と `WPS_CONFIGURE_OPTION` は、WRF/WPS の `./configure` メニュー番号です。WRF/WPS のバージョンによって番号が変わる可能性があります。ビルドに失敗した場合は、該当バージョンの configure menu を確認して番号を合わせてください。

## 2. Podman でコンテナを起動する

実験用の作業ディレクトリを作ります。

```bash
mkdir -p work
```

コンテナを起動します。

```bash
podman run --rm -it \
  -v "$PWD/work:/work" \
  wrf-ubuntu:4.7.1
```

コンテナ内では `/work` が作業場所です。WRF/WPS と依存ライブラリの環境変数はログインシェルで自動設定されます。

確認例です。

```bash
which wrf.exe
which real.exe
which geogrid.exe
which ungrib.exe
which metgrid.exe

printenv WRF_DIR
printenv WPS_DIR
printenv NETCDF
printenv JASPERLIB
```

## 3. Podman で WRF を実行する

WRF の実行ディレクトリを作成します。

```bash
mkdir -p /work/run
cd /work/run
```

必要な入力ファイルを `/work/run` に置きます。

- `namelist.input`
- `wrfbdy_d01`
- `wrfinput_d01`
- 必要に応じて `wrfinput_d02` など

WRF の実行ファイルとテーブル類は、必要に応じてリンクします。

```bash
ln -sf /opt/WRF/main/*.exe .
ln -sf /opt/WRF/run/* .
```

MPI 実行の例です。

```bash
mpirun -np 4 ./wrf.exe
```

初期値作成から行う場合は、まず `real.exe` を実行します。

```bash
mpirun -np 4 ./real.exe
mpirun -np 4 ./wrf.exe
```

Podman の実行時に標準出力へ表示しながらホスト側にもログを残す場合は、コンテナを単発実行し、ホスト側で `tee` します。

```bash
set -o pipefail
mkdir -p logs

podman run --rm \
  -v "$PWD/work:/work" \
  wrf-ubuntu:4.7.1 \
  bash -lc 'cd /work/run && mpirun -np 4 ./real.exe' \

podman run --rm \
  -v "$PWD/work:/work" \
  wrf-ubuntu:4.7.1 \
  bash -lc 'cd /work/run && mpirun -np 4 ./wrf.exe' \
```

SELinux が有効な環境では、bind mount を `-v "$PWD/work:/work:Z"` に変えてください。

## 4. Podman で WPS を実行する

WPS 用の作業ディレクトリを作ります。

```bash
mkdir -p /work/wps
cd /work/wps
```

WPS 実行ファイルとテーブル類をリンクします。

```bash
ln -sf /opt/WPS/geogrid.exe .
ln -sf /opt/WPS/ungrib.exe .
ln -sf /opt/WPS/metgrid.exe .
ln -sf /opt/WPS/link_grib.csh .
ln -sf /opt/WPS/ungrib/Variable_Tables .
ln -sf /opt/WPS/geogrid/GEOGRID.TBL .
ln -sf /opt/WPS/metgrid/METGRID.TBL .
```

`namelist.wps` を配置し、地理データと気象データを bind mount して使います。例として、ホスト側に `geog` と `grib` がある場合です。

```bash
podman run --rm -it \
  -v "$PWD/work:/work" \
  -v "/path/to/geog:/data/geog:ro" \
  -v "/path/to/grib:/data/grib:ro" \
  wrf-ubuntu:4.7.1
```

コンテナ内の `namelist.wps` では、`geog_data_path` をコンテナから見えるパスにします。

```text
geog_data_path = '/data/geog'
```

WPS の実行例です。

```bash
./geogrid.exe
./link_grib.csh /data/grib/FILE_PREFIX*
ln -sf Variable_Tables/Vtable.GFS Vtable
./ungrib.exe
./metgrid.exe
```

Podman の実行時にログを残す例です。

```bash
set -o pipefail
mkdir -p logs

podman run --rm \
  -v "$PWD/work:/work" \
  -v "/path/to/geog:/data/geog:ro" \
  -v "/path/to/grib:/data/grib:ro" \
  wrf-ubuntu:4.7.1 \
  bash -lc 'cd /work/wps && ./geogrid.exe' \

podman run --rm \
  -v "$PWD/work:/work" \
  -v "/path/to/geog:/data/geog:ro" \
  -v "/path/to/grib:/data/grib:ro" \
  wrf-ubuntu:4.7.1 \
  bash -lc 'cd /work/wps && ./link_grib.csh /data/grib/FILE_PREFIX* && ln -sf Variable_Tables/Vtable.GFS Vtable && ./ungrib.exe' \

podman run --rm \
  -v "$PWD/work:/work" \
  -v "/path/to/geog:/data/geog:ro" \
  -v "/path/to/grib:/data/grib:ro" \
  wrf-ubuntu:4.7.1 \
  bash -lc 'cd /work/wps && ./metgrid.exe' \
```

## 5. Apptainer 用 SIF を作成する

Apptainer は Dockerfile を直接ビルドするより、Podman で作成したイメージを archive に保存し、それを SIF に変換する方法が扱いやすいです。

まず Podman イメージを tar archive として保存します。

```bash
podman save -o wrf-ubuntu-4.7.1.tar wrf-ubuntu:4.7.1
```

Apptainer で SIF に変換します。

```bash
apptainer build wrf-ubuntu-4.7.1.sif docker-archive://wrf-ubuntu-4.7.1.tar
```

管理者権限が使えない環境では、fakeroot が使える場合があります。

```bash
apptainer build --fakeroot wrf-ubuntu-4.7.1.sif docker-archive://wrf-ubuntu-4.7.1.tar
```

HPC 環境では、SIF の作成はログインノードではなく、許可されたビルドノードやローカルマシンで行ってください。

## 6. Apptainer でコンテナを起動する

作業ディレクトリを bind してシェルに入ります。

```bash
mkdir -p work
apptainer shell --bind "$PWD/work:/work" wrf-ubuntu-4.7.1.sif
```

コンテナ内で環境を確認します。

```bash
which wrf.exe
which real.exe
which geogrid.exe
printenv WRF_DIR
printenv NETCDF
```

Apptainer は通常、カレントディレクトリやホームディレクトリを自動で bind します。ただし HPC 環境ではサイト設定に依存するため、WRF の作業ディレクトリは明示的に `--bind` するのが安全です。

## 7. Apptainer で WRF を実行する

コンテナ内の MPICH を使って実行する例です。

```bash
apptainer exec --bind "$PWD/work:/work" wrf-ubuntu-4.7.1.sif \
  bash -lc 'cd /work/run && mpirun -np 4 ./real.exe'

apptainer exec --bind "$PWD/work:/work" wrf-ubuntu-4.7.1.sif \
  bash -lc 'cd /work/run && mpirun -np 4 ./wrf.exe'
```

実行前に `/work/run` には WRF の入力ファイル、実行ファイル、テーブル類を置いてください。

```bash
apptainer exec --bind "$PWD/work:/work" wrf-ubuntu-4.7.1.sif \
  bash -lc 'cd /work/run && ln -sf /opt/WRF/main/*.exe . && ln -sf /opt/WRF/run/* .'
```

HPC のジョブスケジューラから実行する場合は、まず小さい `-np` で動作確認してください。ホスト MPI とコンテナ MPI を混ぜる実行は MPI 実装と ABI の互換性が必要です。この Dockerfile はコンテナ内に MPICH をビルドしているため、最初はコンテナ内の `mpirun` を使う方が単純です。

## 8. Apptainer で WPS を実行する

地理データと GRIB データを bind します。

```bash
apptainer shell \
  --bind "$PWD/work:/work" \
  --bind "/path/to/geog:/data/geog:ro" \
  --bind "/path/to/grib:/data/grib:ro" \
  wrf-ubuntu-4.7.1.sif
```

コンテナ内で WPS 作業ディレクトリを準備します。

```bash
mkdir -p /work/wps
cd /work/wps
ln -sf /opt/WPS/geogrid.exe .
ln -sf /opt/WPS/ungrib.exe .
ln -sf /opt/WPS/metgrid.exe .
ln -sf /opt/WPS/link_grib.csh .
ln -sf /opt/WPS/ungrib/Variable_Tables .
ln -sf /opt/WPS/geogrid/GEOGRID.TBL .
ln -sf /opt/WPS/metgrid/METGRID.TBL .
```

`namelist.wps` を置き、`geog_data_path` を `/data/geog` にします。

```bash
./geogrid.exe
./link_grib.csh /data/grib/FILE_PREFIX*
ln -sf Variable_Tables/Vtable.GFS Vtable
./ungrib.exe
./metgrid.exe
```

## 9. よく使う確認コマンド

NetCDF の確認です。

```bash
nc-config --all
nf-config --all
```

MPI の確認です。

```bash
which mpirun
mpirun --version
```

WRF/WPS バイナリの確認です。

```bash
ls -l /opt/WRF/main/wrf.exe /opt/WRF/main/real.exe
ls -l /opt/WPS/geogrid.exe /opt/WPS/ungrib.exe /opt/WPS/metgrid.exe
```

## 10. トラブルシュート

ビルド時に `./configure` の選択番号で失敗する場合は、WRF/WPS の configure menu 番号が Dockerfile の既定値と違う可能性があります。`WRF_CONFIGURE_OPTION` または `WPS_CONFIGURE_OPTION` を build arg で指定してください。

ビルドが途中で止まる場合は、並列数を下げます。

```bash
podman build -f Dockerfile.wrf -t wrf-ubuntu:4.7.1 \
  --build-arg WRF_DEP_JOBS=4 \
  --build-arg WRF_BUILD_JOBS=2 \
  .
```

実行時にライブラリが見つからない場合は、ログインシェルで起動しているか確認します。このイメージの既定 CMD は `bash -l` です。`apptainer exec` で単発実行する場合は、以下のように `bash -lc` を使うと `/etc/profile.d/wrf.sh` が読み込まれます。

```bash
apptainer exec wrf-ubuntu-4.7.1.sif bash -lc 'printenv NETCDF && which wrf.exe'
```

GRIB2 処理で WPS が失敗する場合は、`JASPERLIB` と `JASPERINC` を確認します。

```bash
printenv JASPERLIB
printenv JASPERINC
ls "$JASPERLIB"
ls "$JASPERINC"
```
