# Package

version       = "0.1.0"
author        = "Zumi + TarnishedFables"
description   = "Strife 2024"
license       = "MIT"
srcDir        = "src"
bin           = @["strife"]


# Dependencies

requires "nim >= 2.0.2"
requires "naylib"
requires "results"
requires "chronicles"
requires "docopt"

import std/[os, sugar]

task apk, "Build an Android application":
  # This… is stupidly difficult for no reason at all
  # Requires: Java, Android SDK, Android Build Tools, Android NDK
  
  # Environment variables:
  # $ANDROID_BUILD_TOOLS = ~/android/sdk/build-tools/<version>
  # $ANDROID_SDK = ~/android/sdk

  const
  # --- Configurables ---
    # Where the java library is at
    javaHome = "/usr/lib64/jvm/java"

    # The Java package path
    pkgPath = "/org/zumi/strife30"

    # What to name the APK file
    apkName = "strife"

    # Keystore stuff, fill in your own
    keystoreFile = "/home/zumi/android_tools/zumi.keystore"
    storePass = "android"
    keyPass = "android"
    keyAlias = "testKey"
    
    # Which API version to target?
    apiVersion = 23

  # --- Synthesized ---
    bTools = getEnv("ANDROID_BUILD_TOOLS")
    bPlatform = getEnv("ANDROID_SDK") & "/platforms/android-" & $apiVersion
    androidPlatJar = bPlatform & "/android.jar"
    thisJavaSrc = "android/src"
    thisJavaObj = "android/obj"
    thisPkgSrc = thisJavaSrc & pkgPath
    thisPkgObj = thisJavaObj & pkgPath
  
  # --- Helper functions ---
  type
    AndroidArch = enum
      Arm
      Arm64
      I386
      Amd64
  
  proc arch(a: AndroidArch): string =
    case a
    of Arm: "armeabi-v7a"
    of Arm64: "arm64-v8a"
    of I386: "x86"
    of Amd64: "x86_64"
  
  proc cpu(a: AndroidArch): string =
    case a
    of Arm: "arm"
    of Arm64: "arm64"
    of I386: "i386"
    of Amd64: "amd64"
  
  # --- Start of Build Script ---
  # See also config.nims

  # 1. Compile the Everything™
  #    for Every Possible Target™
  for target in AndroidArch:
    selfExec([
      "c",
      "-d:android",
      "-d:release",
      "-d:AndroidAPI=" & $apiVersion,
      "--cpu:" & target.cpu,
      "-o:android/lib/" & target.arch & "/libmain.so",
      "src/strife"
    ].join(" "))

  # 2. Generate the resource ID code
  exec([
    bTools & "/aapt",
    "package",
    "-f", # overwrite existing
    "-m", # make package directory
    "-J", thisJavaSrc, # in here
    "-S", "android/res", # where the res files are
    "-M", "android/AndroidManifest.xml", # use manifest
    "-I", androidPlatJar # consider the platform resources
  ].join(" "))

  # 3. Generate the Java classes
  exec([
    javaHome & "/bin/javac",
    "-verbose",
    "--source", "11",
    "--target", "11",
    "-d", "android/obj", # generated .class files here
    # Consider the java root thingy
    "--system", javaHome,
    # Consider both the platform and our files
    "--class-path", [
      androidPlatJar, "android/obj"
    ].join(when defined(windows): ";" else: ":"),
    # Point to our files
    "--source-path", "android/src",
    # Compile our Android stuff
    thisPkgSrc & "/R.java",
    thisPkgSrc & "/NativeLoader.java"
  ].join(" "))

  # 4a. Get our objects
  let classes = collect:
    for f in listFiles(thisPkgObj):
      if f.endsWith(".class"):
        f.quoteShell()
  
  # 4b. …and make a classes.dex out of them
  exec([
    bTools & "/d8",
    "--release",
    "--output", "android/bin",
    classes.join(" "),
    "--lib", androidPlatJar,
  ].join(" "))

  # 5. Make a raw unaligned APK
  exec([
    bTools & "/aapt",
    "package",
    "-f", # overwrite existing
    "-M", "android/AndroidManifest.xml", # use manifest
    "-S", "android/res", # where the Android res files are
    "-A", "android/assets", # where MY res files are
    "-I", androidPlatJar, # consider the platform resources
    "-F", "android/" & apkName & ".unaligned.apk",
    "android/bin" # from here
  ].join(" "))

  # 6. Add the Everything™
  #    Done in `android` to make the path `./lib/arm…`
  #    and not `./android/lib/arm…`
  withDir("android"):
    for target in AndroidArch:
      exec([
        bTools & "/aapt",
        "add",
        apkName & ".unaligned.apk",
        "lib/" & target.arch & "/libmain.so"
      ].join(" "))

  # 7. Make aligned APK
  exec([
    bTools & "/zipalign",
    "-p",
    "-f", "4",
    "android/" & apkName & ".unaligned.apk",
    "android/" & apkName & ".aligned.apk"
  ].join(" "))

  # 8. Make final, signed APK
  exec([
    bTools & "/apksigner",
    "sign",
    "--ks", keystoreFile,
    "--ks-pass", "pass:" & storePass,
    "--key-pass", "pass:" & keyPass,
    "--out", apkName & ".apk",
    "--ks-key-alias", keyAlias,
    "android/" & apkName & ".aligned.apk"
  ].join(" "))
