import ./types
import ./indices
import std/random
import chronicles as log
from raylib as rl import nil

proc pick_random_enemy_state*(): EnemyAiState =
  let random_movement =
    cast[EnemyMovement](rand(EnemyMovement.low.ord .. EnemyMovement.high.ord))
  return (
    state: random_movement,
    seconds: (
      case random_movement
      of Jump, Shoot:
        0.05
      else:
        rand(0.02 .. 0.08)
    ),
  )

proc init*(obj: GameObjectRef, state: var GameStateRef): void =
  case obj.kind
  of Player:
    obj.width = state.textures[HariakimaSheet.ord].width.float
    obj.height = state.textures[HariakimaSheet.ord].height.float
    obj.anchor = LowerLeft
  of Enemy:
    obj.width = state.textures[DonutGuySheet.ord].width.float
    obj.height = state.textures[DonutGuySheet.ord].height.float
    obj.anchor = LowerRight
    obj.ai_state = pick_random_enemy_state()
    log.trace("init random enemy state", state = obj.ai_state)
  of Bullet:
    obj.anchor = Center
    case obj.shot_from
    of Player:
      obj.width = state.textures[HariaBullet.ord].width.float
      obj.height = state.textures[HariaBullet.ord].height.float
    of Enemy:
      obj.width = state.textures[DonutBullet.ord].width.float
      obj.height = state.textures[DonutBullet.ord].height.float
    else:
      discard
    if state.soundboard.len >= 2:
      case obj.shot_from
      of Player:
        rl.set_sound_pan(state.soundboard[ShootSFX.ord], 0.8)
      of Enemy:
        rl.set_sound_pan(state.soundboard[ShootSFX.ord], 0.2)
      else:
        discard
      rl.play_sound(state.soundboard[ShootSFX.ord])
  of LmaoDed:
    obj.anchor = (
      case obj.original_guy
      of Player:
        LowerLeft
      of Enemy:
        LowerRight
      else: ## should be unreachable
        Center
    )
    obj.ymom = -1_800

