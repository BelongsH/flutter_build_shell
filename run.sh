### 保存的路径
saveDir="/Users/alex/Desktop/ee";
### 签名文件
keysFile="/Users/alex/Documents/cc/flutter/dd/android/app/key/aa.jks"


### 如果文件夹不存在的话，创建
createDirWhenNotFound(){
  dirname=$1
  if [ ! -d $dirname  ];then
    mkdir $dirname
    echo "创建文件夹:$dirname}"
  else
    echo "文件夹已经存在～"
  fi
}


### 编译APK数据
buildReleaseApk(){
  # 创建父文件夹
  createDirWhenNotFound $saveDir
  # 调用 Flutter 命令编译APK
  flutter build apk --release \
                    --dart-define=channelName=$1 \
                    --dart-define=requestUrl=$2 \
                    --target-platform android-arm,android-arm64 --split-per-abi \
                    --no-tree-shake-icons \
                    --build-name '1.0.5' \
                    --build-number '5' \
  # 切换到 Flutter 编译出来的文件夹中
  cd build/app/outputs/flutter-apk/
  # 创建渠道文件夹
  createDirWhenNotFound $saveDir/$1
  # 拷贝编译后的文件夹到对应的目录
  cp app-*.apk $saveDir/$1
  # 重新APK签名信息
  apksigner sign --ks $keysFile --ks-pass pass:123456 --ks-pass pass:123456 $saveDir/$1/app-arm64-v8a-release.apk
  apksigner sign --ks $keysFile --ks-pass pass:123456 --ks-pass pass:123456 $saveDir/$1/app-armeabi-v7a-release.apk

}


### 编译Android安装包
buildAndroid(){
  flutter clean
  buildReleaseApk oppo http://www.baidu1.com
  buildReleaseApk xiaomi http://www.baidu2.com
  buildReleaseApk huawei http://www.baidu3.com
  buildReleaseApk yingyongbao http://www.baidu3.com
}

buildAndroid