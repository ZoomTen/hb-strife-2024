when defined(emscripten) or defined(android):
  switch("define", "chronicles_enabled=false")
else:
  switch("define", "chronicles_line_numbers=true")
  switch("define", "chronicles_log_level=TRACE")

when defined(emscripten):
  # This path will only run if -d:emscripten is passed to nim.
  switch("define", "GraphicsApiOpenGlEs2")

  switch("os", "linux")
  switch("cpu", "wasm32")
  switch("cc", "clang")

  when defined(windows):
    switch("clang.exe", "emcc.bat")
    switch("clang.linkerexe", "emcc.bat")
    switch("clang.cpp.exe", "emcc.bat")
    switch("clang.cpp.linkerexe", "emcc.bat")
  else:
    switch("clang.exe", "emcc")
    switch("clang.linkerexe", "emcc")
    switch("clang.cpp.exe", "emcc")
    switch("clang.cpp.linkerexe", "emcc")

  switch("mm", "orc")
  switch("threads", "off")
  switch("panics", "on")
  switch("define", "noSignalHandler")
  switch("passL", "-o docs/index.html --preload-file res --shell-file src/shell.html")

when defined(android):
  # I'm running x86_64 Linux
  # $ANDROID_NDK is usually ~/android/ndk
  const
    # toolchains
    tcDir = getEnv("ANDROID_NDK") & "/toolchains/llvm/prebuilt/linux-x86_64/"
    tcBin = tcDir & "/bin/"
    tcInclude = tcDir & "/sysroot/usr/include/"

  const AndroidAPI {.intdefine.} = 23

  switch("define", "AndroidNDK=" & getEnv("ANDROID_NDK"))
  switch("define", "GraphicsApiOpenGLES2")
  switch("define", "noSignalHandler")

  switch("panics", "on")

  switch("os", "android")
  switch("cc", "clang")

  const buildCpuName = (
    when hostCPU == "arm":
      "armv7a"
    elif hostCPU == "arm64":
      "aarch64"
    elif hostCPU == "i386":
      "i686"
    elif hostCPU == "amd64":
      "x86_64"
    else:
      "unknown"
  )

  const buildFlags = (
    when hostCPU == "arm":
      "-march=armv7-a -mfloat-abi=softfp -mfpu=vfpv3-d16"
    elif hostCPU == "arm64":
      "-march=armv8-a -mfix-cortex-a53-835769"
    elif hostCPU == "i386":
      "-march=i686"
    elif hostCPU == "amd64":
      "-march=x86-64"
    else:
      ""
  )

  switch("define", "androidApiVersion=" & $AndroidAPI)

  # Determine compilers
  switch(
    "clang.exe",
    tcBin & "/" & buildCpuName & "-linux-android" &
      (if hostCPU == "arm": "eabi" else: "") & $AndroidAPI & "-clang",
  )
  switch(
    "clang.linkerexe",
    tcBin & "/" & buildCpuName & "-linux-android" &
      (if hostCPU == "arm": "eabi" else: "") & $AndroidAPI & "-clang",
  )
  switch(
    "clang.cpp.exe",
    tcBin & "/" & buildCpuName & "-linux-android" &
      (if hostCPU == "arm": "eabi" else: "") & $AndroidAPI & "-clang++",
  )
  switch(
    "clang.cpp.linkerexe",
    tcBin & "/" & buildCpuName & "-linux-android" &
      (if hostCPU == "arm": "eabi" else: "") & $AndroidAPI & "-clang++",
  )

  switch("passC", "-I" & tcInclude & " " & buildFlags)

  # can't use --app:lib for this as raylib calls `main`
  switch("passL", "-shared")
