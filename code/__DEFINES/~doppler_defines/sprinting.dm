/// The maximum amount of sprint energy a mob can store.
#define SPRINT_ENERGY_MAXIMUM 100
/// The minimum amount of sprint energy a mob can store.
#define SPRINT_ENERGY_MINIMUM 0
/// The amount of sprint energy drained per second while moving.
#define SPRINT_ENERGY_DRAIN_PER_SECOND 5
/// The additional amount of sprint energy drained for each tile moved during a processing tick.
#define SPRINT_ENERGY_DRAIN_PER_TILE 0.3
/// The delay before sprint energy begins regenerating.
#define SPRINT_ENERGY_REGEN_DELAY 4 SECONDS
/// The amount of sprint energy restored per regeneration tick.
#define SPRINT_ENERGY_REGEN_AMOUNT 6.67
/// The interval between sprint-energy regeneration ticks.
#define SPRINT_ENERGY_REGEN_INTERVAL 1 SECONDS

/// The maximum amount of movement momentum a mob can store.
#define SPRINT_MOMENTUM_MAXIMUM 100
/// The minimum amount of movement momentum a mob can store.
#define SPRINT_MOMENTUM_MINIMUM 0
/// The base amount of momentum gained from moving in the current direction.
#define SPRINT_MOMENTUM_GAIN_BASE 10
/// The fraction of current momentum gained from moving in the current direction.
#define SPRINT_MOMENTUM_GAIN_CURRENT_MULTIPLIER 0.2
/// The maximum retained momentum after a 45-degree turn.
#define SPRINT_MOMENTUM_DIAGONAL_TURN_THRESHOLD 0.5
/// The maximum retained momentum after a 90-degree turn.
#define SPRINT_MOMENTUM_RIGHT_ANGLE_TURN_THRESHOLD 0.25
/// The pixel height of the visible momentum bar.
#define SPRINT_MOMENTUM_BAR_HEIGHT 30
