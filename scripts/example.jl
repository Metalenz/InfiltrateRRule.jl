using Infiltrator
using InfiltrateRRule

using ChainRulesCore
import ChainRulesCore: rrule

using Zygote

@infiltrate_rrule function f(x,y,z)
    return x + y * z
end

# Δ, the seed to the pullback, will always be 1 because the functions are linear in x and
#   the inner call stands in for `x` in the outer call
Zygote.gradient((x,y,z) -> f(f(x,y,z),y,z), 3.0, 4.0, 5.0)


@infiltrate_rrule function g(x,y)
    return hypot(x,y)^2
end

# Δ for the inner call should be 50, since (3^2+4^2) = 25, and the outer call is (25^2 + 4^2)
Zygote.gradient((x,y) -> g(g(x,y),y), 3.0, 4.0)


module Foo
    using InfiltrateRRule
    using Infiltrator
    using ChainRulesCore
    import ChainRulesCore: rrule

    my_internal_value = π

    @infiltrate_rrule function b(x,y)
        return sin(x^2 + y^2)
    end

    export b
end

using .Foo

# When in the Infiltrator REPL, you're in the `Foo` namespace, so the following works,
#   without needing a Foo.my_internal_value prefix:
# infil> my_internal_value
# π = 3.1415926535897...
Zygote.gradient((x,y) -> b(b(x,y),y), 3.0, 4.0)