proc update*(obj: GameObjectRef, state: var GameStateRef): void =
  const
    floor_height = 350
    gravity = 3000.0
  case obj.kind
  of Player, Enemy:
    const move_speed = 300.0
    var on_ground = false

    ## Run gravity
    if not on_ground:
      obj.ymom += gravity * state.delta

    ## Apply Y momentum
    if obj.pos.y < floor_height:
      obj.pos.y += obj.ymom * state.delta
    if obj.pos.y > floor_height:
      ## collide with the ground
      obj.pos.y = floor_height
      obj.ymom = 0.0
      on_ground = true

    ## Run kickback, which is like X momentum / jump
    ## but it's triggered when receiving a shot
    if obj.xkickback <= 0:
      obj.xkickback = 0
    else:
      obj.xkickback -= 200.0 * state.delta

    ## Apply X momentum (kickback)
    if obj.kind == Player and obj.pos.x >= 10.0:
      obj.pos.x -= obj.xkickback * state.delta
    elif obj.kind == Enemy and obj.pos.x <= state.canvas.texture.width.float - 10.0:
      obj.pos.x += obj.xkickback * state.delta

    ## Some timeouts...
    if obj.flinch_timeout <= 0:
      obj.flinch_timeout = 0
    else:
      obj.flinch_timeout -= state.delta

    if obj.attack_anim_timeout <= 0:
      obj.attack_anim_timeout = 0
    else:
      obj.attack_anim_timeout -= state.delta

    ## Add some cooldown time between shots
    if obj.shoot_timeout <= 0:
      obj.shoot_timeout = 0
    else:
      obj.shoot_timeout -= state.delta

    ## Check if the other guy exists
    var opponent_exists = false
    for i in state.objects:
      if i != nil:
        if obj.kind == Enemy and i.kind == Player:
          opponent_exists = true
          break
        elif obj.kind == Player and i.kind == Enemy:
          opponent_exists = true
          break

    ## Player or Enemy cannot move when the game is in the
    ## intro phase, they're flinching, or if the opponent doesn't exist anymore
    if not state.allow_move or not opponent_exists or obj.flinch_timeout > 0.0:
      return

    ## Do jump
    obj.pos.y += (
      const jump_momentum = -800
      if obj.pos.y == floor_height:
        case obj.kind
        of Player:
          if (
            ## Keyboard
            rl.is_key_pressed(rl.Up) or (
              ## Gamepad
              rl.is_gamepad_available(0) and
              rl.get_gamepad_button_pressed() == rl.RightTrigger1
            )
          ):
            obj.ymom = jump_momentum
            on_ground = false
            ## Jump!
            obj.ymom * state.delta
          else:
            0.0
        of Enemy:
          if obj.ai_state.state == Jump and not obj.enemy_already_shot_or_jump:
            obj.ymom = jump_momentum
            on_ground = false
            # Also simulate "key pressed"
            obj.enemy_already_shot_or_jump = true
            ## Jump!
            obj.ymom * state.delta
          else:
            0.0
        else: # Shouldn't be reached
          0.0
      else: # Not on the floor
        0.0
    )

    ## Move object
    obj.pos.x += (
      case obj.kind
      of Player:
        if (
          ## Keyboard
          rl.is_key_down(rl.Left) or (
            ## Gamepad
            rl.is_gamepad_available(0) and (
              rl.get_gamepad_axis_movement(0, rl.LeftX) <= -0.5 or
              rl.get_gamepad_button_pressed() == rl.LeftFaceLeft
            )
          )
        ) and obj.pos.x >= 10.0:
          -move_speed * state.delta
        elif (
          ## Keyboard
          rl.is_key_down(rl.Right) or (
            ## Gamepad
            rl.is_gamepad_available(0) and (
              rl.get_gamepad_axis_movement(0, rl.LeftX) >= 0.5 or
              rl.get_gamepad_button_pressed() == rl.LeftFaceRight
            )
          )
        ) and obj.pos.x <= (state.canvas.texture.width / 2) - 80.0:
          move_speed * state.delta
        else:
          0.0
      of Enemy:
        if obj.ai_state.state == MoveLeft and
            obj.pos.x >= (state.canvas.texture.width / 2) + 80.0:
          -move_speed * state.delta
        elif obj.ai_state.state == MoveRight and
            obj.pos.x <= state.canvas.texture.width.float - 10.0:
          move_speed * state.delta
        else:
          0.0
      else: # Shouldn't be reached
        0.0
    )

    ## Shoot something
    if (
      obj.kind == Player and (
        ## Keyboard
        rl.is_key_pressed(rl.KeyboardKey.Z) or (
          ## Gamepad
          rl.is_gamepad_available(0) and
          rl.get_gamepad_button_pressed() == rl.RightFaceRight
        )
      ) and obj.shoot_timeout == 0
    ) or (
      obj.kind == Enemy and obj.ai_state.state == Shoot and
      not obj.enemy_already_shot_or_jump and obj.shoot_timeout == 0
    ):
      state.objects.add(
        GameObjectRef(
          kind: Bullet,
          shot_from: obj.kind,
          pos: rl.Vector2(
            x: (
              case obj.kind
              of Player:
                obj.pos.x + 80.0
              of Enemy:
                obj.pos.x - 80.0
              else: # Shouldn't be reached
                obj.pos.x
            ),
            y: obj.pos.y - 80.0,
          ),
        )
      )
      ## Refractory time until Player or Enemy can shoot again
      obj.shoot_timeout = 0.4
      ## Simulate "key pressed"
      if obj.kind == Enemy:
        obj.enemy_already_shot_or_jump = true
      ## Init newly-created bullet
      state.objects[^1].init(state)
      ## Do attack animation
      obj.attack_anim_timeout = 0.28

    ## Run the AI
    if obj.kind == Enemy:
      if obj.ai_state.seconds < 0:
        obj.ai_state = pick_random_enemy_state()
        obj.enemy_already_shot_or_jump = false
        # log.trace(
        #   "update AI state", state = obj.ai_state.state, seconds = obj.ai_state.seconds
        # )
      else:
        obj.ai_state.seconds -= state.delta
  of Bullet:
    const bullet_speed = 1200.0
    let scr_pos =
      rl.get_world_to_screen_2d(rl.Vector2(x: obj.pos.x, y: obj.pos.y), state.camera)

    var colliding = false
    for other_obj in state.objects:
      if other_obj != nil and other_obj.kind in [Player, Enemy]:
        # Test for collision
        if (
          let initial_collision_check = rl.checkCollisionRecs(
            # This object
            rl.Rectangle(
              x: (
                case obj.anchor
                of LowerLeft, UpperLeft:
                  obj.pos.x
                of LowerRight, UpperRight:
                  obj.pos.x - obj.width
                of Center:
                  obj.pos.x - (obj.width / 2)
              ),
              y: (
                case obj.anchor
                of LowerLeft, LowerRight:
                  obj.pos.y - obj.height
                of UpperLeft, UpperRight:
                  obj.pos.y
                of Center:
                  obj.pos.y - (obj.height / 2)
              ),
              width: obj.width,
              height: obj.height,
            ),
            # Other object
            rl.Rectangle(
              x: (
                case other_obj.anchor
                of LowerLeft, UpperLeft:
                  other_obj.pos.x
                of LowerRight, UpperRight:
                  other_obj.pos.x - other_obj.width
                of Center:
                  other_obj.pos.x - (other_obj.width / 2)
              ),
              y: (
                case other_obj.anchor
                of LowerLeft, LowerRight:
                  other_obj.pos.y - other_obj.height
                of UpperLeft, UpperRight:
                  other_obj.pos.y
                of Center:
                  other_obj.pos.y - (other_obj.height / 2)
              ),
              width: other_obj.width,
              height: other_obj.height,
            ),
          )

          ## This object can only collide with Players and Enemies,
          ## but one can only collide with (and harm) the other!
          initial_collision_check and (
            case obj.shot_from
            of Player:
              other_obj.kind == Enemy
            of Enemy:
              other_obj.kind == Player
            else:
              false
          )
        ):
          obj.hit_who = other_obj
          obj.deletion_pending = true
          break

    if scr_pos.x < rl.get_render_width().float32 and scr_pos.x > 0 and not colliding:
      case obj.shot_from
      of Player:
        obj.pos.x += bullet_speed * state.delta
      of Enemy:
        obj.pos.x -= bullet_speed * state.delta
      else:
        discard
    else:
      obj.deletion_pending = true
  of LmaoDed:
    var on_ground = false

    ## Run gravity
    if not on_ground:
      obj.ymom += gravity * state.delta

    ## Apply Y momentum
    if obj.pos.y < floor_height:
      obj.pos.y += obj.ymom * state.delta
    if obj.pos.y > floor_height:
      ## collide with the ground
      obj.pos.y = floor_height
      obj.ymom = 0.0
      on_ground = true

