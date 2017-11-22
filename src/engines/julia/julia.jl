export messagePassingAlgorithm

include("message_passing.jl")
include("algorithms.jl")

include("update_rules/equality.jl")
include("update_rules/addition.jl")
include("update_rules/multiplication.jl")
include("update_rules/gaussian_mean_variance.jl")
include("update_rules/gaussian_mean_precision.jl")
include("update_rules/log_normal.jl")
include("update_rules/gamma.jl")
include("update_rules/wishart.jl")
include("update_rules/bernoulli.jl")
include("update_rules/categorical.jl")
include("update_rules/beta.jl")
include("update_rules/dirichlet.jl")
include("update_rules/gaussian_mixture.jl")
include("update_rules/sigmoid.jl")
