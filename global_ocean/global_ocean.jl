using ClimaOcean
using Oceananigans
using Oceananigans.Units
using NCDatasets
using Dates: DateTime
using Downloads
using Printf

# =============================================================================
# Global ocean — a laptop-friendly version of ClimaOcean's
# `latitude_longitude_ocean_sea_ice.jl` example.
#
# Coupled ocean–atmosphere simulation on a coarse 4° lat-lon grid (90×38×20)
# spanning 75°S–75°N, initialized from ECCO and forced by repeat-year JRA55
# atmospheric reanalysis. Sea ice and the default expensive closures are
# dropped in favor of a minimal setup so the run completes in a few minutes
# on a CPU.
#
# NOTE: the first run downloads initial conditions (ECCO4 monthly snapshot),
# bathymetry (ETOPO), and atmospheric forcing (JRA55, ~GB) into the artifact
# cache. Subsequent runs reuse the cache and are much faster.
# =============================================================================

arch = CPU()

# --- Coarse global grid (4° lat-lon, 20 vertical levels) ---
Nx, Ny, Nz = 90, 38, 20
depth      = 6000meters

underlying_grid = LatitudeLongitudeGrid(arch;
                                        size      = (Nx, Ny, Nz),
                                        z         = (-depth, 0),
                                        halo      = (7, 7, 7),
                                        latitude  = (-75, 75),
                                        longitude = (0, 360))

# Real bathymetry interpolated onto our coarse grid
bottom_height = regrid_bathymetry(underlying_grid; minimum_depth         = 10,
                                                   interpolation_passes  = 5,
                                                   major_basins          = 3)
grid = ImmersedBoundaryGrid(underlying_grid, GridFittedBottom(bottom_height); active_cells_map=true)

# --- Ocean (minimal closure for laptop speed) ---
closure = simplified_ocean_closure()
ocean   = ocean_simulation(grid; closure)

# --- Initial conditions from ECCO ---
date   = DateTime(1993, 1, 1)
T_meta = Metadatum(:temperature; date, dataset=ECCO4Monthly())
S_meta = Metadatum(:salinity;    date, dataset=ECCO4Monthly())

# Pull ECCO snapshots directly from the public NumericalEarthArtifacts mirror.
# (ClimaOcean's `download_with_fallback` would also work but tries the primary
# ECCO server first, emitting a loud warning + stack trace when ECCO_USERNAME
# isn't set. This bypass goes straight to the mirror — same files, no noise.)
const ARTIFACTS_BASE_URL = "https://github.com/NumericalEarth/NumericalEarthArtifacts/releases/download/data-v1/"

function download_from_mirror(metadata)
    filepath = joinpath(metadata.dir, metadata.filename)
    isfile(filepath) && return filepath
    mkpath(dirname(filepath))
    url = ARTIFACTS_BASE_URL * basename(filepath)
    @info "Downloading $(basename(filepath)) from NumericalEarthArtifacts mirror…"
    Downloads.download(url, filepath)
    return filepath
end

foreach(download_from_mirror, (T_meta, S_meta))
set!(ocean.model, T=T_meta, S=S_meta)

# --- Atmospheric forcing (repeat-year JRA55 reanalysis) ---
atmosphere = JRA55PrescribedAtmosphere(arch; time_indices_in_memory=10)
radiation  = JRA55PrescribedRadiation(arch; time_indices_in_memory=10)

# --- Coupled ocean–atmosphere model (no dynamic sea ice, for simplicity) ---
# OceanOnlyModel couples the ocean to the prescribed atmosphere/radiation and
# defaults sea ice to a FreezingLimitedOceanTemperature constraint (a freezing
# limiter, not a dynamic sea-ice model) so polar cells stay above freezing.
coupled_model = OceanOnlyModel(ocean; atmosphere, radiation)

# --- Simulation ---
simulation = Simulation(coupled_model; Δt=30minutes, stop_time=10days)
add_callback!(simulation, Progress(), IterationInterval(20))

# --- Output: surface fields ---
ocean_outputs = merge(ocean.model.tracers, ocean.model.velocities)

ocean.output_writers[:surface] = NetCDFWriter(ocean.model, ocean_outputs;
    schedule           = TimeInterval(1day),
    filename           = "global_ocean_surface.nc",
    indices            = (:, :, ocean.model.grid.Nz),
    overwrite_existing = true)

run!(simulation)