func draw*(obj: GameObjectRef, state: var GameStateRef): void =
  let texture = (
    case obj.kind
    of Player:
      if obj.flinch_timeout > 0:
        state.textures[HariaFlinch.ord]
      elif obj.attack_anim_timeout > 0:
        state.textures[HariaAttack.ord]
      else:
        state.textures[HariakimaSheet.ord]
    of Enemy:
      if obj.flinch_timeout > 0:
        state.textures[DonutGuyFlinch.ord]
      else:
        state.textures[DonutGuySheet.ord]
    of Bullet:
      case obj.shot_from
      of Player:
        state.textures[HariaBullet.ord]
      of Enemy:
        state.textures[DonutBullet.ord]
      else: ## Should never reach this point
        state.textures[0]
    of LmaoDed:
      case obj.original_guy
      of Player:
        state.textures[HariaDead.ord]
      of Enemy:
        state.textures[DonutGuyDead.ord]
      else: ## Should never reach this point
        state.textures[0]
  )
  # block: ## DEBUG DEBUG DEBUG 
  #   rl.draw_rectangle(
  #     (
  #       case obj.anchor
  #       of LowerLeft, UpperLeft:
  #         obj.pos.x.int32
  #       of LowerRight, UpperRight:
  #         obj.pos.x.int32 - obj.width.int32
  #       of Center:
  #         obj.pos.x.int32 - (obj.width / 2).int32
  #     ),
  #     (
  #       case obj.anchor
  #       of LowerLeft, LowerRight:
  #         obj.pos.y.int32 - obj.height.int32
  #       of UpperLeft, UpperRight:
  #         obj.pos.y.int32
  #       of Center:
  #         obj.pos.y.int32 - (obj.height / 2).int32
  #     ),
  #     texture.width,
  #     texture.height,
  #     rl.White,
  #   )
  rl.draw_texture(
    texture,
    (
      case obj.anchor
      of LowerLeft, UpperLeft:
        obj.pos.x.int32
      of LowerRight, UpperRight:
        obj.pos.x.int32 - texture.width
      of Center:
        obj.pos.x.int32 - (texture.width / 2).int32
    ),
    (
      case obj.anchor
      of LowerLeft, LowerRight:
        obj.pos.y.int32 - texture.height
      of UpperLeft, UpperRight:
        obj.pos.y.int32
      of Center:
        obj.pos.y.int32 - (texture.height / 2).int32
    ),
    rl.White,
  )
  ## Show HP indicator
  if obj.kind in [Player, Enemy]:
    rl.draw_text(
      ($obj.hp).cstring,
      (
        if obj.kind == Player:
          obj.pos.x.int32
        else:
          obj.pos.x.int32 - texture.width.int32
      ) + 3,
      obj.pos.y.int32 - texture.height - 32 + 3,
      32,
      rl.Black,
    )
    rl.draw_text(
      ($obj.hp).cstring,
      (
        if obj.kind == Player:
          obj.pos.x.int32
        else:
          obj.pos.x.int32 - texture.width.int32
      ),
      obj.pos.y.int32 - texture.height - 32,
      32,
      rl.White,
    )
  # block: ## DEBUG DEBUG DEBUG 
  #   rl.draw_rectangle(obj.pos.x.int32 - 2, obj.pos.y.int32 - 2, 4, 4, rl.Red)

