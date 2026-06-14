#!/usr/bin/env julia
# =============================================================================
# Run every tutorial example end-to-end (simulation + plot) in a single Julia
# session.
#
# Usage:
#   # From the shell (Julia exits when done):
#   julia --project=. run_all.jl
#
#   # From an interactive REPL (recommended — keeps the session open afterwards
#   # so you can inspect results):
#   julia> include("run_all.jl")
#
# Notes
# -----
# * Each example is `include`d into a fresh anonymous module so `const`
#   redefinitions across scripts (e.g. `const κᵛᵏ = 0.4` in several setups)
#   don't collide.
# * `rain_over_ocean/` and `coarse_global_ocean/` have their own `Project.toml`
#   files; this script activates them in-place rather than spawning new Julia
#   processes, so package precompilation is amortized across the whole run.
# * Failures in one example don't abort the rest of the run — each example is
#   guarded with try/catch and a summary is printed at the end.
# =============================================================================

using Oceananigans
using Pkg

const REPO_ROOT = @__DIR__

# Grouped by project so we only activate/instantiate each environment once.
# Within a group, examples are ordered from cheapest to most expensive.
const EXAMPLE_GROUPS = [
    "." => [
        "kelvin_helmholtz",
        "hill_flow",
        "dry_atmosphere_les",
        "free_convection",
        "baroclinic_adjustment",
    ],
    "rain_over_ocean"     => ["rain_over_ocean"],
]

function run_example(example::AbstractString)
    example_dir = joinpath(REPO_ROOT, example)
    sim_script  = joinpath(example_dir, "$(example).jl")
    plot_script = joinpath(example_dir, "plot_$(example).jl")

    sim_mod  = Module(Symbol(example, "_sim"))
    plot_mod = Module(Symbol(example, "_plot"))

    cd(example_dir) do
        @info "▶ Running simulation: $example"
        t_sim = @elapsed Base.include(sim_mod, sim_script)
        @info "  simulation finished in $(round(t_sim, digits=1)) s"

        @info "▶ Building animation: $example"
        t_plot = @elapsed Base.include(plot_mod, plot_script)
        @info "  animation finished in $(round(t_plot, digits=1)) s"
    end
end

results = Tuple{String, Bool, Float64}[]

t_total = @elapsed for (project_dir, examples) in EXAMPLE_GROUPS
    @info "═══════════════════════════════════════════════════════════"
    @info "Activating project: $project_dir"
    @info "═══════════════════════════════════════════════════════════"

    try
        Pkg.activate(joinpath(REPO_ROOT, project_dir))
        Pkg.instantiate()
    catch err
        @error "Could not activate/instantiate $project_dir — skipping its examples" exception=(err, catch_backtrace())
        for example in examples
            push!(results, (example, false, 0.0))
        end
        continue
    end

    for example in examples
        t_example = @elapsed try
            run_example(example)
            push!(results, (example, true, 0.0))
        catch err
            @error "✗ $example failed" exception=(err, catch_backtrace())
            push!(results, (example, false, 0.0))
        end
        # Stamp wall time on the just-pushed entry
        name, ok, _ = pop!(results)
        push!(results, (name, ok, t_example))
    end
end

@info "═══════════════════════════════════════════════════════════"
@info "Summary"
@info "═══════════════════════════════════════════════════════════"
for (name, ok, t) in results
    mark = ok ? "✓" : "✗"
    @info "  $mark  $(rpad(name, 25)) $(round(t, digits=1)) s"
end
@info "Total wall time: $(round(t_total / 60, digits=1)) min"
