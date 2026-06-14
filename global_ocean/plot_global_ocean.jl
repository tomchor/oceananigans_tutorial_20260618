using Oceananigans
using GLMakie
using Printf
using Statistics: quantile

# =============================================================================
# Animate coarse_global_ocean.jl output.
# Run coarse_global_ocean.jl first to produce coarse_global_ocean_surface.nc.
# =============================================================================

# --- Load surface timeseries ---
T_ts = FieldTimeSeries("coarse_global_ocean_surface.nc", "T")
S_ts = FieldTimeSeries("coarse_global_ocean_surface.nc", "S")
u_ts = FieldTimeSeries("coarse_global_ocean_surface.nc", "u")
v_ts = FieldTimeSeries("coarse_global_ocean_surface.nc", "v")

times = T_ts.times
Nt    = length(times)

# --- Colormap limits (ignore NaN-filled land cells) ---
T_clean = filter(isfinite, vec(interior(T_ts)))
S_clean = filter(isfinite, vec(interior(S_ts)))
u_clean = filter(isfinite, vec(interior(u_ts)))
v_clean = filter(isfinite, vec(interior(v_ts)))

T_min, T_max = quantile(T_clean, 0.02), quantile(T_clean, 0.98)
S_min, S_max = quantile(S_clean, 0.02), quantile(S_clean, 0.98)
u_lim = max(quantile(abs.(u_clean), 0.99), eps())
v_lim = max(quantile(abs.(v_clean), 0.99), eps())

# --- Figure layout ---
fig = Figure(size=(1400, 900))

n = Observable(1)
title_str = @lift @sprintf("Coarse global ocean  —  t = %.1f days", times[$n] / 86400)
Label(fig[0, :], title_str, fontsize=20)

kwargs = (xlabel="longitude (°)", ylabel="latitude (°)", aspect=2)

ax_T = Axis(fig[1, 1]; title="Surface temperature  T",         kwargs...)
ax_S = Axis(fig[1, 3]; title="Surface salinity  S",            kwargs...)
ax_u = Axis(fig[2, 1]; title="Surface zonal velocity  u",      kwargs...)
ax_v = Axis(fig[2, 3]; title="Surface meridional velocity  v", kwargs...)

T_plt = @lift view(T_ts[$n], :, :, 1)
S_plt = @lift view(S_ts[$n], :, :, 1)
u_plt = @lift view(u_ts[$n], :, :, 1)
v_plt = @lift view(v_ts[$n], :, :, 1)

hm_T = heatmap!(ax_T, T_plt; colormap=:thermal, colorrange=(T_min, T_max),     nan_color=:gray)
hm_S = heatmap!(ax_S, S_plt; colormap=:haline,  colorrange=(S_min, S_max),     nan_color=:gray)
hm_u = heatmap!(ax_u, u_plt; colormap=:balance, colorrange=(-u_lim, u_lim),    nan_color=:gray)
hm_v = heatmap!(ax_v, v_plt; colormap=:balance, colorrange=(-v_lim, v_lim),    nan_color=:gray)

Colorbar(fig[1, 2], hm_T; label="T (°C)")
Colorbar(fig[1, 4], hm_S; label="S (psu)")
Colorbar(fig[2, 2], hm_u; label="u (m s⁻¹)")
Colorbar(fig[2, 4], hm_v; label="v (m s⁻¹)")

# --- Record animation ---
record(fig, "coarse_global_ocean.mp4", 1:Nt; framerate=4) do nn
    n[] = nn
end

@info "Animation saved to coarse_global_ocean.mp4"
