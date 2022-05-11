### 前言

如果你也在使用`Flutter`进行`APP`开发的话，下面这篇文章可能对你有一些帮助。本文主要是针对`Android`的编译打包上面的优化。`IOS`可能也存在类似的问题，目前对`IOS`不是特别熟悉。

#### 0X01 Flutter多渠道

首先，当我们的`Flutter APP`正式上架的过程中。需要对不同的渠道进行统计和一些特定的操作。在`Android` 原生叫做多渠道打包。可以借助`gradle`中的`productFlavors`来完成。 如果使用`productFlavors`就必须要求开发者了解`gradle`的知识，这样的话跨平台的意义可能就没有那么的大。出于这一点考虑。我们尝试着从`Flutter`的角度来处理这个问题。

在`Flutter 1.17` 的时候`string`新增了一个方法

> ```
> external const factory String.fromEnvironment(String name,  {String defaultValue = ""});
> ```

这个方法，能够接受编译时的变量。 这样就让我们在编译时期给程序传递变量有了机会。

##### 案例实践

这里举个例子。我们后台会对所有的请求进行渠道上的分析。分析出哪个应用市场的用户比较多。而区分应用市场的标识都会存在与一个变量`channelName`上。 这就要求，我们针对不同市场需要编译出不同的包。

> 华为市场 channelName huawei
>
> 小米市场 channelName. xiaomi.

然后我们将编译出来的这个`channelName` 放到`http`的`head`中。这样后台就可以进行统计了。

上述介绍了原理，这个贴一下代码。首先你需要定一个`const`常量用于你放在`head`里面

```
/// 渠道信息
const channelName =
    String.fromEnvironment("channelName", defaultValue: "huawei");
```

这个常量会根据你编译配置的参数变化而变化。比如你定义的参数是`oppo`它就是变成`oppo`。

```
flutter build apk  --dart-define=channelName=oppo
```

当你调用如上`shell`，就可以传递这个`channelName`传递到你程序中。而如果你需要打多个`apk`包的话。就可以重复更改这个`channelName`即可。 下文还会给出完整的打包脚本。

#### 0X02 Flutter包体积优化所带来的问题

当我们的项目引入了`ffmpng`的时候。我们应用的包体积就开始猛增。打开`Android Studio` 对`APK`进行查看的时候。发现`Flutter`将所有的架构的`so`文件都打包的`apk`中。 这样很明显是不明智的。 于是我们在网上找到了区分架构的打包脚本

```
 flutter build apk  --target-platform android-arm,android-arm64 --split-per-abi
```

这样子我们就可以将`so`架构进行分类。当你上传对应的应用市场的时候。你会发现。你打出来的包的版本号并不受你的控制。(我们这里`pubspec.yaml`里面定义d的是1.0.4+5。得出来的结论版本信息并不是我们想要的) 。

在解决问题之间。我们还是去查看了`Flutter`官方对版本号的定义 。

