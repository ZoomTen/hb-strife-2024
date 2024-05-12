## Building for Android

1. [Get the SDK](https://developer.android.com/studio) (scroll down to **Command line tools only**). Extract the SDK to somewhere like `~/android/sdk`. Set `ANDROID_SDK` to this directory.
2.
```
pushd $ANDROID_SDK/bin
./sdkmanager --update --sdk_root=$ANDROID_SDK
./sdkmanager --install "build-tools;34.0.0" --sdk_root=$ANDROID_SDK
./sdkmanager --install "platform-tools" --sdk_root=$ANDROID_SDK
./sdkmanager --install "platforms;android-23" --sdk_root=$ANDROID_SDK
popd
```
3. [Get the NDK](https://developer.android.com/ndk/downloads/). Extract the NDK to somewhere like `~/android/ndk`. Set `ANDROID_NDK` to this directory.
4. Set `ANDROID_BUILD_TOOLS` to the build tools directory, in this case `$ANDROID_SDK/build-tools/34.0.0`.
5. Check `config.nims`, in particular `tcDir`.
6. Generate a keystore using `keytool`, which should come with Java I think:
```
keytool -genkeypair -validity 1000 \
-dname "CN=Android,O=Android,C=US" \
-keystore Android.keystore \
-storepass 'android' \
-keypass 'android' \
-alias testKey \
-keyalg RSA
```
7. Check `strife30.nimble`. Set `keystoreFile`, `storePass`, `keyPass`, `keyAlias` accordingly.
8. Run `nimble apk`.