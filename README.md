# Oceananigans Tutorial

Tutorial materials for a hands-on **Oceananigans** session, hosted by:

> **Physical Oceanography Department — CICESE**
> Julio Sheinbaum's group
> Thursday, June 18 2026 — Ensenada, Baja California, Mexico

## About the tutorial

This hands-on tutorial introduces [Oceananigans.jl](https://github.com/CliMA/Oceananigans.jl) — a Julia package for fast, GPU-friendly fluid simulations — through a series of self-contained geophysical and atmospheric flow examples. The aim is to show how modern programming tools can bridge the gap between ease of use and the extreme performance required for high-resolution fluid simulations.

## This repository

Each subdirectory is a self-contained example that can be run interactively in a Julia REPL or executed as a script. Together they showcase a range of Oceananigans (and Breeze) capabilities: nonhydrostatic flow, immersed boundaries, stratified shear instabilities, turbulence closures, and moist atmospheric dynamics.

| Directory | Description |
|---|---|
| `hill_flow/` | 2D nonhydrostatic flow past a Gaussian hill using the immersed boundary method |
| `kelvin_helmholtz/` | 2D Kelvin-Helmholtz instability in a stratified shear layer |
| `free_convection/` | 3D atmospheric free convection heated from below with dynamic Smagorinsky closure |
| `rain_over_ocean/` | 2D precipitating shallow cumulus convection (RICO case) using Breeze's anelastic model with one-moment cloud microphysics |
| `baroclinic_adjustment/` | 3D hydrostatic free-surface model of an unstable meridional buoyancy front on a β-plane, equilibrating via mesoscale eddies |
| `global_ocean/` | Coarsened (4°) coupled ocean–atmosphere global simulation using ClimaOcean, initialized from ECCO and forced by JRA55 reanalysis |

Each directory contains a simulation script (e.g. `hill_flow.jl`) and a matching plot script (e.g. `plot_hill_flow.jl`). Run the simulation first to produce the output file, then run the plot script to generate the animation.

## Prerequisites

- [Julia](https://julialang.org/downloads/) (1.12 or later recommended)
- Most examples share the top-level `Project.toml`. Install its dependencies in one step:

```julia
using Pkg
Pkg.instantiate()
```

This will install [Oceananigans.jl](https://github.com/CliMA/Oceananigans.jl), [GLMakie.jl](https://github.com/MakieOrg/Makie.jl), [Oceanostics.jl](https://github.com/tomchor/Oceanostics.jl), and other dependencies automatically.

Two examples have their own self-contained Julia environments (because they pull in heavier dependencies that the rest of the tutorial doesn't need):

- `rain_over_ocean/` — needs [Breeze.jl](https://github.com/NumericalEarth/Breeze.jl), CloudMicrophysics, AtmosphericProfilesLibrary.
- `global_ocean/` — needs [ClimaOcean.jl](https://github.com/CliMA/ClimaOcean.jl). The first run also downloads ECCO initial conditions, ETOPO bathymetry, and JRA55 atmospheric reanalysis (~GB total) into the artifact cache; subsequent runs reuse the cache.

For those two, activate the folder's project before running:

```julia
using Pkg
Pkg.activate("global_ocean")   # or "rain_over_ocean"
Pkg.instantiate()
```

## Running the examples

Each script can be run from the Julia REPL (recommended for interactive exploration) or from the terminal:

```bash
julia --project=. kelvin_helmholtz/kelvin_helmholtz.jl              # run simulation
julia --project=. kelvin_helmholtz/plot_kelvin_helmholtz.jl         # produce animation
```