proc uninit*(obj: GameObjectRef, state: var GameStateRef): void =
  case obj.kind
  of Bullet:
    if obj.hit_who != nil:
      if obj.hit_who.kind == Player:
        state.shake = 10
      case obj.hit_who.kind
      of Player, Enemy:
        obj.hit_who.xkickback = 100.0
        obj.hit_who.flinch_timeout = 0.4
        obj.hit_who.attack_anim_timeout = 0.0
        obj.hit_who.hp -= 1
        if obj.hit_who.hp == 0:
          obj.hit_who.deletion_pending = true
          rl.play_sound(state.soundboard[ImpactSFX.ord])
          state.objects.add(GameObjectRef(kind: LmaoDed, pos: obj.hit_who.pos))
          state.objects[^1].pos.y -= 5.0 ## initiate the jump
          state.objects[^1].original_guy = obj.hit_who.kind
          state.objects[^1].init(state)
      else:
        discard
      if state.soundboard.len >= 1:
        case obj.hit_who.kind
        of Player:
          rl.set_sound_pan(state.soundboard[SlapSFX.ord], 0.8)
        of Enemy:
          rl.set_sound_pan(state.soundboard[SlapSFX.ord], 0.2)
        else:
          discard
        rl.play_sound(state.soundboard[SlapSFX.ord])
  else:
    discard

proc draw_bg*(
    canvas: rl.RenderTexture2D, texture: rl.Texture, state: var GameStateRef
): void =
  var x {.global.} = 0.0

  ## Cloud parallax 1
  rl.draw_texture(
    texture,
    rl.Rectangle(x: x, y: 0.0, width: texture.width.float, height: 56.0),
    rl.Rectangle(
      x: -10.0, y: -10.0, width: canvas.texture.width.float + 20.0, height: 56.0
    ),
    rl.Vector2(x: 0.0, y: 0.0),
    0.0,
    rl.White,
  )

  ## Cloud parallax 2
  rl.draw_texture(
    texture,
    rl.Rectangle(x: x / 2, y: 56.0, width: texture.width.float, height: 60.0),
    rl.Rectangle(
      x: -10.0, y: 56.0 - 10.0, width: canvas.texture.width.float + 20.0, height: 60.0
    ),
    rl.Vector2(x: 0.0, y: 0.0),
    0.0,
    rl.White,
  )

  ## The rest of the image
  rl.draw_texture(
    texture,
    rl.Rectangle(
      x: 0.0, y: 116.0, width: texture.width.float, height: texture.height.float - 116.0
    ),
    rl.Rectangle(
      x: -10.0,
      y: 116.0 - 10.0,
      width: canvas.texture.width.float + 20.0,
      height: texture.height.float - 116.0,
    ),
    rl.Vector2(x: 0.0, y: 0.0),
    0.0,
    rl.White,
  )
  x += 100.0 * state.delta
