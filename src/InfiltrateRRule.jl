module InfiltrateRRule

using MacroTools

macro infiltrate_rrule(expr...)
    return :(infiltrate_rule(@__MODULE__, $(esc(expr))))
end

function infiltrate_rule(m, expr)
    def = splitdef(first(expr))     # Get the function as a dictionary of expressions
    udef = deepcopy(def)
    udef[:name] = Symbol("_$(udef[:name])")

    base_def = make_wrapper(def)
    wrapper_def = make_wrapper(udef)
    actual_def = make_f_def(def)
    rrule_def = add_infiltrate(def) # Get the rrule

    origdef = combinedef(base_def)
    wrapdef = combinedef(wrapper_def)
    actual_def = combinedef(actual_def)
    diffabledef = combinedef(rrule_def)

    @eval m $origdef
    @eval m $wrapdef
    @eval m $actual_def
    @eval m $diffabledef
end

# Makes a function call another function with the same name but a _ prefix and the same
#   arguments.
function make_wrapper(def)
    new_def = deepcopy(def)
    name = new_def[:name]

    wrapped_name = Symbol("_$name")
    new_def[:body] = :(return $(wrapped_name)($(def[:args]...)))

    return new_def
end

# Given a function definition from `splitdef`, change the name to include a __ prefix
function make_f_def(def)
    new_def = deepcopy(def)
    new_def[:name] = Symbol("__$(def[:name])")
    return new_def
end

# Add an `rrule` for the single _ prefix version of the function. This means when we
#   remove the macro, the intended function gets defined instead of wrapping inner calls
#   that inject an @infiltrate macro
function add_infiltrate(split_def)
    split_def = deepcopy(split_def)

    fname = Symbol("_$(split_def[:name])")  # Name of the original function
    ufname = Symbol("_$fname")              # Name of the AD version of our function
    funtype = :(::typeof($fname))           # Need typeof for dispatch


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
