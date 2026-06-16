using Oceananigans
import NCDatasets   # loads Oceananigans' NetCDF extension
using GLMakie
using Printf
using Statistics: quantile

# =============================================================================
# Animate global_ocean.jl output.
# Run global_ocean.jl first to produce global_ocean_surface.nc.
# =============================================================================

#+++ Load surface timeseries
T_ts = FieldTimeSeries("global_ocean_surface.nc", "T")
S_ts = FieldTimeSeries("global_ocean_surface.nc", "S")
u_ts = FieldTimeSeries("global_ocean_surface.nc", "u")
v_ts = FieldTimeSeries("global_ocean_surface.nc", "v")

times = T_ts.times
Nt    = length(times)

# Surface fields were saved with indices=(:, :, Nz), so each field keeps its
# original vertical index (k=Nz), not a reindexed k=1. Slice at that level.
k_surf = size(T_ts.grid, 3)
#---

#+++ Colormap limits (ignore NaN-filled land cells)
T_clean = filter(isfinite, vec(interior(T_ts)))
S_clean = filter(isfinite, vec(interior(S_ts)))
u_clean = filter(isfinite, vec(interior(u_ts)))
v_clean = filter(isfinite, vec(interior(v_ts)))

T_min, T_max = quantile(T_clean, 0.02), quantile(T_clean, 0.98)
S_min, S_max = quantile(S_clean, 0.02), quantile(S_clean, 0.98)
# Shared limit so one colorbar serves both velocity panels
uv_lim = max(quantile(abs.(u_clean), 0.99), quantile(abs.(v_clean), 0.99), eps())
#---

#+++ Figure layout
fig = Figure(size=(1400, 900))

n = Observable(1)
title_str = @lift @sprintf("Global ocean  —  t = %.1f days", times[$n] / 86400)
Label(fig[0, :], title_str, fontsize=20)

kwargs = (xlabel="longitude (°)", ylabel="latitude (°)", aspect=2)

ax_T = Axis(fig[1, 1]; title="Surface temperature  T",         kwargs...)
ax_S = Axis(fig[1, 3]; title="Surface salinity  S",            kwargs...)
ax_u = Axis(fig[2, 1]; title="Surface zonal velocity  u",      kwargs...)
ax_v = Axis(fig[2, 3]; title="Surface meridional velocity  v", kwargs...)

T_plt = @lift view(T_ts[$n], :, :, k_surf)
S_plt = @lift view(S_ts[$n], :, :, k_surf)
u_plt = @lift view(u_ts[$n], :, :, k_surf)
v_plt = @lift view(v_ts[$n], :, :, k_surf)

hm_T = heatmap!(ax_T, T_plt; colormap=:thermal, colorrange=(T_min, T_max),     nan_color=:gray)
hm_S = heatmap!(ax_S, S_plt; colormap=:haline,  colorrange=(S_min, S_max),     nan_color=:gray)
hm_u = heatmap!(ax_u, u_plt; colormap=:balance, colorrange=(-uv_lim, uv_lim),  nan_color=:gray)
hm_v = heatmap!(ax_v, v_plt; colormap=:balance, colorrange=(-uv_lim, uv_lim),  nan_color=:gray)

Colorbar(fig[1, 2], hm_T; label="T (°C)",       height=Relative(0.8))
Colorbar(fig[1, 4], hm_S; label="S (psu)",      height=Relative(0.8))
# One shared colorbar to the right of the v panel serves both velocity panels
Colorbar(fig[2, 4], hm_u; label="u, v (m s⁻¹)", height=Relative(0.8))

# Size the two panel columns purely by ratio (not by content) so the left and
# right panels in each row come out the same width. Without this, the fixed-aspect
# axes let Makie collapse column 1 and give all the slack to column 3.
colsize!(fig.layout, 1, Auto(false))
colsize!(fig.layout, 3, Auto(false))
#---

#+++ Record animation
record(fig, "global_ocean.mp4", 1:Nt; framerate=4) do nn
    n[] = nn
end

@info "Animation saved to global_ocean.mp4"
#---
