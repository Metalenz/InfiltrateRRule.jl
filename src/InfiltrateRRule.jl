module InfiltrateRRule

using MacroTools

macro infiltrate_rrule(expr...)
    return :(infiltrate_rule(@__MODULE__, $(esc(expr))))
end

function infiltrate_rule(m, expr)
    def = splitdef(first(expr))     # Get the function as a dictionary of expressions
    name = def[:name]               # Name of the function

    # We want a second copy of the function to call with `rrule_via_ad`. For this, we just
    #   change the name to include an underscore prefix
    diffname = Symbol("_$name")     # The differentiable version of the function
    def_new = deepcopy(def)
    def_new[:name] = diffname

    origdef = combinedef(def)
    diffabledef = combinedef(def_new)
    rrule_def = combinedef(add_infiltrate(def)) # Get the rrule

    @eval m $origdef
    @eval m $diffabledef
    @eval m $rrule_def
end


function add_infiltrate(split_def)
    split_def = deepcopy(split_def)

    fname = split_def[:name]        # Name of the original function
    funtype = :(::typeof($fname))   # Need typeof for dispatch

    ufname = Symbol("_$fname")      # Name of the AD version of our function

    rrule_via_ad_args = deepcopy(split_def[:args])

    # sets split_def[:args] to have (cfg, typeof(f), args..) as its function arguments
    pushfirst!(split_def[:args], funtype)
    pushfirst!(split_def[:args], :(cfg::RuleConfig{>:HasReverseMode}))

    # Rename the function to rrule
    split_def[:name] = :rrule

    # our `rrule_via_ad` should have the same arguments as the rrule, plus the dispatch and
    #   config
    pushfirst!(rrule_via_ad_args, ufname)
    pushfirst!(rrule_via_ad_args, :cfg)

    # The function body should `rrule_via_ad` the copy of the function, but @infiltrate
    #   right before actually calling the pullback. The primal and all function arguments
    #   are available in the Infiltrator instance
    split_def[:body] = quote
        Ω, pb = rrule_via_ad($(rrule_via_ad_args...))
        function _inner_pb(Δ)
            @infiltrate
            return pb(Δ)
        end
        return Ω, _inner_pb
    end
    return split_def
end

export @infiltrate_rrule

end # module
