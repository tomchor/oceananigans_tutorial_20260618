using Oceananigans
using GLMakie
using Printf
using Statistics: quantile

# =============================================================================
# Animate baroclinic_adjustment.jl output.
# Run baroclinic_adjustment.jl first to produce the .nc files.
# =============================================================================

# --- Load timeseries ---
b_ts = FieldTimeSeries("baroclinic_adjustment_surface.nc", "b")
ζ_ts = FieldTimeSeries("baroclinic_adjustment_surface.nc", "ζ")
B_ts = FieldTimeSeries("baroclinic_adjustment_zonal.nc",   "b")
U_ts = FieldTimeSeries("baroclinic_adjustment_zonal.nc",   "u")
V_ts = FieldTimeSeries("baroclinic_adjustment_zonal.nc",   "v")

times = b_ts.times
Nt    = length(times)

# --- Colormap limits ---
b_min, b_max = extrema(interior(b_ts))
ζ_lim        = max(quantile(abs.(vec(interior(ζ_ts))), 0.99), eps())
U_lim        = max(quantile(abs.(vec(interior(U_ts))), 0.99), eps())
V_lim        = max(quantile(abs.(vec(interior(V_ts))), 0.99), eps())

# --- Figure layout ---
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

b_plt = @lift view(b_ts[$n], :, :, 1)
ζ_plt = @lift view(ζ_ts[$n], :, :, 1)
U_plt = @lift view(U_ts[$n], 1, :, :)
V_plt = @lift view(V_ts[$n], 1, :, :)

hm_b = heatmap!(ax_b, b_plt; colormap=:thermal, colorrange=(b_min, b_max))
hm_ζ = heatmap!(ax_ζ, ζ_plt; colormap=:balance, colorrange=(-ζ_lim, ζ_lim))
hm_U = heatmap!(ax_U, U_plt; colormap=:balance, colorrange=(-U_lim, U_lim))
hm_V = heatmap!(ax_V, V_plt; colormap=:balance, colorrange=(-V_lim, V_lim))

Colorbar(fig[1, 2], hm_b; label="b (m s⁻²)")
Colorbar(fig[1, 4], hm_ζ; label="ζ (s⁻¹)")
Colorbar(fig[2, 2], hm_U; label="u (m s⁻¹)")
Colorbar(fig[2, 4], hm_V; label="v (m s⁻¹)")

# --- Record animation ---
record(fig, "baroclinic_adjustment.mp4", 1:Nt; framerate=10) do nn
    n[] = nn
end

@info "Animation saved to baroclinic_adjustment.mp4"
