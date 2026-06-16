using Oceananigans
import NCDatasets   # loads Oceananigans' NetCDF extension
using GLMakie
using Printf
using Statistics: quantile

# =============================================================================
# Animate baroclinic_adjustment.jl output.
# Run baroclinic_adjustment.jl first to produce the .nc files.
#
# Each field is read back as a FieldTimeSeries and handed straight to heatmap!.
# Oceananigans' Makie recipe pulls the coordinates from the field and drops the
# singleton (surface-slice / zonally-averaged) dimension automatically, so we
# never extract or pass nodes ourselves.
# =============================================================================

#+++ Load timeseries
b_ts = FieldTimeSeries("baroclinic_adjustment_surface.nc", "b")   # surface buoyancy
ζ_ts = FieldTimeSeries("baroclinic_adjustment_surface.nc", "ζ")   # surface vorticity
U_ts = FieldTimeSeries("baroclinic_adjustment_zonal.nc",   "u")   # zonal-mean zonal velocity
V_ts = FieldTimeSeries("baroclinic_adjustment_zonal.nc",   "v")   # zonal-mean meridional velocity

times = b_ts.times
Nt    = length(times)
#---

#+++ Colormap limits
b_min, b_max = extrema(interior(b_ts))
ζ_lim        = max(quantile(abs.(vec(interior(ζ_ts))), 0.99), eps())
# Shared limit so one colorbar serves both zonal-mean velocity panels
UV_lim       = max(quantile(abs.(vec(interior(U_ts))), 0.99), quantile(abs.(vec(interior(V_ts))), 0.99), eps())
#---

#+++ Figure layout
fig = Figure(size=(1300, 900))

n = Observable(1)
title_str = @lift @sprintf("Baroclinic adjustment  —  t = %.1f days", times[$n] / 86400)
Label(fig[0, :], title_str, fontsize=20)

kwargs_xy = (xlabel="x (m)", ylabel="y (m)", aspect=1)
kwargs_yz = (xlabel="y (m)", ylabel="z (m)", aspect=2)

ax_b = Axis(fig[1, 1]; title="Surface buoyancy  b",                kwargs_xy...)
ax_ζ = Axis(fig[1, 3]; title="Surface vorticity  ζ = ∂ₓv − ∂ᵧu",   kwargs_xy...)
ax_U = Axis(fig[2, 1]; title="Zonal-mean zonal velocity  ⟨u⟩",      kwargs_yz...)
ax_V = Axis(fig[2, 3]; title="Zonal-mean meridional velocity  ⟨v⟩", kwargs_yz...)

# Hand the fields straight to heatmap!; the recipe supplies the coordinates.
b_plt = @lift b_ts[$n]
ζ_plt = @lift ζ_ts[$n]
U_plt = @lift U_ts[$n]
V_plt = @lift V_ts[$n]

hm_b = heatmap!(ax_b, b_plt; colormap=:thermal, colorrange=(b_min, b_max))
hm_ζ = heatmap!(ax_ζ, ζ_plt; colormap=:balance, colorrange=(-ζ_lim, ζ_lim))
hm_U = heatmap!(ax_U, U_plt; colormap=:balance, colorrange=(-UV_lim, UV_lim))
hm_V = heatmap!(ax_V, V_plt; colormap=:balance, colorrange=(-UV_lim, UV_lim))

Colorbar(fig[1, 2], hm_b; label="b (m s⁻²)", height=Relative(0.8))
Colorbar(fig[1, 4], hm_ζ; label="ζ (s⁻¹)",  height=Relative(0.8))
# One shared colorbar to the right of the right-hand zonal-mean velocity panel
Colorbar(fig[2, 4], hm_U; label="u, v (m s⁻¹)", height=Relative(0.8))

# Size the two panel columns purely by ratio (not by content) so the left and
# right panels in each row come out the same width.
colsize!(fig.layout, 1, Auto(false))
colsize!(fig.layout, 3, Auto(false))
#---

#+++ Record animation
record(fig, "baroclinic_adjustment.mp4", 1:Nt; framerate=10) do nn
    n[] = nn
end

@info "Animation saved to baroclinic_adjustment.mp4"
#---
