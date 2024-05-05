when defined(emscripten):
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
