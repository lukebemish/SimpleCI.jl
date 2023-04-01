module SimpleCI

using HumanReadableSExpressions
using StructTypes
import StructTypes: StructType

mutable struct Env
    version::Union{Nothing, String}
end

abstract type Step end
StructTypes.StructType(::Type{Step}) = StructTypes.AbstractType()
StructTypes.subtypekey(::Type{Step}) = :type

struct GradleStep <: Step
    type::String
    name::String
    tasks::Vector{String}
    workingdir::String
end

function StructTypes.construct(::Type{GradleStep}, type, name, tasks, workingdir)
    GradleStep(type, name, tasks, something(workingdir, "."))
end
StructTypes.StructType(::Type{GradleStep}) = StructTypes.Struct()

name(x::GradleStep) = x.name
workingdir(x::GradleStep) = x.workingdir

buildRegex = r"teamcity\[buildNumber \'(.*?)\']"

function runstep(step::GradleStep, env::Env)
    out = read(setenv(`./gradlew $(join(step.tasks, ' '))`, ("TEAMCITY_VERSION"=>"<fake-teamcity>",)), String)
    v = match(buildRegex, out)
    if v !== nothing
        env.version = v[1]
    end
end

struct ShellStep <: Step
    type::String
    name::String
    script::String
    workingdir::String
end

function StructTypes.construct(::Type{ShellStep}, type, name, script, workingdir)
    ShellStep(type, name, script, something(workingdir, "."))
end
StructTypes.StructType(::Type{ShellStep}) = StructTypes.Struct()

name(x::ShellStep) = x.name
workingdir(x::ShellStep) = x.workingdir
function runstep(step::ShellStep, env::Env)
    run(`$(step.script)`)
end

struct TagVersionStep <: Step
    type::String
    name::String
    ignoreexisting::Bool
end

function StructTypes.construct(::Type{TagVersionStep}, type, name, ignoreexisting)
    TagVersionStep(type, name, something(ignoreexisting, false))
end
StructTypes.StructType(::Type{TagVersionStep}) = StructTypes.Struct()

name(x::TagVersionStep) = x.name
workingdir(x::TagVersionStep) = "."
function runstep(step::TagVersionStep, env::Env)
    if env.version === nothing
        error("No version found in previous steps.")
    end
    if success(`git rev-parse $(env.version)`)
        if step.ignoreexisting
            println("Version $(env.version) already exists.")
            return
        else
            error("Version $(env.version) already exists.")
        end
    end
    run(`git tag -a $(env.version) -m ""`)
    run(`git push origin --tags`)
end

StructTypes.subtypes(::Type{Step}) = (gradle=GradleStep,shell=ShellStep,tagversion=TagVersionStep)

struct Config
    steps::Vector{Step}
    filter::String
end

StructTypes.StructType(::Type{Config}) = StructTypes.Struct()
function StructTypes.construct(::Type{Config}, steps, filter)
    Config(steps, something(filter, "(?i)^\\[no-?_?ci"))
end

function main(; configpath = "config.hrse")
    out = read(`git log -1 --pretty=%B`, String)
    config = readhrse(joinpath(".simpleci.jl/", configpath), type = Config)
    if match(Regex(config.filter), strip(out)) !== nothing
        println("Skipping no-ci commit.")
        return
    end
    rootdir = pwd()
    env = Env(nothing)
    for step in config.steps
        println("Running step $(name(step))...")
        cd(joinpath(rootdir, workingdir(step)))
        runstep(step, env)
        cd(rootdir)
    end
end

end # module SimpleCI
