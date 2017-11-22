export LogNormal

"""
Description:

    A log-normal node with location-scale parameterization:

    f(out,m,s) = logN(out|m, s)

Interfaces:

    1. out
    2. m (location)
    3. s (squared scale)

Construction:

    LogNormal(out, m, s, id=:some_id)
"""
type LogNormal <: SoftFactor
    id::Symbol
    interfaces::Vector{Interface}
    i::Dict{Symbol,Interface}

    function LogNormal(out::Variable, m::Variable, s::Variable; id=generateId(LogNormal))
        self = new(id, Array(Interface, 3), Dict{Symbol,Interface}())
        addNode!(currentGraph(), self)
        self.i[:out] = self.interfaces[1] = associate!(Interface(self), out)
        self.i[:m] = self.interfaces[2] = associate!(Interface(self), m)
        self.i[:s] = self.interfaces[3] = associate!(Interface(self), s)

        return self
    end
end

slug(::Type{LogNormal}) = "logN"

ProbabilityDistribution(::Type{Univariate}, ::Type{LogNormal}; m::Float64=1.0, s::Float64=1.0) = ProbabilityDistribution{Univariate, LogNormal}(Dict(:m=>m, :s=>s))
ProbabilityDistribution(::Type{LogNormal}; m::Float64=1.0, s::Float64=1.0) = ProbabilityDistribution{Univariate, LogNormal}(Dict(:m=>m, :s=>s))

dims(dist::ProbabilityDistribution{Univariate, LogNormal}) = 1

vague(::Type{LogNormal}) = ProbabilityDistribution(Univariate, LogNormal, m=1.0, s=huge)

unsafeMean(dist::ProbabilityDistribution{Univariate, LogNormal}) = exp(dist.params[:m] + 0.5*dist.params[:s])
unsafeLogMean(dist::ProbabilityDistribution{Univariate, LogNormal}) = dist.params[:m]

unsafeVar(dist::ProbabilityDistribution{Univariate, LogNormal}) = (exp(dist.params[:s]) - 1.0)*exp(2.0*dist.params[:m] + dist.params[:s])
unsafeLogVar(dist::ProbabilityDistribution{Univariate, LogNormal}) = dist.params[:s]

unsafeCov(dist::ProbabilityDistribution{Univariate, LogNormal}) = unsafeVar(dist)
unsafeLogCov(dist::ProbabilityDistribution{Univariate, LogNormal}) = dist.params[:s]

isProper(dist::ProbabilityDistribution{Univariate, LogNormal}) = (dist.params[:s] > 0.0)

# Entropy functional
function differentialEntropy(dist::ProbabilityDistribution{Univariate, LogNormal})
    0.5*log(dist.params[:s]) +
    dist.params[:m] + 0.5 +
    0.5*log(2*pi)
end

# Average energy functional
function averageEnergy(::Type{LogNormal}, marg_out::ProbabilityDistribution{Univariate}, marg_m::ProbabilityDistribution{Univariate}, marg_s::ProbabilityDistribution{Univariate})
    unsafeLogMean(marg_out) +
    0.5*log(2*pi) +
    0.5*unsafeLogMean(marg_s) +
    0.5*unsafeInverseMean(marg_s)*( unsafeCov(marg_m) + unsafeLogCov(marg_out) + (unsafeLogMean(marg_out) - unsafeMean(marg_m))^2 )
end