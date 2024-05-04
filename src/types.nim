from raylib as rl import nil

type
  ObjectKind* = enum
    Player
    Bullet
    Enemy
    LmaoDed

  EnemyMovement* = enum
    MoveLeft
    MoveRight
    Jump
    Shoot
    DoNothing

  HitboxAnchor* = enum
    LowerLeft
    LowerRight
    UpperLeft
    UpperRight
    Center

  EnemyAiState* = tuple[state: EnemyMovement, seconds: float]

  GameObjectRef* = ref object
    pos*: rl.Vector2 = rl.Vector2(x: 0.0, y: 0.0)
    width*: float
    height*: float
    anchor*: HitboxAnchor
    deletion_pending*: bool = false
    case kind*: ObjectKind
    of Player, Enemy:
      xkickback*: float = 0.0
      attack_anim_timeout*: float = 0.0
      flinch_timeout*: float = 0.0
      shoot_timeout*: float = 0.0
      hp* = 100
    of LmaoDed:
      original_guy*: ObjectKind
    of Bullet:
      shot_from*: ObjectKind
      hit_who*: GameObjectRef
    # Used by Player, Enemy, LmaoDed
    ymom*: float = 0.0
    # the following should only be accessible if kind == Enemy
    # this is a current limitation of the current case-objects in Nim
    ai_state*: EnemyAiState
    enemy_already_shot_or_jump*: bool = false

  GameStateRef* = ref object
    objects*: seq[GameObjectRef]
    camera*: rl.Camera2D
    delta*: float
    shake*: float
    soundboard*: seq[rl.Sound]
    textures*: seq[rl.Texture2D]
    allow_move*: bool = false
    canvas*: rl.RenderTexture2D
