# InfiltrateRRule.jl

`InfiltrateRRule.jl` is a utility for inspect automatically derived `rrule`s with `ChainRulesCore`. 

Consider the following function we would like to differentiate through with `Zygote.jl`:

```julia
f(a,b) = a^2 + b^2
```

`Zygote.jl` can easily differentiate through this function which comprises only functions for which we have exisitng `rrule`s. Crucially, we do not need to write a custom `rrule`. In spite of this, it could be useful to inspect the differential passed *into* `f`, or perhaps verify that the returned value from the pullback matches what we expect among other calculations around the pullback. 

`Infiltrator.jl` is one tool for doing this type of inspection: by inserting an `@infiltrator` line into our code. When the `@infiltrator` line is reached, execution halts and an interactive REPL is opened at that line.

If we have a custom `rrule` for `f` written, we can just directly insert `@infiltrator` into the pullback. However, for an `rrule` which is automatically derived, we can't just insert the `@infiltrator` call since it is generated programmatically.  

`InfiltrateRRule.jl` exports the macro `@infiltrate_rrule` which enables easy inspection of automatically generated pullbacks. After annotating a function with the macro, calls to the pullback will open an `Infiltrator.jl` instance where the pullback input `Δ` are available along with inputs to the primal calculation.

## Example

The code below is a MWE for using `InfiltrateRRule.jl`. When executing the code below, an interactive `Infiltrator.jl` session will open when the pullback is called. 

```julia
using Infiltrator

using ChainRulesCore
import ChainRulesCore: rrule

using InfiltrateRRule

using Zygote

@infiltrate_rrule function f(x,y)
    return x^2 + y^2
end

julia> Zygote.gradient((x,y) -> f(f(x,y),y), 3.0, 4.0)
Infiltrating (::var"#_inner_pb#15"{Zygote.ZygoteRuleConfig{Zygote.Context}, Float64, Float64, Zygote.var"#ad_pullback#41"{typeof(_f), Tuple{Float64, Float64}, typeof(∂(_f))}, Float64})(Δ::Float64) at InfiltrateRRule.jl:57:
```

To inspect the seed to the pullback for the *outer* call to `f` and its local variables, try
```julia
infil> Δ # The seed to the pullback
1.0

infil> x # result of the inner f call
25.0

infil> y
4.0
```
To move onto the second call to `f`, we simply `@continue` and repeat the procedure

```julia
infil> @continue

Infiltrating (::var"#_inner_pb#15"{Zygote.ZygoteRuleConfig{Zygote.Context}, Float64, Float64, Zygote.var"#ad_pullback#41"{typeof(_f), Tuple{Float64, Float64}, typeof(∂(_f))}, Float64})(Δ::Float64) at InfiltrateRRule.jl:57:

infil> Δ # derivative of x^2 when x = 25, fed into the pullback for the inner `f` call
50.0

infil> x
3.0

infil> y
4.0
```

To remove the `Infiltrator.jl` instances, we just remove the `@infiltrate_rrule` annotation (and probably have to restart the REPL). 

## How it Works

The macro works by generating an alternative copy of the function which is used for dispatching `rrule_via_ad` and a custom `rrule` that wraps calls to the pullback. The macro generates roughly the equivalent code below:

```julia
f(x,y) = x^2+y^2

_f(x,y) = x^2+y^2

function rrule(cfg::RuleConfig{>:HasReverseMode}, ::typeof(f), x, y)
    Ω, pb = rrule_via_ad(cfg, _f, x, y)
    function _inner_pb(Δ)
        @infiltrate
        pb(Δ)
    end 
    return Ω, _inner_pb
end
```

Note that we do need the second copy of the function, `_f`. If we didn't, we would call `rrule_via_ad(cfg, f, x, y)`, which actually just calls the same `rrule`, leading to a stack overflow. 

## Remaining Work

1. Automatically generated internal function name for the second copy instead of using `_NAME_OF_ORIGINAL_FUNCTION`, since that name may be taken
2. Conditional execution of `Infiltrator` since it relies on the user having `Infiltrator` in whatever namespace the macro is used. `Requires.jl` might be useful here
3. Local variables within `f` aren't accessible because they live within `f`, not the `rrule`. They should be reproducible by manually re-running the calculations in the primal, but that's a fair amount of redundant computation.
4. A better name!
