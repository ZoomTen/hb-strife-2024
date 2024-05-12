## Let's be a little fancier than just using raw numbers
## for everything…
type
  SoundboardIndex* = enum
    SlapSFX = 0
    ShootSFX
    ImpactSFX

  TextureIndex* = enum
    HariakimaSheet = 0
    DonutGuySheet
    HariaBullet
    DonutBullet
    BackgroundTexture
    HariaFlinch
    DonutGuyFlinch
    DonutGuyDead
    HariaDead
    HariaAttack

  ControlIndex* = enum
    MovePlayerLeft = 0
    MovePlayerRight
    PlayerJump
    PlayerShoot
