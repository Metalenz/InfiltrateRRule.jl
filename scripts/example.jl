using Infiltrator
using InfiltrateRRule

using ChainRulesCore
import ChainRulesCore: rrule

using Zygote

@infiltrate_rrule function f(x,y,z)
	return x + y * z
end

Zygote.gradient((x,y,z) -> f(f(x,y,z),y,z), 3.0, 4.0, 5.0)


@infiltrate_rrule function f(x,y)
    return hypot(x,y)^2
end


module Foo
    using InfiltrateRRule
    using Infiltrator
    using ChainRulesCore
    import ChainRulesCore: rrule

    @infiltrate_rrule function b(a,b,c)
        return a * b + c
    end

    export b
end

