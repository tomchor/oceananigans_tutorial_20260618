using NCDatasets
using GLMakie
using Printf
using Statistics: quantile

# =============================================================================
# Animate baroclinic_adjustment.jl output.
# Run baroclinic_adjustment.jl first to produce the .nc files.
#
# We read the NetCDF output directly with NCDatasets rather than through
# Oceananigans' FieldTimeSeries. The surface fields were saved at a single
# z-level and the zonal-mean diagnostics were written with Average(…, dims=1)
# (a reduced x-dimension); the NetCDF FieldTimeSeries reader in this
# Oceananigans version does not reconstruct either of those cleanly.
# =============================================================================

# --- Surface fields: (x, y) slices at the top level, stored as (x, y, z=1, t) ---
ds_surface = NCDataset("baroclinic_adjustment_surface.nc")
xc = ds_surface["x_caa"][:]           # x cell centers (b)
yc = ds_surface["y_aca"][:]           # y cell centers (b)
xf = ds_surface["x_faa"][:]           # x cell faces   (ζ)
yf = ds_surface["y_afa"][:]           # y cell faces   (ζ)
b_data = ds_surface["b"][:, :, 1, :]  # (x, y, time)
ζ_data = ds_surface["ζ"][:, :, 1, :]  # (x, y, time)
times  = ds_surface["time"][:]        # seconds
close(ds_surface)

# --- Zonal-mean fields: (y, z) sections, stored as (y, z, t) ---
ds_zonal = NCDataset("baroclinic_adjustment_zonal.nc")
y_centers = ds_zonal["y_aca"][:]      # y cell centers (u)
y_faces   = ds_zonal["y_afa"][:]      # y cell faces   (v)
z_centers = ds_zonal["z_aac"][:]      # z cell centers
U_data = ds_zonal["u"][:, :, :]       # (y, z, time)
V_data = ds_zonal["v"][:, :, :]       # (y, z, time)
close(ds_zonal)

Nt = length(times)

# --- Colormap limits ---
b_min, b_max = extrema(b_data)
ζ_lim        = max(quantile(abs.(vec(ζ_data)), 0.99), eps())
# Shared limit so one colorbar serves both zonal-mean velocity panels
UV_lim       = max(quantile(abs.(vec(U_data)), 0.99), quantile(abs.(vec(V_data)), 0.99), eps())

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

b_plt = @lift view(b_data, :, :, $n)
ζ_plt = @lift view(ζ_data, :, :, $n)
U_plt = @lift view(U_data, :, :, $n)
V_plt = @lift view(V_data, :, :, $n)

hm_b = heatmap!(ax_b, xc, yc, b_plt; colormap=:thermal, colorrange=(b_min, b_max))
hm_ζ = heatmap!(ax_ζ, xf, yf, ζ_plt; colormap=:balance, colorrange=(-ζ_lim, ζ_lim))
hm_U = heatmap!(ax_U, y_centers, z_centers, U_plt; colormap=:balance, colorrange=(-UV_lim, UV_lim))
hm_V = heatmap!(ax_V, y_faces,   z_centers, V_plt; colormap=:balance, colorrange=(-UV_lim, UV_lim))

Colorbar(fig[1, 2], hm_b; label="b (m s⁻²)", height=Relative(0.8))
Colorbar(fig[1, 4], hm_ζ; label="ζ (s⁻¹)",  height=Relative(0.8))
# One shared colorbar to the right of the right-hand zonal-mean velocity panel
Colorbar(fig[2, 4], hm_U; label="u, v (m s⁻¹)", height=Relative(0.8))

# Size the two panel columns purely by ratio (not by content) so the left and
# right panels in each row come out the same width.
colsize!(fig.layout, 1, Auto(false))
colsize!(fig.layout, 3, Auto(false))

# --- Record animation ---
record(fig, "baroclinic_adjustment.mp4", 1:Nt; framerate=10) do nn
    n[] = nn
end

@info "Animation saved to baroclinic_adjustment.mp4"