> 每个应用默认的初始版本号是 `1.0.0`。若要更新它，请转到 `pubspec.yaml` 文件并更新以下内容：
>
> version: 1.0.0+1
>
> 版本号由三个点分隔的数字组成，例如上面样例中的 `1.0.0`。然后是可选的构建号，例如上面样例中的 `1`，以 `+` 分隔。
>
> 版本号与构建号都可以在 Flutter 打包时分别使用 `--build-name` 和 `--build-number` 重新指定。
>
> 在 Android 中，`build-number` 被用作 `versionCode`， `build-name` 将作为 `versionName` 使用。更多信息请参考 Android 文档中的 [为你的应用添加版本](https://developer.android.google.cn/studio/publish/versioning)。
>
> 在更新完 pubspec 文件中的版本号之后，在项目根目录下运行 `flutter pub get`，或者使用 IDE 中的 **Pub get** 按钮。这将会更新 `local.properties` 文件
>
> 中的 `versionName` 和 `versionCode`，之后它会在你构建 Flutter 应用的时候更新 `build.gradle`。

根据上述的文档。 我们得出了结论`yaml`里面的`version`会对`versionName`和`versionCode`造成影响。 `versionName`是截取`yaml` + 前面的字符串。而`versionCode`是截取`yaml` + 后面的字符串。这个结论在没有对`so`进行拆分是可靠的。但是对`so`拆分后就不可控了。于是我们尝试着从`Flutter`的打包脚本上查找原因。

##### 问题原因 ，流程梳理

首先`Flutter`在`Android`上的打包脚本是通过`android`目录下的`app`目录下的`build.gradle`里面的

> apply from: "$flutterRoot/packages/flutter_tools/gradle/flutter.gradle"

而这个`flutter.gradle` 文件是你安装`flutter`目录下的一个文件。然后我们查看代码，因为我们在使用过了`split-per-abi`后面出了问题。所以我们直接全局查找`abi`就看到了`flutter.gradle`有关这部的逻辑。

```
// flutter.gradle 810行 
def addFlutterDeps = { variant ->
            if (shouldSplitPerAbi()) {
                variant.outputs.each { output ->
                    def abiVersionCode = ABI_VERSION.get(output.getFilter(OutputFile.ABI))
                    if (abiVersionCode != null) {
                        output.versionCodeOverride =
                            abiVersionCode * 1000 + variant.versionCode
                    }
                }
            }
```

可以看到，`Flutter`打包脚本里面会判断是否使用了`split-per-abi`命令。如果使用了`split-per-abi`的话。它就是用`ABI_VERSION`里面取一个版本。然后*1000在加上本身的版本号。为什么这样做呢？ [官方解释](https://developer.android.com/studio/build/configure-apk-splits)

> 默认情况下，当 Gradle 生成多个 APK 时，每个 APK 都有相同的版本信息，该信息在模块级 `build.gradle` 文件中指定。由于 Google Play 商店不允许同一个应用的多个 APK 全都具有相同的版本信息，因此在上传到 Play 商店之前，您需要确保每个 APK 都有自己唯一的 [`versionCode`](https://developer.android.com/studio/publish/versioning#appversioning)。
>
> 您可以配置模块级 `build.gradle` 文件以替换每个 APK 的 `versionCode`。通过创建一种映射关系来为您配置了多 APK 构建的每种 ABI 和密度分配一个唯一的数值，您可以将输出版本代码替换为一个将在 `defaultConfig` 或 `productFlavors` 代码块中定义的版本代码与分配给相应密度或 ABI 的数值组合在一起的值。
>
> 在以下示例中，`x86` ABI 的 APK 的 `versionCode` 将为 2004，`x86_64` ABI 的 APK 的版本代码将为 3004。如果以较大的增量（如 1000）分配版本代码，那么当您以后需要更新应用时，就可以分配唯一的版本代码。例如，如果 `defaultConfig.versionCode` 在后续更新中迭代到 5，那么 Gradle 为 `x86` APK 分配的 `versionCode` 将为 2005，为 `x86_64` APK 分配的版本代码将为 3005。

而这种版本控制。在我们国内市场似乎没有效果。目前上传腾讯应用市场。要求其版本号必须一致。所以我们将`jenkins`上的`ABI_VERSION`的对应版本改成一致。这样`versionCode`就可控制了。

```
  private static final Map ABI_VERSION = [
        (ARCH_ARM32)        : 3,
        (ARCH_ARM64)        : 3,
        (ARCH_X86)          : 3,
        (ARCH_X86_64)       : 3,
  ]
```

#### 0X03 Flutter打包签名的问题

当我们使用`build apk --release`的时候。 有一些市场可以正常识别出签名信息。但是某些市场并没有办法识别出签名信息。于是我们重新按照官方文档进行证书的配置。

1.  首先要一个证书文件。
1.  然后要把证书文件里面的信息写到一个文件中，这个文件最好放在`[project]/android/key.properties`
1.  最后把这个`key.properties`中的字段读出来。配置到`signingConfigs`里面

这里只是介绍了大概。 具体如何配置可以查看 [打包配置](https://developer.android.com/studio/build/configure-apk-splits)，在反复确认我们的配置并没出现问题。而且某些渠道也可以正常识别后。我们怀疑可能是市场的识别方式不同导致的。 所以我们打算对`APK`进行重新签名。[签名相关](https://developer.android.com/studio/command-line/apksigner?hl=zh-cn)

> ```
> apksigner sign --ks $keysFile --ks-pass pass:123456 --ks-pass pass:123456 $saveDir/$1/app-arm64-v8a-release.apk
> ```

重新签名后。 我们就可以正常上传到应用市场了。

#### 0X04 Flutter 打包脚本

当我们解决了上述所说的一些问题了。 我们尝试的编写一个脚本用来一键解决打包问问题。 具体脚本如下 [Github](https://github.com/BelongsH/flutter_build_shell)

```
### 保存的路径
saveDir="/Users/alex/Desktop/ee";
### 签名文件
keysFile="/Users/alex/Documents/cc/flutter/dd/android/app/key/aa.jks"
​
​
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
​
​
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
​
​
### 编译Android安装包
buildAndroid(){
  flutter clean
  buildReleaseApk oppo http://www.baidu1.com
  buildReleaseApk xiaomi http://www.baidu2.com
  buildReleaseApk huawei http://www.baidu3.com
  buildReleaseApk yingyongbao http://www.baidu3.com
}
​
buildAndroid
​
​
```

