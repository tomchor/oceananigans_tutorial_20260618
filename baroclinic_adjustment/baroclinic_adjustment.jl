using Oceananigans
using Oceananigans.Units
using NCDatasets
using Printf
using Random

# =============================================================================
# Baroclinic adjustment — equilibration of a baroclinically unstable front
#
# A periodic-in-x channel on a β-plane centered at 45°S. An initially
# zonally-uniform meridional buoyancy front sits on top of a stable vertical
# stratification. The front is baroclinically unstable: it spins down by
# generating mesoscale eddies that flatten the isopycnals — the canonical
# eddy-genesis mechanism in the mid-latitude ocean.
#
# Hydrostatic free-surface model.
# =============================================================================

Random.seed!(8675309)   # reproducible noise

# --- Physical parameters ---
Lx = 1000kilometers      # zonal extent
Ly = 1000kilometers      # meridional extent
Lz = 1kilometer          # depth
N² = 1e-5                # s⁻², background buoyancy frequency squared
M² = 1e-7                # s⁻², horizontal buoyancy gradient at the front
Δy = 100kilometers       # width of the front
Δb = Δy * M²             # buoyancy jump across the front
ϵb = 1e-2 * Δb           # initial noise amplitude (seeds the instability)

# --- Grid ---
Nx, Ny, Nz = 48, 48, 8

grid = RectilinearGrid(size     = (Nx, Ny, Nz),
                       x        = (0, Lx),
                       y        = (-Ly/2, Ly/2),
                       z        = (-Lz, 0),
                       topology = (Periodic, Bounded, Bounded))

# --- Model ---
model = HydrostaticFreeSurfaceModel(grid;
                                    coriolis           = BetaPlane(latitude = -45),
                                    buoyancy           = BuoyancyTracer(),
                                    tracers            = :b,
                                    momentum_advection = WENO(),
                                    tracer_advection   = WENO())

# --- Initial conditions ---
# Linear ramp from 0 to 1 between -Δy/2 and +Δy/2
ramp(y, Δy) = min(max(0, y/Δy + 1/2), 1)

# Stable stratification + meridional front + small noise
bᵢ(x, y, z) = N² * z + Δb * ramp(y, Δy) + ϵb * randn()
set!(model, b=bᵢ)

# --- Simulation ---
simulation = Simulation(model; Δt=20minutes, stop_time=20days)
conjure_time_step_wizard!(simulation, IterationInterval(20), cfl=0.2, max_Δt=20minutes)

wall_clock = Ref(time_ns())
function progress(sim)
    u, v, w = sim.model.velocities
    elapsed = prettytime(1e-9 * (time_ns() - wall_clock[]))
    @info @sprintf("t = %s, Δt = %s, max|u| = %.2e m/s, max|v| = %.2e m/s, wall: %s",
                   prettytime(time(sim)), prettytime(sim.Δt),
                   maximum(abs, u), maximum(abs, v), elapsed)
    wall_clock[] = time_ns()
end
add_callback!(simulation, progress, IterationInterval(100))

# --- Output ---
u, v, w = model.velocities
b = model.tracers.b
ζ = ∂x(v) - ∂y(u)              # vertical vorticity
B = Average(b, dims=1)         # zonal-mean buoyancy
U = Average(u, dims=1)         # zonal-mean zonal velocity
V = Average(v, dims=1)         # zonal-mean meridional velocity

# Surface (z = top) snapshot: eddies and vorticity
simulation.output_writers[:surface] = NetCDFWriter(model, (; b, ζ);
    schedule           = TimeInterval(12hours),
    filename           = "baroclinic_adjustment_surface.nc",
    indices            = (:, :, grid.Nz),
    overwrite_existing = true)

# Zonal-mean (y, z) view: residual overturning + jets
simulation.output_writers[:zonal] = NetCDFWriter(model, (; b=B, u=U, v=V);
    schedule           = TimeInterval(12hours),
    filename           = "baroclinic_adjustment_zonal.nc",
    overwrite_existing = true)

run!(simulation)
