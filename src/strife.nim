from raylib as rl import nil
import results
import std/random
import chronicles as log
from std/math import nil
import ./types
import ./utils
import ./game
import ./indices
import docopt
import std/strutils

const
  ## Size of the "fantasy console"
  game_canvas_size = (width: 500, height: 400)

  ## Size of the actual OS window
  init_window_size =
    when defined(emscripten):
      (
        width: game_canvas_size.width.float * 1,
        height: game_canvas_size.height.float * 1,
      )
    elif defined(mobileUI):
      (
        width: (game_canvas_size.width.float * 2) + 500,
        height: game_canvas_size.height.float * 2,
      )
    else:
      (
        width: game_canvas_size.width.float * 2,
        height: game_canvas_size.height.float * 2,
      )

  ## How often to run the "garbage collector"
  my_gc_interval = 30

## Main program
proc main(fps: int): Result[void, string] {.raises: [].} =
  var
    music: rl.Music
    music_is_init: bool = false
    gsr = GameStateRef(camera: rl.Camera2D(zoom: 1.0))
    garbage_collected = false
    last_sec = 0

  randomize()

  when not defined(emscripten) and not defined(android):
    rl.set_trace_log_callback(my_log)

  ## Initialize the OS window
  try:
    rl.init_window(
      init_window_size.width.int32, init_window_size.height.int32, "HB: Strife 2024"
    )
    rl.set_window_min_size(game_canvas_size.width.int32, game_canvas_size.height.int32)
    rl.set_window_state(
      when defined(emscripten):
        rl.flags(rl.VsyncHint, rl.WindowAlwaysRun)
      else:
        rl.flags(rl.VsyncHint, rl.WindowResizable, rl.WindowAlwaysRun)
    )
  except rl.RaylibError:
    return err("can't initialize window")
  defer:
    rl.close_window()

  ## Initialize the game canvas
  try:
    gsr.canvas = rl.load_render_texture(
      game_canvas_size.width.int32, game_canvas_size.height.int32
    )
    rl.set_texture_filter(gsr.canvas.texture, rl.Point)
  except rl.RaylibError:
    return err("can't initialize game canvas")

  ## Initialize the sound device
  rl.init_audio_device()
  defer:
    rl.close_audio_device()

  ## Run the music
  try:
    music = rl.load_music_stream("res/msc_showtime.ogg")
    rl.play_music_stream(music)
    music_is_init = true
  except rl.RaylibError:
    discard

  ## Initial state of the game
  ## Camera was initialized much earlier (can't be init here, for some reason)
  gsr.objects =
    @[
      GameObjectRef(pos: rl.Vector2(x: 30.0, y: 40.0), kind: Player),
      GameObjectRef(
        pos: rl.Vector2(x: game_canvas_size.width.float - 30.0, y: 40.0), kind: Enemy
      ),
    ]

  ## Load the soundboard. I set it up like this because I'm using an enum to access
  ## the sounds, and then I can let the compiler check it for me.
  ## Yeah the sounds are all preloaded basically.
  for i in 0 .. SoundboardIndex.high.ord:
    let new_sound_type = cast[SoundboardIndex](i)
    try:
      case new_sound_type
      of SlapSFX:
        gsr.soundboard.add(rl.load_sound("res/snd_slap.wav"))
      of ShootSFX:
        gsr.soundboard.add(rl.load_sound("res/snd_shoot.wav"))
      of ImpactSFX:
        gsr.soundboard.add(rl.load_sound("res/snd_impact.wav"))
    except rl.RaylibError as e:
      log.error("Cannot load sound", msg = e.msg)
      gsr.soundboard.add(rl.Sound())

  ## Same here with the textures.
  for i in 0 .. TextureIndex.high.ord:
    let new_texture_type = cast[TextureIndex](i)
    try:
      case new_texture_type
      of HariakimaSheet:
        gsr.textures.add(
          rl.load_texture_from_image(rl.load_image("res/spr_hariakima.png"))
        )
      of DonutGuySheet:
        gsr.textures.add(
          rl.load_texture_from_image(rl.load_image("res/spr_donut_guy.png"))
        )
      of HariaBullet:
        gsr.textures.add(
          rl.load_texture_from_image(rl.load_image("res/spr_bullet.png"))
        )
      of DonutBullet:
        gsr.textures.add(rl.load_texture_from_image(rl.load_image("res/spr_donut.png")))
      of BackgroundTexture:
        gsr.textures.add(rl.load_texture_from_image(rl.load_image("res/bg_donut.png")))
      of HariaFlinch:
        gsr.textures.add(
          rl.load_texture_from_image(rl.load_image("res/spr_hariakima_flinch.png"))
        )
      of DonutGuyFlinch:
        gsr.textures.add(
          rl.load_texture_from_image(rl.load_image("res/spr_donut_guy_flinch.png"))
        )
      of HariaDead:
        gsr.textures.add(
          rl.load_texture_from_image(rl.load_image("res/spr_hariakima_ded.png"))
        )
      of DonutGuyDead:
        gsr.textures.add(
          rl.load_texture_from_image(rl.load_image("res/spr_donut_guy_ded.png"))
        )
      of HariaAttack:
        gsr.textures.add(
          rl.load_texture_from_image(rl.load_image("res/spr_hariakima_attack.png"))
        )
    except rl.RaylibError as e:
      log.error("Cannot load texture", msg = e.msg)
      gsr.textures.add(rl.Texture())

  ## Init all the objects
  for obj in gsr.objects.mitems:
    try:
      obj.init(gsr)
    except Exception as e:
      log.error("Cannot init object", msg = e.msg)

  if fps >= 24:
    rl.set_target_fps(fps.int32)

  while not rl.window_should_close():
    ## A custom object garbage collecting routine. Yes. On top of Nim's existing garbage
    ## collection for everything.
    ## This basically moves all the objects to a new list, and then assigns the game
    ## state to this new list.
    block:
      let t = math.split_decimal(rl.get_time())
      if t.intpart.int != last_sec:
        last_sec = t.intpart.int
        ## So the GC can still run
        garbage_collected = false
      if t.intpart.int mod my_gc_interval == 0:
        if not garbage_collected:
          log.trace("number of objects in list", n = gsr.objects.len)
          var new_thing: seq[GameObjectRef]
          for i in gsr.objects:
            if i != nil:
              new_thing.add(i)
          gsr.objects = new_thing
          log.trace("GC done, number of actual objects", n = gsr.objects.len)
          ## GC shouldn't run more than once per period
          garbage_collected = true

    ## Allow the players to move
    ## S T R I F E !
    if last_sec == 3:
      gsr.allow_move = true

    ## Run the music
    if music_is_init:
      rl.update_music_stream(music)

    ## Do object management. In order to reduce the number of sequence resizes, object
    ## deletion isn't taking the object out of the list, but rather performing object
    ## deinit routines and then assigning a NULL pointer in its place, where it'll
    ## stay that way until garbage collection.
    block:
      for objnum in 0 ..< len(gsr.objects):
        var obj = gsr.objects[objnum]
        if obj == nil:
          continue
        try:
          obj.update(gsr)
        except Exception as e:
          log.error("Error updating object", msg = e.msg)
        if obj.deletion_pending:
          try:
            obj.uninit(gsr)
            gsr.objects[objnum] = nil
          except Exception as e:
            log.error("Error deleting object", msg = e.msg)

    ## Do screen shakey effects
    block:
      gsr.shake -= 50.0 * gsr.delta
      if gsr.shake < 0:
        gsr.shake = 0
      gsr.camera.offset.x = rand(gsr.shake).float32
      gsr.camera.offset.y = rand(gsr.shake).float32

    ## Draw game frames to canvas
    rl.texture_mode(gsr.canvas):
      gsr.delta = rl.get_frame_time()
      rl.clear_background(rl.RayWhite)
      rl.mode_2d(gsr.camera):
        ## Fancy background first
        try:
          gsr.canvas.draw_bg(gsr.textures[BackgroundTexture.ord], gsr)
        except Exception as e:
          log.error("Error drawing BG", msg = e.msg)
        ## And then the objects on top
        for obj in gsr.objects:
          if obj == nil:
            continue
          try:
            obj.draw(gsr)
          except Exception as e:
            log.error("Error drawing object", msg = e.msg)

    ## Draw scaled canvas to the main screen
    rl.drawing:
      let prop_game_width =
        game_canvas_size.width.float *
        (rl.get_screen_height().float / game_canvas_size.height.float)
      gsr.delta = rl.get_frame_time()
      rl.clear_background(rl.Black)
      rl.draw_texture(
        gsr.canvas.texture,
        rl.Rectangle(
          x: 0.0,
          y: 0.0,
          width: gsr.canvas.texture.width.float,
          height: -gsr.canvas.texture.height.float,
        ),
        rl.Rectangle(
          x: (rl.get_screen_width().float - prop_game_width) / 2,
          y: 0.0,
          width: prop_game_width,
          height: rl.get_screen_height().float,
        ),
        rl.Vector2(x: 0.0, y: 0.0),
        0.0,
        rl.White,
      )
      rl.draw_rectangle(0, 0, 90, 20, rl.Black)

      ## Draw controls on top
      when defined(mobileUI):
        ## TODO: Hardcoded rectangle for jump button
        rl.draw_rectangle(
          rl.get_screen_width() - 250, rl.get_screen_height() - 500, 250, 250, rl.Green
        )
        ## TODO: Hardcoded rectangle for shoot button
        rl.draw_rectangle(
          rl.get_screen_width() - 250, rl.get_screen_height() - 250, 250, 250, rl.Red
        )
      rl.draw_fps(0, 0)
  ## Done
  return ok()

when is_main_module:
  let args = """
Hariakima Buchmesse: Strife! 2024 version

Programmed by Zumi
Remake of TarnishedFables's 2014 & 2015 versions
Funny Homestuck

Usage:
  strife [--fps=<fps>]
  strife (-h | --help)
  strife --version

If target FPS is not set, the game will run according
to your monitor's refresh rate. Minimum FPS is 30.
""".docopt(
    version = "HB: Strife! 3.0"
  )
  let main_result = main(
    try:
      parse_int($args["--fps"])
    except Exception:
      0
  )
  if main_result.is_ok():
    quit(0)
  else:
    debug_echo(main_result.error)
    quit(1)
