from raylib as rl import nil
import chronicles as log

proc my_log*(mtype: rl.TraceLogLevel, msg: string) =
  log.log_scope:
    topics = "raylib"
  case mtype
  of rl.Info:
    log.info("", msg = msg)
  of rl.Error:
    log.error("", msg = msg)
  of rl.Warning:
    log.warn("", msg = msg)
  of rl.Debug:
    log.debug("", msg = msg)
  else:
    discard
